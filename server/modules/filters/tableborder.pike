// This is a roxen module. Copyright © 2000, Roxen IS.

inherit "module";

constant cvs_version = "$Id: tableborder.pike,v 1.9 2000/11/19 04:52:44 nilsson Exp $";
constant thread_safe = 1;
constant module_type = MODULE_FILTER;
constant module_name = "Table Unveiler";
constant module_doc  =
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
	    "</p>";

static array(string) alter_table(object parser, mapping(string:string) arg, string contents)
{
  arg->border = "1";
  return ({ Roxen.make_container("table", arg, recursive_parse(contents)) });
}

static string recursive_parse(string contents)
{
  return Parser.HTML()->add_container("table", alter_table)->
    finish(contents)->read();
}

mapping filter(mapping result, RequestID id)
{
  if(!result                   // If nobody had anything to say, neither do we.
  || !stringp(result->data)    // Got a file object. Hardly ever happens anyway.
  || !id->prestate->tables     // No prestate, no action.
  || result->type!="text/html" // Only parse html.
    )
    return 0; // Signal that we didn't rewrite the result for good measure.

  result->data = recursive_parse(result->data);
  return result;
}
