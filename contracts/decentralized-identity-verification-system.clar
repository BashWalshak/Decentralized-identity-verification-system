;; Constants
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_VERIFIED (err u101))
(define-constant ERR_NOT_FOUND (err u102))

;; Data vars
(define-data-var contract-owner principal tx-sender)

;; Data maps
(define-map verified-users principal bool)
(define-map verification-requests principal bool)

;; Public functions
(define-public (request-verification)
    (begin
        (asserts! (is-none (map-get? verified-users tx-sender)) ERR_ALREADY_VERIFIED)
        (ok (map-set verification-requests tx-sender true))))

(define-public (approve-verification (user principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (asserts! (is-some (map-get? verification-requests user)) ERR_NOT_FOUND)
        (map-delete verification-requests user)
        (ok (map-set verified-users user true))))

(define-public (reject-verification (user principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (asserts! (is-some (map-get? verification-requests user)) ERR_NOT_FOUND)
        (map-delete verification-requests user)
        (ok true)))

;; Read-only functions
(define-read-only (is-verified (user principal))
    (default-to false (map-get? verified-users user)))

(define-read-only (has-pending-request (user principal))
    (default-to false (map-get? verification-requests user)))



;; Add to data maps
(define-map verification-expiry principal uint)

;; Add constants
(define-constant VERIFICATION_VALIDITY_PERIOD u31536000) ;; 1 year in seconds

;; New function to set expiry when approving verification
(define-public (approve-verification-with-expiry (user principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (asserts! (is-some (map-get? verification-requests user)) ERR_NOT_FOUND)
        (map-delete verification-requests user)
        (map-set verification-expiry user (+ block-height VERIFICATION_VALIDITY_PERIOD))
        (ok (map-set verified-users user true))))



