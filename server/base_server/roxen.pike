string cvs_version = "$Id: roxen.pike,v 1.31.2.7 1997/03/13 01:19:37 kg Exp $";

#define IN_ROXEN
#include <module.h>
#include <variables.h>
#include <roxen.h>

#ifdef NO_DNS
inherit "dummy_hosts";
#else
inherit "hosts";
#endif

inherit "socket";
inherit "disk_cache";
inherit "language";

import Stdio;
import Array;
import String;

int num_connections;

object roxen=this_object();

object main_configuration_port;
mapping allmodules;

#if efun(send_fd)
int shuffle_fd;
#endif

// This is the real Roxen version. It should be changed before each
// release
string real_version = "Roxen Challenger/1.1.1alpha1"; 

// A mapping from ports (objects, that is) to an array of information
// about that port.
// This will be moved to objects cloned from the configuration object
// in the future.
mapping portno=([]);

// The code below was formely in decode.pike, but that object is 
// cloned for each request.    Not exactly good for the performance..
// It is a base64 decoder for the Authentification header (the Basic method)
#define DEC(c) pr2six[(int)c]
#define MAXVAL 63

int *six2pr=({
  'A','B','C','D','E','F','G','H','I','J','K','L','M',
  'N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
  'a','b','c','d','e','f','g','h','i','j','k','l','m',
  'n','o','p','q','r','s','t','u','v','w','x','y','z',
  '0','1','2','3','4','5','6','7','8','9','+','*', 
  });

int *pr2six = lambda() {
    int j;
    int *p=allocate(256);
    for(j=0; j<256; j++) p[ j ] = MAXVAL+ 1;
    for(j=0; j<64; j++) p[ six2pr[ j ] ] = j;
    return p;
}();

public string decode(string bufcoded)
{
  string bufplain; 
  int nbytesdecoded;
  int in=0;
  int out=0;
  int nprbytes;

  bufplain="";

  // Strip leading whitespace. 
  if(!strlen(bufcoded))
    return "";
  while(bufcoded[in]==' ' || bufcoded[in] == '\t') in++;

  // Figure out how many characters are in the input buffer. 
  out=in;
  while((pr2six[bufcoded[in++]] <= MAXVAL) && (strlen(bufcoded)>in));
  nprbytes = in - out - 1;
  in=out;
  out=0;
  while (nprbytes > 0) {
    bufplain+=sprintf("%c", (DEC(bufcoded[in])<<2   | DEC(bufcoded[in+1])>>4));
    bufplain+=sprintf("%c", (DEC(bufcoded[in+1])<<4 | DEC(bufcoded[in+2])>>2));
    bufplain+=sprintf("%c", (DEC(bufcoded[in+2])<<6 | DEC(bufcoded[in+3])));
    in += 4;
    nbytesdecoded += 3;
    nprbytes -= 4;
   }

  if(pr2six[bufcoded[in-2]] == 64)
    nbytesdecoded --;

  if(pr2six[bufcoded[in-1]] == 64)
    nbytesdecoded --;
  nbytesdecoded --;

#if 0
  perror(sprintf("%d %d %d -> %s(%d)\n", pr2six[bufcoded[in-3]],
		 pr2six[bufcoded[in-2]], pr2six[bufcoded[in-1]],
		 bufplain[0..nbytesdecoded], nbytesdecoded+1));
#endif

  return bufplain[0..nbytesdecoded];
}
// End of what was formely known as decode.pike, the base64 decoder

// Function pointer and the root of the to the configuration interface
// object.
private function build_root;
private object root;

// Sub process ids. 
private static array subs; 


// Fork, and then do a 'slow-quit' in the forked copy. Exit the
// original copy, after all listen ports are closed.
// Then the forked copy finish all current connections.
private static void fork_or_quit()
{
  int i;
  object *f;
  if(main_configuration_port && objectp(main_configuration_port))
  {
    int pid;
    if(search(subs, getpid()) == -1)
    {
      perror("Exiting Roxen.\n");
      foreach(subs, pid)
      {
	if(pid != getpid())
	  kill(pid, signum("SIGUSR1"));
      }
    }
  }
#ifdef SOCKET_DEBUG
  perror("SOCKETS: fork_or_quit()\n                 Bye!\n");
#endif
  if(fork()) 
    exit(0);
#if efun(_pipe_debug)
  call_out(lambda() {  // Wait for all connections to finish
    call_out(Simulate.this_function(), 20);
    if(!_pipe_debug()[0]) exit(0);
  }, 1);
#endif
  call_out(lambda(){ exit(0); }, 600); // Slow buggers..
  f=indices(portno);
  for(i=0; i<sizeof(f); i++)
    catch(destruct(f[i]));
}

// Keep a count of how many times in a row there has been an error
// while 'accept'ing.
private int failed_connections = 0;

// This is called for each incoming connection.
private static void accept_callback( object port )
{
  int q=QUERY(NumAccept), l;
  object file;
  
  // Silently enforced. We do _not_ want this if the number of 
  // concurrently running processes is more than, or equal to, 2.

  if(QUERY(copies) > 1) {l=1;q=1;}
  
  if(!portno[port])
  {
    destruct(port->accept());
    perror("$&$$& Garbage Collector bug!!\n");
    return;
  }
  while(q--)
  {
    // Lock due to bugs in OS-es (Solaris 2.*, IRIX 5.*, perhaps others)... 
    // This is only needed if there are any copies that might try 
    // to aquire the lock at the same time as this Roxen.

    if(l) catch { portno[port][-2]->aquire(); };
    catch { file = port->accept(); };
    if(l) catch { portno[port][-2]->free(); };

    if(!portno[port][-1])
    {
      report_error("In accept: Illegal protocol handler for port.\n");
      if(file) destruct(file);
      return;
    }

#ifdef SOCKET_DEBUG
    perror(sprintf("SOCKETS: accept_callback(CONF(%s))\n", 
		   portno[port][1]&&portno[port][1]->name||"Configuration"));
#endif
    if(!file)
    {
      switch(port->errno())
      {
       case 0:
       case 11:
	return;

       default:
#ifdef DEBUG
	perror("Accept failed.\n");
# if efun(real_perror)
	real_perror();
# endif
#endif
 	return;

       case 24:
	if(failed_connections++)
	{
	  report_fatal("Out of sockets. Restarting server gracefully.\n");
	  fork_or_quit();
	}
	return;
      }
    }
    if(failed_connections>0) failed_connections--;

    mark_fd( file->query_fd(), "Connection from "+file->query_address());

    object request;
    request = portno[port][-1]();
    request->assign( file, portno[port][1] );
#ifdef SOCKET_DEBUG
    perror(sprintf("SOCKETS:   Ok. Connect on %O:%O from %O\n", 
		   portno[port][2], portno[port][0], file->query_address()));
#endif
  }
}

// Listen to a port, connected to the configuration 'conf', binding
// only to the netinterface 'ether', using 'requestprogram' as a
// protocol handled.

// If you think that the argument order is quite unintuitive and odd,
// you are right, the order is the same as the implementation order.

// Old spinners only listened to a port number, then the
// configurations came, then the need to bind to a specific
// ethernetinterface, and then the need to have more than one concurrent
// protocol (http, ftp, ssl, etc.)
private static
object create_listen_socket(mixed port_no, object conf,
			    string|void ether, program requestprogram)
{
  object port;
#ifdef SOCKET_DEBUG
  perror(sprintf("SOCKETS: create_listen_socket(%d,CONF(%s),%s)\n",
		 port_no, conf?conf->name:"Configuration port", ether));
#endif
  if(!requestprogram)
    error("No request handling module passed to create_listen_socket()\n");

  if(!port_no)
  {
    port = files.port ( "stdin", accept_callback );

    if(port->errno())
    {
      report_error("Cannot listen to stdin.\n"
		   "Errno is "+port->errno()+"\n");
    }
  } else {
    port = files.port ();
    if(!stringp(ether) || (lower_case(ether) == "any"))
      ether=0;
    if(ether)
      sscanf(ether, "addr:%s", ether);
#if 0
    werror(sprintf("%O(%t), %O(%t), %O(%t)\n",
		   port_no, port_no, accept_callback, accept_callback,
		   ether, ether));
#endif
    
    if(!port->bind(port_no, accept_callback, ether))
    {
      if(ether==0 || !port->bind(port_no, accept_callback))
      {
#ifdef SOCKET_DEBUG
	perror("SOCKETS:    -> Failed.\n");
#endif
	report_error("Failed to open socket on "+port_no+":"+ether
		     +" (already bound?)\nErrno is: "+ port->errno()+"\n");
	return 0;
      } else if(ether) {
	report_error("Failed to bind to specific IP address " + ether +
		     "(using ANY instead).\n");
	ether=0;
      }
    }
  }
  if(conf && QUERY(uselock) && (QUERY(copies) > 1))
    portno[port]=({ port_no, conf, ether||"Any", 
		    ((program)"lock")( port_no + (ether?hash(ether):0)),
		    requestprogram });
  else
    portno[port]=({ port_no, conf, ether||"Any", 0, requestprogram });
#ifdef SOCKET_DEBUG
  perror("SOCKETS:    -> Ok.\n");
#endif
  return port;
}


// The configuration interface is loaded dynamically for faster
// startup-time, and easier coding in the configuration interface (the
// Roxen environment is already finished when it is loaded)
object configuration_interface_obj;
int loading_config_interface;
int enabling_configurations;

object configuration_interface()
{
  if(enabling_configurations)
    return 0;
  if(loading_config_interface)
  {
    perror("Recursive calls to configuration_interface()\n"
	   + describe_backtrace(backtrace())+"\n");
  }
  
  if(!configuration_interface_obj)
  {
    perror("Loading configuration interface.\n");
    loading_config_interface = 1;
    

    configuration_interface_obj= ( (program) "mainconfig" )();
    root = configuration_interface_obj->root;
  }
  if(!configuration_interface_obj)
    perror("Failed to load the configuration interface!\n");
  loading_config_interface = 0;
  return configuration_interface_obj;
}


// Create a new configuration from scratch.

// 'type' is as in the form. 'none' for a empty configuration.
int add_new_configuration(string name, string type)
{
  return configuration_interface()->low_enable_configuration(name, type);
}

// Call the configuration interface function. This is more or less
// equivalent to a virtual configuration with the configurationinterface
// mounted on '/'. This will probably be the case in future versions
mixed configuration_parse(mixed ... args)
{
  if(args)
    return configuration_interface()->configuration_parse(@args);
}

// Write a string to the configuration interface error log and to stderr.
void nwrite(string s, int|void perr)
{
  if(!root)
    if(!configuration_interface())
    {
      perror("Cannot report error to configuration interface:\n"+s);
      return ;
    }
  if(root->descend("Errors", 1))
    root->descend("Errors")->data[s]++;
  if(perr) perror(s);
}
 


// When was Roxen started?
int start_time;

string version()
{
  return QUERY(ident);
}

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
	if(foo=read_bytes(file))
	  parse_supports_string(foo);
	else
	  report_error("Supports: Cannot include file "+file+"\n");
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
	supports[current_section]
	  += ({ ({ Regexp(bar[0])->match,
		     aggregate_multiset(@positive_supports(gazonk)),
		     aggregate_multiset(@negative_supports(gazonk)),
		     })});
      }
    }
  }
}

public void initiate_supports()
{
  supports = ([ 0:({ }) ]);
  foo_defines = ([ ]);
  current_section = 0;
  parse_supports_string(QUERY(Supports));
  foo_defines = 0;
}

array _new_supports = ({});

void done_with_roxen_com()
{
  string new, old;
  new = _new_supports * "";
  old = read_bytes( "etc/supports" );
  
  if(strlen(new) < strlen(old)-200) // Error in transfer?
    return;
  
  if(old != new) {
    perror("Got new supports data from roxen.com\n");
    perror("Replacing old file with new data.\n");
    mv("etc/supports", "etc/supports~");
    write_file("etc/supports", new);
    old = read_bytes( "etc/supports" );
    if(old != new)
    {
      perror("FAILED to update the supports file.\n");
      mv("etc/supports~", "etc/supports");
    } else
      initiate_supports();
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
    perror("Failed to connect to roxen.com:80.\n");
#endif
    return 0;
  }
#ifdef DEBUG
  perror("Connected to roxen.com.:80\n");
#endif
  _new_supports = ({});
  port->set_id(port);
  port->write("GET /supports\n");
  port->set_nonblocking(got_data_from_roxen_com,
			got_data_from_roxen_com,
			done_with_roxen_com);
}

public void update_supports_from_roxen_com()
{
  if(QUERY(AutoUpdate))
  {
    async_connect("roxen.com.", 80, connected_to_roxen_com);
#ifdef DEBUG
    perror("Connecting to roxen.com.:80\n");
#endif
  }
  remove_call_out( update_supports_from_roxen_com );

  object o;
  o = current_configuration;
  current_configuration = 0;

  // Check again in one week.
  QUERY(next_supports_update)=3600*24*7 + time();
  store("Variables", variables, 0);

  current_configuration = o;
  call_out(update_supports_from_roxen_com, 3600*24*7);
}

// Return a list of 'supports' values for the current connection.

public multiset find_supports(string from)
{
  multiset (string) sup = (< >);
  multiset (string) nsup = (< >);

  array (function|multiset) s;
  string v;
  array f;
  
  if(from != "unknown")
  {
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
      perror("Unknown client: "+from+"\n");
#endif
    }
  } else {
    sup = default_supports;
  }
  return sup - nsup;
}

// Parse the logging format strings.
private inline string fix_logging(string s)
{
  string pre, post, c;
  sscanf(s, "%*[\t ]%s", s);
  s = replace(s, ({"\\t", "\\n", "\\r" }), ({"\t", "\n", "\r" }));

  while(s[0] == ' ' || s[0] == '\t') {
    s = s[1..];
  }

  while(sscanf(s, "%s$char(%d)%s", pre, c, post)==3)
    s=sprintf("%s%c%s", pre, c, post);
  while(sscanf(s, "%s$wchar(%d)%s", pre, c, post)==3)
    s=sprintf("%s%2c%s", pre, c, post);
  while(sscanf(s, "%s$int(%d)%s", pre, c, post)==3)
    s=sprintf("%s%4c%s", pre, c, post);
  if(!sscanf(s, "%s$^%s", pre, post))
    s+="\n";
  else
    s=pre+post;
  return s;
}

private void parse_log_formats()
{
  string b;
  array foo=query("LogFormat")/"\n";
  foreach(foo, b)
    if(strlen(b) && b[0] != '#' && sizeof(b/":")>1)
      current_configuration->log_format[(b/":")[0]] 
	= fix_logging((b/":")[1..100000]*":");
}




// Really write an entry to the log.
private void write_to_log( string host, string rest, string oh, function fun )
{
  int s;
  if(!host) host=oh;
  if(!stringp(host))
    host = "error:no_host";
  if(fun) fun(replace(rest, "$host", host));
}

// Logging format support functions.
nomask private inline string host_ip_to_int(string s)
{
  int a, b, c, d;
  sscanf(s, "%d.%d.%d.%d", a, b, c, d);
  return sprintf("%c%c%c%c",a, b, c, d);
}

nomask private inline string unsigned_to_bin(int a)
{
  return sprintf("%4c", a);
}

nomask private inline string unsigned_short_to_bin(int a)
{
  return sprintf("%2c", a);
}

nomask private inline string extract_user(string from)
{
  array tmp;
  if (!from || sizeof(tmp = from/":")<2)
    return "-";
  
  return tmp[0];      // username only, no password
}

public void log(mapping file, object request_id)
{
  string a;
  string form;
  function f;

  if(!request_id->conf)
    return; 

  foreach(request_id->conf->logger_modules(), f) // Call all logging functions
    if(f(request_id,file))
      return;

  if(!request_id->conf->log_function) 
    return;// No file is open for logging.


  if(query("NoLog") && _match(request_id->remoteaddr, query("NoLog")))
    return;
  
  if(!(form=request_id->conf->log_format[(string)file->error]))
    form = request_id->conf->log_format["*"];
  
  if(!form) return;
  
  form=replace(form, 
	       ({ 
		 "$ip_number", "$bin-ip_number", "$cern_date",
		 "$bin-date", "$method", "$resource", "$protocol",
		 "$response", "$bin-response", "$length", "$bin-length",
		 "$referer", "$user_agent", "$user", "$user_id",
	       }), ({
		 (string)request_id->remoteaddr,
		   host_ip_to_int(request_id->remoteaddr),
		   cern_http_date(time(1)),
		   unsigned_to_bin(time(1)),
		   (string)request_id->method,
		   (string)request_id->not_query,
		   (string)request_id->prot,
		   (string)(file->error||200),
		   unsigned_short_to_bin(file->error||200),
		   (string)(file->len>=0?file->len:"?"),
		   unsigned_to_bin(file->len),
		   (string)
		   (sizeof(request_id->referer)?request_id->referer[0]:"-"),
		   http_encode_string(sizeof(request_id->client)?request_id->client*" ":"-"),
		   extract_user(request_id->realauth),
		   (string)request_id->cookies->RoxenUserID,
		 }));
  
  if(search(form, "host") != -1)
       ip_to_host(request_id->remoteaddr, write_to_log, form,
	       request_id->remoteaddr, request_id->conf->log_function);
  else
    request_id->conf->log_function(form);
}

// Support for unique user id's 
private object current_user_id_file;
private int current_user_id_number, current_user_id_file_last_mod;

private void restore_current_user_id_number()
{
  if(!current_user_id_file)
    current_user_id_file = open(configuration_dir + "LASTUSER~", "rwc");
  if(!current_user_id_file)
  {
    call_out(restore_current_user_id_number, 2);
    return;
  } 
  current_user_id_number = (int)current_user_id_file->read(100);
  current_user_id_file_last_mod = current_user_id_file->stat()[2];
  perror("Restoring unique user ID information. (" + current_user_id_number 
	 + ")\n");
  mark_fd(current_user_id_file->query_fd(), "Unique user ID logfile.\n");
}

int increase_id()
{
  if(!current_user_id_file)
  {
    restore_current_user_id_number();
    return current_user_id_number+time();
  }
  if(current_user_id_file->stat()[2] != current_user_id_file_last_mod)
    restore_current_user_id_number();
  current_user_id_number++;
  //perror("New unique id: "+current_user_id_number+"\n");
  current_user_id_file->seek(0);
  current_user_id_file->write((string)current_user_id_number);
  current_user_id_file_last_mod = current_user_id_file->stat()[2];
  return current_user_id_number;
}


// These are here for statistics and debug reasons only.
public string status()
{
  float tmp;
  string res="";

  if(!current_configuration)
    return ("No current_configuration. No configurations enabled?\n");

  if(!current_configuration->sent
     ||!current_configuration->received
     ||!current_configuration->hsent)
    return "Fatal error in status(): Bignum object gone.\n";

  tmp = (current_configuration->sent->mb()/(float)(time(1)-start_time+1)*
	 QUERY(copies));
  res = sprintf("<table><tr align=right><td><b>Sent data:</b></td><td>%.2fMB"
		"</td><td>%.2f Kbit/sec</td>",
		current_configuration->sent->mb()*(float)(QUERY(copies)),
		tmp * 8192.0);
  
  res += sprintf("<td><b>Sent headers:</b></td><td>%.2fMB</td>",
		 current_configuration->hsent->mb()*(float)QUERY(copies));
  
  tmp=(((float)current_configuration->requests*(float)600)/
       (float)((time(1)-start_time)+1)*QUERY(copies));

  res += ("<tr align=right><td><b>Number of requests:</b></td><td>" 
	  + sprintf("%8d", current_configuration->requests*QUERY(copies))
	  + sprintf("</td><td>%.2f/min</td><td><b>Recieved data:</b></"
		    "td><td>%.2f</td>", (float)tmp/(float)10,
		    (current_configuration->received->mb()
		     *(float)QUERY(copies))));
  
  return res +"</table>";
}

public string full_status()
{
  int tmp;
  string res="";
  array foo = ({0.0, 0.0, 0.0, 0.0, 0});
  if(!sizeof(configurations))
    return "<B>No virtual servers enabled</B>\n";
  
#define conf configurations[tmp]
  for(tmp = 0; tmp < sizeof(configurations); tmp++)
  {
    if(!conf->sent
       ||!conf->received
       ||!conf->hsent)
      continue;
    foo[0]+=conf->sent->mb()/(float)(time(1)-start_time+1)*(float)QUERY(copies);
    foo[1]+=conf->sent->mb()*(float)QUERY(copies);
    foo[2]+=conf->hsent->mb()*(float)QUERY(copies);
    foo[3]+=conf->received->mb()*(float)QUERY(copies);
    foo[4]+=conf->requests * QUERY(copies);
  }
#undef conf
  for(tmp = 1; tmp < 4; tmp ++)
  {
    if(foo[tmp] < 1024.0)     
      foo[tmp] = sprintf("%.2f MB", foo[tmp]);
    else
      foo[tmp] = sprintf("%.2f GB", foo[tmp]/1024.0);
  }

  res = ("<table><tr align=right><td><b>Sent data:</b></td><td>"+ foo[1] 
	 + sprintf("</td><td>%.2f Kbit</td>", foo[0] * 8192.0));
  
  res += "<td><b>Sent headers:</b></td><td>"+ foo[2] +"</td>\n";
	    
  tmp=(foo[4]*600)/((time(1)-start_time)+1);

  res += ("<tr align=right><td><b>Number of requests:</b></td><td>" 
	  + sprintf("%8d", foo[4])
	  + sprintf("</td><td>%.2f/min</td>", (float)tmp/(float)10)+
	  "<td><b>Recieved data:</b></td><td>"
	  + foo[3] +"</td>");
  
  return res +"</table>";
}


// These are now more or less outdated, the modules really _should_
// pass the information about the current configuration to roxen,
// to enable async operations. This information is in id->conf.
//
// In the future, most, if not all, of these functions will be moved
// to the configuration object. The functions will still be here for
// compatibility for a while, though.

public string *userinfo(string u, void|object id)
{
  if(id)
    current_configuration = id->conf;
  if(current_configuration->auth_module)
    return current_configuration->auth_module->userinfo(u);
  return 0;
}

public string *userlist(void|object id)
{
  if(id)
    current_configuration = id->conf;
  if(current_configuration->auth_module)
    return current_configuration->auth_module->userlist();
  return 0;
}

public string *user_from_uid(int u, void|object id)
{
  if(id)
    current_configuration = id->conf;
  if(current_configuration->auth_module)
    return current_configuration->auth_module->user_from_uid(u);
}

public string last_modified_by(object file, object id)
{
  int *s;
  int uid;
  mixed *u;
  
  if(objectp(file)) s=file->stat();
  if(!s || sizeof(s)<5) return "A. Nonymous";
  uid=s[5];
  u=user_from_uid(uid, id);
  if(u) return u[0];
  return "A. Nonymous";
}

// FIXME 
private object find_configuration_for(object bar)
{
  object maybe;
  if(!bar) return configurations[0];
  foreach(configurations, maybe)
    if(maybe->otomod[bar]) return maybe;
  return configurations[-1];
}

// FIXME  
public varargs array|string type_from_filename( string file, int to )
{
  mixed tmp;
  string ext=extension(file);
    
  if(!current_configuration)
    current_configuration = find_configuration_for(Simulate.previous_object());
  if(!current_configuration->types_fun)
    return to?({ "application/octet-stream", 0 }):"application/octet-stream";

  while(file[-1] == '/') 
    file = file[0..strlen(file)-2]; // Security patch? 
  
  if(tmp = current_configuration->types_fun(ext))
  {
    mixed tmp2,nx;
    if(tmp[0] == "strip")
    {
      tmp2=file/".";
      if(sizeof(tmp2) > 2)
	nx=tmp2[-2];
      if(nx && (tmp2=current_configuration->types_fun(nx)))
	tmp[0] = tmp2[0];
      else
	if(tmp2=current_configuration->types_fun("default"))
	  tmp[0] = tmp2[0];
	else
	  tmp[0]="application/octet-stream";
    }
    return to?tmp:tmp[0];
  } else {
    if(!(tmp=current_configuration->types_fun("default")))
      tmp=({ "application/octet-stream", 0 });
    // FIXME -- tmp above isn't used /grubba
  }
  return 0;
}
  
private static int nest = 0;
  
#ifdef MODULE_LEVEL_SECURITY
private mapping misc_cache=([]);

int|mapping check_security(function a, object id, void|int slevel)
{
  array level;
  int need_auth;
  array seclevels;
  
  if(!(seclevels = misc_cache[ a ]))
    misc_cache[ a ] = seclevels = ({
      function_object(a)->query_seclevels(),
      function_object(a)->query("_seclvl")
    });

  if(slevel && (seclevels[1] > slevel)) // "Trustlevel" to low.
    return 1;
  

  if(!sizeof(seclevels[0]))
    return 0; // Ok if there are no patterns.

  catch
  {
    foreach(seclevels[0], level)
      switch(level[0])
      {
       case MOD_ALLOW: // allow ip=...
	if(level[1](id->remoteaddr)) return 0; // Match. It's ok.
	return http_low_answer(403, "<h2>Access forbidden</h2>");
	continue;
	
       case MOD_DENY: // deny ip=...
	if(level[1](id->remoteaddr)) throw("");
	return http_low_answer(403, "<h2>Access forbidden</h2>");
	continue;

       case MOD_USER: // allow user=...
//	 perror("Allow user: "+id->auth[0]+" && "+id->auth[1]+"\n");
	 if(id->auth && id->auth[0] && level[1](id->auth[1])) return 0;
	 need_auth = 1;
	 continue;
	
       case MOD_PROXY_USER: // allow user=...
	if(id->misc->proxyauth && id->misc->proxyauth[0] && 
	   level[1](id->misc->proxyauth[1])) return 0;
	return http_proxy_auth_required("user");
      }
  };
  // If auth is needed (access might be allowed if you are the right user),
  // request authentification from the user. Otherwise this is a lost case,
  // the user will never be allowed access unless the patterns change.
  return need_auth ? http_auth_failed("user") : 1; 
}

// Some clients does _not_ handle the magic 'internal-gopher-...'.
// So, lets do it here instead.
private mapping internal_gopher_image(string from)
{
  sscanf(from, "%s.gif", from);
  sscanf(from, "%s.jpg", from);
  from -= ".";
  // Disallow "internal-gopher-..", it won't really do much harm, but a list of
  // all files in '..' might be retrieved (that is, the actual directory
  // file was sent to the browser)
  return (["file":open("roxen-images/dir/"+from+".gif","r"),
	  "type":"image/gif"]);
}

// Inspired by the internal-gopher-... thingie, this is the images
// from the configuration interface. :-)
private mapping internal_roxen_image(string from)
{
  sscanf(from, "%s.gif", from);
  sscanf(from, "%s.jpg", from);
  from -= ".";
  // Disallow "internal-roxen-..", it won't really do much harm, but a list of
  // all files in '..' might be retrieved (that is, the actual directory
  // file was sent to the browser)
  // /internal-roxen-../.. was never possible, since that would be remapped to
  // /..
  return (["file":open("roxen-images/"+from+".gif", "r"),"type":"image/gif"]);
}

public mapping|int get_file(object id, int|void no_magic);

// The function that actually tries to find the data requested.  All
// modules are mapped, in order, and the first one that returns a
// suitable responce is used.

static private mapping|int low_get_file(object id, int|void no_magic)
{
#ifdef MODULE_LEVEL_SECURITY
  int slevel;
#endif
  string file=id->not_query;
  string loc;
  function funp;
  mixed tmp, tmp2;
  mapping|object fid;


  current_configuration = id->conf; // This is needed

  if(!no_magic)
  {
#ifndef NO_INTERNAL_HACK 
    // No, this is not beautiful... :) 
    if(sscanf(id->not_query, "%*s/internal-%s", loc))
    {
      if(sscanf(loc, "gopher-%[^/]", loc))    // The directory icons.
	return internal_gopher_image(loc);

      if(sscanf(loc, "spinner-%[^/]", loc)  // Configuration interface images.
	 ||sscanf(loc, "roxen-%[^/]", loc)) // Try /internal-roxen-power
	return internal_roxen_image(loc);
    }
#endif

    if(id->prestate->diract)
    {
      if(current_configuration->dir_module)
	tmp = current_configuration->dir_module->parse_directory(id);
      if(mappingp(tmp)) return tmp;
    }
  }

  // Well, this just _might_ be somewhat over-optimized, since it is
  // quite unreadable, but, you cannot win them all.. 

#ifdef URL_MODULES
  // Map URL-modules.
  foreach(current_configuration->url_modules(id), funp)
    if((tmp=funp( id, file )) && (mappingp( tmp )||objectp( tmp )) )
    {
      array err;

      if(tmp->error) 
	return tmp;
      nest ++;
      err = catch {
	if( nest < 20 )
	  tmp = low_get_file( tmp, no_magic );
	else
	  error("Too deep recursion in roxen::get_file() while mapping "
		+file+".\n");
      };
      nest = 0;
      if(err)
	throw(err);
      return tmp;
    }
#endif

#ifdef EXTENSION_MODULES  
  if(tmp=current_configuration->extension_modules(loc=extension(file), id))
    foreach(tmp, funp)
      if(tmp=funp(loc, id))
      {
	if(!objectp(tmp)) 
	  return tmp;
	fid = tmp;
#ifdef MODULE_LEVEL_SECURITY
	slevel = function_object(funp)->query("_seclvl");
#endif
	break;
      }
#endif
  
  foreach(current_configuration->location_modules(id), tmp)
  {
    loc = tmp[0];
    if(!search(file, loc)) 
    {
#ifdef MODULE_LEVEL_SECURITY
      if(tmp2 = check_security(tmp[1], id, slevel))
	if(intp(tmp2))
	{
	  continue;
	} else {
	  return tmp2;
	}
#endif
      if(fid=tmp[1]( file[ strlen(loc) .. 1000000 ] + id->extra_extension, id))
      {
	id->virtfile = loc;

	if(mappingp(fid))
	  return fid;
	else 
	{
#ifdef MODULE_LEVEL_SECURITY
	  slevel = misc_cache[ tmp[1] ][1];// misc_cache from check_security
#endif
	  break;
	}
      }
    } else if(strlen(loc)-1==strlen(file)) {
      // This one is here to allow accesses to /local, even if 
      // the mountpoint is /local/. It will slow things down, but...
      if(file+"/" == loc) 
	return http_redirect(id->not_query + "/", id);
    }
  }
  
  if(fid == -1)
  {
    if(no_magic) return -1;
    if(current_configuration->dir_module)
      fid = current_configuration->dir_module->parse_directory(id);
    else
      return 0;
    if(mappingp(fid)) return (mapping)fid;
  }
  
  // Map the file extensions, but only if there is a file...
  if(objectp(fid) && 
     (tmp=current_configuration->
      file_extension_modules(loc=extension(id->not_query), id)))
    foreach(tmp, funp)
    {
#ifdef MODULE_LEVEL_SECURITY
      if(tmp=check_security(funp, id, slevel))
	if(intp(tmp))
	{
	  continue;
	}
	else
	  return tmp;
#endif
      if(tmp=funp(fid, loc, id))
      {
	if(!objectp(tmp))
	  return tmp;
	if(fid)
          destruct(fid);
	fid = tmp;
	break;
      }
    }
  
  if(objectp(fid))
  {
    if(stringp(id->extension))
      id->not_query += id->extension;
    
    tmp=type_from_filename(id->not_query, 1);
    
    if(tmp)
      return ([ "file":fid, "type":tmp[0], "encoding":tmp[1] ]);
    
    return ([ "file":fid, ]);
  }
  return fid;
}

public mapping|int get_file(object id, int|void no_magic)
{
  mixed res, res2;
  function tmp;
  res = low_get_file(id, no_magic);
  // finally map all filter type modules.
  // Filter modules are like TYPE_LAST modules, but they get called
  // for _all_ files.
  foreach(id->conf->filter_modules(id), tmp)
    if(res2=tmp(res,id))
    {
      if(res && res->file && (res2->file != res->file))
	destruct(res->file);
      res=res2;
    }
  return res;
}

// Map location-modules, and then build a listing of this virtual
// directory.

public array find_dir(string file, object id)
{
  string loc;
  array dir = ({ }), d, tmp;

  file=replace(file, "//", "/");
  
  current_configuration = id->conf;

  foreach(current_configuration->location_modules(), tmp)
  {
    loc = tmp[0];
    if(file[0] != '/')
      file = "/" + file;
    
    if(!search(file, loc))
    {
#ifdef MODULE_LEVEL_SECURITY
      if(check_security(tmp[1], id)) continue;
#endif
      if(d=function_object(tmp[1])->find_dir(file[strlen(loc)..1000000], id))
	dir |= d;
    } else {
      if(search(loc, file)==0 && loc[strlen(file)-1]=='/' 
	 && (loc[0]==loc[-1]) && loc[-1]=='/')
      {
	loc=loc[strlen(file)..100000];
	sscanf(loc, "%s/", loc);
	dir += ({ loc });
      }
    }
  }

  if(sizeof(dir))
    return dir;
}

// Stat a virtual file. 

public array stat_file(string file, object id)
{
  string loc;
  array s, tmp;
  
  current_configuration = id->conf;
  
  file=replace(file, "//", "/"); // "//" is really "/" here...
    
  // Map location-modules.
  foreach(current_configuration->location_modules(), tmp)
  {
    loc = tmp[0];
    if((file == loc) || ((file+"/")==loc))
      return ({ 0, -3, 0, 0, 0, 0, 0, 0, 0, 0, 0 });
    if(!search(file, loc)) 
    {
#ifdef MODULE_LEVEL_SECURITY
      if(check_security(tmp[1], id)) continue;
#endif
      if(s=function_object(tmp[1])->stat_file(file[strlen(loc)..], id))
	return s;
    }
  }
}


// Access a virtual file?

public array access(string file, object id)
{
  string loc;
  array s, tmp;
  
  current_configuration = id->conf;
  
  file=replace(file, "//", "/"); // "//" is really "/" here...
    
  // Map location-modules.
  foreach(current_configuration->location_modules(), tmp)
  {
    loc = tmp[0];
    if((file+"/")==loc)
      return file+="/";
    if(!search(file, loc)) 
    {
#ifdef MODULE_LEVEL_SECURITY
      if(check_security(tmp[1], id)) continue;
#endif
      if(s=function_object(tmp[1])->access(file[strlen(loc)..], id))
	return s;
    }
  }
}

// Return the _real_ filename of a virtual file, if any.

public string real_file(string file, object id)
{
  string loc;
  string s;
  array tmp;
  file=replace(file, "//", "/"); // "//" is really "/" here...
    
  if(!id) error("No id passed to real_file");

  // Map location-modules.
  current_configuration = id->conf;

  foreach(current_configuration->location_modules(), tmp)
  {
    loc = tmp[0];
    if(!search(file, loc)) 
    {
#ifdef MODULE_LEVEL_SECURITY
      if(check_security(tmp[1], id)) continue;
#endif
      if(s=function_object(tmp[1])->real_file(file[strlen(loc)..1000000], id))
	return s;
    }
  }
}

// Convenience functions used in quite a lot of modules. Tries to
// read a file into memory, and then returns the resulting string.

// NOTE: A 'file' can be a cgi script, which will be executed, resulting in
// a horrible delay.

public mixed try_get_file(string s, object id, int|void status, 
			  int|void nocache)
{
  string res, q;
  object fake_id;
  mapping m;


  if(objectp(id))
    fake_id = id->clone_me();
  else
    error("No ID passed to 'try_get_file'\n");

  if(!id->pragma["no-cache"] )
    if(res = cache_lookup("file:"+id->conf->name, s))
      return res;

  current_configuration = id->conf;

  if(sscanf(s, "%s?%s", s, q))
  {
    string v, name, value;
    foreach(q/"&", v)
      if(sscanf(v, "%s=%s", name, value))
	fake_id->variables[http_decode_string(name)]=value;
    fake_id->query=q;
  }

  fake_id->raw_url=s;
  fake_id->not_query=s;
  fake_id->misc->internal_get=1;

  if(!(m = get_file(fake_id)) || (m->error && (m->error/100 != 2)))
  {
    fake_id->end();
    return 0;
  }
  fake_id->end();

  if(status) return 1;
  
#ifdef COMPAT
  if(m["string"])  res = m["string"];	// Compability..
#endif
  else if(m->data) res = m->data;
  else res="";
  m->data = 0;
  
  if(m->file)
  {
    res += m->file->read(200000);
    destruct(m->file);
    m->file = 0;
  }
  
  if(m->raw)
  {
    res -= "\r";
    if(!sscanf(res, "%*s\n\n%s", res))
      sscanf(res, "%*s\n%s", res);
  }
  cache_set("file:"+id->conf->name, s, res);
  return res;
}

// Is 'what' a file in our virtual filesystem?
public int is_file(string what, object id)
{
  return !!stat_file(what, id);
}

// Called from the configuration interface.
string check_variable(string name, string value)
{
  switch(name)
  {
   case "cachedir":
    if(!sscanf(value, "%*s/roxen_cache"))
    {
      object node;
      node = (configuration_interface()->root->descend("Globals", 1)->
	      descend("Proxy disk cache: Base Cache Dir", 1));
      if(node && !node->changed) node->change(1);
      call_out(set, 0, "cachedir", value+"roxen_cache/");
      mkdirhier(value+"roxen_cache/foo");
    }
    break;

   case "copies":
    if((int)value < 1)
      return "You must have at least one copy of roxen running";
    break;

   case "ConfigurationURL":
   case "MyWorldLocation":
    if(strlen(value)<7 || value[-1] != '/' ||
       !(sscanf(value,"%*s://%*s/")==2))
      return "The URL should follow this format: protocol://computer[:port]/";
  }
}

void stop_all_modules()
{
  foreach(configurations, object conf)
    conf->stop();
}


// Perhaps somewhat misnamed, really...  This function will close all
// listen ports, fork a new copy to handle the last connections, and
// then quit the original process.  The 'start' script should then
// start a new copy of roxen automatically.

mapping restart() 
{ 
  stop_all_modules();
  call_out(fork_or_quit, 1);
  return ([ "data":read_bytes("etc/restart.html"), "type":"text/html" ]);
} 


// This has to be refined in some way. It is not all that nice to do
// it like this (write a file in /tmp, and then exit.)  The major part
// of code to support this is in the 'start' script.

private array configuration_ports = ({  });
int startpid;

mapping shutdown() 
{
  catch(map(indices(portno)), destruct);

  object privs = ((program)"privs")("Shutting down the server");
  // Change to root user.

  stop_all_modules();
  
  if(main_configuration_port && objectp(main_configuration_port))
  {
    // Only _really_ do something in the main process.
    int pid;
    catch(map(configuration_ports, destruct));
  
    if(search(subs, getpid()) == -1)
    {
      perror("Shutting down Roxen.\n");
      catch(map(subs, kill, signum("SIGUSR1")));
      catch(map(subs, kill, signum("SIGKILL")));
      
      // Fallback for systems without geteuid, Roxen will (probably)
      // not be able to kill the start-script if this is the case.
      rm("/tmp/Roxen_Shutdown_"+startpid);

      object f;
      f=open("/tmp/Roxen_Shutdown_"+startpid, "wc");
      
      if(!f) 
	perror("cannot open shutdown file.\n");
      else f->write(""+getpid());

      if(startpid != getpid())
      {
	kill(startpid, signum("SIGINTR"));
	kill(startpid, signum("SIGHUP"));
//	kill(startpid, signum("SIGKILL"));
      }
    }
  }
  
  call_out(exit, 1, 0);
  return ([ "data":replace(read_bytes("etc/shutdown.html"), "$PWD", getcwd()),
	    "type":"text/html" ]);
} 

private string docurl; 

// I will remove this in a future version of roxen.
private program __p;
private mapping my_loaded = ([]);
program last_loaded() { return __p; }

string filename(object o)
{
  return my_loaded[object_program(o)];
}

object load(string s)   // Should perhaps be renamed to 'reload'. 
{
#if defined(MODULE_DEBUG) && (DEBUG_LEVEL>20)
    perror(s+" ");
#endif
  if(file_size(s+".pike")>0)
    if(__p=compile_file(s+".pike"))
    {
      my_loaded[__p]=s+".pike";
      return __p();
    }
  if(file_size(s+".lpc")>0)
    if(__p=compile_file(s+".lpc"))
    {
      my_loaded[__p]=s+".lpc";
      return __p();
    }
  if(file_size(s+".module")>0)
    if(__p=compile_file(s+".module"))
    {
      my_loaded[__p]=s+".module";
      return __p();
    }
  return 0; // FAILED..
}

array(string) expand_dir(string d)
{
  string nd;
  array(string) dirs=({d});

  foreach((get_dir(d) || ({})) - ({"CVS"}) , nd) 
     if(file_size(d+nd)==-2)
	dirs+=expand_dir(d+nd+"/");

  return dirs;
}

array(string) last_dirs=0,last_dirs_expand;


object load_from_dirs(array dirs, string f)
{
  string dir;
  object o;

  if (dirs!=last_dirs)
  {
     last_dirs_expand=({});
     foreach(dirs, dir)
	last_dirs_expand+=expand_dir(dir);
  }

  foreach (last_dirs_expand,dir)
     if ( (o=load(dir+f)) ) return o;

  return 0;
}

// Some logging stuff, should probably move to either the actual
// configuration object, or into a module. That would be much more
// beautiful, really. 
void init_log_file(object conf)
{
  int possfd;
  object lf, oc;

  if(!conf) return;

  remove_call_out(init_log_file);

  oc = current_configuration;
  current_configuration = conf;

  if(current_configuration->log_function) 
  {
    destruct(function_object(current_configuration->log_function)); 
    // Free the old one.
  }
  
  if(query("Log")) // Only try to open the log file if logging is enabled!!
  {
    if(query("LogFile") == "stdout")
    {
      current_configuration->log_function=stdout->write;
      possfd=-1;
    } else if(query("LogFile") == "stderr") {
      current_configuration->log_function=stderr->write;
    } else {
      if(strlen(query("LogFile")))
      {
	int opened;
	lf=File();
	opened=lf->open( query("LogFile"), "wac");
	if(!opened)
	  mkdirhier(query("LogFile"));
	if(!opened && !(lf->open( query("LogFile"), "wac")))	
	{
	  destruct(lf);
	  report_error("Failed to open logfile. ("+query("LogFile")+")\n" +
		       "No logging will take place!\n");
	  current_configuration->log_function=0;
	} else {
	  mark_fd(lf->query_fd(), "Roxen log file ("+query("LogFile")+")");
	  current_configuration->log_function=lf->write;	
	  // Function pointer, speeds everything up (a little..).
	  possfd=lf->query_fd();
	  lf=0;
	}
      } else
	current_configuration->log_function=0;	
    }
    call_out(init_log_file, 60, current_configuration);
  } else
    current_configuration->log_function=0;	
  current_configuration = oc;
}

void do_dest(object|void o);


// This code should probably be moved to the configuration
// object. That would free roxen from some of the most ugly hacks (the
// query() function, and the current_configuration global variable (I
// do not like that one, but when I started with Spider, I only
// allowed one configuration, so to have the 'start' function with
// friends in the spider seemed like a good idea. Then the need for more
// than one configuration (known externaly as a virtual server)
// manifested itself. I did a quick hack, and this is the result.

void start(int num)
{
  array port;
  int possfd;
  int err=0;
  object lf;
  mapping new=([]), o2;

  if(!sscanf(QUERY(cachedir), "%*s/roxen_cache"))
    set("cachedir", QUERY(cachedir)+"roxen_cache/");
  
  parse_log_formats();

  init_log_file(current_configuration);

  map(indices(current_configuration->open_ports), do_dest);
  current_configuration->open_ports = ([]);

  foreach(query("Ports"), port ) {
#ifdef DEBUG
    perror("Opening port:%s...\n",
	   map(port, lambda(mixed x){ return(x+""); } )*",");
    array port_error;
    port_error = 
#endif /* DEBUG */
      catch {
	array tmp;
	function rp;
	array old = port;
	object o;
	
	if(rp = ((object)(getcwd()+"/protocols/"+port[1]))->real_port)
	  if(tmp = rp(port))
	    port = tmp;
	object privs;
	if(port[0] < 1024)
	  privs = ((program)"privs")("Opening listen port below 1024");
	if(!(o=create_listen_socket(port[0], current_configuration, port[2],
				    (program)(getcwd()+"/protocols/"+port[1]))))
	  {
	    perror("I failed to open the port "+old[0]+" at "+old[2]
		   +" ("+old[1]+")\n");
	    err++;
	  } else
	    current_configuration->open_ports[o]=old;
      };
#ifdef DEBUG
    if (port_error) {
      perror("Failed to open port %s at %s\n%s\n", ""+port[0], ""+port[2],
	     describe_backtrace(port_error));
    }
#endif /* DEBUG */
  }

  if(!num && sizeof(query("Ports")))
  {
    if(err == sizeof(query("Ports")))
    {
      report_error("No ports available for "+current_configuration->name+"\n"
		    "Tried:\n"
		    "Port  Protocol   IP-Number \n"
		    "---------------------------\n"
		    + map(query("Ports"), lambda(array p) {
		      return sprintf("%5d %-10s %-20s\n", @p);
		    })*"");
    }
  }
}


void create()
{
  add_constant("roxen", this_object());
  add_constant("spinner", this_object());
  add_constant("load",    load);
  (object)"color";
}


// Get the current domain. This is not as easy as one could think.
private string get_domain(int|void l)
{
  array f;
  string t, s;

//  ConfigurationURL is set by the 'install' script.
  if(!(!l && sscanf(QUERY(ConfigurationURL), "http://%s:%*s", s)))
  {
#if efun(gethostbyname) && efun(gethostname)
    f = gethostbyname(gethostname()); // First try..
    if(f)
      foreach(f, f) if (arrayp(f)) { 
	foreach(f, t) if(search(t, ".") != -1 && !(int)t)
	  if(!s || strlen(s) < strlen(t))
	    s=t;
      }
#endif
    if(!s)
    {
      t = read_bytes("/etc/resolv.conf");
      if(t) 
      {
	if(!sscanf(t, "domain %s\n", s))
	  if(!sscanf(t, "search %s%*[ \t\n]", s))
	    s="nowhere";
      } else {
	s="nowhere";
      }
      s = "host."+s;
    }
  }
  sscanf(s, "%*s.%s", s);
  if(s && strlen(s))
  {
    if(s[-1] == '.') s=s[..strlen(s)-2];
    if(s[0] == '.') s=s[1..];
  } else {
    s="unknown"; 
  }
  return s;
}


// This is the most likely URL for a virtual server. Again, this
// should move into the actual 'configuration' object. It is not all
// that nice to have all this code lying around in here.

private string get_my_url()
{
  string s;
  s = (gethostname()/".")[0] + "." + query("Domain");
  s -= "\n";
  return "http://" + s + "/";
}

// Set the uid and gid to the ones requested by the user. If the sete*
// functions are available, and the define SET_EFFECTIVE is enabled,
// the euid and egid is set. This might be a minor security hole, but
// it will enable roxen to start CGI scripts with the correct
// permissions (the ones the owner of that script have).

int set_u_and_gid()
{
  string u, g;
  array pw;
  
  u=QUERY(User);
  if(sscanf(u, "%s:%s", u, g) == 2)
  {
    if(getuid())
    {
      perror("It is not possible to change uid and gid if the server\n"
             "is not started as root.\n");
    } else {
    if(pw = getpwnam(u))
    {
      u = (string)pw[2];
    } else
      pw = getpwuid((int)u);
#if efun(initgroups)
    if(pw)
      initgroups(pw[0], (int)g);
#endif
#if efun(setegid) && defined(SET_EFFECTIVE)
    setegid((int)g);
#else
    setgid((int)g);
#endif
#if efun(seteuid) && defined(SET_EFFECTIVE)
    seteuid((int)u);
#else
    setuid((int)u);
#endif
    return 1;
    }
  }
}

private program Configuration = (program)"configuration";


static mapping __vars = ([ ]);

// These two should be documented somewhere. They are to be used to
// set global, but non-persistent, variables in Roxen. By using
// these functions modules can "communicate" with one-another. This is
// not really possible otherwise.
mixed set_var(string var, mixed to)
{
  __vars[var] = to;
}

mixed query_var(string var)
{
  return __vars[var];
}



// The update_*_vars functions are here to automatically change the
// configurationfileformat between releases, so the user can reuse the
// old configuration files. They are very useful, atleast for me.

private void update_global_vars(int from)
{
  string report = "";
#define perr(X) do { report += X; perror(X); } while(0)
  perr("Updating global variables file....\n");
  perr("----------------------------------------------------\n");
  switch(from)
  {
  case 0:
    if(!QUERY(IfModified))
    {
      perr("Setting the 'honor If-Modified-Since: flag to true. The "
	   "bug\nin Roxen seems to be gone now.\n"); 
      QUERY(IfModified) = 1;
    }

  case 1:
  case 2:
  case 3:
   perr("The configuration port variable is now a standard port.\n"
	"Adding the port '"+QUERY(ConfigurationPort)+" http "+
	QUERY(ConfigurationIP)+"\n");
   
   QUERY(ConfigPorts) = ({ ({ QUERY(ConfigurationPort), "http",
			      QUERY(ConfigurationIP), "" }) });
  case 4:
  case 5:

   if(search(QUERY(ident), "Spinner")!=-1)
   {
     QUERY(ident) = real_version;
     perr("Updating version field to "+real_version+"\n");
   }

   if(search(QUERY(ident), "Challenger")!=-1)
     QUERY(ident) = real_version;
   if(!search(QUERY(ident), "Roxen Challenger/1.0")
       && (replace(QUERY(ident),"·"," ") != real_version))
    {
      QUERY(ident)=real_version;
      perr("Updating version field to "+real_version+"\n");
    } else {
      perr("Not updating version field ("+QUERY(ident)+") since it is "
	   "either already updated, or modified by the administrator.\n");
    }
   case 6:
    // Current level
  }
  perr("----------------------------------------------------\n");
  report_debug(report);
}

// This is used to update the server-global and module variables
// between Roxen releases. It enables the poor roxen administrator to
// reuse the configuration file from a previous release. without any
// fuss. Configuration files from Roxen 1.0ß11 pre 11 and earlier
// are not differentiated, but since that release is quite old already
// when I write this, that is not really a problem....


private void update_vars(int from)
{
  string report = "";
  int i;
  string modname;
  mapping redir;
  mapping enabled_modules = retrieve("EnabledModules");
  array p, res=({});

  perr("Updating configuration file....\n");
  perr("----------------------------------------------------\n");
  switch(from)
  {
  case 0:

   // Pre b11p11 
   // Ports changed from int, int, int ... to
   // ({ int, "http", query("PEther") })
   //
    
    if(sizeof(retrieve("spider#0")))
    {
      p = query("Ports");
      foreach(p, p)
	if(intp(p))
	  res += ({ ({ p, "http", query("PEther") }) });

      perr("Updating ports variable.\n");
      set("PEther", 0);
      set("Ports", res);
    } else {
      perr("Ports variable already fixed.\n");
    }

    // Now comes the tricky part..
    // Fix all thoose redirection modules.
    res = ({});
    while(sizeof(redir = retrieve(modname = "redirect#"+i++)))
    {
      string from, to;
      if(redir->fileredirect)
      {
	res += ({ "\n\n" +redir->fileredirect });
	remove( modname );
	if(enabled_modules[modname] )
	  m_delete( enabled_modules, modname );
	continue;
      }
      // from -> to
      remove( modname );
      if(enabled_modules[modname] )
	m_delete( enabled_modules, modname );
      from = redir->from;
      to = redir->redirect;
      if(redir->internal)
	res += ({ from + "	" + to });
      else
	res += ({ from + "	" + "%u" + to });
      perr("Fixing redirect from " + from + " to "+to+"\n");
    }

    if(sizeof(res)) // Hepp hopp
    {
      enabled_modules["redirect#0"] = 1;
      store("redirect#0",
	    ([
	      "fileredirect":"# Automatically converted patterns...\n\n" 
	                     + res*"\n"
	      ]), 1);
    }    
    
    // And now the etc/extentions bug...
    redir = retrieve("contenttypes#0");

    if(!sizeof(redir))
      enabled_modules["contenttypes#0"] = 1;
    else
    {
      redir->exts = replace(redir->exts, "etc/extentions", "etc/extensions");
      store("contenttypes#0", redir, 1);
      perr("Fixing spelling error in contenttypes configuration.\n");
    }
    
    // Is there a directory parser in there somewhere?

    perror("Making a list of all wanted index files...\n");
    
    i=0;
    res=({ });
    while(sizeof(redir = retrieve(modname = "userfs#"+i++)))
    {
      if(redir->indexfiles)
      {
	res |= redir->indexfiles;
#if 0
	if(!redir->indexoverride)
	{
	  perr("WARNING: The user filesystem mounted on "
	       + redir->mountpoint +"\n"
	       "         had the indexfile override flag set to false.\n"
	       "         This variable no longer exists. Create a file named"
	       " .nodiraccess\n"
	       "         in the directory to disable directory listings.\n");
	}
#endif
	redir[".files"] = !redir[".files"];
	store("userfs#"+(i-1), redir, 1);
#ifdef SUPPORT_HTACCESS
	if(redir[".htaccess"])
	{
	  if(!query("htaccess"))
	  {
	    perr("A filesystem used .htaccess parsing.\n"
		 "This variable is now server global.\n"
		 "This variable has now been set to 'Yes'\n");
	    set("htaccess", 1);
	  }
	}
#endif
      }
    }
    i=0;
    while(sizeof(redir = retrieve(modname = "secure_fs#"+i++)))
    {
      if(redir->indexfiles)
      {
	res |= redir->indexfiles;
#if 0
	if(!redir->indexoverride)
	{
	  perr("WARNING: The secure filesystem mounted on "
	       + redir->mountpoint +"\n"
	       "         had the indexfile override flag set to false.\n"
		 "         This variable no longer exists. Create a file named"
		 " .nodiraccess\n"
		 "         in the directory to disable directory listings.\n");
	}
#endif
	redir[".files"] = !redir[".files"];
	store("secure_fs#"+(i-1), redir, 1);
#ifdef SUPPORT_HTACCESS
	if(redir[".htaccess"])
	{
	  if(!query("htaccess"))
	  {
	    perr("A secure filesystem used .htaccess parsing.\n"
		 "This variable is now server global.\n"
		 "This variable has now been set to 'Yes'\n");
	    set("htaccess", 1);
	  }
	}
#endif
      }
    }
    i=0;
    while(sizeof(redir = retrieve(modname = "filesystem#"+i++)))
    {
      if(redir->indexfiles)
      {
	res |= redir->indexfiles;
#if 0
	if(!redir->indexoverride)
	{
	  perror("WARNING: The filesystem mounted on "
		 + redir->mountpoint +"\n"
		 "         had the indexfile override flag set to false.\n"
		 "         This variable no longer exists. Create a file named"
		 " .nodiraccess\n"
		 "         in the directory to disable directory listings.\n");
	}
#endif
	redir[".files"] = !redir[".files"];
	store("filesystem#"+(i-1), redir, 1);
#ifdef SUPPORT_HTACCESS
	if(redir[".htaccess"])
	{
	  if(!query("htaccess"))
	  {
	    perr("A user filesystem used .htaccess parsing.\n"
		 "This variable is now server global.\n"
		 "It has been set to 'Yes'\n");
	    set("htaccess", 1);
	  }
	}
#endif
      }
    }
    perr("-> "+implode_nicely(res)+"\n");
    
    for(i=0; i<10; i++)
    {
      remove("status#"+i);
      m_delete(enabled_modules, "status#"+i);
    }
    
    if(!sizeof(retrieve("directories#0"))
       && (sizeof(redir = retrieve("fastdir#0"))))
    {
      redir->indexfiles = res;
      store("fastdir#0", redir, 1);
      perr("Updated fast directory parser to include new list.\n");
    } else {
      if(!(sizeof(redir = retrieve("directories#0"))))
      {
	enabled_modules["directories#0"] = 1;
	perr("Enabled a directory parsing module.\n");
	redir = ([ ]);
      }
      redir->indexfiles = res;
      store("directories#0", redir, 1);
      perr("Updated directory parser to include new list.\n");
    }
    perr("Saving new module list.\n");
    store( "EnabledModules", enabled_modules, 1 );

  case 1:
  case 2:
   perr("The 'No directory lists' variable is yet again available.\n");
  case 3:
   // The htaccess support moved to a module. 
   if(query(".htaccess"))
   {
     perr("The 'HTACCESS' support has been moved to a module.\n");
     enable_module("htaccess#0");
   }
   case 4:
   case 5:
    
    while(sizeof(redir = retrieve(modname = "lpcscript#"+i)))
    {
      remove( modname );
      if(search(redir->exts, "pike") == -1)
	redir->exts += ({"pike"});
      if(enabled_modules[modname] )
	m_delete( enabled_modules, modname );
      store("pikescript#"+i, redir, 1);
      enable_module("pikescript#"+i);
      perr("Renaming "+modname+" to pikescript#"+i+"\n");
      i++;
    }
    store( "EnabledModules", enabled_modules, 1 );
    
   case 6:// Current level. 
  }

  perr("----------------------------------------------------\n");
  report_debug(report);
}




// Used to hide some variables when logging is not enabled.

int log_is_not_enabled()
{
  return !query("Log");
}


// This function should be moved into the configuration object, since
// that would really make the object-hierarchy much clearer. Then it
// would be possible to do
// clone(configp)->enable(name_of_configuration); instead of
// (config=clone(configp))->name=name_of_configuration;
// enable_configuration(config);, it would also remove the need for
// the global variable 'current_configuration', and also speed up some
// of the functions below.

object enable_configuration(string config)
{
  array modules_to_process;
  string tmp_string;
  
  perror("Enabling virtual server '"+config+"'\n");
  
  current_configuration = Configuration(config);
  configurations += ({ current_configuration });
  

  definvisvar("htaccess", 0, TYPE_FLAG);       // COMPAT ONLY 
#ifdef COMPAT 
// b10 and below, compatibility removed. 
  definvisvar("PEther", "ANY", TYPE_STRING);
#endif



  defvar("ZNoSuchFile", "<title>Sorry. I cannot find this resource</title>"
	 "\n<h2 align=center><configimage src=roxen.gif alt=\"File not found\">\n"
	 "<p><hr noshade>"
	 "\n<i>Sorry</i></h2>\n"
	 "<br clear>\n<font size=+2>The resource requested "
	 "<i>$File</i>\ncannot be found.<p>\n\nIf you feel that this is a "
	 "configuration error, please contact "
	 "the administrators or the author of the <if referer>"
	 "<a href=<referer>>referring</a> </if> <else>referring</else> page."
	 "<p>\n</font>\n"
	 "<hr noshade>"
	 "<version>, at <a href=$Me>$Me</a>.\n", 

	 "Messages: No such file", TYPE_TEXT_FIELD,
	 "What to return when there is no resource or file available "
	 "at a certain location. $File will be replaced with the name "
	 "of the resource requested, and $Me with the URL of this server ");


  defvar("comment", "", "Configuration interface comment",
	 TYPE_TEXT_FIELD,
	 "This text will be visible in the configuration interface, it "
	 " can be quite useful to use as a memory helper.");
  
  defvar("name", "", "Configuration interface name",
	 TYPE_STRING,
	 "This is the name that will be used in the configuration "
	 "interface. If this is left empty, the actual name of the "
	 "virtual server will be used");
  
  defvar("LogFormat", 
 "404: $host $referer - [$cern_date] \"$method $resource $protocol\" 404 -\n"
 "500: $host ERROR - [$cern_date] \"$method $resource $protocol\" 500 -\n"
 "*: $host - - [$cern_date] \"$method $resource $protocol\" $response $length"
	 ,

	 "Logging: Format", 
	 TYPE_TEXT_FIELD,
	 
	 "What format to use for logging. The syntax is:\n"
	 "<pre>"
	 "response-code or *: Log format for that response acode\n\n"
	 "Log format is normal characters, or one or more of the "
	 "variables below:\n"
	 "\n"
	 "\\n \\t \\r       -- As in C, newline, tab and linefeed\n"
	 "$char(int)     -- Insert the (1 byte) character specified by the integer.\n"
	 "$wchar(int)    -- Insert the (2 byte) word specified by the integer.\n"
	 "$int(int)      -- Insert the (4 byte) word specified by the integer.\n"
	 "$^             -- Supress newline at the end of the logentry\n"
	 "$host          -- The remote host name, or ip number.\n"
	 "$ip_number     -- The remote ip number.\n"
	 "$bin-ip_number -- The remote host id as a binary integer number.\n"
	 "\n"
	 "$cern_date     -- Cern Common Log file format date.\n"
       "$bin-date      -- Time, but as an 32 bit iteger in network byteorder\n"
	 "\n"
	 "$method        -- Request method\n"
	 "$resource      -- Resource identifier\n"
	 "$protocol      -- The protocol used (normally HTTP/1.0)\n"
	 "$response      -- The response code sent\n"
	 "$bin-response  -- The response code sent as a binary short number\n"
	 "$length        -- The length of the data section of the reply\n"
       "$bin-length    -- Same, but as an 32 bit iteger in network byteorder\n"
	 "$referer       -- the header 'referer' from the request, or '-'.\n"
      "$user_agent    -- the header 'User-Agent' from the request, or '-'.\n\n"
	 "$user          -- the name of the auth user used, if any\n"
	 "$user_id       -- A unique user ID, if cookies are supported,\n"
	 "                  by the client, otherwise '0'\n"
	 "</pre>", 0, log_is_not_enabled);
  
  defvar("Log", 1, "Logging: Enabled", TYPE_FLAG, "Log requests");
  
  defvar("LogFile", QUERY(logdirprefix)+
	 short_name(current_configuration->name)+"/Log", 

	 "Logging: Log file", TYPE_FILE, "The log file. "
	 "stdout for standard output, or stderr for standard error, or "+
	 "a file name. May be relative to "+getcwd()+".",0, log_is_not_enabled);
  
  defvar("NoLog", ({ }), 

	 "Logging: No Logging for", TYPE_STRING_LIST,
         "Don't log requests from hosts with an IP number which matches any "
	 "of the patterns in this list. This also affects the access counter "
	 "log.\n",0, log_is_not_enabled);
  
  defvar("Domain", get_domain(), 

	 "Domain", TYPE_STRING, 
	 "Your domainname, should be set automatically, if not, "
	 "enter the real domain name here, and send a bug report to "
	 "<a href=mailto:roxen-bugs@infovav.se>roxen-bugs@infovav.se"
	 "</a>");
  

    defvar("Ports", ({ }), 
	 "Listen ports", TYPE_PORTS,
         "The ports this virtual instance of Roxen will bind to.\n");

  defvar("MyWorldLocation", get_my_url(), 
	 "Server URL", TYPE_STRING,
	 "This is where your start page is located.");


// This should be somewhere else, I think. Same goes for HTTP related ones

  defvar("FTPWelcome",  
	 "              +-------------------------------------------------\n"
	 "              +-- Welcome to the Roxen Challenger FTP server ---\n"
	 "              +-------------------------------------------------\n",
	 "Messages: FTP Welcome",
	 TYPE_TEXT_FIELD,
	 "FTP Welcome answer; transmitted to new FTP connections if the file "
	 "<i>/welcome.msg</i> doesn't exist.\n");

  defvar("named_ftp", 0, "Allow named FTP", TYPE_FLAG,
	 "Allow ftp to normal user-accounts (requires auth-module).\n");

  defvar("shells", "/etc/shells", "Shell database", TYPE_FILE,
	 "File which contains a list of all valid shells.\n"
	 "Usually /etc/shells\n");
	 
  defvar("_v", CONFIGURATION_FILE_LEVEL, 0, TYPE_INT, 0, 0, 1);
  setvars(retrieve("spider#0"));
  
  if((sizeof(retrieve("spider#0")) && 
      (!retrieve("spider#0")->_v) 
      || (query("_v") < CONFIGURATION_FILE_LEVEL)))
  {
    update_vars(retrieve("spider#0")->_v?query("_v"):0);
    killvar("PEther"); // From Spinner 1.0b11
    current_configuration->variables->_v[VAR_VALUE] = CONFIGURATION_FILE_LEVEL;
    store("spider#0", current_configuration->variables, 0);
  }
    
  set("_v", CONFIGURATION_FILE_LEVEL);
  
  modules_to_process = sort_array(indices(retrieve("EnabledModules")));

  // Always enable the user database module first.
  if(search(modules_to_process, "userdb#0")>-1)
    modules_to_process = (({"userdb#0"})
			  + (modules_to_process-({"userdb#0"})));


  array err;
  foreach( modules_to_process, tmp_string ) {
    perror("Enabling module %s\n", tmp_string);
    if(err = catch( enable_module( tmp_string ) ))
      perror("Failed to enable the module "+tmp_string+". Skipping\n"
#ifdef MODULE_DEBUG
	     +describe_backtrace(err)+"\n"
#endif
	);
  }
  return current_configuration;
}

// Enable all configurations
static private void enable_configurations()
{
  array configs;
  string config;

  enabling_configurations = 1;
#define DEBUG
#ifdef DEBUG
  if (mixed err =
#endif /* DEBUG */
      catch {
	configs=list_all_configurations(); // From read_config.pike
	configurations = ({});
  
	foreach(configs, config)
	  {
	    enable_configuration(config);
	    start(0);
	  }
      }
#ifdef DEBUG
       ) {
    perror("Failed to enable configuration:\n%s\n",
	   describe_backtrace(err));
  }
#endif /* DEBUG */
  ;
  enabling_configurations = 0;
}


// return the URL of the configuration interface. This is not as easy
// as it sounds, unless the administrator has entered it somewhere.

public string config_url()
{
  if(strlen(QUERY(ConfigurationURL)-" "))
    return QUERY(ConfigurationURL)-" ";

  array ports = QUERY(ConfigPorts), port, tmp;

  if(!sizeof(ports)) return "CONFIG";

  int p;
  string prot;
  string host;

  foreach(ports, tmp)
    if(tmp[1]=="ssl") 
    {
      port=tmp; 
      break;
    }

  if(!port)
    foreach(ports, tmp)
      if(tmp[1]=="http") 
      {
	port=tmp; 
	break;
      }

  if(!port) port=ports[0];

  if(port[2] == "ANY")
//  host = quick_ip_to_host( port[2] );
// else
  {
#if efun(gethostname)
    host = gethostname();
#else
#if 0
    if(configuration_interface()->
#endif
    host = "127.0.0.1";
#endif
  }

  prot = (port[1]!="ssl"?port[1]:"https");
  p = port[0];

  return (prot+"://"+host+":"+p+"/");
}


// The following three functions are used to hide variables when they
// are not used. This makes the user-interface clearer and quite a lot
// less clobbered.
  
int cache_disabled_p() { return !QUERY(cache);         }
int syslog_disabled()  { return QUERY(LogA)!="syslog"; }
int copies_is_one()    { return QUERY(copies)==1;      }
int copies_is_not_one(){ return QUERY(copies)!=1;      }


private void define_global_variables( int argc, array (string) argv )
{
  int p;
  current_configuration=0;


  // Hidden variables (compatibility ones, or internal or too
  // dangerous (in the case of chroot, the variable is totally
  // removed.
  
#if 0
  globvar("chroot", "", "Server root dir", TYPE_DIR,
	  "If you don't know what chroot() will do, this is not the variable "
	  "for you. If set, it be the new root directory for roxen.",1);
#endif

  globvar("set_cookie", 1, "Set unique user id cookies", TYPE_FLAG,
	  "If set, all users of your server whose clients supports "
	  "cookies will get a unique 'user-id-cookie', this can then be "
	  "used in the log and in scripts to track individual users.");

  globvar("show_internals", 1, "Show the internals", TYPE_FLAG,
	  "Show 'Internal server error' messages to the user. "
	  "This is very useful if you are debugging your own modules "
	  "or writing Pike scripts.");
  
  globvar("ConfigurationIP", "ANY", "Configuration interface: Interface",
	  TYPE_STRING,
          "The IP number to bind to. If set to 127.0.0.1, all configuration "
	  "will have to take place from the localhost. This is most secure, "
	  "but it will be more cumbersome to configure the server remotely.",
	  0, 1);

  globvar("ConfigurationPort", 22202, "Configuration interface: Port", 
	  TYPE_INT, 
	  "the portnumber of the configuration interface. Anything will do, "
	  "but you will have to be able to remember it to configure "
	  "the server.", 0, 1);

  globvar("_v", CONFIGURATION_FILE_LEVEL, 0, TYPE_INT, 0, 0, 1);
    


  globvar("logdirprefix", "../logs/", "Log directory prefix", TYPE_DIR,
	  "This is the default file path that will be prepended to the log "
	  " file path in all the default modules and the virtual server.");
  

  // Cache variables. The actual code recides in the file
  // 'disk_cache.pike'
  

  globvar("cache", 0, "Proxy disk cache: Enabled", TYPE_FLAG,
	  "Is the cache enabled at all?");
  
  globvar("garb_min_garb", 1, "Proxy disk cache: Clean size", TYPE_INT,
	 "Minimum number of Megabytes removed when a garbage collect is done",
	  0, cache_disabled_p);

#if 0 // TBD 
  globvar("cache_minimum_left", 5, "Proxy disk cache: Minimum "
	  "available free space", TYPE_INT,
	  "If less than this amount of disk space (in MB) is left, "
	  "the cache will remove a few files",
	  0, cache_disabled_p);
#endif
  
  globvar("cache_size", 25, "Proxy disk cache: Size", TYPE_INT,
        "How many MB may the cache grow to before a garbage collect is done?",
	  0, cache_disabled_p);
  
  globvar("bytes_per_second", 50, "Proxy disk cache: Bytes per second", 
	  TYPE_INT,
	  "How file size should be treated during garbage collect. "
	  " Each X bytes counts as a second, so that larger files will"
	  " be removed first.",
	  0, cache_disabled_p);

  globvar("cachedir", "/tmp/roxen_cache/",
	  "Proxy disk cache: Base Cache Dir",
	  TYPE_DIR,
	  "This is the base directory where cached files will reside. "
	  "To avoid mishaps, 'roxen_cache/' is always prepended to this "
	  "variable.",
	  0, cache_disabled_p);

  globvar("hash_num_dirs", 500,
	  "Proxy disk cache: Number of hash directories",
	  TYPE_INT,
	  "This is the number of directories to hash the contents of the disk "
	  "cache into.  Changing this value currently invalidates the whole "
	  "cache, since the cache cannot find the old files.  In the future, "
	  " the cache will be recalculated when this value is changed.",
	  0, cache_disabled_p); 
  
  /// End of cache variables..
  
  globvar("docurl", "http://roxen.com", "Documentation URL",
	  TYPE_STRING,
	 "The URL to prepend to all documentation urls throughout the "
	 "server. This URL should _not_ end with a '/'.");

  globvar("pidfile", "/tmp/roxen_pid:$uid", "PID file",
	  TYPE_FILE,
	  "In this file, the server will write out it's PID, and the PID "
	  "of the start script. $pid will be replaced with the pid, and "
	  "$uid with the uid of the user running the process.");

  globvar("ident", replace(real_version," ","·"), "Identify as",  TYPE_STRING,
	  "What Roxen will call itself when talking to clients "
	  "It might be useful to set this so that it does not include "
	  "the actual version of Roxen, as recommended by "
	  "the HTTP/1.0 draft 03:<p><blockquote><i>"
	  "Note: Revealing the specific software version of the server "
	  "may allow the server machine to become more vulnerable to "
	  "attacks against software that is known to contain security "
	  "holes. Server implementors are encouraged to make this field "
	  "a configurable option.</i></blockquote>");


  globvar("BS", 0, "Configuration interface: Compact layout", TYPE_FLAG,
	  "Sick and tired of all those images? Set this variable to 'Yes'!");

  globvar("DOC", 1, "Configuration interface: Help texts", TYPE_FLAG,
	  "Do you want documentation? (this is an example of documentation)");

  globvar("BG", 1,  "Configuration interface: Background", TYPE_FLAG,
	  "Should the background be set by the configuration interface?");

  globvar("NumAccept", 1, "Number of accepts to attempt", TYPE_INT_LIST,
	  "The maximum number of accepts to attempt for each read callback "
	  "from the main socket. <p> Increasing this will make the server"
	  " faster for users making many simultaneous connections to it, or"
	  " if you have a very busy server. <p> It won't work on some systems"
	  ", though, eg. IBM AIX 3.2<p> To see if it works, change this"
	  " variable, <b> but don't press save</b>, and then try connecting to"
	  " your server. If it works, come back here and press the save button"
	  ". <p> If it doesen't work, just restart the server and be happy "
	  "with having '1' in this field.<p>"
	  "The higher you set this value, the less load balancing between"
	  " virtual servers (if there are 256 more or less simultaneous "
	  "requests to server 1, and one to server 2, and this variable is "
	  "set to 256, the 256 accesses to the first server might very well be"
	  " handled before the one to the second server.)",
	  ({ 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024 }),
	  copies_is_not_one);
  

  globvar("ConfigPorts", ({ ({ 22202, "http", "ANY", "" }) }),
	  "Configuration interface: Ports",
	  TYPE_PORTS,
	  "The ports that the configuration interface will be "
	  "accessible via.<p>If you have none, you have a problem.\n");
  
  globvar("ConfigurationURL", 
	  "",
          "Configuration interface: URL", TYPE_STRING,
	  "The URL of the configuration interface. This is used to "
	  "generate redirects now and then (when you press save, when "
	  "a module is added, etc.).");
  
  globvar("ConfigurationPassword", "", "Configuration interface: Password", 
	  TYPE_PASSWORD,
	  "The password you will have to enter to use the configuration "
	  "interface. Please note that changing this password in the "
	  "configuration interface will _not_ require an additional entry "
	  "of the password, so it is easy to make a typo. It is recommended "
	  "that you use the <a href=/(changepass)/Globals/>form instead</a>.");
  
  globvar("ConfigurationUser", "", "Configuration interface: User", 
	  TYPE_STRING,
	  "The username you will have to enter to use the configuration "
	  "interface");
  
  globvar("ConfigurationIPpattern", "*", "Configuration interface: IP-Pattern", 
	  TYPE_STRING,
	  "The IP-pattern hosts trying to connect to the configuration "
	  "interface will have to match.");
  
  
  globvar("User", "", "Change uid and gid to", TYPE_STRING,
	  "When roxen is run as root, to be able to open port 80 "
	  "for listening, change to this user-id:group-id when the port "
	  " has been opened. <b>NOTE:</b> Since this is done before the "
	  "modules have been loaded, you will have to use the numeric user and"
	  " group id's, and not the symbolic ones.\n");
  
  globvar("NumHostnameLookup", 2, "Number of hostname lookup processes", 
	  TYPE_INT, 
	  "The number of simultaneos host-name lookup processes roxen should "
	  "run. Roxen must be restarted for a change of this variable to "+
	  "take effect. If you constantly see a large host name lookup "
	  "queue size in the configuration interface 'Status' section, "
	  "consider increasing this variable. A good guidline is: "
	  "<ul>\n"
	  "<li> 1 for normal operation\n"
	  "<li> 1 extra for each 300 000 accesses/day\n"
	  "<li> 1 for each proxy\n"
	  "<li> 1 for each 100 proxy users\n"
	  "</ul>\n");
  
  
  globvar("ModuleDirs", ({ "modules/" }), "Module directories", TYPE_DIR_LIST,
	  "Where to look for modules. Can be relative paths, from the "
	  "directory you started roxen, " + getcwd() + " this time."
	  " The directories are searched in order for modules.");
  
  globvar("Supports", "#include <etc/supports>\n", 
	  "Client supports regexps", TYPE_TEXT_FIELD,
	  "What do the different clients support?\n<br>"
	  "The default information is normally fetched from the file "+
	  getcwd()+"etc/supports, and the format is:<pre>"
	  "<a href=$docurl/configuration/regexp.html>regular-expression</a>"
	  " feature, -feature, ...\n"
	  "</pre>"
	  "If '-' is prepended to the name of the feature, it will be removed"
	  " from the list of features of that client. All patterns that match"
	  " each given client-name are combined to form the final feature list"
	  ". See the file etc/supports for examples.");
  

  globvar("IfModified", 1, "Honor If-Modified-Since headers", TYPE_FLAG,
	  "If set, send a 'Not modified' response in reply to "
	  "if-modified-since headers, as "
	  "<a href=http://www.w3.org/pub/WWW/Protocols/HTTP/1.1/spec"
	  "#If-Modified-Since>specified by the HTTP draft.</a>");
  
  globvar("audit", 0, "Audit trail", TYPE_FLAG,
	 "If set, log all changes of uid in the debug log.");
  
#if efun(syslog)
  globvar("LogA", "file", "Logging method", TYPE_STRING_LIST, 
	  "What method to use for logging, default is file, but "
	  "syslog is also available. When using file, the output is really"
	  " sent to stdout and stderr, but this is handled by the "
	  "start script",
	  ({ "file", "syslog" }));
  
  globvar("LogSP", 1, "Syslog: Log PID", TYPE_FLAG,
	  "If set, the PID will be included in the syslog", 0, 
	  syslog_disabled);
  
  globvar("LogCO", 0, "Syslog: Log to system console", TYPE_FLAG,
	  "If set and syslog is used, the error/debug message will be printed"
	  " to the system console as well as to the system log", 
	  0, syslog_disabled);
  
  globvar("LogST", "Daemon", "Syslog: Log type", TYPE_STRING_LIST,
	  "When using SYSLOG, which log type should be used",
	  ({ "Daemon", "Local 0", "Local 1", "Local 2", "Local 3",
	     "Local 4", "Local 5", "Local 6", "Local 7", "User" }),
	  syslog_disabled);
  
  globvar("LogWH", "Errors", "Syslog: Log what", TYPE_STRING_LIST,
	  "When syslog is used, how much should be sent to it?<br><hr>"
	  "Fatal:    Only messages about fatal errors<br>"+
	  "Errors:   Only error or fatal messages<br>"+
	  "Warning:  Warning messages as well<br>"+
	  "Debug:    Debug messager as well<br>"+
	  "All:      Everything<br>",
	  ({ "Fatal", "Errors",  "Warnings", "Debug", "All" }),
	  syslog_disabled);
  
  globvar("LogNA", "Roxen", "Syslog: Log as", TYPE_STRING, 
	  "When syslog is used, use this as the id of the Roxen daemon"
	  ". This will be appended to all logs.", 0, syslog_disabled);
#endif

  globvar("copies", 1, "Number of copies to run", TYPE_INT,
	  "The number of forked copies of roxen to run simultaneously.\n"
	  "<i>This is quite useful if you have more than one CPU in "
	  "your machine, or if you have a lot of slow NFS accesses.</i>");

  globvar("AutoUpdate", 1, "Update the supports database automatically",
	  TYPE_FLAG, 
	  "If set, the etc/supports file will be updated automatically "
	  "from roxen.com now and then. This is recomended, since "
	  "you will then automatically get supports info for new "
	  "clients, and new versions of old ones.");

  globvar("next_supports_update", time()+3600, "", TYPE_INT,"",0,1);
  

  globvar("uselock",
#if efun(uname)
	  ((uname()->sysname=="SunOS")&&((int)uname()->release==5))
	  ||((uname()->sysname=="IRIX")&&((int)uname()->release==5)),
#else
	  0,
#endif
	  "Use a mutex-lock or semaphore to serialize accept calls",
	  TYPE_FLAG,
	  "This is needed on SunOS 5.* (Solaris 2.*) and IRIX 5.*. "
          "It might be needed"
	  " under other OS-es as well. It will slow down the accept call"
	  " by a percent or two, but without it, the call might hang forever."
          "It is only used if the number of copies to run is set to more "
	  "than one.", 0, copies_is_one);

  setvars(retrieve("Variables"));

  if(sizeof(retrieve("Variables")) &&  
     (!retrieve("Variables")->_v || 
      (QUERY(_v) < CONFIGURATION_FILE_LEVEL)))
  {
    update_global_vars(retrieve("Variables")->_v?QUERY(_v):0);
    QUERY(_v) = CONFIGURATION_FILE_LEVEL;
    store("Variables", variables, 0);
  }
  set("_v", CONFIGURATION_FILE_LEVEL);

  for(p = 1; p < argc; p++)
  {
    string c, v;
    if(sscanf(argv[p],"%s=%s", c, v) == 2)
      if(variables[c])
	variables[c][VAR_VALUE]=compat_decode_value(v);
      else
	perror("Unknown variable: "+c+"\n");
  }
  docurl=QUERY(docurl);
}

// Somewhat misnamed, since there can be more then one
// configuration-interface port nowdays. But, anyway, this function
// opens and listens to all configuration interface ports.

void initiate_configuration_port( int|void first )
{
  object o;
  array port;

  if(catch(map(configuration_ports, destruct)))
    catch(map(configuration_ports, do_dest));
  
  catch(do_dest(main_configuration_port));
  
  configuration_ports = ({ });
  main_configuration_port=0;
    
  if(sizeof(QUERY(ConfigPorts)))
  {
    foreach(QUERY(ConfigPorts), port)
    {
      if(o=create_listen_socket(port[0],0,port[2],
				(program)(getcwd()+"/protocols/"+port[1])))
      {
	perror("Configuration port: port number "
	       +port[0]+" interface " +port[2]+"\n");
	main_configuration_port = o;
	configuration_ports += ({ o });
      } else {
	report_error("The configuration port "+port[0]
		     +" on the interface " +port[2]+" "
		     "could not be opened\n");
      }
    }
    if(!main_configuration_port)
    {
      report_error("No configuration ports could be created.\n"
		   "Is roxen already running?\n");
      if(first)
	exit( 0 );
    }
  } else {
    perror("No configuration port. I hope this is what you want.\n"
	   "Unless the configuration interface as a location module\n"
	   "is enabled, you will not be allowed access to the configuration\n"
	   "interface. You can re-enable the configuration port like this:\n"
	   "./configvar ConfigurationPort=22202\n");
  }
}

#ifdef DUMPVARS

// All code here is used to dump a list of all variables in all
// modules, and the global and configuration global ones, to HTML
// files. If the define DUMPVARS is present, this is the only thing
// Roxen will do at all.

private void dump_variables(string file, mapping variables, array info,
			    string creator, string url)
{
  object f;
  mkdir("vardump");
  rm ("vardump/" + replace(file, "/", "\\")+".html");
  f = open("vardump/" + replace(file, "/", "\\")+".html", "wc");
  if(!f) return;
  
  f->write("<head>\n<title>Roxen: "+info[1]+"</title>\n"
	   "</head>\n"
	   "<body bgcolor=#c0c0c0 text=#000000 link=#005000 vlink=#500000>\n"
	   ""
	   "<hr noshade>\n");

  f->write("<h1>"+info[1]+"</h1>\n\n");
  f->write("<font size=+1>"+info[2]+"</font><p>");

#if 0
  f->write(describe_module_type(info[0])+"<p>");
#endif /* 0 */

  f->write("<font color=black>File:</font> <i>"+file+"</i><br>\n");

  if(creator)
    f->write("<font color=black>Creator:</font> <i>"+creator+"</i><br>\n");

  if(url)
    f->write("<font color=black>Home URL:</font> <i><a href="+url+">"+url+"</a></i><br>\n");

  f->write("<hr noshade>\n\n");
  f->write("<h2>Variables</h2>");
  f->write("<dl>\n");

  array v;
  string n;
  foreach(sort_array(indices(variables)), n)
  {
    v = variables[n];
    if(v[VAR_CONFIGURABLE])
    {
      f->write("<dt><b>"+v[VAR_NAME]+"</b>\n"
#if 0
	       +(strlen(describe_variable_as_text(v,1))?
		 "<i><br>Default value:</i>\n"
		 "<font color=red>"+describe_variable_as_text(v,1)
		 +"</font><br>"
		 :"")
#endif /* 0 */
	       +"<dd>" + v[VAR_DOC_STR] + "<br>" 
#if 0
	       "<i><font color=black>"+describe_type(v[VAR_TYPE], v[VAR_MISC]) 
	       + "</font></i>"
#endif /* 0 */
	       + "<p>\n\n\n");
    }
  }
  f->write("</dl>\n");
  destruct(f);
}
#endif


// Find all modules, so a list of them can be presented to the
// user. This is not needed when the server is started.
void scan_module_dir(string d)
{
  string file,path=d;
  mixed err;

  foreach( get_dir( d )||({}), file)
  {
    if ( file[0]!='.' && !backup_extension(file) && (file[-1]!='z'))
    {
      if(file_size(path+file) == -2)
      {
	if(file!="CVS")
	  scan_module_dir(path+file+"/");
      }
      else
      {
#ifdef MODULE_DEBUG
	perror("Loading module: "+(file-("."+extension(file)))+" - ");
#endif
	string *module_info;
	if (!(err=catch( module_info = lambda ( string file ) {
	  array foo;
	  object o;
	  o =  (compile_file(file))();
#ifdef MODULE_DEBUG
	  perror(" load ok - ");
#endif
	  foo =  o->register_module();
#ifdef DUMPVARS
	  dump_variables(file, o->variables, foo, o->module_creator, o->module_url);
#endif
#ifdef MODULE_DEBUG
	  perror("registered.");
#endif	  
	  return ({ foo[1], foo[2]+"<p><i>"+replace(o->file_name_and_stuff(),
						    "0<br>", file+"<br>")
		      +"</i>", foo[0] });
	  
	}(path + file))))
	{
#ifdef MODULE_DEBUG
//	  perror("MODULES: "+module_info[0]+ "\n"+module_info[1]+"\n");
#endif
	  allmodules[ file-("."+extension(file)) ] = module_info;
	} else {
#ifdef MODULE_DEBUG
	  perror("\n"+err[0]+_master->set_inhibit_compile_errors( 1 ));
#endif
	}
#ifdef MODULE_DEBUG
	perror("\n");
#endif
      }
    }
  }
}

void rescan_modules()
{
  string file, path;
  mixed err;
  
  allmodules=([]);
  foreach(QUERY(ModuleDirs), path)
  {
    _master->set_inhibit_compile_errors(1);
    catch(scan_module_dir( path ));
  }
  if(strlen(_master->errors))
  {
    nwrite("While rescanning module list:\n" + _master->errors, 1);
    _master->set_inhibit_compile_errors(0);
  }

  _master->set_inhibit_compile_errors(0);
}

// ================================================= 
// Parse options to Roxen. This function is quite generic, see the
// main() function for more info about how it is used.

private string find_arg(array argv, array|string shortform, 
			array|string|void longform, 
			array|string|void envvars, 
			string|void def)
{
  string value;
  int i;

  for(i=1; i<sizeof(argv); i++)
  {
    if(argv[i] && strlen(argv[i]) > 1)
    {
      if(argv[i][0] == '-')
      {
	if(argv[i][1] == '-')
	{
	  string tmp;
	  int nf;
	  if(!sscanf(argv[i], "%s=%s", tmp, value))
	  {
	    if(i < sizeof(argv)-1)
	      value = argv[i+1];
	    else
	      value = argv[i];
	    tmp = argv[i];
	    nf=1;
	  }
	  if(arrayp(longform) && search(longform, tmp[2..1000]) != -1)
	  {
	    argv[i] = 0;
	    if(i < sizeof(argv)-1)
	      argv[i+nf] = 0;
	    return value;
	  } else if(longform && longform == tmp[2..10000]) {
	    argv[i] = 0;
	    if(i < sizeof(argv)-1)
	      argv[i+nf] = 0;
	    return value;
	  }
	} else {
	  if((arrayp(shortform) && search(shortform, argv[i][1..1]) != -1) 
	     || stringp(shortform) && shortform == argv[i][1..1])
	  {
	    if(strlen(argv[i]) == 2)
	    {
	      if(i < sizeof(argv)-1)
		value =argv[i+1];
	      argv[i] = argv[i+1] = 0;
	      return value;
	    } else {
	      value=argv[i][2..100000];
	      argv[i]=0;
	      return value;
	    }
	  }
	}
      }
    }
  }

  if(arrayp(envvars))
    foreach(envvars, value)
      if(getenv(value))
	return getenv(value);
  
  if(stringp(envvars))
    if(getenv(envvars))
      return getenv(envvars);

  return def;
}

// do the chroot() call. This is not currently recommended, since
// roxen dynamically loads modules, all module files must be
// available at the new location.

private void fix_root(string to)
{
  if(getuid())
  {
    perror("It is impossible to chroot() if the server is not run as root.\n");
    return;
  }

  if(!chroot(to))
  {
    perror("Roxen: Cannot chroot to "+to+": ");
#if efun(real_perror)
    real_perror();
#endif
    return;
  }
  perror("Root is now "+to+".\n");
}

void create_pid_file(string where)
{
  if(!where) return;
  where = replace(where, ({ "$pid", "$uid" }), 
		  ({ (string)getpid(), (string)getuid() }));

  rm(where);
  if(catch(write_file(where, sprintf("%d\n%d", getpid(), startpid))))
    perror("I cannot create the pid file ("+where+").\n");
}

#if efun(send_fd)
// External multi-threaded data shuffler. This leaves roxen free to
// serve new requests. The file descriptors of the open files and the
// clients are sent to the program, then the shuffler just shuffles 
// the data to the client.
object shuffler;
void init_shuffler()
{
  object out;
  object out2;
  if(file_size("bin/shuffle") > 100)
  {
    if(shuffler)
      destruct(shuffler);
    out=File();
    out2=out->pipe();
    mark_fd(out->query_fd(), "Data shuffler local end of pipe.\n");
    spawne("bin/shuffle", ({}), ({}), out2, stderr, stderr, 0, 0);
    perror("Spawning data mover. (bin/shuffle)\n"); 
    destruct(out2);
    shuffler = out;
    shuffle_fd = out->query_fd();
  }
}
#endif


// To avoid stack error :-)
// This is really a bug in Pike, that is probably fixed by now, but
// since I needed a catch() as well, I never did come around to
// removing the hack. The functions below this one are here for
// process and signal magic, it is basically the support needed
// to use multi-processing with a central process as master and
// control of the other processes.
void do_dest(object|void o)
{
  if(objectp(o))
    catch
    {
      destruct(o);
    };
}


static private int _recurse;

void exit_when_done()
{
  object o;
  int i;
  perror("Interrupt request received. Exiting,\n");
  if(++_recurse > 4)
  {
    werror("Exiting roxen (spurious signals received).\n");
    stop_all_modules();
    exit(0);
  }
  if(main_configuration_port && objectp(main_configuration_port))
  {
    int pid;
    if(search(subs, getpid()) == -1)
    {
      //  perror("Exiting.\n");
      foreach(subs, pid)
      {
	if(pid != getpid())
	  kill(pid, signum("SIGUSR1"));
      }
    }
  }
  // First kill off all listening sockets.. 
  foreach(indices(portno)||({}), o) 
    do_dest(o);

  // Then wait for all sockets, but maximum 10 minutes.. 
#if efun(_pipe_debug)
  call_out(lambda() { 
    call_out(Simulate.this_function(), 5);
    if(!_pipe_debug()[0])
    {
      werror("Exiting roxen (all connections closed).\n");
      stop_all_modules();
      exit(0);
    }
  }, 0.1);
#endif
  call_out(lambda(){
    werror("Exiting roxen (timeout).\n");
    stop_all_modules();
    exit(0);
  }, 600, 0); // Slow buggers..
}

void exit_it()
{
  perror("Recursive signals.\n");
  exit(0);
}

array fork_it();

array do_fork_it()
{ 
  catch(map(configuration_ports, destruct));
  if(objectp(main_configuration_port))
    destruct(main_configuration_port);
  main_configuration_port = 0;
  signal(signum("SIGUSR1"), exit_it);
  signal(signum("SIGUSR2"), exit_it);
  signal(signum("SIGHUP"), exit_it);
  signal(signum("SIGINT"), exit_it);
  return fork_it();
}

array fork_it()
{
  int howmany;
  howmany = QUERY(copies)-1;

  if(subs)
  {
    int pid;
    perror("Reaping old sub-processes.\n");
    foreach(subs, pid)
      kill(pid, signum("SIGUSR1"));
  }
  subs = ({ });

  if(howmany) 
    perror("Forking new sub-processes ("+howmany+").\n");

  while(howmany--)
  {
    int pid;
    if(pid = fork())
    {
      subs += ({ pid }); 
    } else {
      trace(0); // Debug..
      signal(signum("SIGUSR1"), exit_when_done);
      signal(signum("SIGHUP"), exit_when_done);
      signal(signum("SIGINT"), exit_when_done);
#if efun(send_fd)
      init_shuffler(); // No locking here. Each process need one on it's own.
#endif
      create_host_name_lookup_processes();
      main_configuration_port = 0;
      catch {
        if(root)
	  root->dest(); // This saves quite a lot of memory.. 
      };
      subs = ({});
      return 0;
    }
  }
#if efun(send_fd)
  init_shuffler(); // No locking here.. Each process need one on it's own.
#endif
  create_host_name_lookup_processes();
  signal(signum("SIGUSR1"), do_fork_it);
  signal(signum("SIGUSR2"), exit_when_done);
  signal(signum("SIGHUP"), exit_when_done);
  signal(signum("SIGINT"), exit_when_done);
  return subs;
}


// And then we have the main function, this is the oldest function in
// Roxen :) It has not changed all that much since Spider 2.0.

varargs int main(int argc, array (string) argv)
{
  mixed tmp;

  start_time=time(1);
  
  stdin->close();
  stdout->close();
  destruct(stdout);
  destruct(stdin);

  add_constant("write", perror);
  
  
  mark_fd(0, "Stdin");
  mark_fd(1, "Stdout");
  mark_fd(2, "Stderr");

#ifndef DUMPVARS
  configuration_dir = find_arg(argv, "d", ({ "config-dir",
					     "configurations",
					     "configuration-directory" }),
			       ({ "ROXEN_CONFIGDIR", "CONFIGURATIONS" }),
			       "../configurations");

  if(configuration_dir[-1] != "/")
    configuration_dir += "/";


  startpid = (int)find_arg(argv, "s", ({ "start-script-pid" }),
			   ({ "ROXEN_START_SCRIPT_PID"}));
  
  create_pid_file(find_arg(argv, "p", "pid-file", "ROXEN_PID_FILE"));

  if(tmp = find_arg(argv, "r", "root"))
    fix_root(tmp);

  argv -= ({ 0 });
  argc=sizeof(argv);

  perror("Restart initiated at "+ctime(time())); 
  
#endif
  
  define_global_variables(argc, argv);

#ifdef DUMPVARS
  perror("Dumping module variables...\n");
  dump_variables("Global", variables, ({ 0, "Global variables", 
					   "The variables below are all"
					   " global, and affect all virtual"
					   " servers.", 0, 0 }), 0, 0);
  configurations = ({ });

  variables->ModuleDirs[VAR_VALUE] |= ({ "localmodules/" });

  enable_configuration("&lt;servername&gt;");
  dump_variables("Configuration", current_configuration->variables,
		 ({ 0, "Configuration global variables",
		      "The variables below are global to a specific "
		      "configuration, and affect all modules in it.\n", 0, 0}),
		 0, 0);
  
  rescan_modules();
  exit(0);
#endif

  create_pid_file(QUERY(pidfile));

  restore_current_user_id_number();

#if efun(syslog)
  init_logger();
#endif

  init_garber();
  initiate_supports();
  initiate_languages();
  
  enable_configurations();

// Rebuild the configuration interface tree if the interface was
// loaded before the configurations was enabled (a configuration is a
// virtual server, perhaps the name should be changed internally as
// well.. :-)
  
  if(root) 
    configuration_interface()->build_root(root);
  
  call_out(update_supports_from_roxen_com,
	   QUERY(next_supports_update)-time());
  
  if(set_u_and_gid())
    perror("Setting UID and GID ...\n");

  if(fork_it())
  {
    int pid;
    initiate_configuration_port( 1 );
    perror("Time to boot: "+(time()-start_time)+" seconds.\n");
    perror("-------------------------------------\n\n");
  }
//  start_time=time();		// Used by the "uptime" info later on.
  return -1;
}



// Debug functions.  List _all_ open filedescriptors
inline static private string checkfd_fix_line(string l)
{
  string *s;
  s=l/",";
  s[0]=decode_mode((int)("0"+s[0]));
  if((int)s[1])
    s[1]=sizetostring((int)s[1]);
  else
    s[1]="-";
  return s[0..1]*",";
}


string checkfd(object|void id)
{
//  perror(sprintf("%O\n", get_all_active_fd()));
  
  return
    ("<h1>Active filedescriptors</h1>\n"+
     "<br clear=left><hr>\n"+
     "<table width=100% cellspacing=0 cellpadding=0>\n"+
     "<tr align=right><td>fd</td><td>type</td><td>mode</td>"+
     "<td>size</td></tr>\n"+
     (map(get_all_active_fd(),
	  lambda(int fd) 
	  {
	    return ("<tr align=right><th>"+fd+"</th><td>"+
		    replace(checkfd_fix_line(fd_info(fd)),",",
			    "</td><td>")
		    +"</td><td align=left>"
		    +(mark_fd(fd)||"")+"<br></td></tr>"); 
	  })*"\n")+
     "</table>");
}
