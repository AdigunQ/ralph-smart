# Verification Protocol: From Hypothesis to Confirmed Finding

> **Core Principle**: Cyber is unusually friendly to agentic systems because so much is verifiable: "Run the simulation." "Execute the PoC." "Do we steal money / break invariants / crash the system?"

That verification loop keeps the system grounded. It also makes it easier to reward correctness instead of persuasion—the core requirement for Expert-grade AI rather than just fluent output.

---

## The Verification Gates

Every vulnerability finding must pass through these gates:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         VERIFICATION PIPELINE                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  HYPOTHESIS ──► GATE 1 ──► GATE 2 ──► GATE 3 ──► GATE 4 ──► GATE 5     │
│     │           │          │          │          │          │           │
│     │        SYNTACTIC   SEMANTIC   IMPACT     PROOF      REPORT       │
│     │        VALIDITY    ANALYSIS   ASSESSMENT OF        QUALITY       │
│     │                                                  EXPLOIT         │
│     │           │          │          │          │          │           │
│     ▼           ▼          ▼          ▼          ▼          ▼           │
│  DISCARD    INVALID    INVALID   LOW IMPACT   FAIL    INCOMPLETE       │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Gate 1: Syntactic Validity

**Question**: Does the claimed vulnerability even exist in the code?

### Checks

- [ ] Claimed function exists
- [ ] Claimed file exists
- [ ] Claimed line numbers are correct
- [ ] Code snippet matches actual code
- [ ] No hallucinated functions/variables

### Tools

```bash
# Verify function exists
grep -n "function claimFunction" TargetFile.sol

# Verify line numbers
sed -n '10,20p' TargetFile.sol  # Check claimed lines 10-20

# Verify variable exists
grep -n "claimedVariable" TargetFile.sol
```

### Output

- **PASS**: Proceed to Gate 2
- **FAIL**: Discard with label `HALLUCINATION`

---

## Gate 2: Semantic Analysis

**Question**: Does the claimed execution path actually work?

### 2A: Reachability Proof

Prove the path from entry point to sink exists:

```markdown
## Reachability Proof

**Entry Point**: [External function callable by anyone]
**Call Path**:
```
entryFunction(uint256 amount)
  └─> _internalProcess(address caller, uint256 amount)
       └─> _executeTransfer(address to, uint256 value)
            └─> SINK: external call to arbitrary address
```

**Path Verification**:
- [x] Entry function is `external` or `public`
- [x] No `onlyOwner` or access control on entry
- [x] No `whenNotPaused` modifier blocking path
- [x] Call chain is complete (no missing links)
- [x] Parameters flow correctly through calls

**CodeQL Verification**:
```ql
import solidity

from Function entry, Function sink
where
  entry.isPublic() and
  entry.calls+(sink) and
  sink.hasExternalCall()
select entry, "can reach external call"
```
```

### 2B: Controllability Proof

Prove attacker can control relevant inputs:

```markdown
## Controllability Proof

**Attacker-Controlled Inputs**:

| Parameter | Function | Control Level | Constraints |
|-----------|----------|---------------|-------------|
| `to` | `transfer(address,uint256)` | Full | None |
| `amount` | `transfer(address,uint256)` | Bounded | < balance |
| `data` | `execute(bytes)` | Full | None |

**State Influence**:
- Can increase: `balances[arbitrary_address]`
- Can decrease: `balances[msg.sender]` (requires having balance)
- Can set: `owner` (if no check)

**Sanitizers Checked**:
- [x] No input validation on `to`
- [x] No access control modifier
- [x] No rate limiting
```

### Output

- **PASS**: Proceed to Gate 3
- **FAIL**: Discard with label `NOT_REACHABLE` or `NOT_CONTROLLABLE`

---

## Gate 3: Impact Assessment

**Question**: What is the real-world impact if exploited?

### Impact Categories

| Category | Description | Example |
|----------|-------------|---------|
| **Theft** | Direct fund loss | Draining protocol treasury |
| **DoS** | Denial of service | Making protocol unusable |
| **Privilege Esc** | Gaining unauthorized access | Becoming owner |
| **Data Corruption** | Invalid state | Broken invariants |
| **Information Leak** | Exposing sensitive data | Reading private values |

### Quantification Matrix

```markdown
## Impact Quantification

**Impact Type**: Theft
**Direct Loss**: Can drain all user deposits
**Amount at Risk**: ~$500M TVL (verified from DeFiLlama)
**Secondary Effects**: Protocol becomes insolvent

**Exploit Cost**: 
- Gas: ~500K gas (~$50)
- Capital: Flash loan $1M
- Total: <$100

**Profitability**: 
- Expected gain: $500M
- Expected cost: $100
- ROI: 5,000,000x

**Severity**: CRITICAL
```

### Output

- **CRITICAL/HIGH**: Proceed to Gate 4
- **MEDIUM/LOW**: Document but deprioritize
- **NONE**: Discard with label `NO_IMPACT`

---

## Gate 4: Proof of Exploitability

**Question**: Can we actually demonstrate the vulnerability?

### PoC Requirements

A valid PoC must:

1. **Compile**: No syntax errors
2. **Execute**: Runs without reverting (unless that's the bug)
3. **Demonstrate Impact**: Shows the claimed effect
4. **Be Minimized**: Only includes necessary steps

### PoC Template

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/VulnerableContract.sol";

contract ExploitTest is Test {
    VulnerableContract target;
    Attacker attacker;
    
    function setUp() public {
        target = new VulnerableContract();
        attacker = new Attacker(address(target));
        
        // Setup: Fund the protocol
        deal(address(target), 1000 ether);
    }
    
    function testExploit() public {
        // Pre-condition: Record initial state
        uint256 initialBalance = address(target).balance;
        
        // Execute attack
        attacker.attack();
        
        // Post-condition: Verify impact
        assertEq(address(target).balance, 0);
        assertEq(address(attacker).balance, initialBalance);
    }
}

contract Attacker {
    VulnerableContract target;
    
    constructor(address _target) {
        target = VulnerableContract(_target);
    }
    
    function attack() external {
        // Step 1: [Initial action]
        target.vulnerableFunction(...);
        
        // Step 2: [Continuation]
        // ...
        
        // Result: [Impact achieved]
    }
    
    // Add any callbacks needed for reentrancy
    receive() external payable {
        // Reentrancy logic if needed
    }
}
```

### Simulation Requirements

```bash
# Run the PoC
forge test --match-contract ExploitTest -vvvv

# Expected output should show:
# 1. Pre-exploit state
# 2. Exploit execution
# 3. Post-exploit state with impact demonstrated
```

### Output

- **PASS**: Proceed to Gate 5
- **FAIL**: 
  - If exploit reverts → Label `NOT_EXPLOITABLE`
  - If impact not demonstrated → Label `IMPACT_MISMATCH`

---

## Gate 5: Report Quality

**Question**: Is the finding documented clearly and professionally?

### Report Checklist

- [ ] Clear summary (2-3 sentences)
- [ ] Detailed technical explanation
- [ ] Step-by-step reproduction
- [ ] Specific code references (file:line)
- [ ] Impact quantification
- [ ] Recommended fix with code
- [ ] References to similar bugs

### Report Template

```markdown
# [ID]: [Vulnerability Title]

**Severity**: CRITICAL | HIGH | MEDIUM | LOW  
**Status**: CONFIRMED  
**Type**: [Reentrancy/Access Control/Oracle Manipulation/etc.]

## Summary

[2-3 sentences explaining what the bug is and its impact]

## Technical Details

### Location
- **File**: `src/Contract.sol`
- **Lines**: 45-67
- **Function**: `vulnerableFunction()`

### Vulnerability

[Detailed explanation of the bug mechanism]

### Attack Scenario

1. Attacker [action]
2. Protocol [response]
3. Because [missing check], [bad thing happens]
4. Result: [impact]

## Proof of Concept

```solidity
[PoC code]
```

**Test execution**:
```bash
forge test --match-test testExploit -vvvv
[actual output]
```

## Impact

- **Direct Impact**: [What happens]
- **Funds at Risk**: [Amount]
- **Likelihood**: [How easy to exploit]

## Recommendation

```solidity
[Fixed code]
```

## References

- [Similar vulnerability 1]
- [Similar vulnerability 2]
```

### Output

- **PASS**: Finding is complete and ready for submission
- **FAIL**: Return for revision with specific feedback

---

## Verification Commands

### Quick Validation Script

```bash
#!/bin/bash
# verify_finding.sh [finding-id]

FINDING_ID=$1
FINDING_DIR="findings/vulnerabilities/${FINDING_ID}"

echo "=== Gate 1: Syntactic Validity ==="
# Check files exist
if [ ! -f "${FINDING_DIR}/finding.md" ]; then
    echo "FAIL: finding.md missing"
    exit 1
fi

# Extract code references
grep -oE '[A-Za-z0-9]+\.sol:[0-9]+' "${FINDING_DIR}/finding.md" | while read ref; do
    file=$(echo $ref | cut -d: -f1)
    line=$(echo $ref | cut -d: -f2)
    if [ ! -f "target/src/${file}" ]; then
        echo "FAIL: Referenced file ${file} not found"
        exit 1
    fi
    echo "  ✓ ${ref} exists"
done

echo "=== Gate 2: Reachability ==="
# Run CodeQL if available
if command -v codeql &> /dev/null; then
    codeql query run --database=target-db reachability.ql
fi

echo "=== Gate 3: Impact ==="
# Check impact is quantified
grep -E "(\$[0-9]+[KM]?|CRITICAL|HIGH|MEDIUM|LOW)" "${FINDING_DIR}/finding.md"

echo "=== Gate 4: PoC ==="
# Try to run PoC
if [ -f "${FINDING_DIR}/Exploit.t.sol" ]; then
    cd target && forge test --match-contract Exploit -vvvv
fi

echo "=== Gate 5: Report Quality ==="
# Check all sections present
for section in "Summary" "Technical Details" "Attack Scenario" "Impact" "Recommendation"; do
    if grep -q "## ${section}" "${FINDING_DIR}/finding.md"; then
        echo "  ✓ ${section} section present"
    else
        echo "  ✗ ${section} section missing"
    fi
done
```

---

## Failure Analysis

When a finding fails at a gate, document why:

```markdown
## Failed Finding: [ID]

**Failed At**: Gate [1-5]
**Reason**: [Specific failure mode]
**Lesson Learned**: [What to check next time]
**Prevented By**: [Which verification step would have caught this earlier]
```

### Common Failure Patterns

| Failure | Gate | Prevention |
|---------|------|------------|
| Hallucinated function | 1 | Always verify function exists with grep |
| Private function claimed external | 2 | Check visibility modifier |
| No proof of attacker control | 2 | Document all controllable inputs |
| Impact overestimated | 3 | Quantify with specific numbers |
| PoC doesn't compile | 4 | Test compilation before claiming valid |
| PoC reverts | 4 | Debug and fix or discard |
| Missing remediation | 5 | Always include fix with code |

---

## Integration with Ralph

Add to `IMPLEMENTATION_PLAN.md`:

```markdown
## Verification Checklist for Each Finding

- [ ] Gate 1: All code references verified
- [ ] Gate 2: Reachability and controllability proven
- [ ] Gate 3: Impact quantified
- [ ] Gate 4: PoC executes successfully
- [ ] Gate 5: Report complete and professional
```

Add to `PROMPT_build.md`:

```markdown
### For Each Hypothesis, Run Verification Gates

Before reporting a finding, it MUST pass all 5 gates:
1. Verify syntactic validity
2. Prove reachability and controllability
3. Quantify impact
4. Create working PoC
5. Write complete report
```

---

## The "Money In, Vuln Out" Principle

One way to describe what we're building: a "money in, vuln out" machine where the more tokens/compute you feed it, the more verified vulnerabilities it tends to surface. 

The system has:
- **Diminishing returns** - not linear forever
- **Strong harnesses** - verification gates prevent false positives
- **Deterministic verification** - CodeQL and simulation provide ground truth

This is fundamentally defensive: scaling verification and responsible disclosure is a necessary counterweight in a world where capability increasingly maps to "compute budget × automation."
