# Decentralized Identity Verification Contract

## Overview

This project implements a decentralized identity verification system using smart contracts. The contract allows users to request verification, and the contract owner can approve or reject these requests. The contract also provides a way to check the verification status of users and their pending requests.

## Features

- **Request Verification**: Users can request to be verified.
- **Approve Verification**: The contract owner can approve user verification requests.
- **Reject Verification**: The contract owner can reject user verification requests.
- **Check Verification Status**: Anyone can check if a user is verified or has a pending verification request.

## Smart Contract Details

### Constants
- `ERR_UNAUTHORIZED` (u100): Error for unauthorized actions.
- `ERR_ALREADY_VERIFIED` (u101): Error for users already verified.
- `ERR_NOT_FOUND` (u102): Error for non-existent verification requests.

### Data Variables
- `contract-owner`: Principal address of the contract owner.

### Data Maps
- `verified-users`: Maps users to their verification status (true/false).
- `verification-requests`: Maps users to their pending verification requests (true/false).

### Public Functions
1. `request-verification`: Allows a user to request verification.
2. `approve-verification (user)`: Approves a user's verification request (admin-only).
3. `reject-verification (user)`: Rejects a user's verification request (admin-only).

### Read-Only Functions
1. `is-verified (user)`: Returns the verification status of a user.
2. `has-pending-request (user)`: Checks if a user has a pending verification request.

## Unit Tests

The unit tests are written in JavaScript using the **Vitest** framework. They mock the smart contract's behavior to ensure the functionality works as intended.

### Key Tests
- Users can request verification if not already verified.
- The contract owner can approve or reject verification requests.
- Non-admin users cannot approve or reject requests.
- Verification and pending request statuses are checked accurately.

## How to Use

1. **Deploy the Contract**: Deploy the contract on your preferred blockchain.
2. **Request Verification**: Call the `request-verification` function to create a verification request.
3. **Admin Approval/Rejection**: The contract owner can approve or reject requests using the respective functions.
4. **Check Status**: Use the `is-verified` and `has-pending-request` functions to check user statuses.

## Development

### Prerequisites
- Node.js
- Vitest for testing

### Running Tests
```bash
npm install
npm test
