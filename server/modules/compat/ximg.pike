// This is (not really) a roxen module. Copyright © 2000 - 2009, Roxen IS.
//

constant cvs_version="$Id$";
inherit "module";
inherit "roxenlib";

constant thread_safe = 1;
constant module_type = MODULE_PARSER;
constant module_name = "Old Ximg";
constant module_doc  = "<h2>Deprecated</h2> It does the same thing as the imgs tag.";

RoxenModule rxml_warning_cache;
void old_rxml_warning(RequestID id, string no, string yes) {
  if(!rxml_warning_cache) rxml_warning_cache=my_configuration()->get_provider("oldRXMLwarning");
  if(!rxml_warning_cache) return;
  rxml_warning_cache->old_rxml_warning(id, no, yes);
}

array tag_ximg(string t, mapping m, RequestID id) {
  old_rxml_warning(id, "ximg tag","imgs");
  return ({1, "imgs", m});
}
