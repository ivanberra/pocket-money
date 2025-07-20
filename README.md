# Student Stipend Smart Contract

A time-locked smart contract built on the Stacks blockchain for managing student allowances and project funding. This contract enables parents/guardians to set up automated stipend releases while maintaining control over additional project expenses.

## 🎯 Features

- **⏰ Time-locked Allowances**: Automatic release of regular stipends based on configurable intervals
- **📚 Project Funding**: Request-approval system for additional school project expenses
- **👨‍👩‍👧‍👦 Multi-party Control**: Three-tier authorization system (student, guardian, admin)
- **💰 Fund Management**: Secure deposit and withdrawal tracking with overdraft protection
- **🔒 Security**: Comprehensive error handling and authorization checks

## 📋 Contract Overview

The contract manages three types of users:
- **Students**: Can claim allowances and request project funding
- **Guardians**: Can approve project funding requests
- **Contract Owner**: Administrative control and fund deposits

## 🚀 Getting Started

### Prerequisites

- Stacks wallet with STX tokens
- Access to a Stacks blockchain node or testnet
- Clarity development environment (optional for deployment)

### Deployment

1. Deploy the contract to Stacks blockchain:
```bash
stx deploy_contract student-stipend contract.clar --testnet
```

2. Note the contract address for interactions

## 📖 Usage Guide

### 1. Register a Student

**Who can do this:** Contract Owner only

```clarity
(contract-call? .student-stipend register-student 
    'SP1ABC...STUDENT-ADDRESS
    'SP2DEF...GUARDIAN-ADDRESS
    u100000000  ;; 100 STX allowance (in micro-STX)
    u1008       ;; 1008 blocks (~1 week interval)
)
```

### 2. Deposit Funds

**Who can do this:** Contract Owner only

```clarity
(contract-call? .student-stipend deposit-funds 
    u1          ;; student-id
    u500000000  ;; 500 STX deposit (in micro-STX)
)
```

### 3. Claim Regular Allowance

**Who can do this:** Student or Guardian

```clarity
(contract-call? .student-stipend claim-allowance u1)
```

### 4. Request Project Funding

**Who can do this:** Student only

```clarity
(contract-call? .student-stipend request-project-funding 
    u1                                    ;; student-id
    u50000000                            ;; 50 STX request (in micro-STX)
    "Science fair project materials"      ;; description
)
```

### 5. Approve Project Funding

**Who can do this:** Guardian or Contract Owner

```clarity
(contract-call? .student-stipend approve-project-funding 
    u1  ;; student-id
    u1  ;; request-id
)
```

### 6. Withdraw Approved Project Funds

**Who can do this:** Student only

```clarity
(contract-call? .student-stipend withdraw-project-funding 
    u1  ;; student-id
    u1  ;; request-id
)
```

## 🔍 Read-Only Functions

### Check Next Allowance Availability
```clarity
(contract-call? .student-stipend blocks-until-next-allowance u1)
;; Returns: number of blocks until next allowance can be claimed
```

### Check Available Funds
```clarity
(contract-call? .student-stipend get-available-funds u1)
;; Returns: available balance for student
```

### Get Student Details
```clarity
(contract-call? .student-stipend get-student u1)
;; Returns: complete student data structure
```

### Get Project Request Details
```clarity
(contract-call? .student-stipend get-project-request u1 u1)
;; Returns: project request details
```

## 📊 Data Structures

### Student Record
```clarity
{
    student-address: principal,     ;; Student's wallet address
    guardian-address: principal,    ;; Guardian's wallet address
    regular-allowance: uint,        ;; Regular allowance amount (micro-STX)
    last-allowance-block: uint,     ;; Last allowance claim block
    allowance-interval: uint,       ;; Blocks between allowances
    total-deposited: uint,          ;; Total funds deposited
    total-withdrawn: uint,          ;; Total funds withdrawn
    active: bool                    ;; Student account status
}
```

### Project Request
```clarity
{
    amount: uint,                   ;; Requested amount (micro-STX)
    description: string-ascii 256,  ;; Project description
    requested-at: uint,             ;; Request block height
    approved: bool,                 ;; Approval status
    withdrawn: bool                 ;; Withdrawal status
}
```

## ⚠️ Error Codes

- `u100`: Owner-only function called by non-owner
- `u101`: Unauthorized access attempt
- `u102`: Insufficient funds in contract
- `u103`: Student not found
- `u104`: Allowance claimed too early
- `u105`: Invalid amount (zero or negative)

## 🔒 Security Considerations

### Access Control
- **Students** can only access their own data and claim their allowances
- **Guardians** can approve project funding but cannot directly access funds
- **Contract Owner** has administrative privileges but cannot directly access student funds

### Time Locks
- Regular allowances are protected by configurable time intervals
- No early withdrawal possible until the time period elapses

### Fund Safety
- All transfers are validated for sufficient balance
- Double-spending protection for project requests
- Comprehensive error handling prevents invalid states

## 🧪 Testing Scenarios

### Happy Path
1. Register student with 100 STX weekly allowance
2. Deposit 1000 STX to contract
3. Wait 1 week (1008 blocks)
4. Student claims 100 STX allowance
5. Student requests 50 STX for project
6. Guardian approves request
7. Student withdraws project funds

### Edge Cases
- Claiming allowance too early (should fail)
- Requesting more funds than available (should fail)
- Unauthorized access attempts (should fail)
- Double-spending project funds (should fail)

## 📝 Example Workflow

```bash
# 1. Deploy contract
stx deploy_contract student-stipend contract.clar --testnet

# 2. Register student (as contract owner)
stx call_contract_func student-stipend register-student \
  --arg "'SP1ABC...STUDENT" \
  --arg "'SP2DEF...GUARDIAN" \
  --arg "u100000000" \
  --arg "u1008"

# 3. Deposit funds (as contract owner)
stx call_contract_func student-stipend deposit-funds \
  --arg "u1" \
  --arg "u500000000"

# 4. Check when allowance is available
stx call_readonly_func student-stipend blocks-until-next-allowance \
  --arg "u1"

# 5. Claim allowance (as student)
stx call_contract_func student-stipend claim-allowance \
  --arg "u1"
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## ⚡ Block Time Reference

On Stacks mainnet:
- 1 block ≈ 10 minutes
- 144 blocks ≈ 1 day
- 1008 blocks ≈ 1 week
- 4320 blocks ≈ 1 month

## 🔧 Administrative Functions

### Update Student Status
```clarity
(contract-call? .student-stipend update-student-status u1 false)
;; Deactivate student account
```

### Update Allowance Amount
```clarity
(contract-call? .student-stipend update-allowance u1 u150000000)
;; Change allowance to 150 STX
```
