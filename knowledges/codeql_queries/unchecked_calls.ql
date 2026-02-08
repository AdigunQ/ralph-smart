/**
 * @name Unchecked low-level calls
 * @description Finds low-level calls where return values are not checked
 * @kind problem
 * @problem.severity warning
 * @precision high
 * @tags security
 * @id solidity/unchecked-call
 */

import solidity

from FunctionCall call
where
  call.getTarget().getName() = "call" and
  not exists(IfStmt ifStmt |
    ifStmt.getCondition().getAChild*() = call
  ) and
  not exists(Variable v |
    v.getInitializer() = call and
    exists(IfStmt ifStmt | ifStmt.getCondition().getAChild*() = v.getAnAccess())
  ) and
  not exists(TupleExpr t |
    t.getAnElement() = call and
    exists(IfStmt ifStmt | ifStmt.getCondition().getAChild*() = t)
  )
select call, "Unchecked low-level call - return value should be checked"
