#!/usr/bin/env python3
"""
Intelligent Pattern Matching using Solodit API
Integrates with Ralph's verification harness for historical vulnerability lookup.

Usage:
    python pattern_matcher.py "reentrancy in withdraw function" --protocol DeFi --severity HIGH
"""

import sys
import re
from typing import List, Dict, Optional, Tuple
from dataclasses import dataclass
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from solodit_client import get_client, SoloditFinding, SearchResult


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
    
    # Common vulnerability patterns and their associated tags
    VULNERABILITY_PATTERNS = {
        "reentrancy": {
            "tags": ["Reentrancy", "CEI", "External Call"],
            "keywords": ["reentrancy", "re-entrancy", "callback", "external call", "receive()"],
            "severity": "HIGH"
        },
        "access_control": {
            "tags": ["Access Control", "Authentication", "Admin", "Authorization"],
            "keywords": ["access control", "onlyowner", "auth", "permission", "unauthorized"],
            "severity": "CRITICAL"
        },
        "oracle": {
            "tags": ["Oracle", "Price Manipulation", "TWAP", "Price Feed"],
            "keywords": ["oracle", "price", "manipulation", "spot price", "chainlink"],
            "severity": "HIGH"
        },
        "flash_loan": {
            "tags": ["Flash Loan", "Price Manipulation"],
            "keywords": ["flash loan", "flashloan", "atomic"],
            "severity": "HIGH"
        },
        "rounding": {
            "tags": ["Rounding", "Precision", "Decimals", "Division"],
            "keywords": ["rounding", "precision", "division before", "decimals"],
            "severity": "MEDIUM"
        },
        "overflow": {
            "tags": ["Overflow", "Underflow", "SafeMath"],
            "keywords": ["overflow", "underflow", "safemath", "unchecked"],
            "severity": "HIGH"
        },
        "delegatecall": {
            "tags": ["Delegatecall", "Proxy", "DELEGATECALL"],
            "keywords": ["delegatecall", "delegate call", "proxy"],
            "severity": "CRITICAL"
        },
        "signature": {
            "tags": ["Signature", "ECDSA", "EIP-712", "ecrecover"],
            "keywords": ["signature", "ecdsa", "ecrecover", "replay"],
            "severity": "HIGH"
        },
        "frontrunning": {
            "tags": ["Frontrunning", "MEV", "Sandwich"],
            "keywords": ["frontrun", "mev", "sandwich", "front-run"],
            "severity": "MEDIUM"
        },
        "dos": {
            "tags": ["DOS", "Gas Limit", "Denial-Of-Service", "DoS"],
            "keywords": ["dos", "denial", "gas limit", "unbounded loop"],
            "severity": "MEDIUM"
        },
        "timestamp": {
            "tags": ["Timestamp", "block.timestamp", "Time"],
            "keywords": ["timestamp", "block.timestamp", "time manipulation"],
            "severity": "MEDIUM"
        },
        "randomness": {
            "tags": ["Randomness", "Cryptography", "Predictable"],
            "keywords": ["random", "predictable", "blockhash", "weak randomness"],
            "severity": "HIGH"
        },
        "approval": {
            "tags": ["Approve", "Allowance", "ERC20"],
            "keywords": ["approve", "allowance", "approve max"],
            "severity": "MEDIUM"
        },
        "collateral": {
            "tags": ["Collateral", "Liquidation", "Lending"],
            "keywords": ["collateral", "liquidation", "lending", "borrow"],
            "severity": "HIGH"
        },
        "governance": {
            "tags": ["Governance", "Voting", "Timelock", "Proposal"],
            "keywords": ["governance", "voting", "proposal", "timelock"],
            "severity": "HIGH"
        }
    }
    
    def __init__(self):
        self.client = get_client()
    
    def find_similar_vulnerabilities(
        self,
        vulnerability_description: str,
        code_snippet: Optional[str] = None,
        protocol_type: Optional[str] = None,
        severity: Optional[str] = None,
        min_similarity: float = 0.5
    ) -> List[PatternMatch]:
        """
        Find historically similar vulnerabilities.
        
        Args:
            vulnerability_description: Description of the suspected vulnerability
            code_snippet: Optional code snippet for semantic matching
            protocol_type: Type of protocol (DeFi, NFT, etc.)
            severity: Expected severity (HIGH, MEDIUM, LOW)
            min_similarity: Minimum relevance threshold (0.0-1.0)
        
        Returns:
            List of pattern matches sorted by relevance
        """
        # Infer tags from description
        inferred_tags = self._infer_tags(vulnerability_description, code_snippet)
        
        # Extract keywords
        keywords = self._extract_keywords(vulnerability_description)
        
        # Map severity
        impact_filter = None
        if severity:
            impact_map = {
                "CRITICAL": ["HIGH"],
                "HIGH": ["HIGH"],
                "MEDIUM": ["MEDIUM"],
                "LOW": ["LOW"],
                "GAS": ["GAS"]
            }
            impact_filter = impact_map.get(severity.upper())
        
        # Build search query
        search_keywords = " ".join(keywords[:3]) if keywords else None
        
        # Search Solodit
        try:
            results = self.client.search_findings(
                keywords=search_keywords,
                tags=inferred_tags if inferred_tags else None,
                impact=impact_filter,
                protocol_category=[protocol_type] if protocol_type else None,
                quality_score_min=2.5,  # Only decent quality findings
                sort_field="Quality",
                page_size=50  # Get more to filter by relevance
            )
        except Exception as e:
            print(f"Warning: Solodit search failed: {e}", file=sys.stderr)
            return []
        
        # Score and rank matches
        matches = []
        for finding in results.findings:
            score, reasons = self._calculate_relevance(
                finding, vulnerability_description, code_snippet, inferred_tags
            )
            if score >= min_similarity:
                matches.append(PatternMatch(
                    finding=finding,
                    relevance_score=score,
                    match_reasons=reasons
                ))
        
        # Sort by relevance
        matches.sort(key=lambda m: m.relevance_score, reverse=True)
        return matches
    
    def _infer_tags(
        self,
        description: str,
        code_snippet: Optional[str]
    ) -> List[str]:
        """Infer Solodit tags from description and code"""
        text = (description + " " + (code_snippet or "")).lower()
        tags = []
        
        for vuln_type, data in self.VULNERABILITY_PATTERNS.items():
            for keyword in data["keywords"]:
                if keyword.lower() in text:
                    tags.extend(data["tags"])
                    break
        
        # Remove duplicates while preserving order
        seen = set()
        unique_tags = []
        for tag in tags:
            if tag not in seen:
                seen.add(tag)
                unique_tags.append(tag)
        
        return unique_tags[:5]  # Limit to top 5 tags
    
    def _extract_keywords(self, text: str) -> List[str]:
        """Extract relevant keywords from text"""
        text_lower = text.lower()
        keywords = []
        
        # Collect all matching keywords from patterns
        for vuln_type, data in self.VULNERABILITY_PATTERNS.items():
            for keyword in data["keywords"]:
                if keyword.lower() in text_lower:
                    keywords.append(keyword)
        
        # Add specific Solidity/function patterns
        solidity_patterns = [
            r"function\s+(\w+)",
            r"\.call{value:",
            r"delegatecall",
            r"transfer\(",
            r"require\(",
        ]
        
        for pattern in solidity_patterns:
            matches = re.findall(pattern, text)
            keywords.extend(matches)
        
        # Remove duplicates
        return list(dict.fromkeys(keywords))
    
    def _calculate_relevance(
        self,
        finding: SoloditFinding,
        description: str,
        code_snippet: Optional[str],
        query_tags: List[str]
    ) -> Tuple[float, List[str]]:
        """Calculate relevance score between finding and query"""
        score = 0.0
        reasons = []
        
        desc_lower = description.lower()
        content_lower = finding.content.lower()
        
        # 1. Keyword overlap (max 0.35)
        query_keywords = self._extract_keywords(description)
        matching_keywords = [k for k in query_keywords if k.lower() in content_lower]
        if matching_keywords and query_keywords:
            keyword_score = len(matching_keywords) / len(query_keywords) * 0.35
            score += keyword_score
            if keyword_score > 0.1:
                reasons.append(f"keywords: {', '.join(matching_keywords[:3])}")
        
        # 2. Tag overlap (max 0.30)
        if query_tags and finding.tags:
            matching_tags = set(t.lower() for t in query_tags) & set(t.lower() for t in finding.tags)
            if matching_tags:
                tag_score = len(matching_tags) / len(query_tags) * 0.30
                score += tag_score
                reasons.append(f"tags: {', '.join(list(matching_tags)[:3])}")
        
        # 3. Protocol type match (max 0.15)
        # Extract protocol type from description and finding
        protocol_indicators = ["defi", "nft", "lending", "dex", "yield", "staking"]
        for indicator in protocol_indicators:
            if indicator in desc_lower and indicator in (finding.protocol_name or "").lower():
                score += 0.15
                reasons.append(f"protocol: {indicator}")
                break
        
        # 4. Quality bonus (max 0.10)
        score += (finding.quality_score / 5.0) * 0.10
        
        # 5. Rarity bonus (max 0.10)
        score += (finding.rarity_score / 5.0) * 0.10
        
        return min(score, 1.0), reasons
    
    def generate_report(
        self,
        hypothesis_id: str,
        matches: List[PatternMatch],
        include_details: bool = True
    ) -> str:
        """Generate a pattern matching report for a hypothesis"""
        if not matches:
            return f"""## Pattern Matching Report: {hypothesis_id}

**Status**: ❌ No similar historical findings found

**Analysis**: This appears to be a novel vulnerability pattern or the description
may need refinement to match known vulnerability types.

**Recommendation**: Proceed with careful manual analysis and the full 
6-step verification harness.
"""
        
        report = f"""## Pattern Matching Report: {hypothesis_id}

**Status**: ✅ {len(matches)} similar historical finding(s) identified

### Summary Statistics
- **Average Historical Severity**: {self._avg_severity(matches)}
- **Average Quality Score**: {self._avg_quality(matches):.1f}/5
- **Common Tags**: {self._common_patterns(matches)}
- **Most Affected Protocol Type**: {self._common_protocol_type(matches)}

### Top Historical Matches

"""
        
        for i, match in enumerate(matches[:5], 1):
            f = match.finding
            report += f"""
#### {i}. [{f.impact}] {f.title}

**Relevance Score**: {match.relevance_score:.0%}
**Match Reasons**: {', '.join(match.match_reasons) if match.match_reasons else 'Semantic similarity'}
**Protocol**: {f.protocol_name or "N/A"}
**Audit Firm**: {f.firm_name or "N/A"}
**Quality**: {f.quality_score:.1f}/5 | **Rarity**: {f.rarity_score:.1f}/5
**Finders**: {f.finders_count}
**Tags**: {', '.join(f.tags[:5])}
**Date**: {f.report_date or "N/A"}

{f.summary or f.content[:400]}...

**🔗 Source**: {f.source_link or "N/A"}

---
"""
        
        if include_details:
            report += f"""
### Historical Impact Analysis

Based on {len(matches)} similar findings:

| Metric | Value |
|--------|-------|
| Average Severity | {self._avg_severity(matches)} |
| Most Common Impact | {self._most_common_impact(matches)} |
| Highest Quality Finding | {max(matches, key=lambda m: m.finding.quality_score).finding.quality_score:.1f}/5 |
| Most Finders (Popularity) | {max(matches, key=lambda m: m.finding.finders_count).finding.finders_count} |

### Common Vulnerability Patterns

{self._pattern_analysis(matches)}

### Recommended Verification Steps

Based on historical findings of this type:

{self._recommended_checks(matches)}

### Next Steps

1. ✅ **Review historical PoCs**: Check source links for exploitation patterns
2. ✅ **Adapt to target**: Apply historical patterns to current codebase
3. ✅ **Verification harness**: Proceed with full 6-step verification
4. ✅ **Impact assessment**: Use historical losses as reference
"""
        
        return report
    
    def _avg_severity(self, matches: List[PatternMatch]) -> str:
        """Calculate average severity from matches"""
        if not matches:
            return "N/A"
        severities = [m.finding.severity_int for m in matches]
        avg = sum(severities) / len(severities)
        mapping = {3: "HIGH", 2: "MEDIUM", 1: "LOW", 0: "GAS/INFO"}
        return mapping.get(round(avg), "UNKNOWN")
    
    def _avg_quality(self, matches: List[PatternMatch]) -> float:
        """Calculate average quality score"""
        if not matches:
            return 0.0
        return sum(m.finding.quality_score for m in matches) / len(matches)
    
    def _common_patterns(self, matches: List[PatternMatch]) -> str:
        """Extract common patterns from matches"""
        if not matches:
            return "N/A"
        from collections import Counter
        all_tags = []
        for m in matches:
            all_tags.extend(m.finding.tags)
        common = Counter(all_tags).most_common(3)
        return ', '.join([tag for tag, _ in common]) if common else "N/A"
    
    def _common_protocol_type(self, matches: List[PatternMatch]) -> str:
        """Get most common protocol type"""
        if not matches:
            return "N/A"
        from collections import Counter
        protocols = [m.finding.protocol_name for m in matches if m.finding.protocol_name]
        if not protocols:
            return "N/A"
        common = Counter(protocols).most_common(1)
        return common[0][0] if common else "N/A"
    
    def _most_common_impact(self, matches: List[PatternMatch]) -> str:
        """Get most common impact level"""
        if not matches:
            return "N/A"
        from collections import Counter
        impacts = [m.finding.impact for m in matches]
        common = Counter(impacts).most_common(1)
        return common[0][0] if common else "N/A"
    
    def _pattern_analysis(self, matches: List[PatternMatch]) -> str:
        """Analyze patterns across matches"""
        if not matches:
            return "No patterns identified."
        
        # Collect all tags
        all_tags = []
        for m in matches:
            all_tags.extend(m.finding.tags)
        
        from collections import Counter
        tag_counts = Counter(all_tags)
        
        analysis = []
        for tag, count in tag_counts.most_common(5):
            percentage = count / len(matches) * 100
            analysis.append(f"- **{tag}**: Found in {percentage:.0f}% of similar issues")
        
        return '\n'.join(analysis) if analysis else "No specific patterns identified."
    
    def _recommended_checks(self, matches: List[PatternMatch]) -> str:
        """Generate recommended checks based on matches"""
        checks = set()
        
        for m in matches:
            tags_lower = [t.lower() for t in m.finding.tags]
            
            if any("reentrancy" in t for t in tags_lower):
                checks.add("1. ✅ Verify CEI pattern (Checks-Effects-Interactions)")
                checks.add("2. ✅ Check for reentrancy guards (nonReentrant modifier)")
            
            if any("access control" in t for t in tags_lower):
                checks.add("3. ✅ Verify access control modifiers on all privileged functions")
                checks.add("4. ✅ Check that ownership can't be transferred to address(0)")
            
            if any("oracle" in t for t in tags_lower):
                checks.add("5. ✅ Validate oracle price staleness (updatedAt check)")
                checks.add("6. ✅ Check for TWAP usage instead of spot prices")
            
            if any("rounding" in t or "precision" in t for t in tags_lower):
                checks.add("7. ✅ Verify multiplication before division")
                checks.add("8. ✅ Check for precision loss in calculations")
            
            if any("flash loan" in t for t in tags_lower):
                checks.add("9. ✅ Validate price can't be manipulated in single transaction")
                checks.add("10. ✅ Check for flash loan protection mechanisms")
        
        if not checks:
            checks.add("1. ✅ Proceed with standard 6-step verification harness")
        
        return '\n'.join(sorted(checks))


def main():
    """CLI entry point for pattern matching"""
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Find similar vulnerabilities using Solodit",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s "reentrancy in withdraw" --protocol DeFi --severity HIGH
  %(prog)s "access control on mint" --severity CRITICAL --min-similarity 0.6
  %(prog)s "oracle price manipulation" --protocol Lending -n 15
        """
    )
    
    parser.add_argument(
        "description",
        help="Vulnerability description"
    )
    parser.add_argument(
        "--protocol",
        help="Protocol type (DeFi, NFT, Lending, etc.)"
    )
    parser.add_argument(
        "--severity",
        choices=["CRITICAL", "HIGH", "MEDIUM", "LOW", "GAS"],
        help="Expected severity"
    )
    parser.add_argument(
        "--min-similarity",
        type=float,
        default=0.5,
        help="Minimum similarity threshold (0.0-1.0, default: 0.5)"
    )
    parser.add_argument(
        "-n", "--max-results",
        type=int,
        default=10,
        help="Maximum number of results (default: 10)"
    )
    parser.add_argument(
        "--save",
        metavar="FILE",
        help="Save report to file"
    )
    
    args = parser.parse_args()
    
    try:
        matcher = PatternMatcher()
        
        print(f"🔍 Searching for vulnerabilities similar to:")
        print(f"   '{args.description}'")
        if args.protocol:
            print(f"   Protocol: {args.protocol}")
        if args.severity:
            print(f"   Severity: {args.severity}")
        print()
        
        matches = matcher.find_similar_vulnerabilities(
            vulnerability_description=args.description,
            protocol_type=args.protocol,
            severity=args.severity,
            min_similarity=args.min_similarity
        )
        
        # Limit results
        matches = matches[:args.max_results]
        
        # Generate report
        report = matcher.generate_report("CLI-QUERY", matches)
        
        # Output
        if args.save:
            with open(args.save, 'w') as f:
                f.write(report)
            print(f"✅ Report saved to: {args.save}")
        else:
            print(report)
        
        # Summary
        if matches:
            print(f"\n📊 Summary: Found {len(matches)} similar historical vulnerabilities")
            print(f"   Top match relevance: {matches[0].relevance_score:.0%}")
            print(f"   Average severity: {matcher._avg_severity(matches)}")
        else:
            print("\n⚠️  No similar historical vulnerabilities found")
            print("   This may be a novel pattern - proceed with caution!")
            
    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
