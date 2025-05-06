;; Main contract for concert ticket marketplace

;; Import constants and error codes from ticket-models
(define-constant admin-address (contract-call? .ticket-models get-admin-address))
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-EVENT-NOT-FOUND (err u102))
(define-constant ERR-EVENT-INACTIVE (err u103))
(define-constant ERR-INVALID-TICKET-PRICE (err u121))
(define-constant ERR-INVALID-EVENT-INFO (err u120))
(define-constant ERR-INVALID-SEATING (err u108))
(define-constant ERR-INVALID-END-BLOCK (err u109))
(define-constant ERR-INVALID-PRICING-MODEL (err u110))
(define-constant ERR-PRICING-REQUIRED (err u111))
(define-constant ERR-INVALID-SEATING-ZONE (err u112))
(define-constant ERR-EVENT-ENDED (err u113))
(define-constant ERR-CANNOT-CLOSE-EVENT (err u106))
(define-constant ERR-CANNOT-CANCEL-EVENT (err u107))
(define-constant ERR-DISTRIBUTION-COMPLETE (err u105))
(define-constant ERR-NO-SEATS-AVAILABLE (err u114))
(define-constant ERR-TOO-MANY-ZONES (err u115))
(define-constant ERR-INVALID-ALLOCATION (err u116))
(define-constant ERR-NO-TICKET-FOUND (err u117))

;; Import functions from other contracts
(define-read-only (get-event-data (event-id uint))
  (contract-call? .ticket-models get-event-data event-id)
)

(define-read-only (get-ticket-data (event-id uint) (attendee principal))
  (contract-call? .ticket-models get-ticket-data event-id attendee)
)

(define-read-only (get-next-event-id)
  (contract-call? .ticket-models get-next-event-id)
)

;; Public functions
(define-public (create-event (event-info (string-ascii 256)) (seating-zones (list 10 (string-ascii 64))) (end-block uint) (pricing-model (string-ascii 20)) (zone-prices (optional (list 10 uint))))
  (let
    (
      (new-event-id (get-next-event-id))
    )
    (asserts! (> (len event-info) u0) ERR-INVALID-EVENT-INFO)
    (asserts! (> (len seating-zones) u1) ERR-INVALID-SEATING)
    (asserts! (> end-block block-height) ERR-INVALID-END-BLOCK)
    (asserts! (is-some (contract-call? .ticket-models is-valid-pricing-model pricing-model)) ERR-INVALID-PRICING-MODEL)
    (asserts! (or (is-eq pricing-model "flat-rate") (is-eq pricing-model "bidding") (is-some zone-prices)) ERR-PRICING-REQUIRED)
    
    (try! (contract-call? .ticket-models create-new-event 
      new-event-id
      tx-sender
      event-info
      seating-zones
      u0
      true
      (list)
      end-block
      pricing-model
      zone-prices
    ))
    
    (contract-call? .ticket-models increment-event-id)
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
    
    (try! (contract-call? .ticket-models update-ticket
      event-id
      tx-sender
      selected-zone
      (+ payment-amount (get ticket-price existing-ticket))
    ))
    
    (try! (contract-call? .ticket-models update-event-sales
      event-id
      (+ (get total-sales event-data) payment-amount)
    ))
    
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
    
    (try! (contract-call? .ticket-models update-event-status
      event-id
      false
    ))
    
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
    
    (try! (contract-call? .ticket-models update-event-status
      event-id
      false
    ))
    
    (try! (contract-call? .ticket-utils process-refund event-id))
    
    (ok true)
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
    
    (asserts! (contract-call? .ticket-utils validate-zones available-zone-ids (len (get seating-zones event-data))) ERR-INVALID-ALLOCATION)
    
    (try! (contract-call? .ticket-models update-event-zones
      event-id
      available-zone-ids
    ))
    
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
        (refund-amount (contract-call? .ticket-utils calculate-refund-amount event-id))
      )
      (try! (as-contract (stx-transfer? (unwrap! refund-amount u0) tx-sender tx-sender)))
      (try! (contract-call? .ticket-models delete-ticket event-id tx-sender))
      (ok (unwrap! refund-amount u0))
    )
  )
)

;; Export the Component function (required for v0)
(define-public (Component)
  (ok true)
)