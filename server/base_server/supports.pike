// This file is part of Roxen WebServer.
// Copyright © 1999 - 2009, Roxen IS.
//
// Handles supports
// $Id$

#include <module_constants.h>
#include <module.h>
inherit "socket";

// The db for the nice '<if supports=..>' tag.
private mapping (string:array (array (object|multiset))) supports;
private multiset(string) default_supports;
private mapping (string:string) default_client_var;
private array(string) supports_ind;


//------------------ Code to decode the supports file ----------------------

private array(multiset(string)|mapping(string:string)) split_supports(array(string) from) {
  mapping(string:string) m=([]);
  multiset(string) pos=(<>),neg=(<>);
  string i,v;
  foreach(from, string s) {
    if(s[0]=='*') {
      if(sscanf(s,"*%s=%s", i, v)==2)
        m[i]=v;
      else
        report_debug("Error in supports database (%s)\n", s);
    }
    else
      if(s[0]=='-')
	neg[s[1..]]=1;
      else
	pos[s]=1;
  }
  return ({pos, neg, m});
}

private void parse_supports_string(string what, string current_section,
				   mapping(string:array(string)) defines)
{
  what-="\r";
  foreach(replace(what, "\\\n", " ")/"\n"-({""}), string line)
  {
    if(line[0] == '#')
    {
      string file;
      string name, to;
      if(sscanf(line, "#include <%s>", file))
      {
	if(catch(line=lopen(file,"r")->read()))
	  report_error("Supports: Cannot include file "+file+"\n");
	else
	  parse_supports_string(line, current_section, defines);
      }
      else if(sscanf(line, "#define %[^ \t]%*[ \t]%s", name, to)) {
	name -= "\t";
	defines[name] = replace(to, ({"\t",","}), ({" "," "}) )/" "-({""});
	array add=({});
	foreach(defines[name], string sup)
	  if(defines[sup]) {
	    defines[name]-=({sup});
	    add+=defines[sup];
	  }
	defines[name]+=add;
//	report_debug("#defining '"+name+"' to "+to+"\n");
      }
      else if(sscanf(line, "#section %[^ ] {", name)) {
//	report_debug("Entering section "+name+"\n");
	current_section = name;
	if(!supports[name])
	  supports[name] = ({});
      }
      else if((line-" ") == "#}") {
//	report_debug("Leaving section "+current_section+"\n");
	current_section = 0;
      }

    }
    else {
//    report_debug("Parsing supports line '"+line+"'\n");
      array(string) sups = replace(line, ({"\t",","}), ({" "," "}))/" " -({ "" });

      array add=({});
      foreach(sups, string sup)
	if(defines[sup]) {
	  sups-=({sup});
	  add+=defines[sup];
	}
      sups+=add;

      if(sizeof(sups) < 2)
	continue;

      if(sups[0] == "default") {
	array(multiset(string)|mapping(string:string)) tmp=split_supports(sups[1..]);
	default_supports = [multiset(string)]tmp[0] - [multiset(string)]tmp[1];
        default_client_var = [mapping(string:string)]tmp[2];
      }
      else {
	mixed err;
	if (err = catch {
	  supports[current_section]
	    += ({ ({ Regexp(sups[0])->match }) + split_supports(sups[1..]) });
	})
	  report_error("Failed to parse supports regexp:\n%s\n", describe_backtrace(err));
      }
    }
  }
  supports_ind=({0})+(indices(supports)-({0}));
}

public void initiate_supports()
{
  supports = ([ 0:({ }) ]);
  default_supports = (< >);
  default_client_var = ([ ]);
  parse_supports_string([string]roxenp()->query("Supports"), 0, ([]) );
}

private array(multiset(string)|mapping(string:string)) lookup_supports(string from)
{
  if(array(multiset(string)|mapping(string:string)) q = 
     [array(multiset(string)|mapping(string:string))] cache_lookup("supports", from))
    return q + ({ });

  multiset (string) sup = (<>);
  mapping (string:string) m = ([]);
  multiset (string) nsup = (< >);

  foreach(supports_ind, string v)
  {
    if(!v || (sizeof(v)<=sizeof(from) && from[..sizeof(v)-1]==v))
    {
      //  report_debug("Section "+v+" match "+from+"\n");
      foreach(supports[v], array(function|multiset) s)
        if(([function(string:void|mixed)]s[0])(from))
        {
          sup |= s[1];
          nsup |= s[2];
          m |= s[3];
        }
      if(v) break;
    }
  }
  if(!sizeof(sup))
  {
    sup = default_supports;
#ifdef DEBUG
    report_debug("Unknown client: \""+from+"\"\n");
#endif
  }
  sup -= nsup;
  array res = ({sup, m});
  sup = m = 0;	     // Discard refs for memory counting in cache_set.
  cache_set("supports", from, res);
  return res + ({});
}


//---------------------- Returns the supports flags ------------------------

// Return a list of 'supports' flags for the current connection.
multiset(string) find_supports(string from, void|multiset(string) existing_sup)
{
  if(!multisetp(existing_sup)) existing_sup=(<>);
  if(!strlen(from) || from == "unknown")
    return default_supports|existing_sup;

  return ([multiset(string)]lookup_supports(from)[0])|existing_sup;
}

// Return a list of 'supports' variables for the current connection.
mapping(string:string) find_client_var(string from, void|mapping(string:string) existing_cv)
{
  if(!mappingp(existing_cv)) existing_cv=([]);
  if(!strlen(from) || from == "unknown")
    return default_client_var|existing_cv;

  return ([mapping(string:string)]lookup_supports(from)[1])|existing_cv;
}

array(multiset(string)|
      mapping(string:string)) find_supports_and_vars(string from,
						     void|multiset(string) existing_sup,
						     void|mapping(string:string) existing_cv)
{
  if(!multisetp(existing_sup)) existing_sup=(<>);
  if(!mappingp(existing_cv)) existing_cv=([]);
  if(!strlen(from) || from == "unknown")
    return ({ default_supports|existing_sup, default_client_var|existing_cv });

  array(multiset(string)|mapping(string:string)) ret = lookup_supports(from);
  ret[0]|=existing_sup;
  ret[1]|=existing_cv;
  return ret;
}
