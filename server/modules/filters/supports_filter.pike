// This is a roxen module. Copyright © 2000, Roxen IS.
//

#include <module.h>
inherit "module";

constant module_name = "Supports filter";
constant module_doc = ("Filters the result HTML from things the client can not handle,"
		       "based on its supports values.");
constant module_type = MODULE_FILTER;

void create() {
  defvar("bigsmall", 0, "bigsmall", TYPE_FLAG, "Filter out &lt;big&gt; and &lt;small&gt; tags.");
  defvar("center", 0, "center", TYPE_FLAG, "Filter out &lt;center&gt; tags.");
  defvar("font", 0, "font", TYPE_FLAG, "Filter out &lt;font&gt; tags.");
  defvar("images", 0, "images", TYPE_FLAG, "Filter out images.");
  defvar("java", 1, "java", TYPE_FLAG, "Filter out java applets.");
  defvar("javascript", 1, "javascript", TYPE_FLAG, "Filter out javascript.");
  defvar("mailto", 1, "mailto", TYPE_FLAG, "Filter out mailtos from anchors.");
  defvar("stylesheets", 1, "stylesheets", TYPE_FLAG, "Filter out stylesheets.");
}

multiset filtered=(<>);
array all_filters=({
  "bigsmall",
  "center",
  "font",
  "images",
  "java",
  "javascript",
  "mailto",
  "stylesheets",
});

void start() {
  foreach(all_filters, string f)
    filtered[f]=query(f);
}

mapping filter(mapping res, RequestID id) {
  if(!res || !stringp(res->data) ||
     id->prestate["disable-supports-filter"]) return 0;

  mapping tags=([]), conts=([]);

  if(filtered->bigsmall && !id->supports->bigsmall) {
    conts->big=lambda(string t, mapping m, string c) { return "<b>"+c+"</b>"; };
    conts->small=lambda(string t, mapping m, string c) { return c; };
  }

  if(filtered->center && !id->supports->center)
    conts->center=lambda(string r, mapping m, string c) { return c; };

  if(filtered->font && !id->supports->font)
    conts->font=lambda(string t, mapping m, string c) { return c; };

  if(filtered->images && !id->supports->images)
    tags->img="";

  if(filtered->java && !id->supports->java)
    conts->applet="";

  if(filtered->javascript && !id->supports->javascript)
    conts->script=lambda(string t, mapping m, string c) {
		    if(m->language && has_value(lower_case(m->language), "javascript"))
		      return "";
		    if(m->src && m->src[..sizeof(m->src)-4]==".js")
		      return "";
		    return 0;
		  };

  if(filtered->mailto && !id->supports->mailto)
    conts->a=lambda(string t, mapping m, string c) {
	       if(m->href[..5]=="mailto") return c;
	       return 0;
	     };

  if(filtered->stylesheets && !id->supports->stylesheets) {
    conts->style="";
    tags->link=lambda(string t, mapping m, string c) {
		 if(m->type && lower_case(m->type)=="text/css") return "";
		 return 0;
	       };
  }

  if(!sizeof(conts) && !sizeof(tags)) return 0;
  res->data=parse_html(res->data, tags, conts);
  return res;
}
