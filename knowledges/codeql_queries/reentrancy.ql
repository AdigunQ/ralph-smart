/**
 * @name Reentrancy vulnerabilities
 * @description Finds external calls before state updates (CEI violations)
 * @kind problem
 * @problem.severity error
 * @precision high
 * @tags security
 * @id solidity/reentrancy
 */

import solidity

class ExternalCall extends Expr {
  ExternalCall() {
    this instanceof FunctionCall and
    (
      this.(FunctionCall).getTarget().getName() = "call" or
      this.(FunctionCall).getTarget().getName() = "delegatecall" or
      this.(FunctionCall).getTarget().getName() = "staticcall" or
      this.(FunctionCall).getTarget().getName() = "transfer" or
      this.(FunctionCall).getTarget().getName() = "send"
    )
  }
}

class StateUpdate extends Assignment {
  StateUpdate() {
    this.getLValue() instanceof VariableAccess or
    this.getLValue() instanceof IndexAccess
  }
}

predicate hasReentrancyGuard(Function f) {
  exists(ModifierInvocation mi |
    mi.getModifier().getName().toLowerCase().matches("%nonreentrant%") and
    mi = f.getModifierInvocation(_)
  )
}

from Function f, ExternalCall call, StateUpdate update
where
  call.getEnclosingFunction() = f and
  update.getEnclosingFunction() = f and
  call.getLocation().getStartLine() < update.getLocation().getStartLine() and
  not hasReentrancyGuard(f) and
  (f.isPublic() or f.isExternal())
select call, "External call before state update (potential reentrancy) in $@", f, f.getName()
