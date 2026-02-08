/**
 * @name External and public functions
 * @description Lists all external and public functions for attack surface analysis
 * @kind table
 * @tags audit
 * @id solidity/external-functions
 */

import solidity

from Function f
where
  (f.isPublic() or f.isExternal()) and
  not f.getName() = "constructor"
select 
  f.getFile().getName() as file,
  f.getName() as function_name,
  f.getVisibility() as visibility,
  f.getLocation().getStartLine() as line,
  count(f.getParameter(_)) as param_count
