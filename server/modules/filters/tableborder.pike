#include <module.h>
inherit "module";
inherit "roxenlib";
constant cvs_version="$Id: tableborder.pike,v 1.1 1999/12/16 08:40:40 jhs Exp $";

array register_module()
{
  return ({ MODULE_FILTER,
	    "Table Unveiler",
	    "<p>"
	      "This module modifies &lt;table&gt; tags when a prestate "
	      "\"tables\" is added, forcing the border attribute to 1. "
	      "Debugging nested tables has never been easier."
	    "</p><p>"
	      "This convenient javascript function <a href=\"javascript:"
	        "function R(a)"
	        "{"
	          "var p=a[2].split(','),i,r=[],t='tables';"
	          "for(i in p)"
	          "{"
	             "i=p[i];"
	             "if(i==t)"
	               "t=0;"
	             "else if(i)"
	               "r.push(i)"
	          "}"
	          "if(t)"
	            "r.push(t);"
	          "r=r.join();"
	          "return (r?'/('+r+')':r)+a[3]"
	        "}"
	        "with(location)"
	          "pathname=R(/^(\\/\\(([^)]*)\\))?(.*)/(pathname))"
	      "\">toggles the prestate</a>."
	    "</p>", 0, 1 });
}

array(string) alter_table(string name, mapping arg, string contents)
{
  arg->border = "1";
  return ({ make_container(name, arg, recursive_parse(contents)) });
}

string recursive_parse(string contents)
{
  return parse_html(contents, ([ ]), ([ "table" : alter_table ]));
}

mapping filter(mapping result, RequestID id)
{
  if(!result                   // If nobody had anything to say, neither do we.
  || !stringp(result->data)    // Got a file object. Hardly ever happens anyway.
  || !id->prestate->tables     // No prestate, no action.
  || result->type!="text/html" // Only parse html.
    )
    return result;

  result->data = recursive_parse(result->data);
  return result;
}
