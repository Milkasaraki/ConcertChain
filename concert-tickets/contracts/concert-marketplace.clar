;; Concert ticket marketplace

;; Import constants and utility functions
(use-trait ticket-models 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.ticket-models)
(use-trait ticket-utils 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.ticket-utils)

;; Public functions
(define-public (create-event (event-info (string-ascii 256)) (seating-zones (list 10 (string-ascii 64))) (end-block uint) (pricing-model (string-ascii 20)) (zone-prices (optional (list 10 uint))))
  (let
    (
      (new-event-id (var-get next-event-id))
    )
    (asserts! (> (len event-info) u0) ERR-INVALID-EVENT-INFO)
    (asserts! (> (len seating-zones) u1) ERR-INVALID-SEATING)
    (asserts! (> end-block block-height) ERR-INVALID-END-BLOCK)
    (asserts! (is-some (index-of (var-get pricing-models) pricing-model)) ERR-INVALID-PRICING-MODEL)
    (asserts! (or (is-eq pricing-model "flat-rate") (is-eq pricing-model "bidding") (is-some zone-prices)) ERR-PRICING-REQUIRED)
    
    (map-set events
      { event-id: new-event-id }
      {
        organizer: tx-sender,
        event-info: event-info,
        seating-zones: seating-zones,
        total-sales: u0,
        is-active: true,
        allocated-zones: (list),
        end-block: end-block,
        pricing-model: pricing-model,
        zone-prices: zone-prices
      }
    )
    (var-set next-event-id (+ new-event-id u1))
    (ok new-event-id)
  )
)

(define-public (buy-ticket (event-id uint) (selected-zone uint) (payment-amount uint))
  (let
    (
      (event-data (unwrap! (get-event-data event-id) ERR-EVENT-NOT-FOUND))
      (existing-ticket (default-to { zone-number: u0, ticket-price: u0 } (get-ticket-data event-id tx-sender)))
    )
    (asserts! (> payment-amount u0) ERR-INVALID-TICKET-PRICE)
    (asserts! (get is-active event-data) ERR-EVENT-INACTIVE)
    (asserts! (>= (len (get seating-zones event-data)) selected-zone) ERR-INVALID-SEATING-ZONE)
    (asserts! (< block-height (get end-block event-data)) ERR-EVENT-ENDED)
    (try! (stx-transfer? payment-amount tx-sender (as-contract tx-sender)))
    
    (map-set tickets
      { event-id: event-id, attendee: tx-sender }
      {
        zone-number: selected-zone,
        ticket-price: (+ payment-amount (get ticket-price existing-ticket))
      }
    )
    
    (map-set events
      { event-id: event-id }
      (merge event-data { total-sales: (+ (get total-sales event-data) payment-amount) })
    )
    (ok true)
  )
)

(define-public (finalize-event (event-id uint))
  (let
    (
      (event-data (unwrap! (get-event-data event-id) ERR-EVENT-NOT-FOUND))
    )
    (asserts! (or (is-eq (get organizer event-data) tx-sender) (is-eq admin-address tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active event-data) ERR-EVENT-INACTIVE)
    (asserts! (>= block-height (get end-block event-data)) ERR-CANNOT-CLOSE-EVENT)
    
    (map-set events
      { event-id: event-id }
      (merge event-data { is-active: false })
    )
    (ok true)
  )
)

(define-public (cancel-event (event-id uint))
  (let
    (
      (event-data (unwrap! (get-event-data event-id) ERR-EVENT-NOT-FOUND))
    )
    (asserts! (is-eq (get organizer event-data) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active event-data) ERR-EVENT-INACTIVE)
    (asserts! (< block-height (get end-block event-data)) ERR-CANNOT-CANCEL-EVENT)
    
    (map-set events
      { event-id: event-id }
      (merge event-data { is-active: false })
    )
    
    (process-refund event-id)
  )
)

(define-public (allocate-zones (event-id uint) (available-zone-ids (list 5 uint)))
  (let
    (
      (event-data (unwrap! (get-event-data event-id) ERR-EVENT-NOT-FOUND))
    )
    (asserts! (is-eq admin-address tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (not (get is-active event-data)) ERR-EVENT-INACTIVE)
    (asserts! (is-eq (len (get allocated-zones event-data)) u0) ERR-DISTRIBUTION-COMPLETE)
    (asserts! (> (len available-zone-ids) u0) ERR-NO-SEATS-AVAILABLE)
    (asserts! (<= (len available-zone-ids) u5) ERR-TOO-MANY-ZONES)
    
    (asserts! (validate-zones available-zone-ids (len (get seating-zones event-data))) ERR-INVALID-ALLOCATION)
    
    (map-set events
      { event-id: event-id }
      (merge event-data { allocated-zones: available-zone-ids })
    )
    (ok true)
  )
)

(define-public (request-refund (event-id uint))
  (let
    (
      (event-data (unwrap! (get-event-data event-id) ERR-EVENT-NOT-FOUND))
      (ticket-data (unwrap! (get-ticket-data event-id tx-sender) ERR-NO-TICKET-FOUND))
      (available-zone-ids (get allocated-zones event-data))
    )
    (asserts! (is-some (index-of available-zone-ids (get zone-number ticket-data))) ERR-NO-TICKET-FOUND)
    (let
      (
        (refund-amount (calculate-refund-amount event-id))
      )
      (try! (as-contract (stx-transfer? (unwrap! refund-amount u0) tx-sender tx-sender)))
      (map-delete tickets { event-id: event-id, attendee: tx-sender })
      (ok (unwrap! refund-amount u0))
    )
  )
)

;; Contract initialization
(begin
  (var-set next-event-id u0)
)

;; Export the Component function (required for v0)
(define-public (Component)
  (ok true)
)