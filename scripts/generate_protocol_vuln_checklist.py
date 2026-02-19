#!/usr/bin/env python3

import argparse
import json
import math
import re
import subprocess
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Set, Tuple


TEXT_SUFFIXES = {
    ".sol",
    ".vy",
    ".yul",
    ".rs",
    ".move",
}

IGNORED_DIR_NAMES = {
    ".git",
    ".hg",
    ".svn",
    "node_modules",
    "vendor",
    "vendors",
    "lib",
    "libs",
    "dist",
    "build",
    "out",
    "cache",
    "artifacts",
    "coverage",
    ".audit-tmp",
    ".codex",
    ".codex-runtime",
    "tools",
    "tmp",
    "test",
    "tests",
    "script",
    "scripts",
    "mock",
    "mocks",
    "example",
    "examples",
    "audits",
    "analysis",
}

STOPWORDS = {
    "and",
    "the",
    "for",
    "with",
    "from",
    "into",
    "over",
    "under",
    "via",
    "token",
    "tokens",
    "protocol",
    "type",
    "issues",
    "issue",
    "errors",
    "error",
    "missing",
    "incorrect",
    "unsafe",
    "in",
    "on",
    "of",
    "to",
    "by",
    "or",
    "and",
    "is",
    "are",
    "be",
    "that",
    "this",
    "state",
    "update",
    "handling",
    "checks",
    "validation",
    "logic",
    "mechanism",
    "category",
    "categories",
    "mixed",
    "high",
    "medium",
    "low",
    "finding",
    "findings",
    "vulnerabilities",
    "vulnerability",
}

LOW_SIGNAL_TOKENS = {
    "require",
    "assert",
    "revert",
    "address",
    "amount",
    "amounts",
    "value",
    "values",
    "msg",
    "sender",
    "return",
    "returns",
    "call",
    "calls",
    "function",
    "contract",
    "mapping",
    "storage",
    "memory",
    "calldata",
    "public",
    "external",
    "internal",
    "private",
    "bool",
    "true",
    "false",
    "uint",
    "uint8",
    "uint16",
    "uint32",
    "uint64",
    "uint128",
    "uint256",
    "int",
    "int256",
    "bytes",
    "bytes32",
    "string",
    "token",
    "tokens",
    "chain",
    "message",
    "safe",
    "transfer",
    "transferfrom",
    "approve",
    "allowance",
    "owner",
    "admin",
    "role",
    "state",
    "data",
    "input",
    "output",
    "proof",
    "verify",
    "check",
    "checks",
    "validation",
}

TOKEN_EXPANSIONS: Dict[str, List[str]] = {
    "reentrancy": ["reentrancy", "nonreentrant", "reentrant", "delegatecall"],
    "oracle": ["oracle", "chainlink", "pricefeed", "twap", "aggregatorv3interface"],
    "price": ["price", "oracle", "twap", "chainlink"],
    "slippage": ["slippage", "amountoutmin", "minamountout", "maxinputamount", "minout"],
    "liquidation": ["liquidation", "liquidate", "healthfactor", "collateral", "debt"],
    "access": ["onlyowner", "accesscontrol", "grantrole", "revoke", "onlyrole", "permission"],
    "control": ["onlyowner", "accesscontrol", "grantrole", "revoke", "onlyrole", "permission"],
    "flash": ["flashloan", "onflashloan", "flash"],
    "loan": ["flashloan", "borrow", "repay", "debt"],
    "deadline": ["deadline", "timestamp", "expiry", "expiration"],
    "signature": ["signature", "ecrecover", "nonce", "permit", "domain_separator", "chainid"],
    "replay": ["replay", "nonce", "chainid", "signature"],
    "bridge": ["bridge", "crosschain", "layerzero", "wormhole"],
    "cross": ["crosschain", "bridge", "layerzero", "wormhole", "chainid"],
    "overflow": ["overflow", "underflow", "unchecked", "safecast"],
    "underflow": ["underflow", "overflow", "unchecked", "safecast"],
    "rounding": ["rounding", "precision", "decimals", "wad", "ray"],
    "precision": ["precision", "rounding", "decimals", "wad", "ray"],
    "decimal": ["decimals", "decimal", "scaling", "precision"],
    "dos": ["dos", "gas", "outofgas", "unbounded"],
    "unbounded": ["unbounded", "loop", "iteration", "gas"],
    "gas": ["gas", "outofgas", "gasleft", "basefee"],
    "approval": ["safeapprove", "permit", "allowance"],
    "allowance": ["safeapprove", "permit", "allowance"],
    "erc20": ["erc20", "safeerc20", "transferfrom", "approve"],
    "erc721": ["erc721", "safetransferfrom", "onerc721received"],
    "erc4626": ["erc4626", "previewdeposit", "converttoassets", "converttoshares"],
    "upgrade": ["upgrade", "initializer", "reinitializer", "implementation", "uups", "erc1967"],
    "initialization": ["initializer", "reinitializer", "init", "implementation"],
    "selfdestruct": ["selfdestruct", "suicide", "delegatecall"],
    "eth": ["eth", "weth", "msgvalue", "safeTransferETH"],
    "refund": ["refund", "msgvalue", "eth", "call"],
    "timelock": ["timelock", "eta", "delay", "queued"],
    "governance": ["governance", "vote", "checkpoint", "delegate", "proposal"],
    "checkpoint": ["checkpoint", "getpastvotes", "delegate", "votingpower"],
    "staking": ["stake", "unstake", "reward", "accrued"],
    "reward": ["reward", "accrued", "index", "claim"],
    "mint": ["mint", "burn", "totalsupply", "supply"],
}

ALWAYS_KEEP = {
    "reentrancy",
    "oracle",
    "flashloan",
    "liquidation",
    "slippage",
    "nonce",
    "permit",
    "chainid",
    "initializer",
    "upgrade",
    "delegatecall",
    "selfdestruct",
    "onlyowner",
    "accesscontrol",
    "erc4626",
    "bridge",
    "crosschain",
    "wormhole",
    "layerzero",
    "chainid",
}


@dataclass
class CategoryEntry:
    key: str
    title: str
    protocol_type: str
    path: str
    preconditions: List[str]
    detection_heuristics: List[str]
    keywords: List[str]


def git_rev(path: Path) -> str:
    try:
        out = subprocess.check_output(
            ["git", "-C", str(path), "rev-parse", "--short", "HEAD"],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
        return out
    except Exception:
        return "unknown"


def normalize_token(token: str) -> str:
    return re.sub(r"[^a-z0-9_]", "", token.lower())


def to_tokens(text: str) -> List[str]:
    return [normalize_token(x) for x in re.findall(r"[a-zA-Z0-9_]+", text.lower()) if normalize_token(x)]


def de_dupe(items: List[str], limit: int = 32) -> List[str]:
    seen = set()
    out: List[str] = []
    for item in items:
        if not item or item in seen:
            continue
        seen.add(item)
        out.append(item)
        if len(out) >= limit:
            break
    return out


def expand_tokens(tokens: List[str]) -> List[str]:
    expanded: List[str] = []
    for token in tokens:
        if len(token) < 3 or token in STOPWORDS or token in LOW_SIGNAL_TOKENS:
            continue
        if token in TOKEN_EXPANSIONS:
            for item in TOKEN_EXPANSIONS[token]:
                if item not in LOW_SIGNAL_TOKENS:
                    expanded.append(item)
        else:
            expanded.append(token)
    return de_dupe(expanded, limit=40)


def parse_category_file(path: Path) -> CategoryEntry:
    title = path.stem.replace("-", " ").title()
    protocol_type = path.parent.name
    preconditions: List[str] = []
    detection_heuristics: List[str] = []
    section = ""

    lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    for line in lines:
        if line.startswith("# "):
            title = line.replace("# ", "").strip()
            continue

        m = re.match(r"^>\s*Protocol Type:\s*([^|]+)\|", line)
        if m:
            protocol_type = m.group(1).strip().lower()
            continue

        if line.startswith("## "):
            section = line.replace("## ", "").strip().lower()
            continue

        if section == "preconditions" and line.startswith("- "):
            preconditions.append(line[2:].strip())
            continue

        if section == "detection heuristics":
            numbered = re.match(r"^\d+\.\s+(.*)$", line)
            if numbered:
                detection_heuristics.append(numbered.group(1).strip())
            elif line.startswith("- "):
                detection_heuristics.append(line[2:].strip())

    slug_tokens = to_tokens(path.stem)
    title_tokens = to_tokens(title)
    protocol_tokens = to_tokens(protocol_type)
    code_tokens: List[str] = []
    heuristic_text = " ".join(detection_heuristics[:6])
    for backtick_item in re.findall(r"`([^`]+)`", heuristic_text):
        code_tokens.extend(to_tokens(backtick_item))

    keywords = expand_tokens(slug_tokens + title_tokens + protocol_tokens + code_tokens)
    key = f"{protocol_type}/{path.stem}"
    return CategoryEntry(
        key=key,
        title=title,
        protocol_type=protocol_type,
        path=str(path),
        preconditions=preconditions,
        detection_heuristics=detection_heuristics,
        keywords=keywords,
    )


def list_text_files(target_dir: Path, max_file_bytes: int) -> List[Path]:
    files: List[Path] = []
    for p in target_dir.rglob("*"):
        if not p.is_file():
            continue
        if any(part in IGNORED_DIR_NAMES for part in p.parts):
            continue
        if p.suffix.lower() not in TEXT_SUFFIXES:
            continue
        try:
            if p.stat().st_size > max_file_bytes:
                continue
        except Exception:
            continue
        files.append(p)
    return files


def build_token_index(files: List[Path]) -> Tuple[Dict[str, Set[int]], Counter]:
    token_to_files: Dict[str, Set[int]] = defaultdict(set)
    global_counts: Counter = Counter()

    for idx, fp in enumerate(files):
        try:
            text = fp.read_text(encoding="utf-8", errors="ignore").lower()
        except Exception:
            continue

        file_tokens = re.findall(r"[a-z_][a-z0-9_]{2,}", text)
        if not file_tokens:
            continue
        per_file = Counter(file_tokens)
        for token in per_file:
            token_to_files[token].add(idx)
        global_counts.update(per_file)

    return token_to_files, global_counts


def score_entry(
    entry: CategoryEntry,
    token_to_files: Dict[str, Set[int]],
    global_counts: Counter,
    total_files: int,
    common_token_ratio: float,
) -> Tuple[int, List[int], List[str], int]:
    matched_file_ids: Set[int] = set()
    matched_keywords: List[str] = []
    weighted_signal = 0.0

    for kw in entry.keywords:
        ids = token_to_files.get(kw)
        if not ids:
            continue
        coverage = len(ids) / max(total_files, 1)
        if coverage > common_token_ratio and kw not in ALWAYS_KEEP:
            continue
        matched_keywords.append(kw)
        matched_file_ids.update(ids)
        idf = math.log1p(max(total_files, 1) / (1 + len(ids)))
        weighted_signal += min(3.5, idf)

    total_hits = sum(min(global_counts.get(kw, 0), 500) for kw in matched_keywords)
    score = min(len(matched_file_ids), 500) + int(weighted_signal * 20) + min(len(entry.detection_heuristics), 8)
    return score, sorted(matched_file_ids), de_dupe(matched_keywords, limit=16), total_hits


def render_markdown(
    scored: List[Tuple[CategoryEntry, int, List[str], List[str], int]],
    target_dir: Path,
    index_dir: Path,
    commit: str,
    max_entries: int,
) -> str:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%SZ")
    lines = [
        "# Protocol Vulnerability Checklist",
        "",
        f"- generated_utc: {now}",
        f"- target_dir: `{target_dir}`",
        f"- index_dir: `{index_dir}`",
        f"- index_commit: `{commit}`",
        "",
        "## Relevance Summary",
        "",
        "| Category | Protocol Type | Score | Files Matched | Heuristics |",
        "|---|---|---:|---:|---:|",
    ]

    for entry, score, matched_files, _, _ in scored[:120]:
        lines.append(
            f"| `{entry.key}` | `{entry.protocol_type}` | {score} | {len(matched_files)} | {len(entry.detection_heuristics)} |"
        )

    lines.extend(["", "## Actionable Checks", ""])
    relevant = [x for x in scored if x[1] > 0][:max_entries]
    if not relevant:
        relevant = scored[:max_entries]

    for entry, score, matched_files, matched_keywords, total_hits in relevant:
        lines.append(f"### {entry.title} (`{entry.key}`)")
        lines.append("")
        lines.append(f"- relevance_score: {score}")
        lines.append(f"- protocol_type: `{entry.protocol_type}`")
        lines.append(f"- matched_files: {len(matched_files)}")
        lines.append(f"- total_signal_hits: {total_hits}")
        lines.append(f"- source: `{entry.path}`")
        if matched_keywords:
            lines.append(f"- matched_keywords: `{', '.join(matched_keywords)}`")
        if matched_files:
            lines.append("- sample_matches:")
            for p in matched_files[:8]:
                lines.append(f"  - `{p}`")
        if entry.preconditions:
            lines.append("- preconditions:")
            for item in entry.preconditions[:6]:
                lines.append(f"  - {item}")
        if entry.detection_heuristics:
            lines.append("- checklist:")
            for h in entry.detection_heuristics[:10]:
                lines.append(f"  - {h}")
        else:
            lines.append("- checklist:")
            lines.append("  - No detection heuristics were parsed from this entry.")
        lines.append("")

    lines.extend(
        [
            "## Usage in Ralph",
            "",
            "1. Treat each checklist item as a hypothesis seed, not as a confirmed issue.",
            "2. Prove reachability and controllability before escalating severity.",
            "3. Log rejected hypotheses with concrete evidence in `findings/negative_evidence.md`.",
            "",
        ]
    )

    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate protocol vulnerability checklist from protocol-vulnerabilities-index.")
    parser.add_argument("--target-dir", required=True, help="Target codebase directory")
    parser.add_argument(
        "--index-dir",
        default="tools/protocol-vulnerabilities-index",
        help="Path to protocol-vulnerabilities-index root",
    )
    parser.add_argument(
        "--output",
        default="findings/protocol_vulnerability_checklist.md",
        help="Markdown output path",
    )
    parser.add_argument(
        "--json-output",
        default="findings/protocol_vulnerability_checklist.json",
        help="JSON output path",
    )
    parser.add_argument("--max-file-bytes", type=int, default=700_000, help="Skip files larger than this size")
    parser.add_argument("--max-entries", type=int, default=80, help="Max actionable entries in markdown output")
    parser.add_argument(
        "--common-token-ratio",
        type=float,
        default=0.20,
        help="Ignore tokens present in more than this fraction of files",
    )
    args = parser.parse_args()

    target_dir = Path(args.target_dir).resolve()
    index_dir = Path(args.index_dir).resolve()
    categories_dir = index_dir / "categories"
    output = Path(args.output)
    json_output = Path(args.json_output)

    if not target_dir.exists():
        raise SystemExit(f"target dir not found: {target_dir}")
    if not categories_dir.exists():
        raise SystemExit(f"categories dir not found: {categories_dir}")

    category_files = sorted(categories_dir.rglob("*.md"))
    if not category_files:
        raise SystemExit(f"no category files found in {categories_dir}")

    entries = [parse_category_file(p) for p in category_files]
    files = list_text_files(target_dir, max_file_bytes=args.max_file_bytes)
    token_to_files, global_counts = build_token_index(files)

    scored: List[Tuple[CategoryEntry, int, List[str], List[str], int]] = []
    for entry in entries:
        score, file_ids, matched_keywords, total_hits = score_entry(
            entry=entry,
            token_to_files=token_to_files,
            global_counts=global_counts,
            total_files=len(files),
            common_token_ratio=args.common_token_ratio,
        )
        matched_paths = [str(files[i]) for i in file_ids if 0 <= i < len(files)]
        scored.append((entry, score, matched_paths, matched_keywords, total_hits))

    scored.sort(key=lambda x: (x[1], len(x[0].detection_heuristics)), reverse=True)
    commit = git_rev(index_dir)
    markdown = render_markdown(
        scored=scored,
        target_dir=target_dir,
        index_dir=index_dir,
        commit=commit,
        max_entries=args.max_entries,
    )

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(markdown, encoding="utf-8")
    print(f"wrote: {output}")

    payload = {
        "generated_utc": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%SZ"),
        "target_dir": str(target_dir),
        "index_dir": str(index_dir),
        "index_commit": commit,
        "entries": [
            {
                **asdict(entry),
                "score": score,
                "matched_files": matched_files,
                "matched_keywords": matched_keywords,
                "total_signal_hits": total_hits,
            }
            for entry, score, matched_files, matched_keywords, total_hits in scored
        ],
    }
    json_output.parent.mkdir(parents=True, exist_ok=True)
    json_output.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(f"wrote: {json_output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
