/**
 * @name Missing access control on sensitive functions
 * @description Finds functions that modify critical state without access control
 * @kind problem
 * @problem.severity error
 * @precision medium
 * @tags security
 * @id solidity/missing-access-control
 */

import solidity

predicate isSensitiveStateChange(Function f) {
  exists(Assignment a |
    a.getEnclosingFunction() = f and
    (
      a.getLValue().(VariableAccess).getTarget().getName().toLowerCase().matches("%owner%") or
      a.getLValue().(VariableAccess).getTarget().getName().toLowerCase().matches("%admin%") or
      a.getLValue().(VariableAccess).getTarget().getName().toLowerCase().matches("%paused%") or
      a.getLValue().getAChild*().(VariableAccess).getTarget().getName().toLowerCase().matches("%balances%")
    )
  ) or
  exists(FunctionCall c |
    c.getEnclosingFunction() = f and
    c.getTarget().getName() = "selfdestruct"
  ) or
  exists(FunctionCall c |
    c.getEnclosingFunction() = f and
    c.getTarget().getName().toLowerCase().matches("%mint%") and
    not c.getTarget().getName().toLowerCase().matches("%_mint%")
  )
}

predicate hasAccessControl(Function f) {
  exists(ModifierInvocation mi |
    mi.getModifier().getName().toLowerCase().matches("%onlyowner%") or
    mi.getModifier().getName().toLowerCase().matches("%onlyadmin%") or
    mi.getModifier().getName().toLowerCase().matches("%auth%") or
    mi.getModifier().getName().toLowerCase().matches("%authorized%") or
    mi.getModifier().getName().toLowerCase().matches("%requireauth%")
  ) or
  exists(RequireStmt req |
    req.getEnclosingFunction() = f and
    (
      req.getCondition().getAChild*().(VariableAccess).getTarget().getName().toLowerCase().matches("%owner%") or
      req.getCondition().getAChild*().(FunctionCall).getTarget().getName().toLowerCase().matches("%hasrole%")
    )
  )
}

from Function f
where
  isSensitiveStateChange(f) and
  not hasAccessControl(f) and
  (f.isPublic() or f.isExternal()) and
  not f.getName().toLowerCase().matches("%initialize%") // Exclude initializers
select f, "Sensitive function $@ may be missing access control", f, f.getName()
