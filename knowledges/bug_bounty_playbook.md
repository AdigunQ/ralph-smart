# Bug Bounty Playbook

This playbook adapts Ralph for professional Web3 bounty hunting where expected value and payout risk both matter.

## Target Selection Heuristics

Prioritize targets with:
- high complexity (cross-contract flows, bridges, proxies, many assumptions)
- meaningful innovation (new design/mechanics/language/runtime behavior)
- optimization-heavy code paths (assembly, gas refactors, custom math)
- integration density (oracles, bridges, shared libraries, cross-chain)
- weak engineering signals (basic mistakes, poor consistency, rushed changes)

Deprioritize targets with:
- simple or heavily battle-tested logic with little novelty
- low or unclear asset-at-risk
- old/deprecated/inactive deployments
- repository code that does not match deployed code

## Time-to-Market Dynamics

- **Launch window**: speedrun basic auth/config/known pattern checks.
- **Weeks/months after launch**: focus on deep exploit paths and upgrade deltas.
- **Old popular programs**: assume remaining bugs are harder; hunt neglected modules.

## Hunter Modes

- `Digger`: deep focus on one program.
- `Differ`: compare one mechanism across many protocols.
- `Speedrunner`: fast early checks on launches/program starts.
- `Watchman`: monitor upgrades/deployments and diff high-risk changes.
- `Lead Hunter`: develop hypotheses around underexplored bug classes.
- `Scavenger`: mine obscure incidents/writeups for transferable ideas.
- `Scientist`: build automation/monitoring/tooling.

## Impact and Reporting Strategy

- Focus primarily on exploitable `CRITICAL` paths with concrete asset impact.
- Quantify realistic loss and attacker preconditions.
- Avoid unprovable, purely informational, or heavily debate-prone low-severity issues.

## Fairness and Payout Risk Controls

Before major time investment, assess:
- project reputation and prior payout behavior
- program clarity (scope, caps, severity mapping)
- treasury/payability confidence
- response and mediation quality

Archive bounty rules before reporting. Use:
- `scripts/snapshot_bounty_rules.sh <url> <label>`

## What Not to Hunt (Default Filters)

- deprecated or unused code
- inactive implementations behind proxy unless actively reachable
- non-deployed code with no shipping evidence
- chain/version-incompatible paths
- issues requiring trusted-role compromise unless explicitly in scope
