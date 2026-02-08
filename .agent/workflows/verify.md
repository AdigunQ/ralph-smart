---
description: Verify a finding through mutation testing and the 5-gate protocol
trigger: /verify [finding-id]
---

# /verify - Mutation Testing & 5-Gate Verification

This workflow validates a specific finding or PoC by attempting to disprove it through mutation testing and rigorous verification gate checks.

## Purpose

The Skeptic Protocol: "A finding is only valid if it survives attempts to disprove it."

This prevents:
- False positives from hallucinated code
- Tests that don't actually test the vulnerability
- Findings with insufficient impact
- PoCs that fail for unrelated reasons

## When to Use

- After discovering a potential vulnerability
- Before reporting a CRITICAL/HIGH finding
- When a PoC seems "too easy"
- As part of the 5-gate verification process

## Phase 1: Syntactic Validation (Gate 1)

Verify the finding references real code:

```bash
# Check file exists
ls target/src/VulnerableFile.sol

# Verify function exists
grep -n "function vulnerableFunction" target/src/VulnerableFile.sol

# Check line numbers match
sed -n '45,50p' target/src/VulnerableFile.sol
```

**Pass Criteria**:
- [ ] All referenced files exist
- [ ] All referenced functions exist
- [ ] Line numbers are accurate
- [ ] Code snippets match actual code

**Fail Action**: Reject as hallucination

## Phase 2: Mutation Testing

### Mutation 1: Fix the Bug

**Objective**: Prove the PoC detects the actual vulnerability

1. **Apply a Fix**
   ```solidity
   // Vulnerable code
   function withdraw() external {
       uint amount = balances[msg.sender];
       (bool success, ) = msg.sender.call{value: amount}("");
       require(success);
       balances[msg.sender] = 0;  // State update after call
   }
   
   // Fixed code
   function withdraw() external nonReentrant {  // Add reentrancy guard
       uint amount = balances[msg.sender];
       balances[msg.sender] = 0;  // State update before call
       (bool success, ) = msg.sender.call{value: amount}("");
       require(success);
   }
   ```

2. **Run PoC Test**
   ```bash
   forge test --match-test testExploit -vvvv
   ```

3. **Expected Result**
   - **PASS**: Exploit no longer works (vulnerability was real)
   - **FAIL**: Exploit still works (PoC tests wrong thing)

**Pass Criteria**: Test passes after fix

### Mutation 2: Break the Assertion

**Objective**: Prove the test setup is correct

1. **Modify Test to Always Pass**
   ```solidity
   // Original
   assertEq(address(vulnerable).balance, 0);
   
   // Mutated
   assertTrue(true);  // Always passes
   ```

2. **Run Test**
   ```bash
   forge test --match-test testExploit
   ```

3. **Expected Result**
   - **PASS**: Test infrastructure works
   - **FAIL**: Test setup is broken

**Pass Criteria**: Test passes with broken assertion

### Mutation 3: Remove Preconditions

**Objective**: Prove preconditions are necessary

1. **Try Exploit Without Setup**
   ```solidity
   // Original: Requires deposit first
   function testExploit() public {
       attacker.deposit{value: 1 ether}();  // Setup
       attacker.attack();                    // Exploit
   }
   
   // Mutated: Skip setup
   function testExploit() public {
       attacker.attack();  // Should fail without setup
   }
   ```

2. **Expected Result**
   - **PASS**: Exploit fails without preconditions (realistic)
   - **FAIL**: Exploit works anyway (suspicious)

**Pass Criteria**: Preconditions are validated

## Phase 3: 5-Gate Verification Checklist

### Gate 1: Syntactic Validity ✅
```bash
./scripts/verify_gate1.sh [finding-id]
```
- [ ] Code references verified
- [ ] Functions exist
- [ ] Lines match

### Gate 2: Semantic Analysis ✅
```bash
./scripts/verify_gate2.sh [finding-id]
```
- [ ] Reachability proven (external callable)
- [ ] Controllability proven (attacker controls inputs)
- [ ] No hidden sanitizers missed

### Gate 3: Impact Assessment ✅
- [ ] Impact type classified (Theft/DoS/PrivEsc)
- [ ] Financial impact quantified (specific $ amount)
- [ ] Exploit cost calculated
- [ ] Severity justified

### Gate 4: Exploitability Proof ✅
```bash
# Compile test
forge build

# Run PoC
forge test --match-test testExploit -vvvv
```
- [ ] PoC compiles without errors
- [ ] PoC runs successfully
- [ ] Impact is demonstrated
- [ ] Results are reproducible

### Gate 5: Report Quality ✅
- [ ] Summary is clear (2-3 sentences)
- [ ] Technical details are complete
- [ ] Step-by-step reproduction
- [ ] Remediation is specific
- [ ] References to similar bugs

## Phase 4: The Skeptic's Questions

Ask these questions for every finding:

1. **Could I be wrong about the code?**
   - Did I read the right function?
   - Is there a modifier I missed?
   - Is there inheritance affecting behavior?

2. **Could I be wrong about the impact?**
   - Is there a cap on losses?
   - Does access control limit who can exploit?
   - Is there a circuit breaker?

3. **Could the PoC be flawed?**
   - Does it test the right thing?
   - Are the assertions correct?
   - Is the setup realistic?

4. **Has this been reported before?**
   - Check previous audits
   - Search for similar patterns
   - Check if it's a known issue

## Final Verdict

```markdown
## Verification Result: [FINDING-ID]

**Finding**: [Title]
**Original Confidence**: X.X
**Verification Date**: [Date]

### Mutation Test Results
- Fix Applied: [Description]
- Test Result After Fix: PASS / FAIL
- Test Result With Broken Assertion: PASS / FAIL

### 5-Gate Checklist
- [ ] Gate 1: Syntactic Validity
- [ ] Gate 2: Semantic Analysis
- [ ] Gate 3: Impact Assessment
- [ ] Gate 4: Exploitability Proof
- [ ] Gate 5: Report Quality

### Skeptic's Review
- Code accuracy: VERIFIED / QUESTIONABLE
- Impact realism: REALISTIC / OVERSTATED
- PoC validity: VALID / FLAWED
- Novelty: NEW / KNOWN

### FINAL VERDICT: CONFIRMED / REJECTED / NEEDS_REVIEW

**Confidence After Verification**: X.X

**Notes**: [Any reservations or special considerations]
```

## Integration with Workflow

The `/verify` command is automatically triggered by `/audit` for:
- All CRITICAL findings
- Random sample of HIGH findings (10%)
- Any finding with confidence < 0.9

Manual verification is recommended for:
- Findings that seem "too good to be true"
- Complex multi-step exploits
- Novel vulnerability patterns
- Before final report submission

## Common False Positive Patterns

| Pattern | Cause | Detection |
|---------|-------|-----------|
| Hallucinated function | LLM invents code | Gate 1 fails |
| Wrong visibility | Function is internal | Gate 2 fails |
| Hidden modifier | Access control exists | Gate 2 fails |
| Test artifacts | Setup unrealistic | Mutation 3 fails |
| Impact overstatement | Limited by design | Skeptic review catches |
