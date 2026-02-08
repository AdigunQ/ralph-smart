# CodeQL Integration: Determinism Injection for Vulnerability Research

> **Core Principle**: Make as much as possible deterministic, and reserve model reasoning for what can't be deterministic.

In vulnerability research, many painful "reasoning" sub-questions become straightforward when you can query semantics. When CodeQL answers a slice of the problem reliably, the agent doesn't need to "think harder"—it needs to query correctly, then move on with higher confidence and fewer compounding mistakes.

---

## Why CodeQL?

CodeQL provides:
- **Deterministic reachability**: Exact call graph queries
- **Taint tracking**: Source-to-sink data flow analysis
- **Pattern matching**: Finding specific code patterns
- **Semantic queries**: Reasoning about code structure

This turns "I think this input reaches that sink" into "The query confirms this input reaches that sink."

---

## Query Library for Smart Contract Security

### 1. Taint Tracking Queries

#### 1.1 User Input to External Call (Reentrancy)

```ql
/**
 * Finds paths where user-controlled input reaches an external call
 * without passing through a reentrancy guard.
 */

import solidity

class ExternalCall extends Call {
  ExternalCall() {
    this.getTarget().getName() = "call" or
    this.getTarget().getName() = "delegatecall" or
    this.getTarget().getName() = "staticcall" or
    this.getTarget().getName() = "transfer" or
    this.getTarget().getName() = "send"
  }
}

class UserInput extends Parameter {
  UserInput() {
    exists(Function f | f.getParameter(0) = this and
      (f.isPublic() or f.isExternal()))
  }
}

predicate hasReentrancyGuard(Function f) {
  exists(ModifierInvocation mi |
    mi.getModifier().getName() = "nonReentrant" and
    mi = f.getModifierInvocation(_)
  )
}

from UserInput source, ExternalCall sink, Function f
where
  f.getParameter(_) = source and
  not hasReentrancyGuard(f) and
  DataFlow::localFlow(DataFlow::parameterNode(source), DataFlow::exprNode(sink.getArgument(0)))
select source, "User input may reach external call without reentrancy protection"
```

#### 1.2 Unchecked External Call Return Values

```ql
/**
 * Finds low-level calls where return values are not checked.
 */

import solidity

from FunctionCall call
where
  call.getTarget().getName() = "call" and
  not exists(IfStmt ifStmt |
    ifStmt.getCondition().getAChild*() = call
  ) and
  not exists(Variable v |
    v.getInitializer() = call and
    exists(IfStmt ifStmt | ifStmt.getCondition().getAChild*() = v.getAnAccess())
  )
select call, "Unchecked low-level call"
```

#### 1.3 Taint to State-Changing Operations

```ql
/**
 * Tracks user input to sensitive state changes.
 */

import solidity

class SensitiveOperation extends Expr {
  SensitiveOperation() {
    this instanceof Assignment or
    this instanceof FunctionCall
  }
}

from Parameter userInput, SensitiveOperation op
where
  userInput.getFunction().isPublic() and
  DataFlow::localFlow(DataFlow::parameterNode(userInput), DataFlow::exprNode(op))
select userInput, op, "User input reaches state-changing operation"
```

### 2. Access Control Queries

#### 2.1 Missing Access Control on Sensitive Functions

```ql
/**
 * Finds functions that modify state without access control.
 */

import solidity

predicate isSensitiveStateChange(Function f) {
  exists(Assignment a |
    a.getEnclosingFunction() = f and
    a.getLValue().(VariableAccess).getTarget().getName() = "owner"
  ) or
  exists(FunctionCall c |
    c.getEnclosingFunction() = f and
    c.getTarget().getName() = "selfdestruct"
  ) or
  exists(Variable v |
    v.getName() = "balances" and
    exists(Assignment a |
      a.getEnclosingFunction() = f and
      a.getLValue().getAChild*().(VariableAccess).getTarget() = v
    )
  )
}

predicate hasAccessControl(Function f) {
  exists(ModifierInvocation mi |
    mi.getModifier().getName() in ["onlyOwner", "onlyAdmin", "auth", "authorized", "requiresAuth"]
  ) or
  exists(RequireStmt req |
    req.getEnclosingFunction() = f and
    req.getCondition().getAChild*().(VariableAccess).getTarget().getName() = "owner"
  )
}

from Function f
where
  isSensitiveStateChange(f) and
  not hasAccessControl(f) and
  (f.isPublic() or f.isExternal())
select f, "Sensitive state-changing function lacks access control"
```

#### 2.2 Admin Function Visibility

```ql
/**
 * Finds admin functions that are unnecessarily public.
 */

import solidity

from Function f
where
  exists(ModifierInvocation mi |
    mi.getModifier().getName() in ["onlyOwner", "onlyAdmin"] and
    mi = f.getModifierInvocation(_)
  ) and
  (f.isPublic() or f.isExternal()) and
  not exists(FunctionCall c |
    c.getTarget() = f and
    c.getEnclosingFunction() != f
  )
select f, "Admin-only function could be internal"
```

### 3. Oracle and Price Feed Queries

#### 3.1 Missing Staleness Check

```ql
/**
 * Finds Chainlink oracle calls without staleness validation.
 */

import solidity

class ChainlinkCall extends FunctionCall {
  ChainlinkCall() {
    this.getTarget().getName() in ["latestRoundData", "getRoundData"]
  }
}

from ChainlinkCall call, Function f
where
  call.getEnclosingFunction() = f and
  not exists(RequireStmt req |
    req.getEnclosingFunction() = f and
    req.getCondition().getAChild*().(VariableAccess).getTarget().getName() = "updatedAt"
  )
select call, "Oracle call without staleness check"
```

#### 3.2 Spot Price Usage

```ql
/**
 * Finds usage of manipulable spot prices.
 */

import solidity

from FunctionCall call
where
  call.getTarget().getName() = "slot0" and
  exists(VariableAccess va |
    va.getTarget().getName() = "sqrtPriceX96" and
    va.getEnclosingFunction() = call.getEnclosingFunction()
  )
select call, "Using manipulable slot0 price"
```

### 4. Arithmetic and Precision Queries

#### 4.1 Division Before Multiplication

```ql
/**
 * Finds patterns where division occurs before multiplication.
 */

import solidity

from BinaryExpression div, BinaryExpression mul
where
  div.getOperator() = "/" and
  mul.getOperator() = "*" and
  div.getParent*() = mul and
  div.getEnclosingFunction() = mul.getEnclosingFunction()
select div, mul, "Division before multiplication may cause precision loss"
```

#### 4.2 Unchecked Arithmetic (Pre-Solidity 0.8)

```ql
/**
 * Finds arithmetic operations that might overflow in pre-0.8 Solidity.
 */

import solidity

from BinaryExpression expr
where
  expr.getOperator() in ["+", "-", "*"] and
  not exists(UsingDirective ud |
    ud.getLibrary().getName() = "SafeMath"
  ) and
  not expr.getEnclosingFunction().getModifierInvocation(_).getModifier().getName() = "unchecked"
select expr, "Potential overflow/underflow in pre-0.8 Solidity"
```

### 5. Reentrancy Queries

#### 5.1 Checks-Effects-Interactions Violations

```ql
/**
 * Finds external calls before state updates (CEI violation).
 */

import solidity

predicate isStateUpdate(Expr e) {
  e instanceof Assignment or
  e instanceof UnaryAssignExpr
}

from FunctionCall externalCall, Expr stateUpdate
where
  (externalCall.getTarget().getName() = "call" or
   externalCall.getTarget().getName() = "transfer" or
   externalCall.getTarget().getName() = "send") and
  isStateUpdate(stateUpdate) and
  externalCall.getASuccessor+() = stateUpdate and
  externalCall.getEnclosingFunction() = stateUpdate.getEnclosingFunction()
select externalCall, stateUpdate, "External call before state update (CEI violation)"
```

### 6. Call Graph Queries

#### 6.1 Reachable from External

```ql
/**
 * Finds all functions reachable from external entry points.
 */

import solidity

from Function entry, Function target
where
  (entry.isPublic() or entry.isExternal()) and
  entry.calls+(target)
select entry, target, "Target is reachable from external entry"
```

#### 6.2 Dead Code Detection

```ql
/**
 * Finds functions that are never called.
 */

import solidity

from Function f
where
  not exists(FunctionCall c | c.getTarget() = f) and
  not f.isPublic() and
  not f.isExternal() and
  not f.getName() = "constructor"
select f, "Potentially unused internal function"
```

---

## Query Execution Workflow

### Step 1: Database Creation

```bash
# Create CodeQL database for Solidity project
codeql database create solidity-db \
  --language=solidity \
  --source-root=./target \
  --command="forge build"
```

### Step 2: Query Execution

```bash
# Run specific query
codeql query run --database=solidity-db knowledges/codeql_queries/reentrancy.ql

# Run query suite
codeql query run --database=solidity-db ql/solidity/ql/src/Security/
```

### Step 3: Results Interpretation

```bash
# Generate SARIF output
codeql query run --database=solidity-db \
  --output=results.sarif \
  --format=sarifv2.1.0 \
  knowledges/codeql_queries/reentrancy.ql

# Generate CSV for analysis
codeql query run --database=solidity-db \
  --output=results.csv \
  --format=csv \
  knowledges/codeql_queries/reentrancy.ql
```

---

## Integration with Ralph

### Pre-Audit Queries

Run these before starting the audit:

```bash
#!/bin/bash
# Prefer: ./scripts/run_codeql_baseline.sh
# Fallback: manual baseline example below

echo "Creating CodeQL database..."
codeql database create findings/codeql-db \
  --language=solidity \
  --source-root=./target

echo "Running baseline security queries..."

echo "1. Unchecked external calls..."
codeql query run --database=findings/codeql-db \
  knowledges/codeql_queries/unchecked_calls.ql > findings/unchecked_calls.txt

echo "2. Missing access control..."
codeql query run --database=findings/codeql-db \
  knowledges/codeql_queries/missing_access_control.ql > findings/access_control.txt

echo "3. Oracle staleness issues..."
codeql query run --database=findings/codeql-db \
  knowledges/codeql_queries/oracle_staleness.ql > findings/oracle_issues.txt

echo "4. Reentrancy patterns..."
codeql query run --database=findings/codeql-db \
  knowledges/codeql_queries/reentrancy.ql > findings/reentrancy_patterns.txt

echo "Baseline complete. Results in findings/"
```

### Per-Hypothesis Queries

For each vulnerability hypothesis, run targeted queries:

```markdown
## Hypothesis: Reentrancy in withdraw()

**Step 1: Verify external calls**
```bash
codeql query run --database=findings/codeql-db \
  -c "target_function=withdraw" \
  knowledges/codeql_queries/external_calls_in_function.ql
```

**Step 2: Check state updates after external call**
```bash
codeql query run --database=findings/codeql-db \
  -c "target_function=withdraw" \
  knowledges/codeql_queries/state_updates_after_call.ql
```

**Step 3: Verify reentrancy guard absence**
```bash
codeql query run --database=findings/codeql-db \
  -c "target_function=withdraw" \
  knowledges/codeql_queries/missing_reentrancy_guard.ql
```
```

### Results Integration

Add to `IMPLEMENTATION_PLAN.md`:

```markdown
## CodeQL Findings Summary

### High Confidence Issues (CodeQL detected)
- [ ] CEI-001: External call before state update in `withdraw()` 
- [ ] AC-002: Missing access control on `updateOracle()`

### Patterns Requiring Manual Review
- [ ] RENT-003: External call pattern in `claimRewards()` - verify reentrancy guard
```

---

## When to Use CodeQL vs Model Reasoning

| Task | Tool | Why |
|------|------|-----|
| Find all external calls | CodeQL | Deterministic, exhaustive |
| Check if input reaches sink | CodeQL | Taint tracking is reliable |
| Find all public functions | CodeQL | AST query is exact |
| Determine if bug is exploitable | Model | Requires reasoning about context |
| Assess business impact | Model | Needs domain knowledge |
| Generate PoC | Both | CodeQL finds pattern, model writes exploit |
| Verify fix completeness | CodeQL | Re-run query to verify pattern gone |

---

## Custom Query Development

### Template for New Queries

```ql
/**
 * @name [Query Name]
 * @description [What it finds]
 * @kind problem
 * @problem.severity [error/warning/recommendation]
 * @precision [high/medium/low]
 * @tags security
 */

import solidity

// Define predicates
predicate isInteresting(Function f) {
  // Your conditions
}

// Main query
from Function f
where
  isInteresting(f)
select f, "Description of the issue"
```

### Testing Queries

```bash
# Test against known vulnerable contract
codeql query run --database=test-db query.ql

# Verify results match expectations
diff expected.txt actual.txt
```

---

## Best Practices

1. **Query First, Reason Second**: Always run relevant CodeQL queries before spending model tokens on reasoning
2. **Cache Results**: Save query results to avoid re-running expensive analyses
3. **Query Coverage**: Build a library of queries for your most common vulnerability types
4. **Validate Results**: CodeQL can have false positives—always verify findings
5. **Combine Approaches**: Use CodeQL to narrow focus, then use model reasoning for complex cases

---

## References

- [CodeQL for Solidity](https://github.com/github/codeql)
- [Trail of Bits Queries](https://github.com/trailofbits/codeql-queries)
- [Crytic/SlithIR](https://github.com/crytic/slither) - Alternative static analysis
