// Handles supports
// Copyright (c) 1999-2000 Idonex AB
//

#include <module.h>
inherit "socket";

#define LOCALE	roxenp()->LOW_LOCALE->base_server
// The db for the nice '<if supports=..>' tag.
private mapping (string:array (array (object|multiset))) supports;
private multiset default_supports;
private mapping default_client_var;


//------------------ Code to decode the supports file ----------------------

private array split_supports(array from) {
  mapping m=([]);
  multiset pos=(<>),neg=(<>);
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

private void parse_supports_string(string what, string current_section, mapping defines)
{
  foreach(replace(what, "\\\n", " ")/"\n"-({""}), string line)
  {
    array bar, gazonk;
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
      else if(sscanf(line, "#define %[^ ] %s", name, to)) {
	name -= "\t";
	defines[name] = to;
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
      int rec = 10;
      string q=replace(line,",", " ");
      line="";

      // Handle all defines.
      while((strlen(line)!=strlen(q)) && --rec)
      {
	line=q;
	q = replace(q, indices(defines), values(defines));
      }

      line=q;

      if(!rec)
	report_debug("Too deep recursion while replacing defines.\n");

//    werror("Parsing supports line '"+line+"'\n");
      bar = replace(line, ({"\t",","}), ({" "," "}))/" " -({ "" });
      line="";

      if(sizeof(bar) < 2)
	continue;

      if(bar[0] == "default") {
	array tmp=split_supports(bar[1..]);
	default_supports = tmp[0]-tmp[1];
        default_client_var = tmp[2];
      }
      else {
	mixed err;
	if (err = catch {
	  supports[current_section]
	    += ({ ({ Regexp(bar[0])->match }) + split_supports(bar[1..]) });
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
  parse_supports_string(roxenp()->QUERY(Supports), 0, ([]) );
}


//---------------------- Returns the supports flags ------------------------


// Return a list of 'supports' values for the current connection.

private array(multiset|mapping) lookup_supports(string from)
{
  array ret;

  if(!(ret = cache_lookup("supports", from)) ) {
    multiset (string) sup=(<>);
    mapping (string:string) m=([]);
    multiset (string) nsup = (< >);
    foreach(indices(supports), string v)
    {
      if(!v || !search(from, v))
      {
	//  werror("Section "+v+" match "+from+"\n");
	foreach(supports[v], array(function|multiset) s)
	  if(s[0](from))
	  {
	    sup |= s[1];
	    nsup |= s[2];
            m += s[3];
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
    ret=({ sup, m});
    cache_set("supports", from, ret);
  }

  return ret;
}

multiset(string) find_supports(string from, void|multiset existing_sup)
{
  if(!strlen(from) || from == "unknown")
    return default_supports|existing_sup;

  return lookup_supports(from)[0]|existing_sup;
}

mapping(string:string) find_client_var(string from, void|mapping existing_cv)
{
  if(!strlen(from) || from == "unknown")
    return default_client_var+existing_cv;

  return lookup_supports(from)[1]+existing_cv;
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

void connected_to_roxen_com(object port)
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
  if(roxenp()->QUERY(next_supports_update) <= time())
  {
    if(roxenp()->QUERY(AutoUpdate))
    {
      async_connect("www.roxen.com.", 80, connected_to_roxen_com);
#ifdef DEBUG
      werror("Connecting to www.roxen.com.:80\n");
#endif
    }
    remove_call_out( update_supports_from_roxen_com );

  // Check again in one week.
    roxenp()->QUERY(next_supports_update)=3600*24*7 + time();
    roxenp()->store("Variables", roxenp()->variables, 0, 0);
  }
  call_out(update_supports_from_roxen_com, roxenp()->QUERY(next_supports_update)-time());
}
