#include <module.h>
inherit "socket";

#define LOCALE	roxenp()->LOW_LOCALE->base_server
// The db for the nice '<if supports=..>' tag.
mapping (string:array (array (object|multiset))) supports;
private multiset default_supports = (< >);

private static inline array positive_supports(array from)
{
  array res = copy_value(from);
  int i;
  for(i=0; i<sizeof(res); i++)
    if(res[i][0] == '-')
      res[i] = 0;
  return res - ({ 0 });
}

private inline array negative_supports(array from)
{
  array res = copy_value(from);
  int i;
  for(i=0; i<sizeof(res); i++)
    if(res[i][0] != '-')
      res[i] = 0;
    else
      res[i] = res[i][1..];
  return res - ({ 0 });
}

private static mapping foo_defines = ([ ]);
// '#define' in the 'supports' file.
static private string current_section; // Used below.
// '#section' in the 'supports' file.

private void parse_supports_string(string what)
{
  string foo;
  
  array lines;
  int i;
  lines=replace(what, "\\\n", " ")/"\n"-({""});

  foreach(lines, foo)
  {
    array bar, gazonk;
    if(foo[0] == '#')
    {
      string file;
      string name, to;
      if(sscanf(foo, "#include <%s>", file))
      {
	if(foo=Stdio.read_bytes(file))
	  parse_supports_string(foo);
	else
	  report_error(LOCALE->supports_bad_include(file));
      } else if(sscanf(foo, "#define %[^ ] %s", name, to)) {
	name -= "\t";
	foo_defines[name] = to;
//	perror("#defining '"+name+"' to "+to+"\n");
      } else if(sscanf(foo, "#section %[^ ] {", name)) {
//	perror("Entering section "+name+"\n");
	current_section = name;
	if(!supports[name])
	  supports[name] = ({});
      } else if((foo-" ") == "#}") {
//	perror("Leaving section "+current_section+"\n");
	current_section = 0;
      } else {
//	perror("Comment: "+foo+"\n");
      }
      
    } else {
      int rec = 10;
      string q=replace(foo,",", " ");
      foo="";
      
      // Handle all defines.
      while((strlen(foo)!=strlen(q)) && --rec)
      {
	foo=q;
	q = replace(q, indices(foo_defines), values(foo_defines));
      }
      
      foo=q;
      
      if(!rec)
	perror("Too deep recursion while replacing defines.\n");
      
//    perror("Parsing supports line '"+foo+"'\n");
      bar = replace(foo, ({"\t",","}), ({" "," "}))/" " -({ "" });
      foo="";
      
      if(sizeof(bar) < 2)
	continue;
    
      if(bar[0] == "default")
	default_supports = aggregate_multiset(@bar[1..]);
      else
      {
	gazonk = bar[1..];
	mixed err;
	if (err = catch {
	  supports[current_section]
	    += ({ ({ Regexp(bar[0])->match,
		     aggregate_multiset(@positive_supports(gazonk)),
		     aggregate_multiset(@negative_supports(gazonk)),
	    })});
	}) {
	  report_error(LOCALE->supports_bad_regexp(describe_backtrace(err)));
	}
      }
    }
  }
}

public void initiate_supports()
{
  supports = ([ 0:({ }) ]);
  foo_defines = ([ ]);
  current_section = 0;
  parse_supports_string(roxenp()->QUERY(Supports));
  foo_defines = 0;
}

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
    perror("Got new supports data from www.roxen.com\n");
    perror("Replacing old file with new data.\n");
    mv("etc/supports", "etc/supports~");
    Stdio.write_file("etc/supports", new, 0660);
    old = Stdio.read_bytes( "etc/supports" );

    if(old != new)
    {
      perror("FAILED to update the supports file.\n");
      mv("etc/supports~", "etc/supports");
    } else {
      initiate_supports();
    }
  }
#ifdef DEBUG
  else
    perror("No change to the supports file.\n");
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
    perror("Failed to connect to www.roxen.com:80.\n");
#endif
    return 0;
  }
#ifdef DEBUG
  perror("Connected to www.roxen.com.:80\n");
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
      perror("Connecting to www.roxen.com.:80\n");
#endif
    }
    remove_call_out( update_supports_from_roxen_com );

  // Check again in one week.
    roxenp()->QUERY(next_supports_update)=3600*24*7 + time();
    roxenp()->store("Variables", roxenp()->variables, 0, 0);
  }
  call_out(update_supports_from_roxen_com, roxenp()->QUERY(next_supports_update)-time());
}

// Return a list of 'supports' values for the current connection.

public multiset find_supports(string from, void|multiset existing_sup)
{
  multiset (string) sup =  (< >);
  multiset (string) nsup = (< >);

  array (function|multiset) s;
  string v;
  array f;

  if(!existing_sup) existing_sup = (<>);
  
  if(!strlen(from) || from == "unknown")
    return default_supports|existing_sup;
  if(!(sup = cache_lookup("supports", from))) {
    sup = (<>);
    foreach(indices(supports), v)
    {
      if(!v || !search(from, v))
      {
	//  perror("Section "+v+" match "+from+"\n");
	f = supports[v];
	foreach(f, s)
	  if(s[0](from))
	  {
	    sup |= s[1];
	    nsup  |= s[2];
	  }
      }
    }
    if(!sizeof(sup))
    {
      sup = default_supports;
#ifdef DEBUG
      perror("Unknown client: \""+from+"\"\n");
#endif
    }
    sup -= nsup;
    cache_set("supports", from, sup);
  }
  return sup|existing_sup;
}
