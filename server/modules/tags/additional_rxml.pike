// This is a roxen module. Copyright © 2000, Roxen IS.
//

#include <module.h>
inherit "module";

constant cvs_version = "$Id: additional_rxml.pike,v 1.5 2000/09/10 16:35:05 nilsson Exp $";
constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Additional RXML tags";
constant module_doc  = "This module provides some more complex and not as widely used RXML tags.";

void create() {
  defvar("insert_href",0,"Allow <insert href>",
	 TYPE_FLAG|VAR_MORE,
         "If set, it will be possible to use <tt>&lt;insert href&gt;</tt> to "
	 "insert pages from another web server. Note that the thread will be "
	 "blocked while it fetches the web page.");
}

class TagInsertHref {
  inherit RXML.Tag;
  constant name = "insert";
  constant plugin_name = "href";

  string get_data(string var, mapping args, RequestID id) {
    if(!query("insert_href")) RXML.run_error("Insert href is not allowed.");

    if(args->nocache)
      NOCACHE();
    else
      CACHE(60);
    Protocols.HTTP q=Protocols.HTTP.get_url(args->href);
    if(q && q->status>0 && q->status<400)
      return q->data();

    RXML.run_error(q ? q->status_desc + "\n": "No server response\n");
  }
}

string container_recursive_output (string tagname, mapping args,
                                  string contents, RequestID id)
{
  int limit;
  array(string) inside, outside;
  if (id->misc->recout_limit)
  {
    limit = id->misc->recout_limit - 1;
    inside = id->misc->recout_outside, outside = id->misc->recout_inside;
  }
  else
  {
    limit = (int) args->limit || 100;
    inside = args->inside ? args->inside / (args->separator || ",") : ({});
    outside = args->outside ? args->outside / (args->separator || ",") : ({});
    if (sizeof (inside) != sizeof (outside))
      RXML.parse_error("'inside' and 'outside' replacement sequences "
		       "aren't of same length.\n");
  }

  if (limit <= 0) return contents;

  int save_limit = id->misc->recout_limit;
  string save_inside = id->misc->recout_inside, save_outside = id->misc->recout_outside;

  id->misc->recout_limit = limit;
  id->misc->recout_inside = inside;
  id->misc->recout_outside = outside;

  string res = Roxen.parse_rxml (
    parse_html (
      contents,
      (["recurse": lambda (string t, mapping a, string c) {return c;}]),
      ([]),
      "<" + tagname + ">" + replace (contents, inside, outside) +
      "</" + tagname + ">"),
    id);

  id->misc->recout_limit = save_limit;
  id->misc->recout_inside = save_inside;
  id->misc->recout_outside = save_outside;

  return res;
}

class TagSprintf {
  inherit RXML.Tag;
  constant name = "sprintf";

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      array(string) in;
      // if(args->in) in=args->in;
      if(args->split)
	in=content/args->split;
      else
	in=({content});

      array f=((args->format-"%%")/"%")[1..];
      if(sizeof(in)!=sizeof(f))
	RXML.run_error("Indata hasn't the same size as format data (%d, %d).\n", sizeof(in), sizeof(f));

      // Do some casting
      for(int i; i<sizeof(in); i++) {
	int quit;
	foreach(f[i]/1, string char) {
	  if(quit) break;
	  switch(char) {
	  case "d":
	  case "u":
	  case "o":
	  case "x":
	  case "X":
	  case "c":
	  case "b":
	    in[i]=(int)in[i];
	    quit=1;
	    break;
	  case "f":
	  case "g":
	  case "e":
	  case "G":
	  case "E":
	  case "F":
	    in[i]=(float)in[i];
	    quit=1;
	    break;
	  case "s":
	  case "O":
	  case "n":
	  case "t":
	    quit=1;
	    break;
	  }
	}
      }

      result=sprintf(args->format, @in);
      return 0;
    }
  }
}

class TagSscanf {
  inherit RXML.Tag;
  constant name = "sscanf";

  class Frame {
    inherit RXML.Frame;

    string do_return(RequestID id) {
      array(string) vars=args->variables/",";
      array(string) vals=array_sscanf(content, args->format);
      if(sizeof(vars)<sizeof(vals))
	RXML.run_error("Too few variables.\n");

      int var=0;
      foreach(vals, string val)
	RXML.user_set_var(vars[var++], val, args->scope);

      if(args->return)
	RXML.user_set_var(args->return, sizeof(vals), args->scope);
      return 0;
    }
  }
}

class TagDice {
  inherit RXML.Tag;
  constant name = "dice";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    string do_return(RequestID id) {
      NOCACHE();
      if(!args->type) args->type="T6";
      args->type = replace( args->type, "D", "T" );
      int value;
      args->type=replace(args->type, "-", "+-");
      foreach(args->type/"+", string dice) {
	if(has_value(dice, "T")) {
	  if(dice[0]=='T')
	    value+=random((int)dice[1..])+1;
	  else {
	    array(int) x=(array(int))(dice/"T");
	    if(sizeof(x)!=2)
	      RXML.parse_error("Malformed dice type.\n");
	    value+=x[0]*(random(x[1])+1);
	  }
	}
	else
	  value+=(int)dice;
      }

      if(args->variable)
	RXML.user_set_var(args->variable, value, args->scope);
      else
	result=(string)value;

      return 0;
    }
  }
}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([

  "dice":#"<desc cont>Simulates a D&D style dice algorithm.</desc>

<attr name=type value=string default=T6>
 Describes the dices. A six sided dice is called 'D6' or '1D6', while
 two eight sided dices is called '2D8' or 'D8+D8'. Constants may also
 be used, so that a random number between 10 and 20 could be written
 as 'D9+10' (excluding 10 and 20, including 10 and 20 would be 'D11+9').
</attr>",

  "insert#href":#"<desc plugin>Inserts the contents at that URL. This function has to be enabled in
 the <module>RXML 2.0 tags</module> module in the Roxen WebServer
 configuration interface.</desc>

<attr name=href value=string>
 The URL to the page that should be inserted.
</attr>",

]);
#endif
