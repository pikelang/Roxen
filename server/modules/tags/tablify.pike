/* This is a roxen module. (c) Informationsvävarna AB 1997.
 *
 * Converts tab and newline separated lists to tables.
 * 
 * made by Per Hedbor
 */

constant cvs_version = "$Id: tablify.pike,v 1.11 1998/03/06 11:25:43 noring Exp $";
constant thread_safe=1;
#include <module.h>
inherit "module";
inherit "wizard";

mixed *register_module()
{
  return ({ 
    MODULE_PARSER,
    "Tablify",
    (Stdio.read_bytes("modules/tags/docs/tablify")),
    ({}), 1, });
}

/* The meat of the module. Convert the contents of the tag (in 'q') to
 * a table. */

string container_fields(string name, mapping arg, string q,
			mapping m, mapping arg_list)
{
  arg_list->fields = q/(m->cellseparator||"\t");
  return "";
}

string tag_tablify( string tag, mapping m, string q, mapping request_id )
{
  array rows, res;
  string sep, td, color, table;
  int i;

#if 0
  sscanf(q, "%*[\n]%s", q);
  sscanf(reverse(q), "%*[\n]%s", q);
  q = reverse(q);
#endif

  if(tag == "htable") m->nice="nice";
  
  if(m->help) return register_module()[2];

  mapping arg_list = ([]);
  q = parse_html(q, ([]), (["fields":container_fields]), m, arg_list);

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

  array title;
  if(m->nice) {
    title = rows[0]/sep;
    rows = rows[1..];
  }

  if(m->min)
    rows = rows[((int)m->min)..];
  if(m->max)
    rows = rows[..((int)m->max-1)];
  
  if(m->nice)
  {
    rows = Array.map(rows,lambda(string r, string s){return r/s;}, sep);
    return html_table(title, rows, m + arg_list);
  }

  for(i=0; i<sizeof(rows); i++)
    rows[i] = td + (rows[i]/sep) * ("</td>"+td) + "</td>";

  table = "<table";
  foreach(indices(m), td)
    if(m[td]) table += " "+td+"=\""+m[td]+"\"";

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

