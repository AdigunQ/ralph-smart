#!/usr/bin/env python3
"""
Doc Discovery for External Integrations
Uses a lightweight web search to locate official documentation pages.
"""

import argparse
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request
from typing import Dict, List, Tuple

USER_AGENT = "RalphDocsDiscovery/1.0"


def read_integration_names(path: str) -> List[str]:
    if not os.path.exists(path):
        return []

    names: List[str] = []
    patterns = [
        re.compile(r"^#+\\s*Integration\\s*:\\s*(.+)", re.IGNORECASE),
        re.compile(r"^\\s*[-*+]\\s*Integration\\s*:\\s*(.+)", re.IGNORECASE),
        re.compile(r"^Integration\\s*:\\s*(.+)", re.IGNORECASE),
        re.compile(r"^#+\\s*(.+)\\s*\\(Integration\\)", re.IGNORECASE),
    ]

    with open(path, "r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            for pattern in patterns:
                match = pattern.search(line)
                if match:
                    name = match.group(1).strip()
                    if name:
                        names.append(name)
                    break

    deduped: List[str] = []
    seen = set()
    for name in names:
        key = name.lower()
        if key not in seen:
            seen.add(key)
            deduped.append(name)
    return deduped


def fetch_html(url: str, timeout: int = 20) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read().decode("utf-8", errors="ignore")


def extract_duckduckgo_links(html: str) -> List[str]:
    links: List[str] = []
    for match in re.finditer(r'href=\"(https://duckduckgo.com/l/\\?[^\\\"]+)\"', html):
        redirect_url = match.group(1)
        parsed = urllib.parse.urlparse(redirect_url)
        params = urllib.parse.parse_qs(parsed.query)
        uddg = params.get("uddg")
        if not uddg:
            continue
        actual = urllib.parse.unquote(uddg[0])
        if actual.startswith("http"):
            links.append(actual)

    # Deduplicate while preserving order
    deduped: List[str] = []
    seen = set()
    for link in links:
        if link not in seen:
            seen.add(link)
            deduped.append(link)
    return deduped


def pick_best_doc_link(links: List[str], allowlist: List[str]) -> str:
    if not links:
        return ""

    filtered = links
    if allowlist:
        filtered = []
        for link in links:
            for domain in allowlist:
                if domain and domain.lower() in link.lower():
                    filtered.append(link)
                    break
        if filtered:
            links = filtered

    def score(link: str) -> int:
        lowered = link.lower()
        score_val = 0
        if "docs" in lowered:
            score_val += 3
        if "documentation" in lowered:
            score_val += 3
        if "gitbook" in lowered:
            score_val += 2
        if "readthedocs" in lowered:
            score_val += 2
        if "wiki" in lowered:
            score_val -= 2
        return score_val

    ranked = sorted(links, key=score, reverse=True)
    for link in ranked:
        if "wikipedia.org" in link.lower():
            continue
        return link
    return ranked[0]


def discover_docs_for_name(name: str, allowlist: List[str]) -> Tuple[str, List[str]]:
    query = urllib.parse.quote(f"{name} documentation official docs")
    search_url = f"https://duckduckgo.com/html/?q={query}"
    html = fetch_html(search_url)
    links = extract_duckduckgo_links(html)
    best = pick_best_doc_link(links, allowlist)
    return best, links[:5]


def load_allowlist(path: str) -> Dict[str, List[str]]:
    mapping: Dict[str, List[str]] = {}
    if not path or not os.path.exists(path):
        return mapping

    with open(path, "r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if ":" in line:
                name, domains = line.split(":", 1)
            elif "=" in line:
                name, domains = line.split("=", 1)
            else:
                continue
            name = name.strip().lower()
            domain_list = [d.strip() for d in domains.split(",") if d.strip()]
            if name and domain_list:
                mapping[name] = domain_list
    return mapping


def load_discovery_map(path: str) -> Dict[str, Dict[str, str]]:
    if not path or not os.path.exists(path):
        return {}
    try:
        with open(path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
        if isinstance(data, dict):
            return data
    except Exception:
        return {}
    return {}


def save_discovery_map(path: str, data: Dict[str, Dict[str, str]]) -> None:
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, sort_keys=True)


def main() -> None:
    parser = argparse.ArgumentParser(description="Discover documentation URLs for external integrations")
    parser.add_argument("--integrations-file", default="findings/external_integrations.md")
    parser.add_argument("--urls-file", default="specs/external_docs/urls.txt")
    parser.add_argument("--log", default="specs/external_docs/discovery.log")
    parser.add_argument("--allowlist", default="specs/external_docs/allowlist.txt")
    parser.add_argument("--state", default="specs/external_docs/discovery.json")
    parser.add_argument("--refresh", action="store_true")
    args = parser.parse_args()

    names = read_integration_names(args.integrations_file)
    if not names:
        print("No integrations found. Ensure findings/external_integrations.md exists.")
        sys.exit(0)

    os.makedirs(os.path.dirname(args.urls_file), exist_ok=True)
    os.makedirs(os.path.dirname(args.log), exist_ok=True)
    os.makedirs(os.path.dirname(args.state), exist_ok=True)

    allowlist_map = load_allowlist(args.allowlist)
    discovery_map = load_discovery_map(args.state)
    urls: List[str] = []
    with open(args.log, "w", encoding="utf-8") as logf:
        for name in names:
            key = name.lower()
            if not args.refresh and key in discovery_map:
                existing = discovery_map[key].get("url", "")
                if existing:
                    urls.append(existing)
                    logf.write(f"{name}: {existing} (cached)\\n")
                    continue

            try:
                allow_domains = allowlist_map.get(key, [])
                best, sample = discover_docs_for_name(name, allow_domains)
                logf.write(f"{name}: {best}\\n")
                for candidate in sample:
                    logf.write(f"  - {candidate}\\n")
                if best:
                    urls.append(best)
                    discovery_map[key] = {"url": best, "ts": str(int(time.time()))}
            except Exception as exc:
                logf.write(f"{name}: error ({exc})\\n")

    # Deduplicate URLs
    deduped = []
    seen = set()
    for url in urls:
        if url not in seen:
            seen.add(url)
            deduped.append(url)

    with open(args.urls_file, "w", encoding="utf-8") as outf:
        for url in deduped:
            outf.write(url + "\\n")

    save_discovery_map(args.state, discovery_map)
    print(f"Discovered {len(deduped)} docs URLs -> {args.urls_file}")


if __name__ == "__main__":
    main()
