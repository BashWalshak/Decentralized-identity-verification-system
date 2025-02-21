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


;; Add new maps and constants
(define-map verification-challenges principal uint)
(define-constant CHALLENGE_DURATION u144) ;; 24 hours in blocks
(define-constant CHALLENGE_THRESHOLD u3)

(define-public (start-verification-challenge)
    (ok (map-set verification-challenges tx-sender (+ block-height CHALLENGE_DURATION))))


;; Add new maps
(define-map recovery-guardians principal (list 3 principal))
(define-map recovery-votes (tuple (user principal) (guardian principal)) bool)

(define-public (set-recovery-guardians (guardians (list 3 principal)))
    (begin
        (asserts! (is-verified tx-sender) ERR_UNAUTHORIZED)
        (ok (map-set recovery-guardians tx-sender guardians))))



;; Add new map and constants
(define-map verification-levels principal uint)
(define-constant LEVEL-BASIC u1)
(define-constant LEVEL-INTERMEDIATE u2)
(define-constant LEVEL-ADVANCED u3)

(define-public (upgrade-verification-level)
    (let ((current-level (default-to LEVEL-BASIC (map-get? verification-levels tx-sender))))
        (asserts! (< current-level LEVEL-ADVANCED) (err u105))
        (ok (map-set verification-levels tx-sender (+ current-level u1)))))


;; Add new map
(define-map endorsements (tuple (endorser principal) (endorsed principal)) uint)
(define-constant MIN_ENDORSEMENTS u3)

(define-public (endorse-identity (user principal))
    (begin
        (asserts! (is-verified tx-sender) ERR_UNAUTHORIZED)
        (asserts! (not (is-eq tx-sender user)) (err u106))
        (ok (map-set endorsements {endorser: tx-sender, endorsed: user} block-height))))


;; Add new map and constants
(define-map verification-timelocks principal uint)
(define-constant TIMELOCK_PERIOD u720) ;; 5 days in blocks
(define-constant TIMELOCK_STAKE u500)

(define-public (initiate-timelock-verification)
    (begin
        (try! (stx-transfer? TIMELOCK_STAKE tx-sender (as-contract tx-sender)))
        (ok (map-set verification-timelocks tx-sender (+ block-height TIMELOCK_PERIOD)))))

(define-public (complete-timelock-verification)
    (begin
        (asserts! (>= block-height (default-to u0 (map-get? verification-timelocks tx-sender))) ERR_UNAUTHORIZED)
        (try! (as-contract (stx-transfer? TIMELOCK_STAKE (as-contract tx-sender) tx-sender)))
        (ok (map-set verified-users tx-sender true))))


;; Add new maps
(define-map referrals principal principal)
(define-map referral-count principal uint)
(define-constant REFERRAL_LIMIT u5)

(define-public (refer-user (new-user principal))
    (begin
        (asserts! (is-verified tx-sender) ERR_UNAUTHORIZED)
        (asserts! (< (default-to u0 (map-get? referral-count tx-sender)) REFERRAL_LIMIT) (err u107))
        (map-set referrals new-user tx-sender)
        (ok (map-set referral-count tx-sender 
            (+ (default-to u0 (map-get? referral-count tx-sender)) u1)))))



;; Add new maps and constants
(define-map trust-scores principal uint)
(define-constant BASE_TRUST_SCORE u50)
(define-constant MAX_TRUST_SCORE u100)

(define-public (calculate-trust-score (user principal))
    (let ((base-score BASE_TRUST_SCORE)
          (verification-bonus (if (is-verified user) u20 u0))
          (stake-bonus (if (> (default-to u0 (map-get? staked-amounts user)) u0) u30 u0))
          (total-score (+ base-score verification-bonus stake-bonus)))
        (ok (map-set trust-scores user 
            (if (> total-score MAX_TRUST_SCORE) MAX_TRUST_SCORE total-score)))))
