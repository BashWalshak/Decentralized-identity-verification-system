;; Zero-Knowledge Identity Challenge System
;; Enables privacy-preserving identity verification through cryptographic commitments

;; Error constants
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_INVALID_CHALLENGE (err u401))
(define-constant ERR_CHALLENGE_EXPIRED (err u402))
(define-constant ERR_ALREADY_SUBMITTED (err u403))
(define-constant ERR_INVALID_PROOF (err u404))
(define-constant ERR_INSUFFICIENT_STAKE (err u405))
(define-constant ERR_CHALLENGE_NOT_FOUND (err u406))
(define-constant ERR_INVALID_RANGE (err u407))
(define-constant ERR_PROOF_VERIFICATION_FAILED (err u408))
(define-constant ERR_COMMITMENT_MISMATCH (err u409))
(define-constant ERR_CHALLENGE_ALREADY_VERIFIED (err u410))
(define-constant ERR_INVALID_ATTRIBUTE_TYPE (err u411))
(define-constant ERR_REWARD_ALREADY_CLAIMED (err u412))
(define-constant ERR_CHALLENGE_NOT_VERIFIED (err u413))

;; System constants
(define-constant CHALLENGE_VALIDITY_PERIOD u1440) ;; 10 days in blocks
(define-constant MIN_CHALLENGE_STAKE u500)
(define-constant PROOF_SUBMISSION_WINDOW u288) ;; 2 days in blocks
(define-constant VERIFICATION_REWARD u200)
(define-constant CHALLENGE_CREATION_FEE u100)
(define-constant MAX_ATTRIBUTE_VALUE u1000000)
(define-constant ZK_COMMITMENT_SIZE u32)

;; Challenge type constants
(define-constant CHALLENGE_TYPE_AGE_RANGE u1)
(define-constant CHALLENGE_TYPE_CITIZENSHIP u2)
(define-constant CHALLENGE_TYPE_INCOME_RANGE u3)
(define-constant CHALLENGE_TYPE_EDUCATION_LEVEL u4)
(define-constant CHALLENGE_TYPE_EMPLOYMENT_STATUS u5)
(define-constant CHALLENGE_TYPE_CREDIT_SCORE_RANGE u6)

;; Challenge status constants
(define-constant STATUS_PENDING u1)
(define-constant STATUS_SUBMITTED u2)
(define-constant STATUS_VERIFIED u3)
(define-constant STATUS_REJECTED u4)
(define-constant STATUS_EXPIRED u5)

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var challenge-counter uint u0)
(define-data-var total-verified-challenges uint u0)
(define-data-var verification-oracle principal tx-sender)

;; Challenge definition structure
(define-map zk-challenges
    uint
    (tuple
        (challenger principal)
        (challenge-type uint)
        (min-value uint)
        (max-value uint)
        (commitment-hash (buff 32))
        (creation-time uint)
        (expiry-time uint)
        (stake-amount uint)
        (status uint)
        (reward-claimed bool)))

;; Proof submission structure
(define-map challenge-proofs
    uint
    (tuple
        (prover principal)
        (proof-hash (buff 32))
        (witness-commitment (buff 32))
        (submission-time uint)
        (verification-status uint)))

;; User attribute commitments (for privacy preservation)
(define-map user-commitments
    (tuple (user principal) (attribute-type uint))
    (tuple
        (commitment-hash (buff 32))
        (salt-hash (buff 32))
        (timestamp uint)
        (verified bool)))

;; Verifier network for proof validation
(define-map authorized-verifiers principal bool)
(define-map verifier-reputation principal uint)
(define-map verifier-statistics principal 
    (tuple
        (total-verifications uint)
        (successful-verifications uint)
        (rejected-verifications uint)))

;; Challenge participation tracking
(define-map user-challenge-history
    (tuple (user principal) (challenge-id uint))
    (tuple
        (participation-time uint)
        (result uint)
        (reward-earned uint)))

;; Staking pool for challenge security
(define-map challenge-stakes principal uint)
(define-map stake-rewards principal uint)

;; Zero-knowledge proof validation cache
(define-map proof-validation-cache
    (buff 32)
    (tuple
        (is-valid bool)
        (validation-time uint)
        (validator principal)))

;; Attribute range verification templates
(define-map verification-templates
    uint
    (tuple
        (template-name (string-ascii 50))
        (min-stake-required uint)
        (verification-complexity uint)
        (reward-multiplier uint)))

;; Initialize verification templates
(define-public (initialize-verification-templates)
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (map-set verification-templates CHALLENGE_TYPE_AGE_RANGE 
            {template-name: "Age Range Verification", min-stake-required: u300, verification-complexity: u1, reward-multiplier: u100})
        (map-set verification-templates CHALLENGE_TYPE_CITIZENSHIP 
            {template-name: "Citizenship Proof", min-stake-required: u500, verification-complexity: u2, reward-multiplier: u150})
        (map-set verification-templates CHALLENGE_TYPE_INCOME_RANGE 
            {template-name: "Income Range Proof", min-stake-required: u800, verification-complexity: u3, reward-multiplier: u200})
        (map-set verification-templates CHALLENGE_TYPE_EDUCATION_LEVEL 
            {template-name: "Education Verification", min-stake-required: u400, verification-complexity: u2, reward-multiplier: u120})
        (map-set verification-templates CHALLENGE_TYPE_EMPLOYMENT_STATUS 
            {template-name: "Employment Status", min-stake-required: u600, verification-complexity: u2, reward-multiplier: u130})
        (ok (map-set verification-templates CHALLENGE_TYPE_CREDIT_SCORE_RANGE 
            {template-name: "Credit Score Range", min-stake-required: u1000, verification-complexity: u4, reward-multiplier: u250}))))

;; Create a new zero-knowledge identity challenge
(define-public (create-zk-challenge 
    (challenge-type uint) 
    (min-value uint) 
    (max-value uint) 
    (commitment-hash (buff 32)) 
    (stake-amount uint))
    (let ((challenge-id (+ (var-get challenge-counter) u1))
          (template (map-get? verification-templates challenge-type)))
        (asserts! (is-some template) ERR_INVALID_ATTRIBUTE_TYPE)
        (asserts! (< min-value max-value) ERR_INVALID_RANGE)
        (asserts! (<= max-value MAX_ATTRIBUTE_VALUE) ERR_INVALID_RANGE)
        (asserts! (>= stake-amount (get min-stake-required (unwrap-panic template))) ERR_INSUFFICIENT_STAKE)
        (try! (stx-transfer? (+ stake-amount CHALLENGE_CREATION_FEE) tx-sender (as-contract tx-sender)))
        (var-set challenge-counter challenge-id)
        (map-set challenge-stakes tx-sender (+ (default-to u0 (map-get? challenge-stakes tx-sender)) stake-amount))
        (ok (map-set zk-challenges challenge-id
            {challenger: tx-sender,
             challenge-type: challenge-type,
             min-value: min-value,
             max-value: max-value,
             commitment-hash: commitment-hash,
             creation-time: block-height,
             expiry-time: (+ block-height CHALLENGE_VALIDITY_PERIOD),
             stake-amount: stake-amount,
             status: STATUS_PENDING,
             reward-claimed: false}))))

;; Submit a zero-knowledge proof for a challenge
(define-public (submit-zk-proof 
    (challenge-id uint) 
    (proof-hash (buff 32)) 
    (witness-commitment (buff 32)))
    (let ((challenge (map-get? zk-challenges challenge-id)))
        (asserts! (is-some challenge) ERR_CHALLENGE_NOT_FOUND)
        (asserts! (< block-height (get expiry-time (unwrap-panic challenge))) ERR_CHALLENGE_EXPIRED)
        (asserts! (is-eq (get status (unwrap-panic challenge)) STATUS_PENDING) ERR_ALREADY_SUBMITTED)
        (asserts! (is-none (map-get? challenge-proofs challenge-id)) ERR_ALREADY_SUBMITTED)
        (map-set challenge-proofs challenge-id
            {prover: tx-sender,
             proof-hash: proof-hash,
             witness-commitment: witness-commitment,
             submission-time: block-height,
             verification-status: STATUS_SUBMITTED})
        (map-set zk-challenges challenge-id
            (merge (unwrap-panic challenge) {status: STATUS_SUBMITTED}))
        (ok true)))

;; Verify a submitted zero-knowledge proof
(define-public (verify-zk-proof (challenge-id uint) (is-valid bool))
    (let ((challenge (map-get? zk-challenges challenge-id))
          (proof (map-get? challenge-proofs challenge-id)))
        (asserts! (default-to false (map-get? authorized-verifiers tx-sender)) ERR_UNAUTHORIZED)
        (asserts! (is-some challenge) ERR_CHALLENGE_NOT_FOUND)
        (asserts! (is-some proof) ERR_CHALLENGE_NOT_FOUND)
        (asserts! (is-eq (get status (unwrap-panic challenge)) STATUS_SUBMITTED) ERR_INVALID_CHALLENGE)
        (if is-valid
            (begin
                (map-set zk-challenges challenge-id
                    (merge (unwrap-panic challenge) {status: STATUS_VERIFIED}))
                (map-set challenge-proofs challenge-id
                    (merge (unwrap-panic proof) {verification-status: STATUS_VERIFIED}))
                (map-set user-challenge-history 
                    {user: (get prover (unwrap-panic proof)), challenge-id: challenge-id}
                    {participation-time: (get submission-time (unwrap-panic proof)),
                     result: STATUS_VERIFIED,
                     reward-earned: VERIFICATION_REWARD})
                (var-set total-verified-challenges (+ (var-get total-verified-challenges) u1))
                (unwrap-panic (update-verifier-stats tx-sender true)))
            (begin
                (map-set zk-challenges challenge-id
                    (merge (unwrap-panic challenge) {status: STATUS_REJECTED}))
                (map-set challenge-proofs challenge-id
                    (merge (unwrap-panic proof) {verification-status: STATUS_REJECTED}))
                (unwrap-panic (update-verifier-stats tx-sender false))))
        (ok is-valid)))

;; Commit to an identity attribute (privacy-preserving)
(define-public (commit-identity-attribute 
    (attribute-type uint) 
    (commitment-hash (buff 32)) 
    (salt-hash (buff 32)))
    (let ((commitment-key {user: tx-sender, attribute-type: attribute-type}))
        (asserts! (<= attribute-type CHALLENGE_TYPE_CREDIT_SCORE_RANGE) ERR_INVALID_ATTRIBUTE_TYPE)
        (ok (map-set user-commitments commitment-key
            {commitment-hash: commitment-hash,
             salt-hash: salt-hash,
             timestamp: block-height,
             verified: false}))))

;; Validate commitment against submitted proof
(define-public (validate-commitment 
    (user principal) 
    (attribute-type uint) 
    (challenge-id uint))
    (let ((commitment-key {user: user, attribute-type: attribute-type})
          (commitment (map-get? user-commitments commitment-key))
          (challenge (map-get? zk-challenges challenge-id))
          (proof (map-get? challenge-proofs challenge-id)))
        (asserts! (default-to false (map-get? authorized-verifiers tx-sender)) ERR_UNAUTHORIZED)
        (asserts! (is-some commitment) ERR_CHALLENGE_NOT_FOUND)
        (asserts! (is-some challenge) ERR_CHALLENGE_NOT_FOUND)
        (asserts! (is-some proof) ERR_CHALLENGE_NOT_FOUND)
        (asserts! (is-eq (get challenge-type (unwrap-panic challenge)) attribute-type) ERR_INVALID_CHALLENGE)
        (asserts! (is-eq (get prover (unwrap-panic proof)) user) ERR_UNAUTHORIZED)
        (map-set user-commitments commitment-key
            (merge (unwrap-panic commitment) {verified: true}))
        (ok true)))

;; Claim verification rewards
(define-public (claim-verification-reward (challenge-id uint))
    (let ((challenge (map-get? zk-challenges challenge-id))
          (user-history (map-get? user-challenge-history {user: tx-sender, challenge-id: challenge-id})))
        (asserts! (is-some challenge) ERR_CHALLENGE_NOT_FOUND)
        (asserts! (is-some user-history) ERR_CHALLENGE_NOT_FOUND)
        (asserts! (is-eq (get status (unwrap-panic challenge)) STATUS_VERIFIED) ERR_CHALLENGE_NOT_VERIFIED)
        (asserts! (not (get reward-claimed (unwrap-panic challenge))) ERR_REWARD_ALREADY_CLAIMED)
        (asserts! (is-eq (get result (unwrap-panic user-history)) STATUS_VERIFIED) ERR_INVALID_CHALLENGE)
        (map-set zk-challenges challenge-id
            (merge (unwrap-panic challenge) {reward-claimed: true}))
        (map-set stake-rewards tx-sender 
            (+ (default-to u0 (map-get? stake-rewards tx-sender)) VERIFICATION_REWARD))
        (as-contract (stx-transfer? VERIFICATION_REWARD (as-contract tx-sender) tx-sender))))

;; Update verifier statistics
(define-private (update-verifier-stats (verifier principal) (successful bool))
    (let ((current-stats (default-to 
                         {total-verifications: u0, successful-verifications: u0, rejected-verifications: u0}
                         (map-get? verifier-statistics verifier))))
        (map-set verifier-statistics verifier
            {total-verifications: (+ (get total-verifications current-stats) u1),
             successful-verifications: (if successful 
                                         (+ (get successful-verifications current-stats) u1)
                                         (get successful-verifications current-stats)),
             rejected-verifications: (if (not successful)
                                       (+ (get rejected-verifications current-stats) u1)
                                       (get rejected-verifications current-stats))})
        (map-set verifier-reputation verifier
            (calculate-verifier-reputation 
                (+ (get total-verifications current-stats) u1)
                (if successful 
                    (+ (get successful-verifications current-stats) u1)
                    (get successful-verifications current-stats))))
        (ok true)))

;; Calculate verifier reputation score
(define-private (calculate-verifier-reputation (total uint) (successful uint))
    (if (> total u0)
        (+ u500 (/ (* successful u500) total)) ;; Base 500 + success rate bonus
        u500))

;; Add authorized verifier
(define-public (add-authorized-verifier (verifier principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (map-set authorized-verifiers verifier true)
        (ok (map-set verifier-reputation verifier u500))))

;; Remove authorized verifier
(define-public (remove-authorized-verifier (verifier principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (ok (map-delete authorized-verifiers verifier))))

;; Set verification oracle
(define-public (set-verification-oracle (new-oracle principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (ok (var-set verification-oracle new-oracle))))

;; Emergency challenge cancellation
(define-public (cancel-challenge (challenge-id uint))
    (let ((challenge (map-get? zk-challenges challenge-id)))
        (asserts! (is-some challenge) ERR_CHALLENGE_NOT_FOUND)
        (asserts! (or (is-eq tx-sender (var-get contract-owner))
                      (is-eq tx-sender (get challenger (unwrap-panic challenge)))) ERR_UNAUTHORIZED)
        (asserts! (< (get status (unwrap-panic challenge)) STATUS_VERIFIED) ERR_CHALLENGE_ALREADY_VERIFIED)
        (map-set zk-challenges challenge-id
            (merge (unwrap-panic challenge) {status: STATUS_EXPIRED}))
        (as-contract (stx-transfer? (get stake-amount (unwrap-panic challenge)) 
                                   (as-contract tx-sender) 
                                   (get challenger (unwrap-panic challenge))))))

;; Read-only functions
(define-read-only (get-challenge-details (challenge-id uint))
    (map-get? zk-challenges challenge-id))

(define-read-only (get-proof-details (challenge-id uint))
    (map-get? challenge-proofs challenge-id))

(define-read-only (get-user-commitment (user principal) (attribute-type uint))
    (map-get? user-commitments {user: user, attribute-type: attribute-type}))

(define-read-only (get-verifier-reputation (verifier principal))
    (default-to u0 (map-get? verifier-reputation verifier)))

(define-read-only (get-verifier-stats (verifier principal))
    (map-get? verifier-statistics verifier))

(define-read-only (get-user-challenge-history (user principal) (challenge-id uint))
    (map-get? user-challenge-history {user: user, challenge-id: challenge-id}))

(define-read-only (is-challenge-expired (challenge-id uint))
    (match (map-get? zk-challenges challenge-id)
        challenge (>= block-height (get expiry-time challenge))
        true))

(define-read-only (get-total-verified-challenges)
    (var-get total-verified-challenges))

(define-read-only (get-challenge-counter)
    (var-get challenge-counter))

(define-read-only (is-authorized-verifier (verifier principal))
    (default-to false (map-get? authorized-verifiers verifier)))

(define-read-only (get-verification-template (challenge-type uint))
    (map-get? verification-templates challenge-type))

(define-read-only (get-user-stake-balance (user principal))
    (default-to u0 (map-get? challenge-stakes user)))

(define-read-only (get-pending-rewards (user principal))
    (default-to u0 (map-get? stake-rewards user)))


