# Ralph for Security Researchers

> **Autonomous vulnerability hunting combining Ralph's loop methodology with finite-monkey's possibility space construction**

Hunt blockchain and smart contract vulnerabilities systematically using AI agents in autonomous loops. This specialized Ralph implementation is designed for security researchers conducting code audits.

![Ralph Banner](https://github.com/user-attachments/assets/692be4b4-8bd9-4002-af29-9e65c5e6b61c)

## 🎯 What is This?

**Ralph** is a technique where you run an AI coding agent in a loop until a specification is fulfilled:

```bash
while :; do cat PROMPT.md | claude-code ; done
```

**Ralph for Security Researchers** applies this to vulnerability hunting with:

- 🔄 **Autonomous loop** until all checks complete
- 🧠 **Possibility space construction** (generate hypotheses → validate → converge)
- 📋 **6 Taint Model templates** for systematic coverage
- ✅ **Rigorous validation** to filter false positives
- 📝 **Auto-generated PoCs** for confirmed vulnerabilities

## 🚀 Quick Start

### 1. Clone or Download

```bash
git clone <this-repo-url>
cd ralph-security-researcher
```

### 2. Add Your Target Project

```bash
# Option A: Symlink existing project
ln -s /path/to/your/smart-contract-project target

# Option B: Clone into target/
git clone https://github.com/project/vulnerable-defi target
```

### 3. Create Audit Specification (Optional but Recommended)

```bash
cp specs/spec_template.md specs/my-audit.md
# Edit specs/my-audit.md with project details
```

### 4. Run Ralph Loop

```bash
./loop.sh
```

That's it! Ralph will:

1. **Planning phase** (iteration 1): Analyze codebase, create vulnerability hunting checklist
2. **Building phase** (iterations 2-N): Execute each check, find bugs, create PoCs
3. **Auto-stop** when all checks complete or max iterations reached

## 📁 Project Structure

```
ralph-security-researcher/
├── loop.sh                          # Main Ralph loop
├── PROMPT_plan.md                   # Planning mode prompt
├── PROMPT_build.md                  # Building mode prompt
├── AGENTS.md                        # Operational guide
├── target/                          # Your audit target goes here
├── findings/                        # Auto-generated analysis & vulnerabilities
│   ├── vulnerabilities/            # Confirmed bugs with PoCs
│   ├── project_analysis.md         # Initial understanding
│   ├── business_flows.md           # Flow diagrams
│   └── assumptions.md              # Security assumptions
├── knowledges/                      # Knowledge base
│   ├── taint_models/               # 6 taint analysis frameworks
│   │   ├── invariant.md           # Data consistency
│   │   ├── assumption.md          # Business logic
│   │   ├── expression.md          # Dangerous code points
│   │   ├── temporal.md            # State machine/time
│   │   ├── composition.md         # Attack combinations
│   │   └── boundary.md            # Edge cases
│   └── vulnerability_patterns/     # Common attack patterns
│       ├── reentrancy.md
│       ├── oracle_manipulation.md
│       └── ...
└── specs/                           # Audit specifications
    ├── spec_template.md
    └── example_defi_audit.md
```

## 🧠 The Methodology

### Ralph Philosophy

> "Sit on the loop, not in it" - Let the agent run autonomously while you do other things

**Key Principles**:

- Fresh context each iteration (no context rot)
- Progress persists in files and git history
- Backpressure via validation (tests, code analysis)

### Finite-Monkey Philosophy

> "Shift from 'finding the right answer' to 'managing the possibility space'"

**Key Innovation**:

- **Intentionally trigger LLM hallucinations** to explore vulnerability hypothesis space
- The possibility space is **finite** (10 iterations won't generate infinite unique bugs)
- **Validate rigorously** to converge from hypotheses to real findings

### Combined Approach

1. **Planning Phase**: Analyze target, create systematic checklist using 6 taint models
2. **Building Phase**: For each check:
   - Generate 3-5 vulnerability hypotheses (reverse scan: "There IS a bug here")
   - Validate each hypothesis (forward scan: rigorous proof)
   - Create PoC for confirmed bugs
   - Mark check complete

### Combined Approach

1. **Planning Phase**: Analyze target, create systematic checklist using 6 taint models
2. **Building Phase**: For each check:
   - Generate 3-5 vulnerability hypotheses (reverse scan: "There IS a bug here")
   - Validate each hypothesis (forward scan: rigorous proof)
   - Create PoC for confirmed bugs
   - Mark check complete
3. **Automatic Exit**: When all checks done or max iterations reached

See `knowledges/hound_methodology.md` for deep reasoning techniques.

## 📊 The 6 Taint Models

Every vulnerability is a **SOURCE → SINK** path with missing **SANITIZER**.

| Model   | Focus                 | Example Vulnerability            |
| ------- | --------------------- | -------------------------------- |
| **INV** | Data consistency      | `totalSupply != sum(balances)`   |
| **ASM** | Business logic flow   | Borrow before deposit            |
| **EXP** | Dangerous expressions | Unchecked external `.call()`     |
| **TMP** | State machine/timing  | Bypass governance timelock       |
| **CMP** | Attack combinations   | Flash loan + oracle manipulation |
| **BND** | Edge cases            | Zero/MAX values, overflow        |

Each model has:

- Definition and core question
- SOURCE/SINK/SANITIZER framework
- Real-world examples
- Detection prompts
- Mitigation strategies

See `knowledges/taint_models/` for detailed guides.

## 🔎 Using the Knowledge Base with LLMs

The `knowledges/` folder contains a rich library of security patterns, audit reports, and taint models. Here's how to instruct your LLM to leverage this knowledge during audits.

### Knowledge Base Structure

```
knowledges/
├── security_primer.md          # 370+ vulnerability patterns
├── erc4626_security_primer.md  # 366 vault-specific patterns
├── taint_models/               # 6 systematic analysis frameworks
├── vulnerability_patterns/     # Common attack patterns
└── solodit/                    # 575 real audit reports
    └── reports/
        ├── Cyfrin/
        ├── Pashov Audit Group/
        ├── Trust Security/
        └── ... (17 security firms)
```

### Example LLM Prompts

#### 1. Pattern Matching Against Known Vulnerabilities

```
Read `knowledges/security_primer.md` and check if any of the
vulnerability patterns apply to the `withdraw()` function in
`contracts/Vault.sol`.

For each matching pattern, explain:
1. Which pattern matches
2. Where in the code it applies
3. How to exploit it
```

#### 2. Search Similar Audit Reports

```
Search `knowledges/solodit/reports/` for audits of lending protocols.
Find any findings related to "liquidation" or "collateral ratio".
Apply those findings to analyze the liquidation logic in our target
contract at `target/contracts/LendingPool.sol`.
```

#### 3. Apply Taint Model Framework

```
Read `knowledges/taint_models/invariant.md` and apply its
SOURCE → SINK → SANITIZER framework to the accounting logic in
`target/contracts/Pool.sol`.

Generate 3 hypotheses about broken invariants, then validate each one.
```

#### 4. Cross-Reference with ERC4626 Patterns

```
Our target implements an ERC4626 vault. Read
`knowledges/erc4626_security_primer.md` and check for:
1. First depositor attack mitigations
2. Share price manipulation vectors
3. Rounding direction issues

Report any patterns that match our implementation.
```

#### 5. Full Audit with Knowledge Integration

```
You are auditing `target/contracts/`. Before analyzing each function:

1. Check `knowledges/vulnerability_patterns/` for matching patterns
2. Search `knowledges/solodit/reports/` for similar protocol audits
3. Apply the relevant taint model from `knowledges/taint_models/`
4. Reference `knowledges/security_primer.md` for edge cases

Document all matches and create PoCs for confirmed vulnerabilities.
```

### Search Commands for Knowledge Base

Use these commands to find relevant knowledge:

```bash
# Find all vault-related findings
grep -r "vault" knowledges/solodit/reports/ --include="*.md"

# Find reentrancy patterns
grep -r "reentrancy" knowledges/ --include="*.md"

# Find all Critical/High findings from Cyfrin
grep -r "Critical\|High" knowledges/solodit/reports/Cyfrin/

# List all audit reports for lending protocols
ls knowledges/solodit/reports/*/ | xargs grep -l "lending\|borrow"
```

### Integrating Knowledge into PROMPT Files

Add this context to your `PROMPT_build.md`:

```markdown
## Knowledge Base Context

Before analyzing each function, reference:

- `knowledges/security_primer.md` for vulnerability patterns
- `knowledges/taint_models/[relevant].md` for the analysis framework
- `knowledges/solodit/reports/` for similar protocol audits

Search for patterns matching the function's behavior and apply
lessons from historical audits.
```

## ⚙️ Configuration

Edit `loop.sh` or set environment variables:

```bash
# Maximum iterations (default: 50)
export MAX_ITERATIONS=30

# Circuit breaker: stop after N consecutive errors (default: 3)
export CIRCUIT_BREAKER_ERRORS=3

# Delay between iterations in seconds (default: 5)
export RATE_LIMIT_DELAY=10

# Codex AI model (default: claude-sonnet-4)
export CODEX_MODEL="gpt-4o"

# Run
./loop.sh
```

## 📖 Manual Deep Reading Audit

For audits that require **deep human-like analysis** rather than pattern matching, use the Manual Deep Reading approach.

> _"The bug is always in the line you didn't read carefully."_

### Philosophy

This approach mimics how a senior human auditor reads code:

- **Line by line**, character by character
- **No checklists**, no automated patterns
- **Focus on understanding**, not scanning

### Key Focus Areas

1. **Data Layer First**

   - Read every struct, mapping, and state variable
   - Understand what each represents in the real world
   - Trace how variables are initialized

2. **State Transitions**

   - For every function that modifies state, ask:
   - _"What must be true before? What will be true after?"_
   - Read state changes in order - bugs hide between steps

3. **Slow Read on Critical Functions**

   - Pick the function that moves money
   - Read it character by character
   - Every operator, every comparison, every assignment

4. **Uncomfortable Questions**
   - What if I'm a malicious user?
   - What if I'm a malicious admin?
   - What if external dependencies fail?

### Timeline

A proper deep read of 1000 lines takes **4-8 hours**.

If you're going faster, you're not reading deeply enough.

### Full Guide

See **[MANUAL_AUDIT_DEEP_READING.md](MANUAL_AUDIT_DEEP_READING.md)** for the complete methodology.

## 💰 Cost Estimation

Running Ralph with premium models can be expensive:

| Model           | Cost per Iteration | Full Audit (30 iterations) |
| --------------- | ------------------ | -------------------------- |
| Claude Sonnet 4 | $0.50 - $2.00      | $15 - $60                  |
| GPT-4o          | $0.30 - $1.00      | $9 - $30                   |
| DeepSeek        | $0.10 - $0.30      | $3 - $9                    |

**Cost Optimization**:

- Use cheaper models for planning phase
- Set `MAX_ITERATIONS` lower
- Enable circuit breaker to stop on errors

## 🔍 Example Workflow

### Audit a DeFi Lending Protocol

```bash
# 1. Clone target
git clone https://github.com/example/lending-protocol target

# 2. Create specification
cp specs/spec_template.md specs/lending-audit.md
# Edit specs/lending-audit.md

# 3. Run Ralph
./loop.sh --max-iterations=20

# 4. Monitor progress
tail -f findings/loop.log
```

### After 5-10 Iterations

Check findings:

```bash
ls findings/vulnerabilities/
# INV-001_supply_accounting_mismatch.md
# EXP-003_reentrancy_in_withdraw.md
# CMP-001_flash_loan_oracle_manipulation.md
```

Each finding includes:

- Vulnerability description
- SOURCE → SINK taint path
- Proof of Concept code
- Impact assessment
- Mitigation recommendations

## 🛠️ Integration with Testing Frameworks

### Foundry (Ethereum/Solidity)

```bash
# Ralph creates PoC in findings/vulnerabilities/EXP-001_reentrancy.md
# Extract the PoC and run:
cd target
forge test --match-contract ExploitReentrancy -vvvv
```

### Anchor (Solana/Rust)

```bash
cd target
anchor test
```

### Aptos/Sui (Move)

```bash
cd target
aptos move test
```

## 📚 Further Reading

### Ralph Methodology

- [Ralph Wiggum explained](https://ghuntley.com/ralph/) - Original concept
- [Awesome Ralph](https://github.com/snwfdhmp/awesome-ralph) - Curated resources

### Finite-Monkey Philosophy

- [Philosophy of Monkey](https://github.com/BradMoonUESTC/finite-monkey-engine/blob/main/philosophy_of_monkey_en.md)
- [Methodology Approach](https://github.com/BradMoonUESTC/finite-monkey-engine/blob/main/Methdology_approach.md)

### Smart Contract Security

- [Smart Contract Weakness Classification](https://swcregistry.io/)
- [Ethereum Security Tools](https://consensys.github.io/smart-contract-best-practices/security-tools/)

## 🤝 Contributing

Improvements welcome! Areas to expand:

- More vulnerability patterns in `knowledges/vulnerability_patterns/`
- Language-specific taint models (Rust, Move, Cairo)
- Integration with static analysis tools (Slither, Mythril)
- Advanced validation techniques

## ⚠️ Disclaimer

This tool generates vulnerability hypotheses using AI. Always:

- ✅ Validate findings manually
- ✅ Test PoCs in safe environments
- ✅ Understand the code before claiming vulnerabilities
- ✅ Follow responsible disclosure practices

False positives are expected and part of the methodology!

## 📄 License

MIT License - See LICENSE file

---

**Built with 🔒 by security researchers, for security researchers**

_Hunt vulnerabilities autonomously. Sleep well knowing Ralph is working._
