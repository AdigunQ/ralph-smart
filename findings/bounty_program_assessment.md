program_name: "Snowbridge On-Chain Code"
program_url: "https://hackenproof.com/programs/snowbridge-on-chain-code"
assessment_date: "2026-02-06"
mode: "LEAD_HUNTER"
target_priority: "HIGH"
complexity_score: 8
innovation_score: 8
optimization_risk_score: 7
integration_risk_score: 9
maturity_penalty_score: 3
expected_value_score: 8
reputation_assessment: "Program is live with public docs, explicit scope notes, and active triage process; reliability appears medium-high."
treasury_assessment: "Trusted payer flag and defined reward bands suggest credible payout process, but EV still depends on strict in-scope proof quality."
rules_clarity: "CLEAR"
scope_notes:
  - "Solidity + Rust on-chain code in scope; off-chain-only findings out of scope."
  - "Cross-chain dependent issues should include Polkadot + Ethereum exploit analysis where applicable."
  - "Known invalid class: missing message.origin checks for V2 handlers."
red_flags:
  - "Bridge complexity increases false-positive risk; must prioritize deterministic evidence and PoCs."
hunt_focus:
  - "Inbound verification, privileged command dispatch, upgrade control, custody/unlock/mint flows."
  - "Cross-chain state mismatch exploits with direct asset impact."
avoid_focus:
  - "Theoretical-only claims, style/gas-only findings, and out-of-scope off-chain paths."
rules_snapshot_path: "findings/rules_snapshot/snowbridge_hackenproof_2026-02-06.txt"
go_no_go: "GO"
notes: "High-value target with meaningful complexity and payout ceiling; proceed with strict exploitability-first filtering."
