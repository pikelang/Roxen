// This is a roxen module. Copyright © 2000 - 2009, Roxen IS.

#include <module.h>
#include <config.h>
inherit "module";

constant cvs_version = "$Id$";
constant thread_safe = 1;
constant module_type = MODULE_FIRST;
constant module_name = "Implicit <use> Module";
constant module_doc  = "Defines tags from a template file";

void create() {

  defvar("uses", "*   package=roxenlogo", "Match pattern", TYPE_TEXT_FIELD,
	 "Maps from URL glob to what template to activate. The template is "
         "either file=name or package=name.");

}

Configuration conf;
mapping(string:array(string)) matches;

void start(int num, Configuration c) {
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
  conf = c;
}

string status() {
  HTML.OBox obox = HTML.OBox();
  obox->add_tagdata_cell("th", (["align":"center"]), "Pattern");
  obox->add_tagdata_cell("th", (["align":"center"]), "Use");

  foreach(indices(matches), string match)
    foreach(matches[match], string use)
      obox->add_row( ({ match, use }) );

  return (string)obox;
}

mapping first_try(RequestID id) {

  if(id->misc->_parser) return 0;

  string uses="";
  foreach(indices(matches), string match)
    if(glob(match,id->not_query))
      uses += map(matches[match],
		  lambda(string in) { return "<use "+in+"/>"; })*"";

  RXML.PXml parser = conf->rxml_tag_set ( RXML.t_html(RXML.PXml), id);
  parser->recover_errors = 1;
  id->misc->_parser = parser;

  if (mixed err = catch( parser->write_end (uses) )) {
    if (objectp (err) && err->thrown_at_unwind)
      error ("Can't handle RXML parser unwinding in "
	     "compatibility mode (error=%O).\n", err);
    else throw (err);
  }

  return 0;
}
