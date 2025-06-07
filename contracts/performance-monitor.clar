;; Performance Monitoring Contract
;; Tracks operational efficiency and performance metrics

;; Constants
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_EQUIPMENT_NOT_FOUND (err u201))
(define-constant ERR_INVALID_METRICS (err u202))
(define-constant ERR_FUTURE_TIMESTAMP (err u203))

;; Data Variables
(define-data-var next-record-id uint u1)

;; Data Maps
(define-map performance-records
  { record-id: uint }
  {
    equipment-id: uint,
    timestamp: uint,
    efficiency-rate: uint,
    uptime-hours: uint,
    downtime-hours: uint,
    production-output: uint,
    energy-consumption: uint,
    recorded-by: principal,
    recorded-at: uint
  }
)

(define-map equipment-latest-performance
  { equipment-id: uint }
  { record-id: uint }
)

(define-map daily-performance-summary
  { equipment-id: uint, date: uint }
  {
    total-uptime: uint,
    total-downtime: uint,
    avg-efficiency: uint,
    total-output: uint,
    total-energy: uint,
    record-count: uint
  }
)

;; Public Functions
(define-public (record-performance
  (equipment-id uint)
  (timestamp uint)
  (efficiency-rate uint)
  (uptime-hours uint)
  (downtime-hours uint)
  (production-output uint)
  (energy-consumption uint))
  (let ((record-id (var-get next-record-id))
        (current-date (/ timestamp u86400))) ;; Convert to days

    ;; Validate inputs
    (asserts! (<= efficiency-rate u100) ERR_INVALID_METRICS)
    (asserts! (<= timestamp block-height) ERR_FUTURE_TIMESTAMP)
    (asserts! (> uptime-hours u0) ERR_INVALID_METRICS)

    ;; Record performance data
    (map-set performance-records
      { record-id: record-id }
      {
        equipment-id: equipment-id,
        timestamp: timestamp,
        efficiency-rate: efficiency-rate,
        uptime-hours: uptime-hours,
        downtime-hours: downtime-hours,
        production-output: production-output,
        energy-consumption: energy-consumption,
        recorded-by: tx-sender,
        recorded-at: block-height
      }
    )

    ;; Update latest performance
    (map-set equipment-latest-performance
      { equipment-id: equipment-id }
      { record-id: record-id }
    )

    ;; Update daily summary
    (update-daily-summary equipment-id current-date efficiency-rate uptime-hours downtime-hours production-output energy-consumption)

    (var-set next-record-id (+ record-id u1))
    (ok record-id)
  )
)

;; Private Functions
(define-private (update-daily-summary
  (equipment-id uint)
  (date uint)
  (efficiency uint)
  (uptime uint)
  (downtime uint)
  (output uint)
  (energy uint))
  (let ((existing-summary (default-to
    { total-uptime: u0, total-downtime: u0, avg-efficiency: u0, total-output: u0, total-energy: u0, record-count: u0 }
    (map-get? daily-performance-summary { equipment-id: equipment-id, date: date }))))

    (map-set daily-performance-summary
      { equipment-id: equipment-id, date: date }
      {
        total-uptime: (+ (get total-uptime existing-summary) uptime),
        total-downtime: (+ (get total-downtime existing-summary) downtime),
        avg-efficiency: (/ (+ (* (get avg-efficiency existing-summary) (get record-count existing-summary)) efficiency)
                          (+ (get record-count existing-summary) u1)),
        total-output: (+ (get total-output existing-summary) output),
        total-energy: (+ (get total-energy existing-summary) energy),
        record-count: (+ (get record-count existing-summary) u1)
      }
    )
  )
)

;; Read-only Functions
(define-read-only (get-performance-record (record-id uint))
  (map-get? performance-records { record-id: record-id })
)

(define-read-only (get-latest-performance (equipment-id uint))
  (match (map-get? equipment-latest-performance { equipment-id: equipment-id })
    entry (map-get? performance-records { record-id: (get record-id entry) })
    none
  )
)

(define-read-only (get-daily-summary (equipment-id uint) (date uint))
  (map-get? daily-performance-summary { equipment-id: equipment-id, date: date })
)

(define-read-only (calculate-efficiency-trend (equipment-id uint) (days-back uint))
  (let ((current-date (/ block-height u86400)))
    (fold calculate-daily-efficiency (list u0 u1 u2 u3 u4 u5 u6) u0)
  )
)

(define-private (calculate-daily-efficiency (day-offset uint) (acc uint))
  (let ((date (- (/ block-height u86400) day-offset)))
    (match (map-get? daily-performance-summary { equipment-id: u1, date: date })
      summary (+ acc (get avg-efficiency summary))
      acc
    )
  )
)
