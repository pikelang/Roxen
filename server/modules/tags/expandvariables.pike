// This is a ChiliMoon module which provides controlled variable expansion
// capabilities.
// Copyright (c) 2004-2005, Stephen R. van den Berg, The Netherlands.
//                     <srb@cuci.nl>
//
// This module is open source software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published
// by the Free Software Foundation; either version 2, or (at your option) any
// later version.
//

constant cvs_version =
 "$Id: expandvariables.pike,v 1.1 2004/05/24 13:43:07 _cvs_stephen Exp $";
constant thread_safe = 1;

#include <module.h>

inherit "module";

// ---------------- Module registration stuff ----------------

constant module_type = MODULE_TAG;
constant module_name = "Tags: Expand variables";
constant module_doc  = 
 "This module provides the expand-variables RXML tag.<br />"
 "<p>Copyright &copy; 2004-2005, by "
 "<a href='mailto:srb@cuci.nl'>Stephen R. van den Berg</a>, "
 "The Netherlands.</p>"
 "<p>This module is open source software; you can redistribute it and/or "
 "modify it under the terms of the GNU General Public License as published "
 "by the Free Software Foundation; either version 2, or (at your option) any "
 "later version.</p>";

void create()
{
  set_module_creator("Stephen R. van den Berg <srb@cuci.nl>");
}

static mapping(string:int) replacecounts=([]);

string status() {
  string s="<tr><td colspan=2>None yet</td></tr>";
  if(sizeof(replacecounts))
   { s="";
     foreach(sort(indices(replacecounts)),string scope)
        s+=sprintf("<tr><td>%s</td><td align=right>%d</td></tr>",
	 scope,replacecounts[scope]);
   }
  return "<table border=1><tr><th>Scope</th><th>Substitutions</th></tr>"+
   s+"</table>";
}

#define IS(arg) ((arg) && sizeof(arg))

// ------------------- Containers ----------------

class TagExpandVariables
{
  inherit RXML.Tag;
  constant name = "expand-variables";

  mapping(string:RXML.Type) req_arg_types = ([
  ]);
  mapping(string:RXML.Type) opt_arg_types = ([
   "scope":RXML.t_text(RXML.PEnt),
   "from":RXML.t_text(RXML.PEnt),
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      RXML.Context ctx = RXML_CONTEXT;
      multiset scope;
      result = IS(args->from)?ctx->user_get_var(args->from):content||"";

      if(IS(args->scope))
         scope = mkmultiset(args["scope"]/",");
      Parser.HTML p = Parser.HTML();
      p->ignore_tags(1);
      p->lazy_entity_end(1);
      p->_set_entity_callback(lambda(Parser.HTML p,string ent)
       { int i;
         string s=p->tag_name();
         if((i=search(s,"."))<1)
	    return 0;			     // exit early if no scope present
	 string cscope=s[..i-1];
	 s=s[i+1..];
         if(scope)
          { if(!scope[cscope])
	       return cscope[0]==':'&&2==sscanf(cscope,":%*[:]%[^:]",cscope)&&
	        scope[cscope]?({"&"+ent[2..]}):0;  // strip one colon per pass
	  }
         else if(!ctx->get_scope(cscope))
	    return cscope[0]==':'?({"&"+ent[2..]}):0;
	 else if(2!=sscanf(s+";;","%*[-.:a-zA-Z0-9];%*c"))
	    return 0;
	 string encoding;
	 sscanf(s,"%[^:]:%s",s,encoding);
         array splitted=ctx->parse_user_var(s,cscope);
	 s=ctx->get_var(splitted[1..],cscope)||"";
	 replacecounts[cscope]++;
	 return ({encoding?Roxen.roxen_encode(s,encoding):s});
       });
      result=p->finish(result)->read();

      return 0;
    }
  }
}

// --------------------- Documentation -----------------------

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
"expand-variables":#"<desc type='cont'><p><short hide='hide'>
 Expand certain scopes only.</short>The &lt;expand-variables&gt;
 tag allows one to specify which scopes to parse and expand, while
 leaving all other entities and tags untouched.</p>
<p>
 The tag is intended for situations where external data needs to be parsed
 for certain entities only, not affecting RXML code nor other
 entities/variables.
</p></desc>

<attr name='scope' value='list'><p>
 Comma-separated array of scopes to expand.  If omitted, all known scopes
 are parsed and replaced.</p>
</attr>

<attr name='from'><p>
 Variable to use as source instead of the content of the container.</p>
</attr>
",
    ]);
#endif
