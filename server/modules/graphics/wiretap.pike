// This is a roxen module. Copyright © 2000, Idonex AB.
//

constant cvs_version="$Id: wiretap.pike,v 1.8 2000/02/10 10:17:39 nilsson Exp $";

#include <module.h>
inherit "module";
inherit "roxenlib";


//---------------------- Module Registration --------------------------------

constant module_type   = MODULE_PARSER;
constant module_name   = "HTML Color Wiretap";
constant module_doc    = "Parses HTML tags and tries to determine the text and"
  " background colors all over the page. This information can be used to let image"
  " modules generate images that automatically blend into the page.";
constant thread_safe   = 1;

void create()
{
  defvar("colorparsing", ({"body", "td", "layer", "ilayer", "table"}),
	 "Tags to parse for color",
	 TYPE_STRING_LIST|VAR_INITIAL,
	 "Which tags should be parsed for document colors? "
	 "This will affect documents without gtext as well as documents "
	 "with it, the parsing time is relative to the number of parsed "
	 "tags in a document. You have to reload this module or restart "
	 "roxen for changes of this variable to take effect.");

  defvar("colormode", 1, "Normalize colors in parsed tags",
         TYPE_FLAG|VAR_INITIAL,
	 "If set, replace 'roxen' colors (@c,m,y,k etc) with "
	 "'netscape' colors (#rrggbb). Setting this to off will lessen the "
	 "performance impact of the 'Tags to parse for color' option quite"
	 " dramatically. You can try this out with the &lt;gauge&gt; tag." );
}


// -------------------- The actual wiretap code  --------------------------

inline string ns_color(array (int) col)
{
  if(!arrayp(col)||sizeof(col)!=3)
    return "#000000";
  return sprintf("#%02x%02x%02x", col[0],col[1],col[2]);
}

int|array tag_body(string t, mapping args, RequestID id)
{
  int changed=0;
  int cols=(args->bgcolor||args->text||args->link||args->alink||args->vlink);

#define FIX(Y,Z,X) do{ \
  if(!args->Y || args->Y==""){ \
    id->misc->defines[X]=Z; \
    if(cols){ \
      args->Y=Z; \
      changed=1; \
    } \
  } \
  else{ \
    id->misc->defines[X]=args->Y; \
    if(QUERY(colormode)&&args->Y[0]!='#'){ \
      args->Y=ns_color(parse_color(args->Y)); \
      changed=1; \
    } \
  } \
}while(0)

  //FIXME: These values are not up to date

  FIX(text,   "#000000","fgcolor");
  FIX(link,   "#0000ee","link");
  FIX(alink,  "#ff0000","alink");
  FIX(vlink,  "#551a8b","vlink");

  if(search(id->client_var->fullname||"","windows")!=-1)
  {
    FIX(bgcolor,"#c0c0c0","bgcolor");
  } else {
    FIX(bgcolor,"#ffffff","bgcolor");
  }

  if(changed && QUERY(colormode))
    return ({1, "body", args });
  return ({1});
}

string|array push_color(string tagname, mapping args, RequestID id)
{
  int changed;
  if(!id->misc->wiretap_stack)
    id->misc->wiretap_stack = ({ ({ tagname, id->misc->defines->fgcolor, id->misc->defines->bgcolor }) });
  else
    id->misc->wiretap_stack += ({ ({ tagname, id->misc->defines->fgcolor, id->misc->defines->bgcolor }) });

#undef FIX
#define FIX(X,Y) if(args->X && args->X!=""){ \
  id->misc->defines->Y=args->X; \
  if(QUERY(colormode) && args->X[0]!='#'){ \
    args->X=ns_color(parse_color(args->X)); \
    changed = 1; \
  } \
}

  FIX(bgcolor,bgcolor);
  FIX(color,fgcolor);
  FIX(text,fgcolor);
#undef FIX

  if(changed && QUERY(colormode))
    return ({1, tagname, args });
  return ({1});
}

string|array pop_color(string tagname, mapping args, RequestID id)
{
  array c = id->misc->wiretap_stack;
  if(c && sizeof(c)) {
    int i;
    tagname = tagname[1..];

    for(i=0; i<sizeof(c); i++)
      if(c[-i-1][0]==tagname)
      {
	id->misc->defines->fgcolor = c[-i-1][1];
	id->misc->defines->bgcolor = c[-i-1][2];
	break;
      }

    id->misc->wiretap_stack = c[..sizeof(c)-i-2];
  }
  return ({1});
}


// --------------- tag and container registration ----------------------

mapping query_tag_callers()
{
  mapping tags=([]);
  foreach(query("colorparsing"), string t)
  {
    switch(t)
    {
    case "body":
      tags[t] = tag_body;
      break;
    default:
      tags[t] = push_color;
      tags["/"+t]=pop_color;
    }
  }
  return tags;
}
