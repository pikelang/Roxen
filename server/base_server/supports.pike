// Handles supports
// Copyright © 1999 - 2000, Roxen IS.
// $Id: supports.pike,v 1.15 2000/03/07 02:38:35 nilsson Exp $

#pragma strict_types

#include <module_constants.h>
#include <module.h>
inherit "socket";

#define LOCALE	([object(RoxenLocale.standard)]roxenp()->LOW_LOCALE)->base_server
// The db for the nice '<if supports=..>' tag.
private mapping (string:array (array (object|multiset))) supports;
private multiset(string) default_supports;
private mapping (string:string) default_client_var;


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
	neg[s]=1;
      else
	pos[s]=1;
  }
  return ({pos, neg, m});
}

private void parse_supports_string(string what, string current_section,
				   mapping(string:array(string)) defines)
{
  foreach(replace(what, "\\\n", " ")/"\n"-({""}), string line)
  {
    if(line[0] == '#')
    {
      string file;
      string name, to;
      if(sscanf(line, "#include <%s>", file))
      {
	if(line=Stdio.read_bytes(file))
	  parse_supports_string(line, current_section, defines);
	else
	  report_error(LOCALE->supports_bad_include(file));
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
//	werror("#defining '"+name+"' to "+to+"\n");
      }
      else if(sscanf(line, "#section %[^ ] {", name)) {
//	werror("Entering section "+name+"\n");
	current_section = name;
	if(!supports[name])
	  supports[name] = ({});
      }
      else if((line-" ") == "#}") {
//	werror("Leaving section "+current_section+"\n");
	current_section = 0;
      }

    }
    else {
//    werror("Parsing supports line '"+line+"'\n");
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
	  report_error(LOCALE->supports_bad_regexp(describe_backtrace(err)));
      }
    }
  }
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
    return q;

  multiset (string) sup = (<>);
  mapping (string:string) m = ([]);
  multiset (string) nsup = (< >);

  foreach(indices(supports), string v)
  {
    if(!v || !search(from, v))
    {
      //  werror("Section "+v+" match "+from+"\n");
      foreach(supports[v], array(function|multiset) s)
        if(([function(string:void|mixed)]s[0])(from))
        {
          sup |= s[1];
          nsup |= s[2];
          m |= s[3];
        }
    }
  }
  if(!sizeof(sup))
  {
    sup = default_supports;
#ifdef DEBUG
    werror("Unknown client: \""+from+"\"\n");
#endif
  }
  sup -= nsup;
  cache_set("supports", from, ({sup,m}));
  return ({ sup, m });
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


//------------------- Code that updates the supports database --------------

array _new_supports = ({});

void done_with_roxen_com()
{
  string new, old;
  new = _new_supports * "";
  new = (new/"\r\n\r\n")[1..]*"\r\n\r\n";
  old = Stdio.read_bytes( "etc/supports" );

  if(strlen(new) < strlen(old)-200) // Error in transfer?
    return;

  if(old != new) {
    report_debug("Got new supports data from www.roxen.com\n"
		 "Replacing old file with new data.\n");
    mv("etc/supports", "etc/supports~");
    Stdio.write_file("etc/supports", new, 0660);
    old = Stdio.read_bytes( "etc/supports" );

    if(old != new)
    {
      report_debug("FAILED to update the supports file.\n");
      mv("etc/supports~", "etc/supports");
    } else {
      initiate_supports();
    }
  }
#ifdef DEBUG
  else
    werror("No change to the supports file.\n");
#endif
}

void got_data_from_roxen_com(object this, string foo)
{
  if(!foo)
    return;
  _new_supports += ({ foo });
}

void connected_to_roxen_com(object(Stdio.File) port)
{
  if(!port)
  {
#ifdef DEBUG
    werror("Failed to connect to www.roxen.com:80.\n");
#endif
    return 0;
  }
#ifdef DEBUG
  werror("Connected to www.roxen.com.:80\n");
#endif
  _new_supports = ({});
  port->set_id(port);
  string v = roxenp()->version();
  if (v != roxenp()->real_version) {
    v = v + " (" + roxenp()->real_version + ")";
  }
  port->write("GET /supports HTTP/1.0\r\n"
	      "User-Agent: " + v + "\r\n"
	      "Host: www.roxen.com:80\r\n"
	      "Pragma: no-cache\r\n"
	      "\r\n");
  port->set_nonblocking(got_data_from_roxen_com,
			got_data_from_roxen_com,
			done_with_roxen_com);
}

public void update_supports_from_roxen_com()
{
  // FIXME:
  // This code has a race-condition, but it only occurs once a week...
  if([int]roxenp()->query("next_supports_update") <= time())
  {
    if([int(0..1)]roxenp()->query("AutoUpdate"))
    {
      async_connect("www.roxen.com.", 80, connected_to_roxen_com);
#ifdef DEBUG
      werror("Connecting to www.roxen.com.:80\n");
#endif
    }
    remove_call_out( update_supports_from_roxen_com );

  // Check again in one week.
    ([array(string|int)]roxenp()->variables["next_supports_update"])[VAR_VALUE]=3600*24*7 + time(1);
    roxenp()->store("Variables", roxenp()->variables, 0, 0);
  }
  call_out(update_supports_from_roxen_com,
	   [int]roxenp()->query("next_supports_update")-time(1));
}
