;; ticket-utils.clar
;; Utility functions for the concert ticket marketplace

;; Import error constants from ticket-models
(define-constant ERR-EVENT-NOT-FOUND (err u102))
(define-constant ERR-NO-TICKET-FOUND (err u117))
(define-constant ERR-REFUND-ERROR (err u118))
(define-constant ERR-REFUND-IN-PROGRESS (err u119))

;; Import traits properly (remove the "." prefix and use proper trait definition)
;; Import functions from ticket-models directly
(define-read-only (get-event-data (event-id uint))
  (contract-call? .ticket-models get-event-data event-id)
)

(define-read-only (get-ticket-data (event-id uint) (attendee principal))
  (contract-call? .ticket-models get-ticket-data event-id attendee)
)

;; Helper functions
(define-private (calculate-compensation (event-data { organizer: principal, event-info: (string-ascii 256), seating-zones: (list 10 (string-ascii 64)), total-sales: uint, is-active: bool, allocated-zones: (list 5 uint), end-block: uint, pricing-model: (string-ascii 20), zone-prices: (optional (list 10 uint)) }) (ticket-data { zone-number: uint, ticket-price: uint }) (allocated-zone-ids (list 5 uint)))
  (let
    (
      (pricing-type (get pricing-model event-data))
      (event-revenue (get total-sales event-data))
      (attendee-payment (get ticket-price ticket-data))
    )
    (if (is-eq pricing-type "flat-rate")
      attendee-payment
      (if (is-eq pricing-type "bidding")
        (/ (* attendee-payment event-revenue) event-revenue)
        (let
          (
            (price-list (unwrap! (get zone-prices event-data) u0))
            (zone-rate (unwrap! (element-at price-list (- (get zone-number ticket-data) u1)) u0))
          )
          (+ attendee-payment (* attendee-payment (/ zone-rate u100)))
        )
      )
    )
  )
)

(define-private (get-zone-payment (zone-id uint) (event-id uint))
  (let
    (
      (ticket-data (get-ticket-data event-id tx-sender))
    )
    (if (is-some ticket-data)
      (let
        ((ticket-details (unwrap! ticket-data u0)))
        (if (is-eq (get zone-number ticket-details) zone-id)
          (get ticket-price ticket-details)
          u0
        )
      )
      u0
    )
  )
)

(define-private (validate-zone-allocations (zones (list 5 uint)) (max-zone uint))
  (let
    (
      (zone-1 (element-at zones u0))
      (zone-2 (element-at zones u1))
      (zone-3 (element-at zones u2))
      (zone-4 (element-at zones u3))
      (zone-5 (element-at zones u4))
    )
    (and
      (match zone-1
        value (and (> value u0) (<= value max-zone))
        true)
      (match zone-2
        value (and (> value u0) (<= value max-zone))
        true)
      (match zone-3
        value (and (> value u0) (<= value max-zone))
        true)
      (match zone-4
        value (and (> value u0) (<= value max-zone))
        true)
      (match zone-5
        value (and (> value u0) (<= value max-zone))
        true)
    )
  )
)

(define-private (initiate-refund (event-id uint))
  (let
    ((ticket-data (get-ticket-data event-id tx-sender)))
    (match ticket-data
      ticket-details (match (as-contract (stx-transfer? (get ticket-price ticket-details) tx-sender tx-sender))
        success (begin
          ;; Modified to use contract-call instead of direct map access
          (contract-call? .ticket-models delete-ticket event-id tx-sender)
          (ok true)
        )
        error ERR-REFUND-ERROR
      )
      ERR-REFUND-IN-PROGRESS
    )
  )
)

;; Export utility functions
(define-private (initiate-refund (event-id uint))
  (let
    ((ticket-data (get-ticket-data event-id tx-sender)))
    (if (is-some ticket-data)
      (let 
        ((ticket-details (unwrap-panic ticket-data)))
        ;; Attempt the transfer with proper error handling
        (match (as-contract (stx-transfer? (get ticket-price ticket-details) tx-sender tx-sender))
          success (begin
            ;; Modified to use contract-call instead of direct map access
            (contract-call? .ticket-models delete-ticket event-id tx-sender)
          )
          error (err ERR-REFUND-ERROR)
        )
      )
      (err ERR-REFUND-IN-PROGRESS)
    )
  )
)