// This is a roxen module. Copyright © 1996 - 2001, Roxen IS.
// by Mirar <mirar@roxen.com>

// Adds the <sed> tag, to emulate a subset of sed operations in rxml
//
// <sed [suppress] [lines] [chars] [split=<linesplit>]
//      [append] [prepend]>
// <e [rxml]>edit command</e>
// <raw>raw, unparsed data</raw>
// <rxml>data run in rxml parser before edited</rxml>
// <source variable|cookie=name [rxml]>
// <destination variable|cookie=name>
// </sed>
//
// edit commands supported:
// <firstline>,<lastline><edit command>
//    ^^ numeral (17) ^^
//       or relative (+17, -17)
//       or a search regexp (/regexp/)
//       or multiple (17/regexp//regexp/+2)
//
// D                  - delete first line in space
// G                  - insert hold space
// H                  - append current space to hold space
// P                  - print current data
// a<string>          - insert
// c<string>          - change current space
// d                  - delete current space
// h                  - copy current space to hold space
// i<string>          - print string
// l                  - print current space
// p                  - print first line in data
// q                  - quit evaluating
// s/regexp/with/x    - replace
// y/chars/chars/     - replace chars
//
// where line is numeral, first line==1

constant cvs_version = "$Id: sed.pike,v 1.14 2004/06/04 00:11:53 mani Exp $";
constant thread_safe=1;

#include <module.h>

inherit "module";

constant module_type = MODULE_TAG;
constant module_name = "Tags: SED";
constant module_doc =
#"This module provides the <tt>&lt;sed&gt;</tt> tag, that works like the 
Unix sed command.";

string simpletag_sed(string tag, mapping m, string cont, RequestID id)
{
   mapping c=(["e":({})]);
   string|array d;

   // FIXME: Rewrite to use internal tags.
   parse_html(cont,
	      (["source":lambda(string tag,mapping m,mapping c,object id)
			 {
			    if (m->variable)
			      c->data = RXML_CONTEXT->user_get_var (m->variable) || "";
			    else if (m->cookie)
			       c->data=id->cookie[m->cookie]||"";
			    else
			       c->data="";
			    if (m->rxml) c->data=Roxen.parse_rxml(c->data,id);
			 },
		"destination":lambda(string tag,mapping m,mapping c,object id)
			 {
			    if (m->variable) c->destvar=m->variable;
			    else if (m->cookie) c->destcookie=m->cookie;
			    else c->nodest=1;
			 },
	      ]),
	      (["e":lambda(string tag,mapping m,string cont,mapping c,
			   object id)
		    { if (m->rxml) c->e+=({Roxen.parse_rxml(cont,id)});
		       else c->e+=({cont}); },
		"raw":lambda(string tag,mapping m,string cont,mapping c)
		       { c->data=cont; },
		"rxml":lambda(string tag,mapping m,string cont,mapping c,
			      object id)
		       { c->data=Roxen.parse_rxml(cont,id); },
	      ]),c,id);

   if (!c->data) return "<!-- sed command missing data -->";

   d=c->data;

   if (m->split) d/=m->split;
   else if (m->lines) d/="\n";
   else if (m->chars) d/="";
   else d=({c->data});

   d=Tools.sed(c->e, d, !!(m->suppress||m["-n"]));

   if (m->split) d*=m->split;
   else if (m->lines) d*="\n";
   else if (m->chars) d*="";
   else d=d*"";

   if (c->destvar)
   {
      if (m->prepend) d += RXML_CONTEXT->user_get_var (c->destvar) || "";
      if (m->apppend || m->append)
	d = (RXML_CONTEXT->user_get_var (c->destvar) || "") + d;
      RXML_CONTEXT->user_set_var (c->destvar, d);
   }
   else if (c->destcookie)
   {
      if (m->prepend) d += id->cookie[c->destcookie] || "";
      if (m->apppend || m->append)
	d = (id->cookie[c->destcookie] || "") + d;
      id->cookie[c->destcookie]=d;
   }
   else if (!c->nodest)
      return d;

   return "";
}
