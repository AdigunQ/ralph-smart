#!/usr/bin/env python3

import argparse
import json
import re
import subprocess
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Tuple


TEXT_SUFFIXES = {
    ".sol",
    ".vy",
    ".yul",
    ".rs",
    ".move",
    ".ts",
    ".js",
    ".jsx",
    ".tsx",
    ".py",
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
}


DEFAULT_PATTERNS: Dict[str, List[str]] = {
    "erc-20": [r"\bIERC20\b", r"\bERC20\b", r"\btransferFrom\s*\(", r"\bapprove\s*\(", r"\bSafeERC20\b"],
    "erc-721": [r"\bIERC721\b", r"\bERC721\b", r"\bsafeTransferFrom\s*\(", r"\bownerOf\s*\("],
    "erc-777": [r"\bIERC777\b", r"\bERC777\b", r"\btokensReceived\b"],
    "erc-1155": [r"\bIERC1155\b", r"\bERC1155\b", r"\bsafeBatchTransferFrom\s*\("],
    "erc-4626": [r"\bIERC4626\b", r"\bERC4626\b", r"\bpreviewDeposit\s*\(", r"\bmaxDeposit\s*\("],
    "erc-3156": [r"\bIERC3156\b", r"\bflashLoan\s*\(", r"\bonFlashLoan\s*\("],
    "erc-165": [r"\bIERC165\b", r"\bsupportsInterface\s*\("],
    "erc-1167": [r"\bClones\b", r"\bcloneDeterministic\s*\(", r"\bminimal proxy\b"],
    "erc-1822": [r"\bproxiableUUID\s*\(", r"\bUUPS\b", r"\bERC1822\b"],
    "erc-1967": [r"\bERC1967\b", r"\bTransparentUpgradeableProxy\b", r"\bimplementation\(\)"],
    "erc-7201": [r"\bERC7201\b", r"\bnamespaced storage\b", r"\bstorage slot\b"],
    "erc-1271": [r"\bIERC1271\b", r"\bisValidSignature\s*\("],
    "erc-2612": [r"\bpermit\s*\(", r"\bnonces\s*\(", r"\bDOMAIN_SEPARATOR\b"],
    "erc-2771": [r"\bERC2771\b", r"\bisTrustedForwarder\s*\(", r"\b_msgSender\s*\("],
    "erc-712": [r"\bEIP712\b", r"\b_domainSeparatorV4\s*\(", r"\bhashTypedDataV4\s*\("],
    "eip-1014": [r"\bCREATE2\b", r"\bcreate2\b", r"\bsalt\b"],
    "eip-6780": [r"\bSELFDESTRUCT\b", r"\bselfdestruct\s*\("],
    "eip-214": [r"\bSTATICCALL\b", r"\bstaticcall\b"],
    "eip-150": [r"\bgas stipend\b", r"\b63/64\b", r"\b.call\{gas:"],
    "eip-1559": [r"\bbasefee\b", r"\bblock\.basefee\b", r"\bmaxFeePerGas\b"],
    "eip-2929": [r"\bwarm\b", r"\bcold\b", r"\baccess list\b"],
    "eip-155": [r"\bchainid\b", r"\bCHAIN_ID\b", r"\becrecover\b", r"\bv\s*==\s*2[78]\b"],
    "eip-7702-work-in-progress": [r"\b7702\b", r"\beip[-_ ]?7702\b", r"\bauthcall\b", r"\bdelegation indicator\b"],
    "eip-7825": [r"\b7825\b", r"\beip[-_ ]?7825\b", r"\bmax tx gas\b", r"\bper[- ]tx gas cap\b"],
}


@dataclass
class Heuristic:
    cls: str
    text: str


@dataclass
class StandardEntry:
    key: str
    title: str
    path: str
    heuristics: List[Heuristic]
    patterns: List[str]


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


def parse_handbook_file(path: Path) -> StandardEntry:
    key = path.stem.lower()
    title = key.upper()
    current_cls = "General"
    heuristics: List[Heuristic] = []

    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("# ") and "Security Review" in line:
            title = line.replace("#", "").strip()
        elif line.startswith("### "):
            current_cls = line.replace("### ", "").strip()
        elif line.startswith("**Heuristic:**"):
            text = line.split("**Heuristic:**", 1)[1].strip()
            if text:
                heuristics.append(Heuristic(current_cls, text))

    patterns = DEFAULT_PATTERNS.get(key, [rf"\b{re.escape(key.replace('-', ' '))}\b"])
    return StandardEntry(
        key=key,
        title=title,
        path=str(path),
        heuristics=heuristics,
        patterns=patterns,
    )


def list_text_files(target_dir: Path, max_file_bytes: int) -> List[Path]:
    files: List[Path] = []
    for p in target_dir.rglob("*"):
        if not p.is_file():
            continue
        if any(part in IGNORED_DIR_NAMES for part in p.parts):
            continue
        if p.suffix.lower() in TEXT_SUFFIXES:
            try:
                if p.stat().st_size > max_file_bytes:
                    continue
            except Exception:
                continue
            files.append(p)
    return files


def score_entry(entry: StandardEntry, files: List[Path]) -> Tuple[int, List[str], int]:
    regexes = [re.compile(p, re.IGNORECASE) for p in entry.patterns]
    matched_files: List[str] = []
    total_hits = 0

    for fp in files:
        try:
            data = fp.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        file_hits = 0
        for rx in regexes:
            file_hits += len(rx.findall(data))
        if file_hits > 0:
            matched_files.append(str(fp))
            total_hits += file_hits

    score = len(matched_files) * 10 + min(total_hits, 100)
    return score, matched_files, total_hits


def render_markdown(
    entries: List[StandardEntry],
    scored: List[Tuple[StandardEntry, int, List[str], int]],
    handbook_root: Path,
    target_dir: Path,
    commit: str,
) -> str:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%SZ")
    lines: List[str] = [
        "# EIP Security Checklist",
        "",
        f"- generated_utc: {now}",
        f"- target_dir: `{target_dir}`",
        f"- handbook_dir: `{handbook_root}`",
        f"- handbook_commit: `{commit}`",
        "",
        "## Relevance Summary",
        "",
        "| Standard | Score | Files Matched | Heuristics |",
        "|---|---:|---:|---:|",
    ]

    for entry, score, matched_files, _ in scored:
        lines.append(f"| `{entry.key}` | {score} | {len(matched_files)} | {len(entry.heuristics)} |")

    lines.extend(["", "## Actionable Checks", ""])

    relevant = [x for x in scored if x[1] > 0]
    if not relevant:
        relevant = scored[:6]

    for entry, score, matched_files, total_hits in relevant:
        lines.append(f"### {entry.title} (`{entry.key}`)")
        lines.append("")
        lines.append(f"- relevance_score: {score}")
        lines.append(f"- matched_files: {len(matched_files)}")
        lines.append(f"- total_pattern_hits: {total_hits}")
        lines.append(f"- source: `{entry.path}`")
        if matched_files:
            lines.append("- sample_matches:")
            for m in matched_files[:8]:
                lines.append(f"  - `{m}`")
        if entry.heuristics:
            lines.append("- checklist:")
            for h in entry.heuristics:
                lines.append(f"  - [{h.cls}] {h.text}")
        else:
            lines.append("- checklist:")
            lines.append("  - No explicit heuristic entries parsed from source file.")
        lines.append("")

    lines.extend(
        [
            "## Notes",
            "",
            "- Use this file to seed `DETECT` and `BUILDING` hypotheses.",
            "- Confirm exploitability with reachability + controllability + impact evidence.",
            "- Do not report non-applicable standards just because they exist in the handbook.",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate EIP/ERC security checklist from EIP-Security-Handbook")
    parser.add_argument("--target-dir", required=True, help="Audit target directory")
    parser.add_argument("--handbook-dir", default="tools/EIP-Security-Handbook/src", help="Handbook src directory")
    parser.add_argument("--output", default="findings/eip_security_checklist.md", help="Markdown output path")
    parser.add_argument("--json-output", default="findings/eip_security_checklist.json", help="JSON output path")
    parser.add_argument("--max-file-bytes", type=int, default=700_000, help="Skip files larger than this many bytes")
    args = parser.parse_args()

    target_dir = Path(args.target_dir).resolve()
    handbook_dir = Path(args.handbook_dir).resolve()
    out_md = Path(args.output)
    out_json = Path(args.json_output)

    if not target_dir.exists():
        raise SystemExit(f"target dir not found: {target_dir}")
    if not handbook_dir.exists():
        raise SystemExit(f"handbook dir not found: {handbook_dir}")

    files = sorted(handbook_dir.rglob("*.md"))
    if not files:
        raise SystemExit(f"no markdown files found in handbook dir: {handbook_dir}")

    entries = [parse_handbook_file(f) for f in files]
    target_files = list_text_files(target_dir, args.max_file_bytes)

    scored: List[Tuple[StandardEntry, int, List[str], int]] = []
    for e in entries:
        score, matched_files, total_hits = score_entry(e, target_files)
        scored.append((e, score, matched_files, total_hits))
    scored.sort(key=lambda x: x[1], reverse=True)

    commit = git_rev(handbook_dir.parent if (handbook_dir / ".git").exists() else handbook_dir)
    md = render_markdown(entries, scored, handbook_dir, target_dir, commit)

    out_md.parent.mkdir(parents=True, exist_ok=True)
    out_md.write_text(md, encoding="utf-8")

    json_blob = {
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "target_dir": str(target_dir),
        "handbook_dir": str(handbook_dir),
        "handbook_commit": commit,
        "entries": [
            {
                **asdict(e),
                "score": score,
                "matched_files": matched_files,
                "total_pattern_hits": total_hits,
            }
            for e, score, matched_files, total_hits in scored
        ],
    }
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_json.write_text(json.dumps(json_blob, indent=2), encoding="utf-8")

    print(f"wrote: {out_md}")
    print(f"wrote: {out_json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
