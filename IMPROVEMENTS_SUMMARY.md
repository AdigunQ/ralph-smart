# Ralph Security Agent Improvements Summary

This document summarizes the improvements made to the Ralph security agent based on the technical retrospective about building agentic infrastructure for zero-day vulnerability research.

---

## 🎯 Core Philosophy Added

**"Harnesses beat vibes"**: The difference between occasional brilliance and repeatable expert-grade output is the harness—the set of constraints, scaffolding, and checks that forces an agent to generate hypotheses explicitly, collect evidence before escalating confidence, use deterministic tools when possible, fail fast, and produce artifacts a reviewer can trust.

---

## 📁 New Files Created

### 1. `knowledges/agentic_harness.md`
The core framework implementing the 6-step verification harness:

- **Step 1**: Observation (document suspicious behavior)
- **Step 2**: Reachability (prove call paths)
- **Step 3**: Controllability (prove attacker influence)
- **Step 4**: Impact Assessment (quantify real-world impact)
- **Step 5**: Demonstration (working PoC)
- **Step 6**: Reporting (clear explanation + remediation)

Includes:
- Checkpoint requirements for each step
- Fail-fast pruning rules
- Confidence tracking methodology
- Determinism injection principles

### 2. `knowledges/verification_protocol.md`
The 5-gate verification system:

- **Gate 1**: Syntactic Validity (does the code exist?)
- **Gate 2**: Semantic Analysis (reachability + controllability)
- **Gate 3**: Impact Assessment (quantified impact)
- **Gate 4**: Proof of Exploitability (working PoC)
- **Gate 5**: Report Quality (complete documentation)

Includes:
- Verification commands and scripts
- Failure analysis framework
- "Money In, Vuln Out" principle documentation

### 3. `knowledges/codeql_integration.md`
Comprehensive CodeQL integration for deterministic analysis:

- Taint tracking queries (reentrancy, unchecked calls)
- Access control queries (missing auth checks)
- Oracle queries (staleness checks, spot price usage)
- Arithmetic queries (precision loss patterns)
- Call graph queries (reachability analysis)

Includes:
- Query execution workflow
- Integration with Ralph loop
- Best practices for determinism injection

### 4. `knowledges/subagent_orchestration.md`
The Scout/Strategist/Finalizer pattern:

- **Scout**: Maps code, documents observations (Junior role)
- **Strategist**: Finds contradictions, generates hypotheses (Senior role)
- **Finalizer**: Proves/disproves with PoC (QA role)

Includes:
- Output formats for each role
- Orchestration patterns (linear, parallel, iterative)
- Model selection by role
- Communication protocols

---

## 📝 Updated Files

### 5. `AGENTS.md` (Major Update)
Added:
- **SOTA-First Model Selection**: Use frontier models (Opus 4.5, GPT-5.2-Codex) rather than smaller models
- **Test-Time Compute Scaling**: Adaptive allocation based on difficulty and promise
- **Native Toolchain Pairing**: Match models to their native tools (GPT→Codex, Opus→claude-code)
- **Determinism Injection**: CodeQL integration guidelines
- **Verification Harness**: Reference to 6-step process
- **Subagent Architecture**: Scout/Strategist/Finalizer pattern

### 6. `PROMPT_plan.md` (Major Update)
Enhanced with:
- **Deterministic Baseline**: CodeQL queries run before deep analysis
- **Hypothesis Generation Framework**: Specific, falsifiable hypotheses
- **Assumption Reversal Technique**: Systematically violate assumptions
- **Compute Allocation Planning**: Assign compute levels to tasks
- **CodeQL Integration Points**: Specific queries for each task type

### 7. `PROMPT_build.md` (Major Update)
Enhanced with:
- **Verification Harness Integration**: All 6 steps for each hypothesis
- **CodeQL-First Approach**: Run queries before generating hypotheses
- **Checkpoint Documentation**: Required artifacts at each step
- **Pruning Rules**: Fail-fast criteria
- **5-Gate Checklist**: Verification gates for each finding
- **Adaptive Compute Instructions**: Allocate based on signal strength

### 8. `loop.sh` (Major Update)
Added:
- **Adaptive Compute Allocation**: COMPUTE_BUDGET and compute tracking
- **Task-Based Model Selection**: Different models for different compute levels
- **CodeQL Baseline Integration**: Automatic database creation and query execution
- **Task Status Tracking**: Update IMPLEMENTATION_PLAN.md automatically
- **Compute Cost Calculation**: HIGH=5, MEDIUM=3, LOW=1 compute units
- **Budget Management**: Skip or downgrade tasks when budget is low

### 9. `README.md` (Updated)
Added:
- New methodology selection options (/harness, /codeql)
- Verification Harness overview
- CodeQL Integration quick reference
- New core directives (Query First, Harness Everything, Compute Optimally)
- Updated execution instructions

---

## 🔑 Key Improvements

### 1. From Vibes to Harnesses
**Before**: Rely on model's "reasoning" for vulnerability detection  
**After**: Structured 6-step harness with verifiable checkpoints at each step

### 2. Determinism Injection
**Before**: Pure LLM reasoning for all analysis  
**After**: CodeQL for deterministic queries (reachability, taint, patterns) + LLM for interpretation

### 3. SOTA-First Model Selection
**Before**: Use smaller models for efficiency  
**After**: Use frontier models (Opus 4.5, GPT-5.2-Codex) with native toolchains

### 4. Adaptive Compute Allocation
**Before**: Uniform effort across all tasks  
**After**: Allocate compute based on signal strength (HIGH/MEDIUM/LOW)

### 5. Subagent Decomposition
**Before**: Single agent does everything  
**After**: Scout→Strategist→Finalizer pipeline with specific roles

### 6. Verification Gates
**Before**: Report based on confidence threshold  
**After**: Must pass all 5 verification gates (Syntactic→Semantic→Impact→PoC→Report)

### 7. Fail-Fast Pruning
**Before**: Investigate all hypotheses equally  
**After**: Prune quickly if no entry point, access control exists, or impact is low

### 8. Artifact Requirements
**Before**: Report findings in single document  
**After**: 6 required artifacts per finding (observation, reachability, controllability, impact, PoC, report)

---

## 🎓 Research Principles Applied

From the technical retrospective, these principles are now embedded:

1. **Long-form reasoning needs decomposition**: 6-step harness maintains accuracy
2. **Harnesses create reliability**: Structured constraints beat clever prompts
3. **Cyber tooling is essential**: CodeQL provides "determinism injection"
4. **Compute scales discovery**: Adaptive allocation based on difficulty
5. **SOTA-first beats weak-to-strong**: Frontier models outperform tuned smaller models
6. **Verification is built-in**: Cyber is friendly to agents because exploits are verifiable
7. **"Money in, vuln out"**: More compute + strong harnesses = more verified vulnerabilities

---

## 🚀 Usage Improvements

### Running with Adaptive Compute
```bash
# Default: 100 compute units
./loop.sh

# Custom budget
COMPUTE_BUDGET=200 ./loop.sh

# High-compute mode for critical audits
COMPUTE_BUDGET=500 ADAPTIVE_MODE=true ./loop.sh
```

### Running with Specific Models
```bash
# Use Opus for complex protocols
STRATEGIST_MODEL=claude-opus-4.5 FINALIZER_MODEL=claude-opus-4.5 ./loop.sh

# Use GPT-Codex for code-heavy tasks
FINALIZER_MODEL=gpt-5.2-codex ./loop.sh
```

### Running with CodeQL
```bash
# CodeQL runs automatically if available
# Or manually:
./scripts/run_codeql_baseline.sh
```

### Using the Harness Manually
```bash
# Scout a specific contract
cat knowledges/subagent_orchestration.md | grep -A 50 "Scout Prompt"

# Run verification on hypothesis
# Follow 6-step process in agentic_harness.md
```

---

## 📊 Expected Outcomes

With these improvements, the Ralph agent should:

1. **Find more real vulnerabilities**: Better hypothesis generation + verification
2. **Report fewer false positives**: 5-gate verification catches hallucinations
3. **Produce higher-quality reports**: Required artifacts ensure completeness
4. **Use compute efficiently**: Adaptive allocation based on signal strength
5. **Be more reliable**: Deterministic tools reduce compounding errors
6. **Scale better**: Subagent decomposition enables parallelization

---

## 🔗 References

Key papers and resources referenced:

- Artificial Expert Intelligence through PAC-reasoning - arXiv:2412.02441
- Scaling LLM Test-Time Compute Optimally - arXiv:2408.03314
- Smaller, Weaker, Yet Better: Training LLM Reasoners - arXiv:2408.16737
- Certified Reasoning with Language Models - arXiv:2305.20050
- CodeQL for Solidity - https://github.com/github/codeql

---

## 📝 Migration Guide

If you were using the previous version of Ralph:

1. **Read the new AGENTS.md**: Updated operational procedures
2. **Run CodeQL baseline**: New deterministic analysis capability
3. **Update IMPLEMENTATION_PLAN.md**: Add compute levels to tasks
4. **Use new prompts**: PROMPT_plan.md and PROMPT_build.md are enhanced
5. **Try subagent mode**: Use Scout/Strategist/Finalizer for complex audits

The core loop.sh still works the same way, but now with much more powerful capabilities under the hood.
