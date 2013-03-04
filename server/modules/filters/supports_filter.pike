// This is a roxen module. Copyright © 2000 - 2009, Roxen IS.
//

#include <module.h>
inherit "module";

constant cvs_version = "$Id$";
constant module_name = "Supports filter";
constant module_type = MODULE_FILTER;
constant thread_safe = 1;
constant module_doc =
#"<p>The supports filter module takes a look at the supports flag at the
client and then filters the HTML before sending it back to the client,
removing things that the client can not handle. Which flags the module
looks for is optional, and can be controlled from the administration
interface. The following supports flags are available:</p>

<table border='1' cellspacing='0'>
<tr><th>Support flag</th><th>Affected tags</th><th>Transformed into</th></tr>
<tr valign='top'><td>bigsmall</td><td>&lt;big&gt;txt&lt;/big&gt;<br />&lt;small&gt;txt&lt;/small&gt;</td>
  <td>&lt;b&gt;txt&lt;/b&gt;<br />txt</td></tr>
<tr><td>center</td><td>&lt;center&gt;txt&lt;/center&gt;</td><td>txt</td></tr>
<tr><td>font</td><td>&lt;font&gt;txt&lt;/font&gt;</td><td>txt</td></tr>
<tr><td>images</td><td>&lt;img /&gt;</td><td>&nbsp;</td></tr>
<tr><td>java</td><td>&lt;applet&gt;txt&lt;/applet&gt;</td><td>&nbsp;</td></tr>
<tr><td>javascript</td><td>&lt;script&gt;txt&lt;/script&gt;</td><td>&nbsp;</td></tr>
<tr><td>mailto</td><td>&lt;a href=\"mailto: ...\"&gt;txt&lt;/a&gt;</td><td>txt</td></tr>
<tr valign='top'><td>stylesheets</td><td>&lt;style&gt;txt&lt;/style&gt;<br />&lt;link style=\"text/css\" /&gt;</td>
  <td>&nbsp;</td></tr>
</table>

<p>Note: Javascript only removes script tags where the language attribute
is \"javascript\" or where the src attribute ends in \".js\".</p>";

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
constant all_filters=({
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
    conts->big=lambda(object p, mapping m, string c) { return "<b>"+c+"</b>"; };
    conts->small=lambda(object p, mapping m, string c) { return c; };
  }

  if(filtered->center && !id->supports->center)
    conts->center=lambda(object p, mapping m, string c) { return c; };

  if(filtered->font && !id->supports->font)
    conts->font=lambda(object p, mapping m, string c) { return c; };

  if(filtered->images && !id->supports->images)
    tags->img="";

  if(filtered->java && !id->supports->java)
    conts->applet="";

  if(filtered->javascript && !id->supports->javascript)
    conts->script=lambda(object p, mapping m, string c) {
		    if(m->language && has_value(lower_case(m->language), "javascript"))
		      return "";
		    if(m->src && m->src[..sizeof(m->src)-4]==".js")
		      return "";
		    return 0;
		  };

  if(filtered->mailto && !id->supports->mailto)
    conts->a=lambda(object p, mapping m, string c) {
	       if(m->href && m->href[..5]=="mailto") return c;
	       return 0;
	     };

  if(filtered->stylesheets && !id->supports->stylesheets) {
    conts->style="";
    tags->link=lambda(object p, mapping m, string c) {
		 if(m->type && lower_case(m->type)=="text/css") return "";
		 return 0;
	       };
  }

  if(!sizeof(conts) && !sizeof(tags)) return 0;
  res->data=Parser.HTML()->add_tags(tags)->
    add_containers(conts)->finish(res->data)->read();
  return res;
}
