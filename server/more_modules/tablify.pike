#include <module.h>
inherit "module";

mixed *register_module()
{
  return ({ 
    MODULE_PARSER,
    "Tablify",
      ("Generates tables from, as an example, tab separated fields."
       "<p>This module defines a tag, &lt;tablify&gt;"), ({}), 1,
    });
}

string tag_tablify( string tag, mapping m, string q, mapping got )
{
  array rows, res;
  string sep, td, table;
  int i;

  if(sep = m->rowseparator)
    m->rowseparator = 0;
  else
    sep = "\n";

  rows = (q / sep);
  
  if(sep = m->cellseparator)
    m->cellseparator = 0;
  else
    sep = "\t";

  if(m->cellalign)
  {
    td = "<td align="+m->cellalign+">";
    m->cellalign = 0;
  } else
    td="<td>";

  for(i=0; i<sizeof(rows); i++)
    rows[i] = td + (rows[i]/sep) * ("</td>"+td) + "</td>";

  table = "<table";
  foreach(indices(m), td)
    if(m[td])
      table += " "+td+"=\""+m[td]+"\"";

  table += ">";
  if(m->rowalign)
  {
    td = "<tr align="+m->cellalign+">";
    m->rowalign=0;
  } else
    td="<tr>";

  return table + td + rows*("</tr>\n"+td) + "</tr>\n</table>";
}

mapping query_container_callers()
{
  return ([ "tablify" : tag_tablify ]);
}
