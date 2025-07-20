;; Student Stipend Smart Contract
;; A time-locked contract for releasing student allowances and project funds

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-insufficient-funds (err u102))
(define-constant err-student-not-found (err u103))
(define-constant err-too-early (err u104))
(define-constant err-invalid-amount (err u105))

;; Data Variables
(define-data-var next-student-id uint u1)

;; Student Data Map
(define-map students 
    { student-id: uint }
    {
        student-address: principal,
        guardian-address: principal,
        regular-allowance: uint,
        last-allowance-block: uint,
        allowance-interval: uint,
        total-deposited: uint,
        total-withdrawn: uint,
        active: bool
    }
)

;; Project Funding Requests Map
(define-map project-requests
    { student-id: uint, request-id: uint }
    {
        amount: uint,
        description: (string-ascii 256),
        requested-at: uint,
        approved: bool,
        withdrawn: bool
    }
)

;; Request Counter Map
(define-map student-request-count
    { student-id: uint }
    { count: uint }
)

;; Helper Functions

;; Get current block height
(define-read-only (get-current-block)
    block-height
)

;; Get student data
(define-read-only (get-student (student-id uint))
    (map-get? students { student-id: student-id })
)

;; Check if caller is authorized (student or guardian)
(define-private (is-authorized (student-id uint))
    (match (get-student student-id)
        student-data 
            (or 
                (is-eq tx-sender (get student-address student-data))
                (is-eq tx-sender (get guardian-address student-data))
                (is-eq tx-sender contract-owner)
            )
        false
    )
)

;; Public Functions

;; Register a new student
(define-public (register-student 
    (student-address principal)
    (guardian-address principal) 
    (regular-allowance uint)
    (allowance-interval uint)
)
    (let 
        (
            (student-id (var-get next-student-id))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> regular-allowance u0) err-invalid-amount)
        (asserts! (> allowance-interval u0) err-invalid-amount)
        
        (map-set students 
            { student-id: student-id }
            {
                student-address: student-address,
                guardian-address: guardian-address,
                regular-allowance: regular-allowance,
                last-allowance-block: block-height,
                allowance-interval: allowance-interval,
                total-deposited: u0,
                total-withdrawn: u0,
                active: true
            }
        )
        
        (map-set student-request-count
            { student-id: student-id }
            { count: u0 }
        )
        
        (var-set next-student-id (+ student-id u1))
        (ok student-id)
    )
)

;; Deposit funds for a student
(define-public (deposit-funds (student-id uint) (amount uint))
    (let 
        (
            (student-data (unwrap! (get-student student-id) err-student-not-found))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> amount u0) err-invalid-amount)
        
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        (map-set students 
            { student-id: student-id }
            (merge student-data { 
                total-deposited: (+ (get total-deposited student-data) amount)
            })
        )
        (ok true)
    )
)

;; Claim regular allowance
(define-public (claim-allowance (student-id uint))
    (let 
        (
            (student-data (unwrap! (get-student student-id) err-student-not-found))
            (blocks-since-last (- block-height (get last-allowance-block student-data)))
            (allowance-amount (get regular-allowance student-data))
            (available-funds (- (get total-deposited student-data) (get total-withdrawn student-data)))
        )
        (asserts! (get active student-data) err-not-authorized)
        (asserts! (is-authorized student-id) err-not-authorized)
        (asserts! (>= blocks-since-last (get allowance-interval student-data)) err-too-early)
        (asserts! (>= available-funds allowance-amount) err-insufficient-funds)
        
        (try! (as-contract (stx-transfer? allowance-amount tx-sender (get student-address student-data))))
        
        (map-set students 
            { student-id: student-id }
            (merge student-data { 
                last-allowance-block: block-height,
                total-withdrawn: (+ (get total-withdrawn student-data) allowance-amount)
            })
        )
        (ok allowance-amount)
    )
)

;; Request project funding
(define-public (request-project-funding 
    (student-id uint) 
    (amount uint) 
    (description (string-ascii 256))
)
    (let 
        (
            (student-data (unwrap! (get-student student-id) err-student-not-found))
            (current-count (default-to { count: u0 } (map-get? student-request-count { student-id: student-id })))
            (request-id (+ (get count current-count) u1))
        )
        (asserts! (get active student-data) err-not-authorized)
        (asserts! (is-eq tx-sender (get student-address student-data)) err-not-authorized)
        (asserts! (> amount u0) err-invalid-amount)
        
        (map-set project-requests
            { student-id: student-id, request-id: request-id }
            {
                amount: amount,
                description: description,
                requested-at: block-height,
                approved: false,
                withdrawn: false
            }
        )
        
        (map-set student-request-count
            { student-id: student-id }
            { count: request-id }
        )
        
        (ok request-id)
    )
)

;; Approve project funding (guardian or owner only)
(define-public (approve-project-funding (student-id uint) (request-id uint))
    (let 
        (
            (student-data (unwrap! (get-student student-id) err-student-not-found))
            (request-data (unwrap! (map-get? project-requests { student-id: student-id, request-id: request-id }) err-not-authorized))
        )
        (asserts! (or 
            (is-eq tx-sender (get guardian-address student-data))
            (is-eq tx-sender contract-owner)
        ) err-not-authorized)
        (asserts! (not (get approved request-data)) err-not-authorized)
        
        (map-set project-requests
            { student-id: student-id, request-id: request-id }
            (merge request-data { approved: true })
        )
        (ok true)
    )
)

;; Withdraw approved project funding
(define-public (withdraw-project-funding (student-id uint) (request-id uint))
    (let 
        (
            (student-data (unwrap! (get-student student-id) err-student-not-found))
            (request-data (unwrap! (map-get? project-requests { student-id: student-id, request-id: request-id }) err-not-authorized))
            (amount (get amount request-data))
            (available-funds (- (get total-deposited student-data) (get total-withdrawn student-data)))
        )
        (asserts! (get active student-data) err-not-authorized)
        (asserts! (is-eq tx-sender (get student-address student-data)) err-not-authorized)
        (asserts! (get approved request-data) err-not-authorized)
        (asserts! (not (get withdrawn request-data)) err-not-authorized)
        (asserts! (>= available-funds amount) err-insufficient-funds)
        
        (try! (as-contract (stx-transfer? amount tx-sender (get student-address student-data))))
        
        (map-set project-requests
            { student-id: student-id, request-id: request-id }
            (merge request-data { withdrawn: true })
        )
        
        (map-set students 
            { student-id: student-id }
            (merge student-data { 
                total-withdrawn: (+ (get total-withdrawn student-data) amount)
            })
        )
        (ok amount)
    )
)

;; Read-only functions

;; Check when next allowance can be claimed
(define-read-only (blocks-until-next-allowance (student-id uint))
    (match (get-student student-id)
        student-data
            (let 
                (
                    (blocks-since-last (- block-height (get last-allowance-block student-data)))
                    (interval (get allowance-interval student-data))
                )
                (if (>= blocks-since-last interval)
                    u0
                    (- interval blocks-since-last)
                )
            )
        u0
    )
)

;; Get available funds for student
(define-read-only (get-available-funds (student-id uint))
    (match (get-student student-id)
        student-data
            (- (get total-deposited student-data) (get total-withdrawn student-data))
        u0
    )
)

;; Get project request details
(define-read-only (get-project-request (student-id uint) (request-id uint))
    (map-get? project-requests { student-id: student-id, request-id: request-id })
)

;; Get total students registered
(define-read-only (get-total-students)
    (- (var-get next-student-id) u1)
)

;; Admin functions

;; Update student status
(define-public (update-student-status (student-id uint) (active bool))
    (let 
        (
            (student-data (unwrap! (get-student student-id) err-student-not-found))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        
        (map-set students 
            { student-id: student-id }
            (merge student-data { active: active })
        )
        (ok true)
    )
)

;; Update allowance amount
(define-public (update-allowance (student-id uint) (new-allowance uint))
    (let 
        (
            (student-data (unwrap! (get-student student-id) err-student-not-found))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> new-allowance u0) err-invalid-amount)
        
        (map-set students 
            { student-id: student-id }
            (merge student-data { regular-allowance: new-allowance })
        )
        (ok true)
    )
)