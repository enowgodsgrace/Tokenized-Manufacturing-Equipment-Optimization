;; Equipment Registration Contract
;; Records and manages industrial machinery on the blockchain

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_EQUIPMENT_EXISTS (err u101))
(define-constant ERR_EQUIPMENT_NOT_FOUND (err u102))
(define-constant ERR_INVALID_DATA (err u103))

;; Data Variables
(define-data-var next-equipment-id uint u1)

;; Data Maps
(define-map equipment-registry
  { equipment-id: uint }
  {
    owner: principal,
    manufacturer: (string-ascii 50),
    model: (string-ascii 50),
    serial-number: (string-ascii 50),
    installation-date: uint,
    location: (string-ascii 100),
    status: (string-ascii 20),
    registered-at: uint
  }
)

(define-map owner-equipment
  { owner: principal, equipment-id: uint }
  { active: bool }
)

;; Public Functions
(define-public (register-equipment
  (manufacturer (string-ascii 50))
  (model (string-ascii 50))
  (serial-number (string-ascii 50))
  (installation-date uint)
  (location (string-ascii 100)))
  (let ((equipment-id (var-get next-equipment-id)))
    (asserts! (> (len manufacturer) u0) ERR_INVALID_DATA)
    (asserts! (> (len model) u0) ERR_INVALID_DATA)
    (asserts! (> (len serial-number) u0) ERR_INVALID_DATA)

    (map-set equipment-registry
      { equipment-id: equipment-id }
      {
        owner: tx-sender,
        manufacturer: manufacturer,
        model: model,
        serial-number: serial-number,
        installation-date: installation-date,
        location: location,
        status: "active",
        registered-at: block-height
      }
    )

    (map-set owner-equipment
      { owner: tx-sender, equipment-id: equipment-id }
      { active: true }
    )

    (var-set next-equipment-id (+ equipment-id u1))
    (ok equipment-id)
  )
)

(define-public (update-equipment-status (equipment-id uint) (new-status (string-ascii 20)))
  (let ((equipment (unwrap! (map-get? equipment-registry { equipment-id: equipment-id }) ERR_EQUIPMENT_NOT_FOUND)))
    (asserts! (is-eq (get owner equipment) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> (len new-status) u0) ERR_INVALID_DATA)

    (map-set equipment-registry
      { equipment-id: equipment-id }
      (merge equipment { status: new-status })
    )
    (ok true)
  )
)

(define-public (transfer-equipment (equipment-id uint) (new-owner principal))
  (let ((equipment (unwrap! (map-get? equipment-registry { equipment-id: equipment-id }) ERR_EQUIPMENT_NOT_FOUND)))
    (asserts! (is-eq (get owner equipment) tx-sender) ERR_UNAUTHORIZED)

    ;; Remove from old owner
    (map-set owner-equipment
      { owner: tx-sender, equipment-id: equipment-id }
      { active: false }
    )

    ;; Add to new owner
    (map-set owner-equipment
      { owner: new-owner, equipment-id: equipment-id }
      { active: true }
    )

    ;; Update equipment owner
    (map-set equipment-registry
      { equipment-id: equipment-id }
      (merge equipment { owner: new-owner })
    )
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-equipment (equipment-id uint))
  (map-get? equipment-registry { equipment-id: equipment-id })
)

(define-read-only (get-next-equipment-id)
  (var-get next-equipment-id)
)

(define-read-only (is-equipment-owner (equipment-id uint) (owner principal))
  (match (map-get? owner-equipment { owner: owner, equipment-id: equipment-id })
    entry (get active entry)
    false
  )
)
