#!/usr/bin/env python3
"""
Solodit API Client for Ralph Security Agent
Provides intelligent vulnerability pattern matching and historical finding lookup.

Usage:
    from solodit_client import get_client, SoloditFinding
    
    client = get_client()
    results = client.search_findings(
        keywords="reentrancy external call",
        tags=["Reentrancy"],
        impact=["HIGH"]
    )
"""

import os
import json
import time
import logging
from typing import List, Dict, Optional, Literal, Any, Tuple
from dataclasses import dataclass, field
from datetime import datetime, timedelta
import requests
from urllib.parse import urljoin

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# API Configuration
SOLODIT_API_BASE = "https://solodit.cyfrin.io/api/v1/solodit"
DEFAULT_TIMEOUT = 15
MAX_RETRIES = 3
DEFAULT_CACHE_TTL = 300  # 5 minutes


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
    tags: List[str] = field(default_factory=list)
    finders: List[str] = field(default_factory=list)
    
    @property
    def severity_int(self) -> int:
        """Convert impact to numeric severity for calculations"""
        return {"HIGH": 3, "MEDIUM": 2, "LOW": 1, "GAS": 0}.get(self.impact, 0)
    
    @property
    def severity_label(self) -> str:
        """Get human-readable severity label"""
        return self.impact
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for serialization"""
        return {
            "id": self.id,
            "slug": self.slug,
            "title": self.title,
            "summary": self.summary,
            "impact": self.impact,
            "quality_score": self.quality_score,
            "rarity_score": self.rarity_score,
            "protocol_name": self.protocol_name,
            "firm_name": self.firm_name,
            "tags": self.tags,
            "source_link": self.source_link,
        }


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
    
    @property
    def has_more(self) -> bool:
        """Check if more results are available"""
        return self.current_page < self.total_pages
    
    def get_by_impact(self, impact: str) -> List[SoloditFinding]:
        """Filter findings by impact level"""
        return [f for f in self.findings if f.impact == impact]


class SoloditAPIError(Exception):
    """Custom exception for Solodit API errors"""
    
    def __init__(self, message: str, status_code: Optional[int] = None, retry_after: Optional[int] = None):
        super().__init__(message)
        self.status_code = status_code
        self.retry_after = retry_after


class SoloditClient:
    """
    Production-ready Solodit API client for Ralph Security Agent.
    Implements retry logic, rate limiting, and intelligent caching.
    
    Requires SOLODIT_API_KEY environment variable or pass api_key to constructor.
    Get your API key at: https://solodit.cyfrin.io/
    """
    
    def __init__(self, api_key: Optional[str] = None, cache_ttl: int = DEFAULT_CACHE_TTL):
        """
        Initialize the Solodit client.
        
        Args:
            api_key: Solodit API key (or set SOLODIT_API_KEY env var)
            cache_ttl: Cache time-to-live in seconds (default: 300)
        """
        self.api_key = api_key or os.environ.get("SOLODIT_API_KEY")
        if not self.api_key:
            raise SoloditAPIError(
                "SOLODIT_API_KEY not provided. "
                "Get your key at https://solodit.cyfrin.io/"
            )
        
        self.cache_ttl = cache_ttl
        self.session = requests.Session()
        self.session.headers.update({
            "Content-Type": "application/json",
            "X-Cyfrin-API-Key": self.api_key,
        })
        
        # In-memory cache: {cache_key: (result, timestamp)}
        self._cache: Dict[str, Tuple[Any, float]] = {}
        
        logger.info("Solodit client initialized")
    
    def _get_cache_key(self, endpoint: str, data: Dict) -> str:
        """Generate cache key for request"""
        return f"{endpoint}:{json.dumps(data, sort_keys=True)}"
    
    def _get_cached(self, cache_key: str) -> Optional[Any]:
        """Get cached result if not expired"""
        if cache_key not in self._cache:
            return None
        
        result, timestamp = self._cache[cache_key]
        if time.time() - timestamp > self.cache_ttl:
            # Expired
            del self._cache[cache_key]
            return None
        
        logger.debug(f"Cache hit for {cache_key[:50]}...")
        return result
    
    def _set_cached(self, cache_key: str, result: Any):
        """Cache result with timestamp"""
        self._cache[cache_key] = (result, time.time())
        
        # Simple cache size management
        if len(self._cache) > 1000:
            # Remove oldest entries
            sorted_items = sorted(self._cache.items(), key=lambda x: x[1][1])
            for key, _ in sorted_items[:100]:
                del self._cache[key]
    
    def _make_request(
        self,
        endpoint: str,
        data: Dict,
        timeout: int = DEFAULT_TIMEOUT
    ) -> Dict:
        """
        Make API request with retry logic and error handling.
        
        Args:
            endpoint: API endpoint (e.g., "/findings")
            data: Request body data
            timeout: Request timeout in seconds
            
        Returns:
            JSON response as dictionary
            
        Raises:
            SoloditAPIError: If request fails after retries
        """
        # Construct full URL - endpoint should not have leading slash
        # to properly append to base URL
        endpoint_clean = endpoint.lstrip('/')
        url = f"{SOLODIT_API_BASE}/{endpoint_clean}"
        
        for attempt in range(MAX_RETRIES):
            try:
                logger.debug(f"API request to {endpoint} (attempt {attempt + 1})")
                response = self.session.post(
                    url,
                    json=data,
                    timeout=timeout
                )
                
                # Handle rate limiting (429)
                if response.status_code == 429:
                    retry_after = int(response.headers.get("Retry-After", 2))
                    logger.warning(f"Rate limited. Retrying after {retry_after}s")
                    if attempt < MAX_RETRIES - 1:
                        time.sleep(retry_after)
                        continue
                
                # Handle authentication errors
                if response.status_code in (401, 403):
                    raise SoloditAPIError(
                        f"Authentication failed ({response.status_code}). "
                        "Check your SOLODIT_API_KEY.",
                        status_code=response.status_code
                    )
                
                response.raise_for_status()
                return response.json()
                
            except requests.exceptions.Timeout:
                logger.warning(f"Request timeout (attempt {attempt + 1})")
                if attempt < MAX_RETRIES - 1:
                    time.sleep(0.5 * (attempt + 1))
                    continue
                raise SoloditAPIError(f"Request timed out after {timeout}s")
                
            except requests.exceptions.RequestException as e:
                logger.error(f"Request error: {e}")
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
        min_finders: Optional[str] = None,
        max_finders: Optional[str] = None,
        reported_days: Optional[str] = None,
        quality_score_min: Optional[float] = None,
        rarity_score_min: Optional[float] = None,
        sort_field: str = "Recency",
        sort_direction: str = "Desc",
        page: int = 1,
        page_size: int = 20,
        use_cache: bool = True
    ) -> SearchResult:
        """
        Search for vulnerability findings with comprehensive filters.
        
        This is the main method for finding historical vulnerabilities similar to
        your suspected issue. Use it during Ralph's Observation and Impact Assessment
        steps.
        
        Args:
            keywords: Search in title and content
            impact: Filter by severity ["HIGH", "MEDIUM", "LOW", "GAS"]
            firms: Filter by audit firm names ["Cyfrin", "OpenZeppelin", etc.]
            tags: Filter by vulnerability tags ["Reentrancy", "Access Control"]
            protocol: Filter by protocol name (partial match)
            protocol_category: Filter by category ["DeFi", "NFT", "Lending"]
            languages: Filter by language ["Solidity", "Rust", "Cairo"]
            user: Filter by finder/auditor handle
            min_finders: Minimum number of finders
            max_finders: Maximum number of finders
            reported_days: "30", "60", "90", or "alltime"
            quality_score_min: Minimum quality (0-5)
            rarity_score_min: Minimum rarity (0-5)
            sort_field: "Recency", "Quality", or "Rarity"
            sort_direction: "Desc" or "Asc"
            page: Page number (1-based)
            page_size: Results per page (max 100)
            use_cache: Whether to use caching
            
        Returns:
            SearchResult containing findings and metadata
            
        Example:
            >>> client = SoloditClient()
            >>> results = client.search_findings(
            ...     keywords="reentrancy withdraw",
            ...     tags=["Reentrancy"],
            ...     impact=["HIGH"],
            ...     quality_score_min=4.0
            ... )
            >>> print(f"Found {results.total_results} similar issues")
        """
        # Build filters
        filters: Dict[str, Any] = {}
        
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
        if min_finders:
            filters["minFinders"] = min_finders
        if max_finders:
            filters["maxFinders"] = max_finders
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
        
        request_data: Dict[str, Any] = {
            "page": max(1, page),
            "pageSize": min(max(1, page_size), 100),
        }
        if filters:
            request_data["filters"] = filters
        
        # Check cache
        cache_key = self._get_cache_key("/findings", request_data)
        if use_cache:
            cached = self._get_cached(cache_key)
            if cached:
                return cached
        
        # Make request
        response = self._make_request("/findings", request_data)
        
        # Parse findings
        findings = []
        for f in response.get("findings", []):
            try:
                finding = SoloditFinding(
                    id=f["id"],
                    slug=f["slug"],
                    title=f["title"],
                    content=f["content"],
                    summary=f.get("summary"),
                    impact=f["impact"],
                    quality_score=f.get("quality_score", 0),
                    rarity_score=f.get("general_score", 0),
                    report_date=f.get("report_date"),
                    firm_name=f.get("firm_name"),
                    protocol_name=f.get("protocol_name"),
                    finders_count=f.get("finders_count", 0),
                    source_link=f.get("source_link"),
                    tags=[t["tags_tag"]["title"] 
                          for t in f.get("issues_issuetagscore", [])],
                    finders=[finder["wardens_warden"]["handle"]
                            for finder in f.get("issues_issue_finders", [])]
                )
                findings.append(finding)
            except (KeyError, TypeError) as e:
                logger.warning(f"Failed to parse finding: {e}")
                continue
        
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
        if use_cache:
            self._set_cached(cache_key, result)
        
        return result
    
    def get_finding_by_id(self, finding_id: str) -> Optional[SoloditFinding]:
        """
        Get detailed information about a specific finding by ID or slug.
        
        Args:
            finding_id: The finding ID or slug
            
        Returns:
            SoloditFinding if found, None otherwise
        """
        results = self.search_findings(
            keywords=finding_id,
            page_size=1,
            use_cache=True
        )
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
        Find similar historical vulnerabilities by type.
        
        This is a convenience method for Ralph's pattern matching that maps
        common vulnerability names to Solodit tags.
        
        Args:
            vulnerability_type: Type of vulnerability (e.g., "reentrancy")
            protocol_type: Protocol category (e.g., "DeFi")
            min_quality: Minimum quality score (0-5)
            max_results: Maximum number of results
            
        Returns:
            List of similar findings
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
            "timestamp": ["Timestamp", "block.timestamp"],
            "randomness": ["Randomness", "Cryptography"],
        }
        
        # Get tags for vulnerability type
        lookup_key = vulnerability_type.lower().replace(" ", "_")
        tags = tag_mapping.get(lookup_key, [vulnerability_type])
        
        logger.info(f"Searching for {vulnerability_type} with tags: {tags}")
        
        results = self.search_findings(
            tags=tags,
            protocol_category=[protocol_type] if protocol_type else None,
            quality_score_min=min_quality,
            sort_field="Quality",
            page_size=max_results
        )
        
        return results.findings


# Singleton instance for reuse
_client: Optional[SoloditClient] = None

def get_client(api_key: Optional[str] = None, cache_ttl: int = DEFAULT_CACHE_TTL) -> SoloditClient:
    """
    Get or create Solodit client singleton.
    
    This is the recommended way to get a client instance in Ralph.
    It reuses the same client across calls for connection pooling and caching.
    
    Args:
        api_key: Optional API key (uses env var if not provided)
        cache_ttl: Cache time-to-live in seconds
        
    Returns:
        SoloditClient instance
    """
    global _client
    if _client is None:
        _client = SoloditClient(api_key=api_key, cache_ttl=cache_ttl)
    return _client


def reset_client():
    """Reset the singleton client (useful for testing)"""
    global _client
    _client = None


# CLI interface
if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Search Solodit for vulnerability patterns"
    )
    parser.add_argument(
        "keywords",
        nargs="?",
        help="Search keywords"
    )
    parser.add_argument(
        "--tags",
        nargs="+",
        help="Filter by tags"
    )
    parser.add_argument(
        "--impact",
        nargs="+",
        choices=["HIGH", "MEDIUM", "LOW", "GAS"],
        help="Filter by impact"
    )
    parser.add_argument(
        "--protocol",
        help="Filter by protocol name"
    )
    parser.add_argument(
        "--min-quality",
        type=float,
        default=3.0,
        help="Minimum quality score"
    )
    parser.add_argument(
        "--page-size",
        type=int,
        default=10,
        help="Results per page"
    )
    parser.add_argument(
        "--output",
        choices=["text", "json"],
        default="text",
        help="Output format"
    )
    
    args = parser.parse_args()
    
    try:
        client = get_client()
        
        results = client.search_findings(
            keywords=args.keywords,
            tags=args.tags,
            impact=args.impact,
            protocol=args.protocol,
            quality_score_min=args.min_quality,
            page_size=args.page_size
        )
        
        if args.output == "json":
            import json
            output = {
                "total": results.total_results,
                "findings": [f.to_dict() for f in results.findings]
            }
            print(json.dumps(output, indent=2))
        else:
            print(f"Found {results.total_results} results (showing {len(results.findings)}):")
            print(f"Rate limit: {results.rate_limit_remaining} remaining\n")
            
            for i, finding in enumerate(results.findings, 1):
                print(f"{i}. [{finding.impact}] {finding.title}")
                print(f"   Protocol: {finding.protocol_name or 'N/A'}")
                print(f"   Firm: {finding.firm_name or 'N/A'}")
                print(f"   Quality: {finding.quality_score}/5 | Rarity: {finding.rarity_score}/5")
                print(f"   Tags: {', '.join(finding.tags[:5])}")
                print()
                
    except SoloditAPIError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nInterrupted", file=sys.stderr)
        sys.exit(130)
