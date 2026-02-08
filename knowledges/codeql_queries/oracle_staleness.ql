/**
 * @name Missing oracle staleness check
 * @description Finds Chainlink oracle calls without staleness validation
 * @kind problem
 * @problem.severity warning
 * @precision medium
 * @tags security
 * @id solidity/oracle-staleness
 */

import solidity

class ChainlinkCall extends FunctionCall {
  ChainlinkCall() {
    this.getTarget().getName() in ["latestRoundData", "getRoundData"]
  }
}

predicate hasStalenessCheck(Function f) {
  exists(RequireStmt req |
    req.getEnclosingFunction() = f and
    req.getCondition().getAChild*().(VariableAccess).getTarget().getName().toLowerCase().matches("%updatedat%") or
    req.getCondition().getAChild*().(VariableAccess).getTarget().getName().toLowerCase().matches("%timestamp%") or
    req.getCondition().getAChild*().(VariableAccess).getTarget().getName().toLowerCase().matches("%answeredinround%")
  ) or
  exists(IfStmt ifStmt |
    ifStmt.getEnclosingFunction() = f and
    ifStmt.getCondition().getAChild*().(VariableAccess).getTarget().getName().toLowerCase().matches("%updatedat%")
  )
}

from ChainlinkCall call, Function f
where
  call.getEnclosingFunction() = f and
  not hasStalenessCheck(f)
select call, "Oracle call without staleness check in $@", f, f.getName()
