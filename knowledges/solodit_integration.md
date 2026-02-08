# Solodit API Integration for Ralph

> **The Solodit API provides programmatic access to 50,000+ smart contract security findings.**
> 
> API Base: `https://solodit.cyfrin.io/api/v1/solodit`
> Documentation: `https://docs.solodit.cyfrin.io/`

---

## Getting Started

### 1. Create Account & Get API Key

1. Sign up at [solodit.cyfrin.io](https://solodit.cyfrin.io/)
2. Generate API key from dropdown menu
3. Set environment variable:
   ```bash
   export SOLODIT_API_KEY="your-api-key-here"
   ```

### 2. Rate Limits

- Default: Check `X-RateLimit-*` headers in responses
- Retry logic: Built into the client
- Max page size: 100 results per request

---

## API Client Implementation

### Python Client (`scripts/solodit_client.py`)

```python
#!/usr/bin/env python3
"""
Solodit API Client for Ralph Security Agent
Provides intelligent vulnerability pattern matching and historical finding lookup.
"""

import os
import json
import time
from typing import List, Dict, Optional, Literal
from dataclasses import dataclass
from datetime import datetime
import requests
from urllib.parse import urljoin

# API Configuration
SOLODIT_API_BASE = "https://solodit.cyfrin.io/api/v1/solodit"
DEFAULT_TIMEOUT = 15
MAX_RETRIES = 3


@dataclass
class SoloditFinding:
    """Represents a single vulnerability finding from Solodit"""
    id: str
    slug: str
    title: str
    content: str
    summary: Optional[str]
    impact: Literal["HIGH", "MEDIUM", "LOW", "GAS"]
    quality_score: float
    rarity_score: float
    report_date: Optional[str]
    firm_name: Optional[str]
    protocol_name: Optional[str]
    finders_count: int
    source_link: Optional[str]
    tags: List[str]
    finders: List[str]
    
    @property
    def severity_int(self) -> int:
        """Convert impact to numeric severity"""
        return {"HIGH": 3, "MEDIUM": 2, "LOW": 1, "GAS": 0}.get(self.impact, 0)


@dataclass
class SearchResult:
    """Container for search results with metadata"""
    findings: List[SoloditFinding]
    total_results: int
    current_page: int
    total_pages: int
    query_time_ms: float
    rate_limit_remaining: int
    rate_limit_reset: int


class SoloditClient:
    """
    Production-ready Solodit API client for Ralph Security Agent.
    Implements retry logic, rate limiting, and intelligent caching.
    """
    
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.environ.get("SOLODIT_API_KEY")
        if not self.api_key:
            raise ValueError(
                "SOLODIT_API_KEY not provided. "
                "Get your key at https://solodit.cyfrin.io/"
            )
        
        self.session = requests.Session()
        self.session.headers.update({
            "Content-Type": "application/json",
            "X-Cyfrin-API-Key": self.api_key,
        })
        
        # Simple in-memory cache
        self._cache: Dict[str, tuple] = {}
        self._cache_ttl = 300  # 5 minutes
    
    def _make_request(
        self,
        endpoint: str,
        data: Dict,
        timeout: int = DEFAULT_TIMEOUT
    ) -> Dict:
        """Make API request with retry logic"""
        url = urljoin(SOLODIT_API_BASE, endpoint)
        
        for attempt in range(MAX_RETRIES):
            try:
                response = self.session.post(
                    url,
                    json=data,
                    timeout=timeout
                )
                
                # Handle rate limiting
                if response.status_code == 429:
                    retry_after = int(response.headers.get("Retry-After", 2))
                    if attempt < MAX_RETRIES - 1:
                        time.sleep(retry_after)
                        continue
                
                response.raise_for_status()
                return response.json()
                
            except requests.exceptions.Timeout:
                if attempt < MAX_RETRIES - 1:
                    time.sleep(0.5 * (attempt + 1))
                    continue
                raise
            except requests.exceptions.RequestException as e:
                if attempt < MAX_RETRIES - 1:
                    time.sleep(0.5 * (attempt + 1))
                    continue
                raise SoloditAPIError(f"Request failed: {e}")
        
        raise SoloditAPIError("Max retries exceeded")
    
    def search_findings(
        self,
        keywords: Optional[str] = None,
        impact: Optional[List[str]] = None,
        firms: Optional[List[str]] = None,
        tags: Optional[List[str]] = None,
        protocol: Optional[str] = None,
        protocol_category: Optional[List[str]] = None,
        languages: Optional[List[str]] = None,
        user: Optional[str] = None,
        reported_days: Optional[str] = None,
        quality_score_min: Optional[float] = None,
        rarity_score_min: Optional[float] = None,
        sort_field: str = "Recency",
        sort_direction: str = "Desc",
        page: int = 1,
        page_size: int = 20
    ) -> SearchResult:
        """
        Search for vulnerability findings with comprehensive filters.
        
        Args:
            keywords: Search in title and content
            impact: Filter by severity ["HIGH", "MEDIUM", "LOW", "GAS"]
            firms: Filter by audit firm names
            tags: Filter by vulnerability tags
            protocol: Filter by protocol name
            protocol_category: Filter by category ["DeFi", "NFT", "Lending", etc.]
            languages: Filter by language ["Solidity", "Rust", "Cairo"]
            user: Filter by finder handle
            reported_days: "30", "60", "90", or "alltime"
            quality_score_min: Minimum quality (0-5)
            rarity_score_min: Minimum rarity (0-5)
            sort_field: "Recency", "Quality", or "Rarity"
            sort_direction: "Desc" or "Asc"
            page: Page number (1-based)
            page_size: Results per page (max 100)
        """
        # Build filters
        filters = {}
        if keywords:
            filters["keywords"] = keywords
        if impact:
            filters["impact"] = impact
        if firms:
            filters["firms"] = [{"value": f} for f in firms]
        if tags:
            filters["tags"] = [{"value": t} for t in tags]
        if protocol:
            filters["protocol"] = protocol
        if protocol_category:
            filters["protocolCategory"] = [{"value": c} for c in protocol_category]
        if languages:
            filters["languages"] = [{"value": l} for l in languages]
        if user:
            filters["user"] = user
        if reported_days:
            filters["reported"] = {"value": reported_days}
        if quality_score_min is not None:
            filters["qualityScore"] = quality_score_min
        if rarity_score_min is not None:
            filters["rarityScore"] = rarity_score_min
        if sort_field:
            filters["sortField"] = sort_field
        if sort_direction:
            filters["sortDirection"] = sort_direction
        
        request_data = {
            "page": page,
            "pageSize": min(page_size, 100),
        }
        if filters:
            request_data["filters"] = filters
        
        # Check cache
        cache_key = json.dumps(request_data, sort_keys=True)
        cached = self._cache.get(cache_key)
        if cached:
            result, timestamp = cached
            if time.time() - timestamp < self._cache_ttl:
                return result
        
        response = self._make_request("/findings", request_data)
        
        # Parse findings
        findings = []
        for f in response.get("findings", []):
            findings.append(SoloditFinding(
                id=f["id"],
                slug=f["slug"],
                title=f["title"],
                content=f["content"],
                summary=f.get("summary"),
                impact=f["impact"],
                quality_score=f["quality_score"],
                rarity_score=f["general_score"],
                report_date=f.get("report_date"),
                firm_name=f.get("firm_name"),
                protocol_name=f.get("protocol_name"),
                finders_count=f["finders_count"],
                source_link=f.get("source_link"),
                tags=[t["tags_tag"]["title"] for t in f.get("issues_issuetagscore", [])],
                finders=[finder["wardens_warden"]["handle"] 
                        for finder in f.get("issues_issue_finders", [])]
            ))
        
        metadata = response.get("metadata", {})
        rate_limit = response.get("rateLimit", {})
        
        result = SearchResult(
            findings=findings,
            total_results=metadata.get("totalResults", 0),
            current_page=metadata.get("currentPage", 1),
            total_pages=metadata.get("totalPages", 1),
            query_time_ms=metadata.get("elapsed", 0) * 1000,
            rate_limit_remaining=rate_limit.get("remaining", 0),
            rate_limit_reset=rate_limit.get("reset", 0)
        )
        
        # Cache result
        self._cache[cache_key] = (result, time.time())
        
        return result
    
    def get_finding_by_id(self, finding_id: str) -> Optional[SoloditFinding]:
        """Get detailed information about a specific finding"""
        results = self.search_findings(keywords=finding_id, page_size=1)
        if results.findings:
            return results.findings[0]
        return None
    
    def search_similar_findings(
        self,
        vulnerability_type: str,
        protocol_type: Optional[str] = None,
        min_quality: float = 3.0,
        max_results: int = 10
    ) -> List[SoloditFinding]:
        """
        Find similar historical vulnerabilities.
        
        This is the main method Ralph uses for pattern matching.
        """
        # Map common vulnerability names to Solodit tags
        tag_mapping = {
            "reentrancy": ["Reentrancy", "CEI", "External Call"],
            "access_control": ["Access Control", "Authentication", "Admin"],
            "oracle": ["Oracle", "Price Manipulation", "TWAP"],
            "flash_loan": ["Flash Loan", "Price Manipulation"],
            "rounding": ["Rounding", "Precision", "Decimals"],
            "overflow": ["Overflow", "Underflow", "SafeMath"],
            "delegatecall": ["Delegatecall", "Proxy"],
            "signature": ["Signature", "ECDSA", "EIP-712"],
            "frontrunning": ["Frontrunning", "MEV", "Sandwich"],
            "dos": ["DOS", "Gas Limit", "Denial-Of-Service"],
        }
        
        tags = tag_mapping.get(vulnerability_type.lower(), [vulnerability_type])
        
        results = self.search_findings(
            tags=tags,
            protocol_category=[protocol_type] if protocol_type else None,
            quality_score_min=min_quality,
            sort_field="Quality",
            page_size=max_results
        )
        
        return results.findings


class SoloditAPIError(Exception):
    """Custom exception for Solodit API errors"""
    pass


# Singleton instance
_client: Optional[SoloditClient] = None

def get_client() -> SoloditClient:
    """Get or create Solodit client singleton"""
    global _client
    if _client is None:
        _client = SoloditClient()
    return _client
```

---

## Ralph Integration

### Pattern Matching Workflow

```python
# scripts/pattern_matcher.py

#!/usr/bin/env python3
"""
Intelligent Pattern Matching using Solodit API
Integrates with Ralph's verification harness for historical vulnerability lookup.
"""

import sys
from typing import List, Dict
from dataclasses import dataclass

# Import the Solodit client
from solodit_client import get_client, SoloditFinding


@dataclass
class PatternMatch:
    """Represents a matched pattern with relevance score"""
    finding: SoloditFinding
    relevance_score: float  # 0.0 - 1.0
    match_reasons: List[str]


class PatternMatcher:
    """
    Intelligent pattern matcher that finds similar vulnerabilities.
    Part of Ralph's Step 1 (Observation) and Step 4 (Impact Assessment).
    """
    
    def __init__(self):
        self.client = get_client()
    
    def find_similar_vulnerabilities(
        self,
        vulnerability_description: str,
        code_snippet: Optional[str] = None,
        protocol_type: Optional[str] = None,
        severity: Optional[str] = None,
        min_similarity: float = 0.7
    ) -> List[PatternMatch]:
        """
        Find historically similar vulnerabilities.
        
        Args:
            vulnerability_description: Description of the suspected vulnerability
            code_snippet: Optional code snippet for semantic matching
            protocol_type: Type of protocol (DeFi, NFT, etc.)
            severity: Expected severity (HIGH, MEDIUM, LOW)
            min_similarity: Minimum relevance threshold
        
        Returns:
            List of pattern matches sorted by relevance
        """
        # Extract keywords from description
        keywords = self._extract_keywords(vulnerability_description)
        
        # Determine tags from description
        tags = self._infer_tags(vulnerability_description, code_snippet)
        
        # Search Solodit
        results = self.client.search_findings(
            keywords=" ".join(keywords[:3]),  # Top 3 keywords
            tags=tags if tags else None,
            impact=[severity] if severity else None,
            protocol_category=[protocol_type] if protocol_type else None,
            quality_score_min=3.0,  # High quality findings only
            sort_field="Quality",
            page_size=20
        )
        
        # Score and rank matches
        matches = []
        for finding in results.findings:
            score, reasons = self._calculate_relevance(
                finding, vulnerability_description, code_snippet
            )
            if score >= min_similarity:
                matches.append(PatternMatch(
                    finding=finding,
                    relevance_score=score,
                    match_reasons=reasons
                ))
        
        # Sort by relevance
        matches.sort(key=lambda m: m.relevance_score, reverse=True)
        return matches[:10]  # Return top 10
    
    def _extract_keywords(self, text: str) -> List[str]:
        """Extract relevant keywords from text"""
        # Security-relevant keywords
        security_terms = [
            "reentrancy", "access control", "oracle", "flash loan",
            "overflow", "underflow", "delegatecall", "signature",
            "frontrunning", " sandwich", "dos", "griefing",
            "rounding", "precision", "fee", "reward",
            "collateral", "liquidation", "governance", "timelock"
        ]
        
        text_lower = text.lower()
        found = []
        for term in security_terms:
            if term in text_lower:
                found.append(term)
        
        return found
    
    def _infer_tags(
        self,
        description: str,
        code_snippet: Optional[str]
    ) -> List[str]:
        """Infer Solodit tags from description and code"""
        tags = []
        text = (description + " " + (code_snippet or "")).lower()
        
        # Pattern-based tag inference
        patterns = {
            "Reentrancy": ["reentrancy", "re-entrancy", "external call", "callback"],
            "Access Control": ["access control", "onlyowner", "auth", "permission"],
            "Oracle": ["oracle", "price feed", "chainlink", "twap"],
            "Flash Loan": ["flash loan", "flashloan"],
            "Rounding": ["rounding", "precision", "division before multiplication"],
            "Overflow": ["overflow", "underflow", "safemath"],
            "Delegatecall": ["delegatecall", "delegate call", "proxy"],
            "Signature": ["signature", "ecrecover", "eip-712"],
        }
        
        for tag, keywords in patterns.items():
            if any(kw in text for kw in keywords):
                tags.append(tag)
        
        return tags
    
    def _calculate_relevance(
        self,
        finding: SoloditFinding,
        description: str,
        code_snippet: Optional[str]
    ) -> tuple[float, List[str]]:
        """Calculate relevance score between finding and query"""
        score = 0.0
        reasons = []
        
        desc_lower = description.lower()
        content_lower = finding.content.lower()
        
        # Keyword overlap (0.4 max)
        keywords = self._extract_keywords(description)
        matching_keywords = [k for k in keywords if k in content_lower]
        score += len(matching_keywords) / max(len(keywords), 1) * 0.4
        if matching_keywords:
            reasons.append(f"Keywords: {', '.join(matching_keywords[:3])}")
        
        # Tag overlap (0.3 max)
        query_tags = self._infer_tags(description, code_snippet)
        matching_tags = set(query_tags) & set(finding.tags)
        score += len(matching_tags) / max(len(query_tags), 1) * 0.3
        if matching_tags:
            reasons.append(f"Tags: {', '.join(matching_tags)}")
        
        # Quality bonus (0.2 max)
        score += (finding.quality_score / 5.0) * 0.2
        
        # Rarity bonus (0.1 max)
        score += (finding.rarity_score / 5.0) * 0.1
        
        return min(score, 1.0), reasons
    
    def generate_report(
        self,
        hypothesis_id: str,
        matches: List[PatternMatch]
    ) -> str:
        """Generate a pattern matching report for a hypothesis"""
        if not matches:
            return f"""
## Pattern Matching Report: {hypothesis_id}

**Status**: No similar historical findings found

**Analysis**: This appears to be a novel vulnerability pattern or the description
may need refinement to match known vulnerability types.

**Recommendation**: Proceed with careful manual analysis.
"""
        
        report = f"""
## Pattern Matching Report: {hypothesis_id}

**Status**: {len(matches)} similar historical findings identified

### Top Matches

"""
        
        for i, match in enumerate(matches[:5], 1):
            f = match.finding
            report += f"""
#### {i}. [{f.impact}] {f.title}

**Relevance**: {match.relevance_score:.0%}
**Match Reasons**: {', '.join(match.match_reasons)}
**Protocol**: {f.protocol_name or "N/A"}
**Audit Firm**: {f.firm_name or "N/A"}
**Quality Score**: {f.quality_score}/5
**Tags**: {', '.join(f.tags[:5])}

{f.summary or f.content[:300]}...

**Source**: {f.source_link or "N/A"}

---
"""
        
        report += f"""
### Historical Impact Analysis

Based on similar findings:
- **Average Severity**: {self._avg_severity(matches)}
- **Common Affected Patterns**: {self._common_patterns(matches)}
- **Recommended Checks**: {self._recommended_checks(matches)}

### Next Steps

1. Review the matched findings for exploitation patterns
2. Adapt historical PoCs to the current target
3. Verify the vulnerability exists with the verification harness
"""
        
        return report
    
    def _avg_severity(self, matches: List[PatternMatch]) -> str:
        """Calculate average severity from matches"""
        severities = [m.finding.severity_int for m in matches]
        avg = sum(severities) / len(severities) if severities else 0
        return {3: "HIGH", 2: "MEDIUM", 1: "LOW", 0: "GAS/INFO"}.get(round(avg), "UNKNOWN")
    
    def _common_patterns(self, matches: List[PatternMatch]) -> str:
        """Extract common patterns from matches"""
        all_tags = []
        for m in matches:
            all_tags.extend(m.finding.tags)
        
        from collections import Counter
        common = Counter(all_tags).most_common(3)
        return ', '.join([tag for tag, _ in common]) if common else "N/A"
    
    def _recommended_checks(self, matches: List[PatternMatch]) -> str:
        """Generate recommended checks based on matches"""
        checks = set()
        for m in matches:
            if "Reentrancy" in m.finding.tags:
                checks.add("Check CEI pattern and reentrancy guards")
            if "Access Control" in m.finding.tags:
                checks.add("Verify access control modifiers")
            if "Oracle" in m.finding.tags:
                checks.add("Validate oracle staleness checks")
        
        return '; '.join(checks) if checks else "Standard verification"


def main():
    """CLI entry point for pattern matching"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Find similar vulnerabilities")
    parser.add_argument("description", help="Vulnerability description")
    parser.add_argument("--protocol", help="Protocol type (DeFi, NFT, etc.)")
    parser.add_argument("--severity", help="Expected severity")
    parser.add_argument("--min-similarity", type=float, default=0.6)
    
    args = parser.parse_args()
    
    matcher = PatternMatcher()
    matches = matcher.find_similar_vulnerabilities(
        vulnerability_description=args.description,
        protocol_type=args.protocol,
        severity=args.severity,
        min_similarity=args.min_similarity
    )
    
    print(matcher.generate_report("CLI-QUERY", matches))


if __name__ == "__main__":
    main()
```

---

## Integration with Ralph's Verification Harness

### Step 1: Observation Enhancement

```markdown
## Enhanced Observation Step

When documenting a suspicious pattern, automatically search Solodit:

1. **Extract vulnerability indicators**
   - Function names (withdraw, mint, liquidate)
   - Code patterns (external calls, state updates)
   - Risk signals (no access control, missing checks)

2. **Query Solodit API**
   ```python
   matches = pattern_matcher.find_similar_vulnerabilities(
       vulnerability_description="External call before state update in withdraw",
       code_snippet="(bool s,) = msg.sender.call{value: amount}('')",
       protocol_type="DeFi",
       severity="HIGH"
   )
   ```

3. **Document findings**
   - Include top 3 historical matches in observation report
   - Note common exploitation patterns
   - Reference similar protocol vulnerabilities
```

### Step 4: Impact Assessment Enhancement

```markdown
## Enhanced Impact Assessment

When quantifying impact, use historical data:

1. **Historical Loss Analysis**
   - Query Solodit for similar vulnerabilities
   - Extract actual loss amounts from historical exploits
   - Calculate average impact for vulnerability type

2. **Probability Assessment**
   - Check how many similar findings were confirmed exploitable
   - Review exploitation difficulty from historical reports
   - Consider protocol type risk factors

3. **Contextual Severity**
   - Compare to same-protocol historical issues
   - Consider TVL at risk based on similar protocols
   - Factor in exploitability from historical PoCs
```

---

## Usage Examples

### Example 1: Find Reentrancy Patterns

```python
from scripts.solodit_client import get_client

client = get_client()

# Search for reentrancy vulnerabilities in DeFi protocols
results = client.search_findings(
    tags=["Reentrancy", "CEI"],
    protocol_category=["DeFi"],
    impact=["HIGH"],
    quality_score_min=4.0,
    page_size=10
)

for finding in results.findings:
    print(f"[{finding.impact}] {finding.title}")
    print(f"  Protocol: {finding.protocol_name}")
    print(f"  Tags: {', '.join(finding.tags[:5])}")
    print()
```

### Example 2: Find Similar Access Control Issues

```python
from scripts.pattern_matcher import PatternMatcher

matcher = PatternMatcher()

# Find similar access control vulnerabilities
matches = matcher.find_similar_vulnerabilities(
    vulnerability_description="
        The mint function lacks access control, allowing any user 
        to mint unlimited tokens. No onlyOwner or onlyRole modifier
        is present on the _mint call.
    ",
    protocol_type="DeFi",
    severity="CRITICAL"
)

for match in matches:
    print(f"{match.relevance_score:.0%} match: {match.finding.title}")
    print(f"  Reasons: {', '.join(match.match_reasons)}")
```

### Example 3: Generate Pattern Matching Report

```bash
# CLI usage
python scripts/pattern_matcher.py \
    "Flash loan price manipulation in lending protocol" \
    --protocol "DeFi" \
    --severity "HIGH" \
    --min-similarity 0.7
```

---

## Best Practices

### 1. Caching

```python
# The client caches results for 5 minutes
# For batch operations, reuse the client instance
client = get_client()

# Multiple searches use cache when possible
results1 = client.search_findings(tags=["Reentrancy"])
results2 = client.search_findings(tags=["Reentrancy"], impact=["HIGH"])
```

### 2. Rate Limiting

```python
# The client handles rate limiting automatically
# Check remaining quota before large operations
results = client.search_findings(page_size=100)
print(f"Rate limit remaining: {results.rate_limit_remaining}")
```

### 3. Error Handling

```python
from scripts.solodit_client import SoloditAPIError

try:
    results = client.search_findings(...)
except SoloditAPIError as e:
    # Fall back to local knowledge base
    print(f"API error: {e}, using local patterns")
```

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SOLODIT_API_KEY` | Your Solodit API key | Required |
| `SOLODIT_API_TIMEOUT` | Request timeout (seconds) | 15 |
| `SOLODIT_CACHE_TTL` | Cache time-to-live (seconds) | 300 |

---

## Migration from Local Files

### Old Approach (File-based)

```bash
# Grepping through local markdown files
grep -r "reentrancy" knowledges/solodit/reports/
```

**Problems:**
- No semantic search
- No relevance ranking
- No metadata (quality, rarity scores)
- Limited to downloaded reports
- No filtering capabilities

### New Approach (API-based)

```python
from scripts.solodit_client import get_client

client = get_client()
results = client.search_findings(
    keywords="reentrancy external call state update",
    tags=["Reentrancy", "CEI"],
    impact=["HIGH"],
    quality_score_min=4.0,
    sort_field="Quality"
)
```

**Benefits:**
- Semantic search across 50,000+ findings
- Relevance-ranked results
- Rich metadata (quality, rarity, finder counts)
- Advanced filtering (protocol, firm, date, etc.)
- Always up-to-date

---

## References

- [Solodit Platform](https://solodit.cyfrin.io/)
- [Solodit Documentation](https://docs.solodit.cyfrin.io/)
- [Solodit MCP Server](https://github.com/zerotrust-labs/solodit-mcp)
- [API Authentication](https://solodit.cyfrin.io/settings/api)
