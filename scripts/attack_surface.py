#!/usr/bin/env python3
"""
Attack Surface Generator for Ralph Security Agent
Produces a focused map of external/public entrypoints and external call sites
"""

import argparse
import json
import os
import re
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional

IGNORE_DIRS = {
    ".git",
    "node_modules",
    "venv",
    ".venv",
    "__pycache__",
    "out",
    "artifacts",
    "cache",
    "build",
    "dist",
    "findings",
    "knowledges",
}

EXTERNAL_CALL_PATTERNS = [
    (re.compile(r"\.call\b"), "call"),
    (re.compile(r"\.delegatecall\b"), "delegatecall"),
    (re.compile(r"\.staticcall\b"), "staticcall"),
    (re.compile(r"\.transfer\s*\("), "transfer"),
    (re.compile(r"\.send\s*\("), "send"),
]

VISIBILITY_KEYWORDS = ["external", "public", "internal", "private"]
ATTRIBUTE_KEYWORDS = ["view", "pure", "payable", "virtual", "override"]


def strip_comments_keep_lines(lines: List[str]) -> List[str]:
    """Remove // and /* */ comments while preserving line count."""
    out: List[str] = []
    in_block = False

    for line in lines:
        working = line

        if in_block:
            if "*/" in working:
                _, after = working.split("*/", 1)
                working = after
                in_block = False
            else:
                out.append("")
                continue

        while "/*" in working:
            before, rest = working.split("/*", 1)
            if "*/" in rest:
                after = rest.split("*/", 1)[1]
                working = before + " " + after
            else:
                working = before
                in_block = True
                break

        if "//" in working:
            working = working.split("//", 1)[0]

        out.append(working)

    return out


def collect_sol_files(root_dir: str) -> List[Path]:
    files: List[Path] = []
    for base, dirs, filenames in os.walk(root_dir):
        dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
        for name in filenames:
            if name.endswith(".sol"):
                files.append(Path(base) / name)
    return files


def compute_contract_ranges(lines: List[str]) -> List[Dict[str, int]]:
    ranges: List[Dict[str, int]] = []
    stack: List[Dict[str, int]] = []
    brace_depth = 0

    contract_re = re.compile(r"\b(contract|library|interface)\s+(\w+)")

    for idx, line in enumerate(lines, start=1):
        match = contract_re.search(line)
        if match:
            stack.append({
                "name": match.group(2),
                "start_line": idx,
                "start_depth": brace_depth,
            })

        brace_depth += line.count("{") - line.count("}")

        while stack and brace_depth <= stack[-1]["start_depth"]:
            contract = stack.pop()
            contract["end_line"] = idx
            ranges.append(contract)

    return ranges


def find_contract_for_line(ranges: List[Dict[str, int]], line_no: int) -> str:
    chosen = None
    for item in ranges:
        if item["start_line"] <= line_no <= item.get("end_line", line_no):
            if chosen is None or item["start_line"] >= chosen["start_line"]:
                chosen = item
    return chosen["name"] if chosen else "(unknown)"


def parse_functions(lines: List[str], contract_ranges: List[Dict[str, int]]) -> List[Dict[str, str]]:
    entries: List[Dict[str, str]] = []

    idx = 0
    total = len(lines)
    while idx < total:
        line = lines[idx]
        if "function" in line or "fallback" in line or "receive" in line:
            sig_lines = [line]
            j = idx
            while j < total and "{" not in lines[j] and ";" not in lines[j]:
                j += 1
                if j < total:
                    sig_lines.append(lines[j])
            signature = " ".join(s.strip() for s in sig_lines)

            func_match = re.search(r"\bfunction\s+(\w+)\s*\(([^)]*)\)\s*([^;{]*)", signature)
            fallback_match = re.search(r"\b(fallback|receive)\s*\(([^)]*)\)\s*([^;{]*)", signature)

            if func_match or fallback_match:
                if func_match:
                    name = func_match.group(1)
                    params = func_match.group(2).strip()
                    tail = func_match.group(3).strip()
                else:
                    name = fallback_match.group(1)
                    params = fallback_match.group(2).strip()
                    tail = fallback_match.group(3).strip()

                visibility = next((v for v in VISIBILITY_KEYWORDS if v in tail), "")
                if name in {"fallback", "receive"} and not visibility:
                    visibility = "external"

                attributes = []
                for attr in ATTRIBUTE_KEYWORDS:
                    if attr in tail:
                        attributes.append(attr)

                entries.append({
                    "contract": find_contract_for_line(contract_ranges, idx + 1),
                    "function": name,
                    "params": params,
                    "visibility": visibility,
                    "attributes": " ".join(attributes),
                    "raw_tail": tail,
                    "line": idx + 1,
                })
            idx = j
        idx += 1

    return entries


def parse_external_calls(lines: List[str]) -> List[Dict[str, str]]:
    results: List[Dict[str, str]] = []
    for idx, line in enumerate(lines, start=1):
        trimmed = line.strip()
        if not trimmed:
            continue
        for pattern, label in EXTERNAL_CALL_PATTERNS:
            if pattern.search(trimmed):
                results.append({
                    "line": idx,
                    "pattern": label,
                    "snippet": trimmed[:120],
                })
                break
    return results


def render_markdown(entries: List[Dict[str, str]], callsites: Dict[str, List[Dict[str, str]]], root_dir: str) -> str:
    lines: List[str] = []
    lines.append("# Attack Surface Map")
    lines.append("")
    lines.append(f"Generated: {datetime.utcnow().isoformat()}Z")
    lines.append(f"Target Root: {root_dir}")
    lines.append("")

    lines.append("## External/Public Entry Points")
    lines.append("")
    lines.append("| Contract | Function | Visibility | Attributes | File | Line |")
    lines.append("|---|---|---|---|---|---|")

    entry_count = 0
    for entry in entries:
        if entry["visibility"] not in {"external", "public"}:
            continue
        entry_count += 1
        attrs = entry["attributes"] or "-"
        lines.append(
            f"| {entry['contract']} | `{entry['function']}` | {entry['visibility']} | {attrs} | `{entry['file']}` | {entry['line']} |"
        )

    if entry_count == 0:
        lines.append("| (none) | - | - | - | - | - |")

    lines.append("")
    lines.append("## Fallback/Receive")
    lines.append("")
    lines.append("| Contract | Function | Visibility | Attributes | File | Line |")
    lines.append("|---|---|---|---|---|---|")

    fb_count = 0
    for entry in entries:
        if entry["function"] in {"fallback", "receive"}:
            fb_count += 1
            attrs = entry["attributes"] or "-"
            lines.append(
                f"| {entry['contract']} | `{entry['function']}` | {entry['visibility'] or '-'} | {attrs} | `{entry['file']}` | {entry['line']} |"
            )

    if fb_count == 0:
        lines.append("| (none) | - | - | - | - | - |")

    lines.append("")
    lines.append("## External Call Sites (Low-Level / Transfer)")
    lines.append("")
    lines.append("| File | Line | Pattern | Snippet |")
    lines.append("|---|---|---|---|")

    call_count = 0
    for file_path, entries_list in callsites.items():
        for call in entries_list:
            call_count += 1
            snippet = call["snippet"].replace("|", "\\|")
            lines.append(
                f"| `{file_path}` | {call['line']} | {call['pattern']} | `{snippet}` |"
            )

    if call_count == 0:
        lines.append("| (none) | - | - | - |")

    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate attack surface map for Solidity codebases")
    parser.add_argument("--root", default=None, help="Root directory to scan (default: ./target if exists, else .)")
    parser.add_argument("--output", default="findings/attack_surface.md", help="Markdown output file")
    parser.add_argument("--json", dest="json_output", default="", help="Optional JSON output file")

    args = parser.parse_args()

    if args.root:
        root_dir = args.root
    else:
        root_dir = "./target" if Path("./target").exists() else "."

    sol_files = collect_sol_files(root_dir)
    if not sol_files:
        print("No Solidity files found. Nothing to map.")
        return

    all_entries: List[Dict[str, str]] = []
    all_callsites: Dict[str, List[Dict[str, str]]] = {}

    for file_path in sol_files:
        try:
            raw_lines = file_path.read_text(encoding="utf-8").splitlines()
        except Exception:
            continue

        stripped_lines = strip_comments_keep_lines(raw_lines)
        contract_ranges = compute_contract_ranges(stripped_lines)
        file_entries = parse_functions(stripped_lines, contract_ranges)

        for entry in file_entries:
            entry["file"] = str(file_path)
            all_entries.append(entry)

        callsites = parse_external_calls(stripped_lines)
        if callsites:
            all_callsites[str(file_path)] = callsites

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    markdown = render_markdown(all_entries, all_callsites, root_dir)
    output_path.write_text(markdown, encoding="utf-8")

    if args.json_output:
        json_path = Path(args.json_output)
        json_path.parent.mkdir(parents=True, exist_ok=True)
        json_path.write_text(
            json.dumps({
                "generated": datetime.utcnow().isoformat() + "Z",
                "root": root_dir,
                "entrypoints": all_entries,
                "external_calls": all_callsites,
            }, indent=2),
            encoding="utf-8",
        )

    print(f"✅ Attack surface map written to {output_path}")


if __name__ == "__main__":
    main()
