/* This is a roxen module. (c) Informationsvävarna AB 1997.
 *
 * Converts tab and newline separated lists to tables.
 * 
 * made by Per Hedbor
 */

constant cvs_version = "$Id: tablify.pike,v 1.7 1997/11/14 16:40:39 per Exp $";
constant thread_safe=1;
#include <module.h>
inherit "module";
inherit "wizard";

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

/* The meat of the module. Convert the contents of the tag (in 'q') to
 * a table. */

string tag_tablify( string tag, mapping m, string q, mapping request_id )
{
  array rows, res;
  string sep, td, color, table;
  int i;

  if(tag == "htable") m->nice="nice";

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

  if(m->nice)
  {
    array title = rows[0]/sep;
    rows = Array.map(rows[1..],lambda(string r, string s){ return r/s; }, sep);
    return html_table(title, rows);
  }

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

mapping query_container_callers()
{
  return ([ "tablify" : tag_tablify, "htable" : tag_tablify ]);
}

