/**
 * @name State variable mutations
 * @description Tracks where state variables are modified
 * @kind table
 * @tags audit
 * @id solidity/state-mutation
 */

import solidity

from Variable v, Assignment a
where
  v.isStateVariable() and
  a.getLValue().getAChild*().(VariableAccess).getTarget() = v
select
  v.getFile().getName() as file,
  v.getName() as variable,
  a.getEnclosingFunction().getName() as modified_by,
  a.getLocation().getStartLine() as line
