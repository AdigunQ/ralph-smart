# Root Cause Taxonomy

Use these tags for `root_cause_primary` and optional `root_cause_secondary`.

- `missing_invariant`: Critical state/property is never enforced or checked.
- `unsafe_default`: Default behavior is insecure without explicit opt-in hardening.
- `trust_boundary_break`: Untrusted input or external system crosses boundary unsafely.
- `state_machine_gap`: Invalid transition/order is possible in lifecycle logic.
- `integration_mismatch`: Implementation diverges from external integrator requirements.
- `spec_gap`: Security-relevant behavior was unspecified or ambiguously specified.
- `test_gap`: Existing tests failed to encode/guard the violated security property.
- `monitoring_gap`: Runtime detection/alerting absent for exploit precursor conditions.
- `authorization_gap`: Privilege checks are missing, weak, or bypassable.
- `input_validation_gap`: User/external inputs are insufficiently validated.

Patch level guidance:
- `local_fix`: Minimal localized code change.
- `module_refactor`: Involves structural updates in one module.
- `architecture_change`: Cross-module design/security model changes required.
- `process_control`: Primary fix is SDLC/process (tests, spec, runbook, monitoring).
