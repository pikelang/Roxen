// This is (not really) a roxen module. Copyright © 2000, Roxen IS.
//

constant cvs_version="$Id: ximg.pike,v 1.7 2000/02/24 05:27:36 nilsson Exp $";
inherit "module";
inherit "roxenlib";

constant thread_safe = 1;
constant module_type = MODULE_PARSER;
constant module_name = "Ximg";
constant module_doc  = "<h2>Deprecated</h2> It does the same thing as the imgs tag.";

RoxenModule rxml_warning_cache;
void old_rxml_warning(RequestID id, string no, string yes) {
  if(!rxml_warning_cache) rxml_warning_cache=my_configuration()->get_provider("oldRXMLwarning");
  if(!rxml_warning_cache) return;
  rxml_warning_cache->old_rxml_warning(id, no, yes);
}

string tag_ximg(string t, mapping m, RequestID id) {
  old_rxml_warning(id, "ximg tag","imgs");
  return make_tag("imgs",m);
}
