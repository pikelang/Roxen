// This is a roxen module. Copyright © 2000 - 2001, Roxen IS.

#include <module.h>
#include <config.h>
inherit "module";

constant cvs_version = "$Id: implicit_use.pike,v 1.10 2004/05/31 14:42:33 _cvs_stephen Exp $";
constant thread_safe = 1;
constant module_type = MODULE_FIRST;
constant module_name = "Implicit <use> Module";
constant module_doc  = "Defines tags from a template file";

void create() {

  defvar("uses", "*   package=roxenlogo", "Match pattern", TYPE_TEXT_FIELD,
	 "Maps from URL glob to what template to activate. The template is "
         "either file=name or package=name.");

}

mapping(string:array(string)) matches;

void start(int n, Configuration c)
{
  if( c )
    module_dependencies(c, ({ "usertags" }) );
  matches=([]);
  string uses=query("uses")-"\r";
  foreach(uses/"\n", string pair) {
    replace(pair, "\t", " ");
    array res=pair/" " - ({""});
    if(sizeof(res)>1) {
      if(matches[res[0]])
	matches[res[0]] += ({ res[1..]*" " });
      else
	matches[res[0]] = ({ res[1..]*" " });
    }
  }
}

string status() {
  String.HTML.OBox obox = String.HTML.OBox();
  obox->add_tagdata_cell("th", (["align":"center"]), "Pattern");
  obox->add_tagdata_cell("th", (["align":"center"]), "Use");

  foreach(indices(matches), string match)
    foreach(matches[match], string use)
      obox->add_row( ({ match, use }) );

  return (string)obox;
}

mapping first_try(RequestID id) {

  if(id->misc->_implicituse)
    return 0;

  string uses="";
  foreach(indices(matches), string match)
    if(glob(match,id->not_query))
      uses += map(matches[match],
		  lambda(string in) { return "<use "+in+"/>"; })*"";

  id->misc->rxmlprefix = (id->misc->rxmlprefix||"") + uses;
  id->misc->_implicituse = 1;

  return 0;
}
