# CodeQL Queries for Smart Contract Security

This directory contains CodeQL queries for deterministic analysis of Solidity smart contracts.

## Quick Start

```bash
# Run all baseline queries
./scripts/run_codeql_baseline.sh

# Or run individually
codeql query run --database=findings/codeql-db knowledges/codeql_queries/reentrancy.ql
```

## Query Categories

### Security Queries (High Priority)

| Query | Purpose | Severity |
|-------|---------|----------|
| `reentrancy.ql` | Finds CEI violations and external calls before state updates | Error |
| `unchecked_calls.ql` | Finds low-level calls with unchecked return values | Warning |
| `missing_access_control.ql` | Finds sensitive functions without proper authorization | Error |
| `oracle_staleness.ql` | Finds oracle calls without staleness checks | Warning |

### Audit Queries (Informational)

| Query | Purpose |
|-------|---------|
| `external_functions.ql` | Lists all external/public functions for attack surface analysis |
| `state_mutation.ql` | Tracks which functions modify which state variables |

## Adding New Queries

### Template

```ql
/**
 * @name Query Name
 * @description What this query finds
 * @kind problem
 * @problem.severity [error/warning/recommendation]
 * @precision [high/medium/low]
 * @tags security
 * @id solidity/query-id
 */

import solidity

from Element e
where
  // Your conditions
select e, "Description of the issue"
```

### Testing

1. Create a test contract with known vulnerabilities
2. Create CodeQL database: `codeql database create test-db --language=solidity --source-root=./test`
3. Run query: `codeql query run --database=test-db your_query.ql`
4. Verify results match expectations

## Integration with Ralph

Queries are automatically run during:
- Planning phase: Baseline analysis to identify high-confidence patterns
- Building phase: Targeted queries for specific hypotheses

Results are saved to `findings/codeql_results/` for review.

## References

- [CodeQL for Go](https://codeql.github.com/docs/codeql-language-guides/codeql-library-for-go/)
- [CodeQL Queries](https://github.com/github/codeql)
- [Trail of Bits Queries](https://github.com/trailofbits/codeql-queries)
