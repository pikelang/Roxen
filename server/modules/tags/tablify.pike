// Tablify module
// Converts tab and newline separated lists to tables.



string cvs_version = "$Id: tablify.pike,v 1.4 1996/12/02 04:32:49 per Exp $";
#include <module.h>
inherit "module";

mixed *register_module()
{
  return ({ 
    MODULE_PARSER,
    "Tablify",
      ("Generates tables from, as an example, tab separated fields in newline"
       " separated records (this is the default)."
       "<p>This module defines a tag, &lt;tablify&gt;<p>Arguments:<br>"
       "cellseparator=str: Use str as the column-separator<br>\n"
       "rowseparator=str: Use str as the row-separator<br>\n"
       "cellalign=left|right|center: Align the contents of the cells<br>\n"
       "rowalign=left|right|center: Align the contents of the rows<br>\n"),
      ({}), 1, });
}

string tag_tablify( string tag, mapping m, string q, mapping request_id );

mapping query_container_callers()
{
  return ([ "tablify" : tag_tablify ]);
}


// The meat of the module. Convert the contents of the tag (in 'q') to
// a table.

string tag_tablify( string tag, mapping m, string q, mapping request_id )
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
    td = "<tr align="+m->rowalign+">";
    m->rowalign=0;
  } else
    td="<tr>";

  return table + td + rows*("</tr>\n"+td) + "</tr>\n</table>";
}

