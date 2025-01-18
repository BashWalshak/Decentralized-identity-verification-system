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



;;  maps
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



;;  maps
(define-map user-tiers principal uint)

;; Add constants
(define-constant TIER-BASIC u1)
(define-constant TIER-ADVANCED u2)
(define-constant TIER-PREMIUM u3)

(define-public (set-user-tier (user principal) (tier uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (asserts! (is-verified user) ERR_NOT_FOUND)
        (ok (map-set user-tiers user tier))))



;;  maps
(define-map verification-history (tuple (user principal) (action uint)) uint)
(define-data-var history-index uint u0)

(define-constant ACTION-REQUEST u1)
(define-constant ACTION-APPROVE u2)
(define-constant ACTION-REJECT u3)

(define-public (log-verification-action (user principal) (action uint))
    (begin
        (var-set history-index (+ (var-get history-index) u1))
        (ok (map-set verification-history {user: user, action: action} (var-get history-index)))))



;;  maps
(define-map user-profiles 
    principal 
    (tuple 
        (name (string-ascii 50))
        (email (string-ascii 50))
        (country (string-ascii 2))))

(define-public (set-profile-data (name (string-ascii 50)) (email (string-ascii 50)) (country (string-ascii 2)))
    (begin
        (asserts! (is-verified tx-sender) ERR_UNAUTHORIZED)
        (ok (map-set user-profiles tx-sender {name: name, email: email, country: country}))))



;;  maps
(define-map authorized-verifiers principal bool)

(define-public (add-verifier (verifier principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (ok (map-set authorized-verifiers verifier true))))

(define-public (remove-verifier (verifier principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (ok (map-delete authorized-verifiers verifier))))



;;  maps
(define-map staked-amounts principal uint)
(define-constant MINIMUM_STAKE_AMOUNT u1000)

(define-public (stake-for-verification (amount uint))
    (begin
        (asserts! (>= amount MINIMUM_STAKE_AMOUNT) (err u103))
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (ok (map-set staked-amounts tx-sender amount))))



;;  vars
(define-data-var emergency-mode bool false)

(define-public (enable-emergency-mode)
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (ok (var-set emergency-mode true))))

(define-public (revoke-verification (user principal))
    (begin
        (asserts! (var-get emergency-mode) ERR_UNAUTHORIZED)
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (ok (map-delete verified-users user))))
