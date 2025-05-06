;; ticket-models.clar
;; Data models and constants for concert ticket marketplace

;; Error Constants
(define-constant admin-address tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-EVENT-EXISTS (err u101))
(define-constant ERR-EVENT-NOT-FOUND (err u102))
(define-constant ERR-EVENT-INACTIVE (err u103))
(define-constant ERR-PAYMENT-FAILED (err u104))
(define-constant ERR-DISTRIBUTION-COMPLETE (err u105))
(define-constant ERR-CANNOT-CLOSE-EVENT (err u106))
(define-constant ERR-CANNOT-CANCEL-EVENT (err u107))
(define-constant ERR-INVALID-SEATING (err u108))
(define-constant ERR-INVALID-END-BLOCK (err u109))
(define-constant ERR-INVALID-PRICING-MODEL (err u110))
(define-constant ERR-PRICING-REQUIRED (err u111))
(define-constant ERR-INVALID-SEATING-ZONE (err u112))
(define-constant ERR-EVENT-ENDED (err u113))
(define-constant ERR-NO-SEATS-AVAILABLE (err u114))
(define-constant ERR-TOO-MANY-ZONES (err u115))
(define-constant ERR-INVALID-ALLOCATION (err u116))
(define-constant ERR-NO-TICKET-FOUND (err u117))
(define-constant ERR-REFUND-ERROR (err u118))
(define-constant ERR-REFUND-IN-PROGRESS (err u119))
(define-constant ERR-INVALID-EVENT-INFO (err u120))
(define-constant ERR-INVALID-TICKET-PRICE (err u121))

;; Data variables
(define-data-var next-event-id uint u0)

;; Pricing models
(define-data-var pricing-models (list 10 (string-ascii 20)) (list "flat-rate" "bidding" "tiered-pricing"))

;; Define event data structure
(define-map events
  { event-id: uint }
  {
    organizer: principal,
    event-info: (string-ascii 256),
    seating-zones: (list 10 (string-ascii 64)),
    total-sales: uint,
    is-active: bool,
    allocated-zones: (list 5 uint),
    end-block: uint,
    pricing-model: (string-ascii 20),
    zone-prices: (optional (list 10 uint))
  }
)

;; Define ticket data structure
(define-map tickets
  { event-id: uint, attendee: principal }
  { zone-number: uint, ticket-price: uint }
)

;; Read-only functions
(define-read-only (get-event-data (event-id uint))
  (map-get? events { event-id: event-id })
)

(define-read-only (get-ticket-data (event-id uint) (attendee principal))
  (map-get? tickets { event-id: event-id, attendee: attendee })
)

(define-read-only (get-block-number)
  block-height
)

;; Add the delete-ticket function here
(define-public (delete-ticket (event-id uint) (attendee principal))
  (begin
    (map-delete tickets { event-id: event-id, attendee: attendee })
    (ok true)
  )
)

;; Get admin address
(define-read-only (get-admin-address)
  admin-address
)

;; Get the next event ID
(define-read-only (get-next-event-id)
  (var-get next-event-id)
)

;; Increment the event ID counter
(define-public (increment-event-id)
  (begin
    (var-set next-event-id (+ (var-get next-event-id) u1))
    (ok true)
  )
)

;; Check if a pricing model is valid
(define-read-only (is-valid-pricing-model (model (string-ascii 20)))
  (index-of (var-get pricing-models) model)
)

;; Create a new event
(define-public (create-new-event 
  (event-id uint)
  (organizer principal)
  (event-info (string-ascii 256))
  (seating-zones (list 10 (string-ascii 64)))
  (total-sales uint)
  (is-active bool)
  (allocated-zones (list 5 uint))
  (end-block uint)
  (pricing-model (string-ascii 20))
  (zone-prices (optional (list 10 uint)))
)
  (begin
    (map-set events
      { event-id: event-id }
      {
        organizer: organizer,
        event-info: event-info,
        seating-zones: seating-zones,
        total-sales: total-sales,
        is-active: is-active,
        allocated-zones: allocated-zones,
        end-block: end-block,
        pricing-model: pricing-model,
        zone-prices: zone-prices
      }
    )
    (ok true)
  )
)

;; Update ticket
(define-public (update-ticket
  (event-id uint)
  (attendee principal)
  (zone-number uint)
  (ticket-price uint)
)
  (begin
    (map-set tickets
      { event-id: event-id, attendee: attendee }
      {
        zone-number: zone-number,
        ticket-price: ticket-price
      }
    )
    (ok true)
  )
)

;; Update event sales
(define-public (update-event-sales
  (event-id uint)
  (new-sales uint)
)
  (let
    (
      (event-data (unwrap! (get-event-data event-id) ERR-EVENT-NOT-FOUND))
    )
    (map-set events
      { event-id: event-id }
      (merge event-data { total-sales: new-sales })
    )
    (ok true)
  )
)

;; Update event status
(define-public (update-event-status
  (event-id uint)
  (status bool)
)
  (let
    (
      (event-data (unwrap! (get-event-data event-id) ERR-EVENT-NOT-FOUND))
    )
    (map-set events
      { event-id: event-id }
      (merge event-data { is-active: status })
    )
    (ok true)
  )
)

;; Update event zones
(define-public (update-event-zones
  (event-id uint)
  (zones (list 5 uint))
)
  (let
    (
      (event-data (unwrap! (get-event-data event-id) ERR-EVENT-NOT-FOUND))
    )
    (map-set events
      { event-id: event-id }
      (merge event-data { allocated-zones: zones })
    )
    (ok true)
  )
)

;; Contract initialization
(begin
  (var-set next-event-id u0)
)