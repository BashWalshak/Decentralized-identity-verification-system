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


;; Add new maps
(define-map user-badges principal (list 10 uint))
(define-constant BADGE-EARLY-ADOPTER u1)
(define-constant BADGE-ACTIVE-VERIFIER u2)
(define-constant BADGE-TRUSTED-MEMBER u3)

(define-public (award-badge (user principal) (badge-id uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (ok (map-set user-badges user 
            (unwrap-panic (as-max-len? 
                (append (default-to (list) (map-get? user-badges user)) badge-id) 
                u10))))))


;; Add new maps
(define-map delegated-verifiers principal principal)
(define-map delegation-expiry principal uint)

(define-public (delegate-verification-rights (delegate principal) (expiry uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (map-set delegated-verifiers delegate tx-sender)
        (ok (map-set delegation-expiry delegate (+ block-height expiry)))))

;; Add new maps and constants
(define-map reputation-points principal uint)
(define-constant POINTS-VERIFICATION u100)
(define-constant POINTS-ENDORSEMENT u50)

(define-public (award-reputation-points (user principal) (points uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (ok (map-set reputation-points user 
            (+ (default-to u0 (map-get? reputation-points user)) points)))))
;; Add new maps
(define-map recovery-codes principal (string-ascii 64))
(define-map recovery-attempts principal uint)
(define-constant MAX_RECOVERY_ATTEMPTS u3)

(define-public (set-recovery-code (code (string-ascii 64)))
    (begin
        (asserts! (is-verified tx-sender) ERR_UNAUTHORIZED)
        (ok (map-set recovery-codes tx-sender code))))
;; Add new maps and constants
(define-map tier-requirements uint uint)
(define-constant TIER-1-STAKE u1000)
(define-constant TIER-2-STAKE u5000)
(define-constant TIER-3-STAKE u10000)

(define-public (set-tier-requirement (tier uint) (stake-requirement uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (ok (map-set tier-requirements tier stake-requirement))))
;; Add new maps and constants
(define-map verifier-fees principal uint)
(define-map verifier-ratings principal uint)
(define-constant MIN_VERIFIER_FEE u100)

(define-public (register-as-verifier (fee uint))
    (begin
        (asserts! (>= fee MIN_VERIFIER_FEE) (err u108))
        (asserts! (is-verified tx-sender) ERR_UNAUTHORIZED)
        (ok (map-set verifier-fees tx-sender fee))))
;; Add new maps and constants
(define-map challenge-timestamps principal uint)
(define-map challenge-completions principal uint)
(define-constant CHALLENGE_INTERVAL u720) ;; 5 days in blocks

(define-public (start-time-challenge)
    (begin
        (asserts! (is-verified tx-sender) ERR_UNAUTHORIZED)
        (ok (map-set challenge-timestamps tx-sender block-height))))
;; Add new maps and constants
(define-map insurance-policies principal uint)
(define-constant INSURANCE_PREMIUM u500)
(define-constant INSURANCE_COVERAGE u5000)

(define-public (purchase-insurance)
    (begin
        (asserts! (is-verified tx-sender) ERR_UNAUTHORIZED)
        (try! (stx-transfer? INSURANCE_PREMIUM tx-sender (as-contract tx-sender)))
        (ok (map-set insurance-policies tx-sender INSURANCE_COVERAGE))))



(define-map multi-sig-verification-requests principal (list 5 principal))
(define-map multi-sig-approvals (tuple (user principal) (verifier principal)) bool)
(define-constant REQUIRED_APPROVALS u3)

(define-public (request-multi-sig-verification (verifiers (list 5 principal)))
    (begin
        (asserts! (is-none (map-get? verified-users tx-sender)) ERR_ALREADY_VERIFIED)
        (ok (map-set multi-sig-verification-requests tx-sender verifiers))))

(define-public (approve-multi-sig-verification (user principal))
    (let ((verifiers (default-to (list) (map-get? multi-sig-verification-requests user)))
          (approval-tuple {user: user, verifier: tx-sender}))
        (asserts! (is-some (index-of verifiers tx-sender)) ERR_UNAUTHORIZED)
        (map-set multi-sig-approvals approval-tuple true)
        (if (>= (count-approvals user verifiers) REQUIRED_APPROVALS)
            (begin
                (map-delete multi-sig-verification-requests user)
                (ok (map-set verified-users user true)))
            (ok true))))

(define-read-only (count-approvals (user principal) (verifiers (list 5 principal)))
    (fold count-approval-fold verifiers u0))

(define-private (count-approval-fold (verifier principal) (count uint))
    (if (default-to false (map-get? multi-sig-approvals {user: tx-sender, verifier: verifier}))
        (+ count u1)
        count))



(define-constant ERR_NOT_EXPIRING_SOON (err u110))
(define-constant RENEWAL_WINDOW u4320) ;; 30 days in blocks

(define-public (renew-verification)
    (let ((current-expiry (default-to u0 (map-get? verification-expiry tx-sender))))
        (asserts! (is-verified tx-sender) ERR_NOT_FOUND)
        (asserts! (< block-height (+ current-expiry RENEWAL_WINDOW)) ERR_NOT_EXPIRING_SOON)
        (ok (map-set verification-expiry tx-sender (+ block-height VERIFICATION_VALIDITY_PERIOD)))))

(define-read-only (get-verification-expiry (user principal))
    (default-to u0 (map-get? verification-expiry user)))

(define-read-only (is-verification-valid (user principal))
    (and 
        (is-verified user)
        (< block-height (default-to u0 (map-get? verification-expiry user)))))



(define-map staking-start-time principal uint)
(define-map staking-rewards principal uint)
(define-constant REWARD_RATE u10) ;; 10 tokens per 1000 blocks
(define-constant REWARD_PERIOD u1000)

(define-public (stake-with-rewards (amount uint))
    (begin
        (asserts! (>= amount MINIMUM_STAKE_AMOUNT) (err u103))
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set staked-amounts tx-sender amount)
        (ok (map-set staking-start-time tx-sender block-height))))

(define-public (claim-staking-rewards)
    (let ((stake-amount (default-to u0 (map-get? staked-amounts tx-sender)))
          (start-time (default-to block-height (map-get? staking-start-time tx-sender)))
          (elapsed-periods (/ (- block-height start-time) REWARD_PERIOD))
          (reward (* (/ (* stake-amount REWARD_RATE) u1000) elapsed-periods)))
        (asserts! (> stake-amount u0) (err u111))
        (asserts! (> elapsed-periods u0) (err u112))
        (map-set staking-start-time tx-sender block-height)
        (map-set staking-rewards tx-sender (+ (default-to u0 (map-get? staking-rewards tx-sender)) reward))
        (ok reward)))

(define-public (withdraw-rewards)
    (let ((rewards (default-to u0 (map-get? staking-rewards tx-sender))))
        (asserts! (> rewards u0) (err u113))
        (map-set staking-rewards tx-sender u0)
        (as-contract (stx-transfer? rewards (as-contract tx-sender) tx-sender))))


(define-map marketplace-listings principal 
    (tuple 
        (fee uint)
        (description (string-ascii 100))
        (active bool)))
(define-map service-ratings (tuple (provider principal) (client principal)) uint)
(define-constant MAX_RATING u5)

(define-public (create-marketplace-listing (fee uint) (description (string-ascii 100)))
    (begin
        (asserts! (is-verified tx-sender) ERR_UNAUTHORIZED)
        (ok (map-set marketplace-listings tx-sender 
            {fee: fee, description: description, active: true}))))

(define-public (update-listing-status (active bool))
    (let ((listing (default-to {fee: u0, description: "", active: false} 
                   (map-get? marketplace-listings tx-sender))))
        (asserts! (is-verified tx-sender) ERR_UNAUTHORIZED)
        (ok (map-set marketplace-listings tx-sender 
            {fee: (get fee listing), 
             description: (get description listing), 
             active: active}))))

(define-public (rate-service-provider (provider principal) (rating uint))
    (begin
        (asserts! (<= rating MAX_RATING) (err u114))
        (ok (map-set service-ratings {provider: provider, client: tx-sender} rating))))

(define-read-only (get-provider-average-rating (provider principal))
    (default-to u0 (map-get? service-ratings {provider: provider, client: tx-sender})))



(define-map governance-proposals uint 
    (tuple 
        (title (string-ascii 100))
        (description (string-ascii 500))
        (proposer principal)
        (start-block uint)
        (end-block uint)
        (executed bool)))

(define-map proposal-votes (tuple (proposal-id uint) (voter principal)) bool)
(define-data-var proposal-counter uint u0)
(define-constant VOTING_PERIOD u1440) ;; 10 days in blocks
(define-constant MIN_STAKE_TO_PROPOSE u5000)

(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)))
    (let ((proposal-id (+ (var-get proposal-counter) u1)))
        (asserts! (is-verified tx-sender) ERR_UNAUTHORIZED)
        (asserts! (>= (default-to u0 (map-get? staked-amounts tx-sender)) MIN_STAKE_TO_PROPOSE) (err u115))
        (var-set proposal-counter proposal-id)
        (ok (map-set governance-proposals proposal-id 
            {title: title, 
             description: description, 
             proposer: tx-sender, 
             start-block: block-height, 
             end-block: (+ block-height VOTING_PERIOD), 
             executed: false}))))

(define-public (vote-on-proposal (proposal-id uint) (support bool))
    (let ((proposal (default-to 
                    {title: "", description: "", proposer: tx-sender, 
                     start-block: u0, end-block: u0, executed: false} 
                    (map-get? governance-proposals proposal-id))))
        (asserts! (is-verified tx-sender) ERR_UNAUTHORIZED)
        (asserts! (< block-height (get end-block proposal)) (err u116))
        (ok (map-set proposal-votes {proposal-id: proposal-id, voter: tx-sender} support))))



(define-map verification-delegates (tuple (owner principal) (delegate principal)) bool)
(define-map delegate-permissions principal uint)
(define-constant PERMISSION_APPROVE u1)
(define-constant PERMISSION_REJECT u2)
(define-constant PERMISSION_FULL u3)

(define-public (add-verification-delegate (delegate principal) (permissions uint))
    (begin
        (asserts! (is-verified tx-sender) ERR_UNAUTHORIZED)
        (asserts! (<= permissions PERMISSION_FULL) (err u117))
        (map-set verification-delegates {owner: tx-sender, delegate: delegate} true)
        (ok (map-set delegate-permissions delegate permissions))))

(define-public (remove-verification-delegate (delegate principal))
    (begin
        (asserts! (is-verified tx-sender) ERR_UNAUTHORIZED)
        (ok (map-delete verification-delegates {owner: tx-sender, delegate: delegate}))))

(define-public (delegate-approve-verification (user principal))
    (let ((owner (var-get contract-owner))
          (permissions (default-to u0 (map-get? delegate-permissions tx-sender))))
        (asserts! (default-to false (map-get? verification-delegates {owner: owner, delegate: tx-sender})) ERR_UNAUTHORIZED)
        (asserts! (or (is-eq permissions PERMISSION_APPROVE) (is-eq permissions PERMISSION_FULL)) ERR_UNAUTHORIZED)
        (asserts! (is-some (map-get? verification-requests user)) ERR_NOT_FOUND)
        (map-delete verification-requests user)
        (ok (map-set verified-users user true))))



