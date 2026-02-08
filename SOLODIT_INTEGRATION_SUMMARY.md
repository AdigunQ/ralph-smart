# Solodit API Integration for Ralph - Summary

## Overview

The Ralph security agent now integrates with the **Solodit API** to provide intelligent pattern matching against 50,000+ historical smart contract vulnerabilities. This replaces the previous file-based grep approach with a semantic search API.

---

## What Changed

### Before (File-Based)
```bash
# Limited local search
grep -r "reentrancy" knowledges/solodit/reports/
```

**Problems:**
- Only searched downloaded reports (~300)
- No semantic understanding
- No relevance ranking
- No metadata (quality scores, rarity)
- Static, outdated data

### After (API-Based)
```bash
# Intelligent semantic search
python scripts/pattern_matcher.py "external call before state update"
```

**Benefits:**
- Search 50,000+ vulnerabilities
- Relevance-ranked results
- Rich metadata (quality, rarity, finder counts)
- Always up-to-date
- Historical impact analysis

---

## New Files Created

| File | Purpose |
|------|---------|
| `knowledges/solodit_integration.md` | Complete integration documentation |
| `scripts/solodit_client.py` | Production-ready API client |
| `scripts/pattern_matcher.py` | Pattern matching with relevance scoring |
| `.agent/workflows/pattern_match.md` | `/pattern` workflow documentation |

---

## Integration Points

### 1. Verification Harness Step 1.5

Pattern matching is now part of the standard verification process:

```
Step 1: Observation
Step 1.5: Pattern Matching (NEW)  ← Search Solodit for similar issues
Step 2: Reachability
Step 3: Controllability
Step 4: Impact Assessment (enhanced with historical data)
Step 5: PoC
Step 6: Report
```

### 2. Impact Assessment Enhancement

Historical impact data from Solodit informs severity ratings:
- Average loss from similar findings
- Largest historical exploits
- Exploit frequency
- Time to exploit complexity

### 3. New `/pattern` Workflow

```bash
# Find similar vulnerabilities
/pattern "reentrancy in withdraw function" --protocol DeFi --severity HIGH
```

---

## Setup

### 1. Get API Key

1. Sign up at [solodit.cyfrin.io](https://solodit.cyfrin.io/)
2. Generate API key from dropdown menu
3. Set environment variable:
   ```bash
   export SOLODIT_API_KEY="your-api-key-here"
   ```

### 2. Test Integration

```bash
# Test the client
python scripts/solodit_client.py --tags Reentrancy --impact HIGH --page-size 5

# Test pattern matching
python scripts/pattern_matcher.py "access control bypass" --severity HIGH
```

---

## Usage Examples

### Example 1: During Audit

When investigating a hypothesis:

```markdown
## HYP-001: Reentrancy in Vault.withdraw()

### Step 1: Observation
[Document suspicious pattern]

### Step 1.5: Pattern Matching
```bash
python scripts/pattern_matcher.py \
  "external call before state update in withdraw" \
  --protocol DeFi \
  --severity HIGH \
  --save findings/tasks/HYP-001/pattern_match.md
```

**Results**:
- ✅ Found 15 similar historical findings
- Average severity: HIGH
- Top match: Grim Finance ($30M loss)
- Relevance: 95%
- Confidence adjustment: +0.2
```

### Example 2: CLI Usage

```bash
# Basic search
python scripts/pattern_matcher.py "oracle price manipulation"

# With filters
python scripts/pattern_matcher.py \
  "flash loan price manipulation" \
  --protocol Lending \
  --severity HIGH \
  --min-similarity 0.7 \
  --save report.md
```

### Example 3: In Code

```python
from scripts.pattern_matcher import PatternMatcher

matcher = PatternMatcher()
matches = matcher.find_similar_vulnerabilities(
    vulnerability_description="access control missing on mint",
    protocol_type="DeFi",
    severity="CRITICAL"
)

report = matcher.generate_report("HYP-001", matches)
print(report)
```

---

## Key Features

### 1. Automatic Tag Inference

The system automatically maps descriptions to Solodit tags:

| Description Contains | Inferred Tags |
|---------------------|---------------|
| "reentrancy" | Reentrancy, CEI, External Call |
| "access control" | Access Control, Authentication, Admin |
| "oracle price" | Oracle, Price Manipulation, TWAP |
| "flash loan" | Flash Loan, Price Manipulation |

### 2. Relevance Scoring

Matches are scored (0-100%) based on:
- Keyword overlap (35%)
- Tag overlap (30%)
- Protocol match (15%)
- Quality score (10%)
- Rarity score (10%)

### 3. Rich Reporting

Reports include:
- Top 5 historical matches
- Average historical severity
- Common vulnerability patterns
- Recommended verification steps
- Historical impact analysis

---

## API Client Features

### Caching
- Results cached for 5 minutes
- Reduces API calls
- Improves response time

### Rate Limiting
- Automatic retry with backoff
- Respects rate limits
- Configurable timeout

### Error Handling
- Graceful fallbacks
- Clear error messages
- Connection retry logic

---

## Configuration

| Environment Variable | Description | Default |
|---------------------|-------------|---------|
| `SOLODIT_API_KEY` | Your API key | Required |
| `SOLODIT_API_TIMEOUT` | Request timeout | 15s |
| `SOLODIT_CACHE_TTL` | Cache duration | 300s |

---

## Troubleshooting

### No API Key
```bash
Error: SOLODIT_API_KEY not provided

Solution:
export SOLODIT_API_KEY="your-key-here"
```

### Rate Limited
```
Warning: Rate limited. Retrying after 2s

Note: This is handled automatically by the client
```

### No Results
```
No similar historical vulnerabilities found

Interpretation: This may be a novel finding!
Action: Proceed with extra thorough verification
```

---

## Benefits for Ralph

1. **Evidence-Based Analysis**: Historical data supports findings
2. **Impact Quantification**: Real loss data from similar exploits
3. **Novel Detection**: Identifies truly unique vulnerabilities
4. **Confidence Scoring**: Data-driven confidence adjustments
5. **Report Quality**: Reference similar findings in reports

---

## Migration Guide

If you were using the old file-based approach:

1. **Set up API key** (one-time)
2. **Replace grep commands** with pattern matcher
3. **Add pattern matching step** to verification harness
4. **Use historical data** in impact assessment

---

## References

- [Solodit Platform](https://solodit.cyfrin.io/)
- [Solodit Documentation](https://docs.solodit.cyfrin.io/)
- [Full Integration Guide](knowledges/solodit_integration.md)
- [Pattern Matcher Usage](.agent/workflows/pattern_match.md)
