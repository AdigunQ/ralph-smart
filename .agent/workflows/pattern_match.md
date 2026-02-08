---
description: Find similar historical vulnerabilities using Solodit API
trigger: /pattern [vulnerability-description]
---

# /pattern - Historical Vulnerability Pattern Matching

This workflow searches the Solodit database (50,000+ vulnerabilities) for historical findings similar to your suspected vulnerability. It provides evidence-based pattern matching to inform the verification harness.

## Overview

**Purpose**: Find historically similar vulnerabilities to:
1. Confirm if the pattern is known and exploitable
2. Learn from historical exploitation techniques
3. Quantify impact based on similar incidents
4. Generate relevant PoC references

**Data Source**: [Solodit API](https://solodit.cyfrin.io/) - 50,000+ security findings

## Prerequisites

```bash
# Set your Solodit API key
export SOLODIT_API_KEY="your-api-key-here"

# Get your API key at: https://solodit.cyfrin.io/
```

## Usage

### Basic Pattern Search

```bash
# CLI usage
python scripts/pattern_matcher.py "reentrancy in withdraw function"

# Or in the audit workflow
/pattern "External call before state update in withdraw function"
```

### Advanced Search with Filters

```bash
/pattern "access control bypass on mint" --protocol DeFi --severity CRITICAL
```

### As Part of Verification Harness

When investigating a hypothesis, run:

```markdown
## HYP-001: Reentrancy in Vault.withdraw()

### Step 1: Pattern Matching

**Run**: `/pattern "external call before state update in withdraw()"`

**Expected Output**:
- Historical similar findings
- Relevance scores
- Recommended verification steps
- Historical impact data
```

## How It Works

### 1. Tag Inference

The system automatically infers Solodit tags from your description:

| Your Input | Inferred Tags |
|------------|---------------|
| "reentrancy" | Reentrancy, CEI, External Call |
| "access control" | Access Control, Authentication, Admin |
| "oracle price" | Oracle, Price Manipulation, TWAP |
| "flash loan" | Flash Loan, Price Manipulation |

### 2. Semantic Search

The API searches across:
- Finding titles
- Vulnerability descriptions
- Code snippets
- Tags
- Protocol types

### 3. Relevance Scoring

Each match is scored based on:
- **Keyword overlap** (35%): Matching security terms
- **Tag overlap** (30%): Matching vulnerability categories
- **Protocol match** (15%): Same protocol type
- **Quality score** (10%): Finding quality rating
- **Rarity score** (10%): Finding uniqueness

### 4. Report Generation

Output includes:
- Top 5 historical matches
- Average historical severity
- Common patterns
- Recommended verification steps
- Historical impact analysis

## Integration with Verification Harness

### Step 1: Observation Enhancement

```markdown
### Observation Record with Pattern Matching

**Observation**: External call before state update in withdraw()
**Location**: Vault.sol:45-52

**Historical Context** (via /pattern):
- Found 23 similar reentrancy findings
- Average severity: HIGH
- Most common tag: Reentrancy
- Recommended checks: CEI pattern, nonReentrant modifier

**Initial Confidence**: 0.7 (based on historical precedents)
```

### Step 4: Impact Assessment Enhancement

```markdown
### Impact Assessment with Historical Data

**Historical Similar Findings**:
1. Cream Finance - $130M (reentrancy + price manipulation)
2. Grim Finance - $30M (reentrancy in vault)
3. Various others - avg $2M loss

**Estimated Impact Range**: $500K - $10M
**Likelihood**: HIGH (well-known pattern)
**Severity**: CRITICAL
```

## Example Outputs

### Example 1: Reentrancy Pattern

```
$ /pattern "external call before state update in withdraw"

## Pattern Matching Report: CLI-QUERY

**Status**: ✅ 15 similar historical finding(s) identified

### Summary Statistics
- **Average Historical Severity**: HIGH
- **Average Quality Score**: 4.2/5
- **Common Tags**: Reentrancy, CEI, External Call
- **Most Affected Protocol Type**: DeFi Vaults

### Top Historical Matches

#### 1. [HIGH] Reentrancy in withdraw() allows fund drainage

**Relevance Score**: 95%
**Match Reasons**: tags: Reentrancy, CEI; keywords: withdraw, external call
**Protocol**: Grim Finance
**Audit Firm**: Independent
**Quality**: 4.5/5 | **Rarity**: 3.8/5
**Finders**: 12

A reentrancy vulnerability in the withdraw function allows attackers
to drain the vault by recursively calling withdraw before the balance
is updated...

🔗 Source: https://...

---

### Recommended Verification Steps

Based on historical findings of this type:

1. ✅ Verify CEI pattern (Checks-Effects-Interactions)
2. ✅ Check for reentrancy guards (nonReentrant modifier)
3. ✅ Ensure state is updated before external calls
```

### Example 2: No Matches Found

```
$ /pattern "novel quantum-resistant signature scheme bug"

## Pattern Matching Report: CLI-QUERY

**Status**: ❌ No similar historical findings found

**Analysis**: This appears to be a novel vulnerability pattern or the description
may need refinement to match known vulnerability types.

**Recommendation**: 
- Proceed with careful manual analysis
- Use the full 6-step verification harness
- Consider this a potentially novel finding
- Document thoroughly for the community
```

## Best Practices

### 1. When to Use Pattern Matching

**Always use when**:
- Investigating a new hypothesis
- During Step 1 (Observation)
- Before finalizing impact assessment
- When writing the final report

**Results inform**:
- Confidence scoring
- Verification priority
- Impact quantification
- PoC strategy

### 2. Interpreting Results

| Match Count | Interpretation | Action |
|-------------|----------------|--------|
| 10+ matches | Well-known pattern | Standard verification |
| 5-9 matches | Known pattern | Thorough verification |
| 1-4 matches | Rare pattern | Extra careful verification |
| 0 matches | Novel pattern | Expert review required |

### 3. High-Relevance Indicators

Matches are highly relevant when:
- Relevance score > 80%
- Same protocol type
- Same vulnerability tags
- Multiple matching keywords
- High quality score (>4.0)

## Troubleshooting

### API Key Issues

```bash
# Error: SOLODIT_API_KEY not provided
export SOLODIT_API_KEY="your-key-here"

# Verify key is set
echo $SOLODIT_API_KEY
```

### Rate Limiting

```
# If you see rate limit warnings:
# - The client automatically retries with backoff
# - Wait a few seconds between requests
# - Reduce page size if needed
```

### No Results

```
# If no results found:
# - Try different keywords
# - Remove specific filters
# - Use broader vulnerability type
# - Check API connectivity
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SOLODIT_API_KEY` | Your API key | Required |
| `SOLODIT_API_TIMEOUT` | Request timeout | 15s |
| `SOLODIT_CACHE_TTL` | Cache duration | 300s |

### Cache Behavior

Results are cached for 5 minutes to:
- Reduce API calls
- Improve response time
- Handle retries gracefully

## Comparison: Old vs New Approach

### Old Approach (File-based)

```bash
# Grepping through local files
grep -r "reentrancy" knowledges/solodit/reports/

# Problems:
# - Limited to downloaded reports
# - No relevance ranking
# - No metadata (quality, rarity)
# - Static data
```

### New Approach (API-based)

```bash
# Intelligent semantic search
/pattern "external call before state update"

# Benefits:
# - 50,000+ findings searchable
# - Relevance-ranked results
# - Rich metadata
# - Always up-to-date
```

## References

- [Solodit Platform](https://solodit.cyfrin.io/)
- [Solodit API Docs](https://docs.solodit.cyfrin.io/)
- [Solodit MCP Server](https://github.com/zerotrust-labs/solodit-mcp)
- `knowledges/solodit_integration.md` - Full integration guide
