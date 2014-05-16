// Copyright (C) 2001 - 2009, Roxen IS
// Module author: Johan Sundström

inherit "module";
#include <request_trace.h>

#define JS_PRESTATE(P) \
"javascript:"           \
"function R(a)"          \
"{"                       \
  "var p=a[2].split(',')," \
      "i,r=[],t='" P "';"   \
  "for(i in p)"              \
  "{"                         \
     "i=p[i];"                 \
     "if(i==t)"                 \
       "t=0;"                    \
     "else if(i)"                 \
       "r.push(i)"                 \
  "}"                               \
  "if(t)"                            \
    "r.push(t);"                      \
  "r=r.join();"                        \
  "return (r?'/('+r+')':r)+a[3]"        \
"}"                                      \
"with(location)"                          \
  "pathname=R(/^(\\/\\(([^)]*)\\))?(.*)/(pathname))"

constant cvs_version = "$Id$";
constant thread_safe = 1;
constant module_type = MODULE_FILTER;
constant module_name = "Table/Image Border Unveiler";
constant module_doc  =
            "<p>"
	      "This module modifies all <tt>&lt;table&gt;</tt> and/or "
	      "<tt>&lt;img&gt;</tt> tags when a prestate \"tables\" or "
	      "\"images\" is added, forcing the border attribute to 1. "
	      "Debugging nested tables or images has never been easier."
	    "</p><p>"
	      "These convenient javascript functions <a href=\"" +
	      JS_PRESTATE("tables") + "\">toggle the prestate \"tables\"</a> "
	      "and <a href=\"" + JS_PRESTATE("images") + "\">\"images\"</a> "
	      "respectively."
	    "</p>";

protected array(string) add_border(Parser.HTML me, mapping arg,
				   string contents, RequestID id,
				   Parser.HTML parser)
{
  arg->border = "1";
  id->misc->borders_unveiled++;
  parser->set_extra( id, parser->clone() );
  return ({ Roxen.make_container(me->tag_name(), arg,
				 parser->finish( contents )->read()) });
}

mapping|void filter(mapping result, RequestID id)
{
  if (!result) return;
  string|array(string) type = result->type;
  if (arrayp(type))
    type = type[0];
  if(!result				// nobody had anything to say
  || !stringp(result->data)		// got a file object
  || !(id->prestate->tables ||
       id->prestate->images)		// only bother when we're being hailed
  || !glob("text/html*", type)
  || id->misc->borders_unveiled++	// borders already unveiled?
    )
    return 0; // signal that we didn't rewrite the result for good measure

  TRACE_ENTER("Turning on borders for all " +
	      (id->prestate->tables ? "tables" : "") +
	      (id->prestate->tables &&
	       id->prestate->images ? " and "  : "") +
	      (id->prestate->images ? "images" : "") + ".", 0);

  Parser.HTML parser = Parser.HTML();
  if(id->prestate->tables) parser->add_container("table", add_border);
  if(id->prestate->images) parser->add_container("img", add_border);
  parser->set_extra(id, parser->clone() );
  result->data = parser->finish( result->data )->read();

  TRACE_LEAVE(id->misc->borders_unveiled - 1 + " border" +
	      (1==id->misc->borders_unveiled ? "" : "s" ) + " unveiled.");

  return result;
}
