string cvs_version = "$Id: roxen.pike,v 1.38 1997/02/18 02:43:55 per Exp $";
#define IN_ROXEN

#include <fifo.h>
#include <module.h>
#include <variables.h>
#include <roxen.h>
#include <config.h>

#ifdef NO_DNS
inherit "dummy_hosts";
#else
inherit "hosts";
#endif

inherit "socket";
inherit "disk_cache";
inherit "language";

import Array;
import spider;

object roxen=this_object(), current_configuration;

private program Configuration;	/*set in create*/

object main_configuration_port;
mapping allmodules;

#if efun(send_fd)
int shuffle_fd;
#endif

// This is the real Roxen version. It should be changed before each
// release
string real_version = "Roxen Challenger/1.2 alpha"; 

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

  return bufplain[0..nbytesdecoded];
}
// End of what was formely known as decode.pike, the base64 decoder

// Function pointer and the root of the to the configuration interface
// object.
private function build_root;
private object root;


// Fork, and then do a 'slow-quit' in the forked copy. Exit the
// original copy, after all listen ports are closed.
// Then the forked copy finish all current connections.
private static void fork_or_quit()
{
  int i;
  object *f;
  int pid;
  perror("Exiting Roxen.\n");

#ifdef SOCKET_DEBUG
  perror("SOCKETS: fork_or_quit()\n                 Bye!\n");
#endif
  if(fork()) 
    exit(0);
#if efun(_pipe_debug)
  call_out(lambda() {  // Wait for all connections to finish
    call_out(backtrace()[-1][-1], 20);
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
  int q=QUERY(NumAccept);
  object file;
  array pn=portno[port];
  
#ifdef DEBUG
  if(!pn)
  {
    destruct(port->accept());
    perror("$&$$& Garbage Collector bug!!\n");
    return;
  }
#endif
  while(q--)
  {
    catch { file = port->accept(); };
#ifdef SOCKET_DEBUG
    if(!pn[-1])
    {
      report_error("In accept: Illegal protocol handler for port.\n");
      if(file) destruct(file);
      return;
    }
    perror(sprintf("SOCKETS: accept_callback(CONF(%s))\n", 
		   pn[1]&&pn[1]->name||"Configuration"));
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
	report_fatal("Out of sockets. Restarting server gracefully.\n");
	fork_or_quit();
	return;
      }
    }
#ifdef SOCKET_DEBUG
    mark_fd( file->query_fd(), "Connection from "+file->query_address());
#endif
    pn[-1](file,pn[1]);
#ifdef SOCKET_DEBUG
    perror(sprintf("SOCKETS:   Ok. Connect on %O:%O from %O\n", 
		   pn[2], pn[0], file->query_address()));
#endif
  }
}

#ifdef THREADS
#define THREAD_DEBUG

object (Queue) handle_queue = Queue();

void handler_thread(int id)
{
#ifdef THREAD_DEBUG
  perror("Handler thread "+id+" started.\n");
#endif
  array (mixed) h;
  while( h=handle_queue->read() )
  {
#ifdef THREAD_DEBUG
    perror(id+" START.\n");
#endif
#ifdef DEBUG
    array err=
#endif
      catch { h[0](@h[1]); };
#ifdef DEBUG
    if(err) perror("Error in handler thread:\n"+describe_backtrace(err)+"\n");
#endif
#ifdef THREAD_DEBUG
    perror(id+" DONE.\n");
#endif
    h=0;
  }
}

int number_of_threads;
void start_handler_threads()
{
  perror("Starting "+QUERY(numthreads)+" threads to handle requests.\n");
#if efun(thread_set_concurrency)
  thread_set_concurrency(QUERY(numthreads)+1);
#endif
  for(; number_of_threads < QUERY(numthreads); number_of_threads++)
    thread_create( handler_thread, number_of_threads );
}
#endif

void handle(function f, mixed ... args)
{
#ifdef THREADS
/*  thread_create(f, @args); */
  handle_queue->write(({f, args }));
#else
  f(@args);
#endif
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
  if(root && root->descend("Errors", 1))
  {
    mapping e = root->descend("Errors")->data;
    if(!e[s]) e[s]=({ time(1) });
    else e[s]+=({ time(1) });
  }
  perror(s);
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
	if(foo=Stdio.read_bytes(file))
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
  old = Stdio.read_bytes( "etc/supports" );
  
  if(strlen(new) < strlen(old)-200) // Error in transfer?
    return;
  
  if(old != new) {
    perror("Got new supports data from roxen.com\n");
    perror("Replacing old file with new data.\n");
    mv("etc/supports", "etc/supports~");
    Stdio.write_file("etc/supports", new);
    old = Stdio.read_bytes( "etc/supports" );
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

  // Check again in one week.
  QUERY(next_supports_update)=3600*24*7 + time();
  store("Variables", variables, 0, 0);

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

public void log(mapping file, object request_id)
{
  if(!request_id->conf) return; 
  request_id->conf->log(file, request_id);
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
    foo[0]+=conf->sent->mb()/(float)(time(1)-start_time+1);
    foo[1]+=conf->sent->mb();
    foo[2]+=conf->hsent->mb();
    foo[3]+=conf->received->mb();
    foo[4]+=conf->requests;
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

public string *userlist(object id)
{
  object current_configuration;
  if(!id) error("No id in userlist(object id)\n");
  current_configuration = id->conf;
  if(current_configuration->auth_module)
    return current_configuration->auth_module->userlist();
  return 0;
}

public string *user_from_uid(int u, object id)
{
  object current_configuration;
  if(!id) error("No id in user_from_uid(int uid, object id)\n");
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
public varargs string type_from_filename( string file, int to )
{
  mixed tmp;
  object current_configuration;
  string ext=extension(file);
    
  if(current_configuration = find_configuration_for(backtrace()[-2][-1]))
    current_configuration->type_from_filename( file, to );
}
  
#define COMPAT_ALIAS(X) mixed X(string file, object id){return id->conf->X(file,id);}

COMPAT_ALIAS(find_dir);
COMPAT_ALIAS(stat_file);
COMPAT_ALIAS(access);
COMPAT_ALIAS(real_file);
COMPAT_ALIAS(is_file);
COMPAT_ALIAS(userinfo);
  
public mapping|int get_file(object id, int|void no_magic)
{
  return id->conf->get_file(id, no_magic);
}

public mixed try_get_file(string s, object id, int|void status, int|void nocache)
{
  return id->conf->try_get_file(s,id,status,nocache);
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
  return ([ "data":Stdio.read_bytes("etc/restart.html"), "type":"text/html" ]);
} 

private array configuration_ports = ({  });
int startpid;



// This has to be refined in some way. It is not all that nice to do
// it like this (write a file in /tmp, and then exit.)  The major part
// of code to support this is in the 'start' script.
mapping shutdown() 
{
  catch(Array.map(indices(portno)), destruct);

  object privs = ((program)"privs")("Shutting down the server");
  // Change to root user.

  stop_all_modules();
  
  if(main_configuration_port && objectp(main_configuration_port))
  {
    // Only _really_ do something in the main process.
    int pid;
    catch(map(configuration_ports, destruct));
  
    perror("Shutting down Roxen.\n");
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
      kill(getppid(), signum("SIGINTR"));
      kill(getppid(), signum("SIGHUP"));
//	kill(startpid, signum("SIGKILL"));
    }
  }
  
  call_out(exit, 1, 0);
  return ([ "data":replace(Stdio.read_bytes("etc/shutdown.html"), "$PWD", getcwd()),
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
  if(file_stat(s+".pike"))
  {
    if(__p=compile_file(s+".pike"))
    {
      my_loaded[__p]=s+".pike";
      return __p();
    } else
      perror(s+".pike exists, but compilation failed.\n");
  }
  if(file_stat(s+".lpc"))
    if(__p=compile_file(s+".lpc"))
    {
      my_loaded[__p]=s+".lpc";
      return __p();
    } else
      perror(s+".lpc exists, but compilation failed.\n");
  if(file_stat(s+".module"))
    if(__p=load_module(s+".so"))
    {
      my_loaded[__p]=s+".so";
      return __p();
    } else
      perror(s+".so exists, but compilation failed.\n");
  return 0; // FAILED..
}

array(string) expand_dir(string d)
{
  string nd;
  array(string) dirs=({d});

//perror("Expand dir "+d+"\n");
  
  foreach((get_dir(d) || ({})) - ({"CVS"}) , nd) 
    if(file_stat(d+nd)[1]==-2)
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

void create()
{
  add_constant("roxen", this_object());
  (object)"color";
  (object)"fonts";
  Configuration = (program)"configuration";
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
//    if(!QUERY(IfModified))
//    {
//      perr("Setting the 'honor If-Modified-Since: flag to true. The "
//	   "bug\nin Roxen seems to be gone now.\n"); 
//      QUERY(IfModified) = 1;
//    }

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

object enable_configuration(string name)
{
  object cf = Configuration(name);
  configurations += ({ cf });
  return cf;
}

// Enable all configurations
static private void enable_configurations()
{
  array err;

  enabling_configurations = 1;
  catch {
    configurations = ({});
  
    foreach(list_all_configurations(), string config)
    {
      if(err=catch {
	enable_configuration(config)->start();
      })
	perror("Error while enabling configuration "+config+":\n"+
	       describe_backtrace(err)+"\n");
    }
  };
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


private void define_global_variables( int argc, array (string) argv )
{
  int p;
  // Hidden variables (compatibility ones, or internal or too
  // dangerous (in the case of chroot, the variable is totally
  // removed.
  
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
	  ({ 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024 }));
  

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
  

//  globvar("IfModified", 1, "Honor If-Modified-Since headers", TYPE_FLAG,
//	  "If set, send a 'Not modified' response in reply to "
//	  "if-modified-since headers, as "
//	  "<a href=http://www.w3.org/pub/WWW/Protocols/HTTP/1.1/spec"
//	  "#If-Modified-Since>specified by the HTTP draft.</a>");
  
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

#ifdef THREADS
  globvar("numthreads", 5, "Number of threads to run", TYPE_INT,
	  "The number of simultaneous threads roxen will use.\n"
	  "<p>Please note that even if this is one, Roxen will still "
	  " be able to serve multiple requests, using a select loop bases "
	  " system.\n"
	  "<i>This is quite useful if you have more than one CPU in "
	  "your machine, or if you have a lot of slow NFS accesses.</i>");
#endif
  
  globvar("AutoUpdate", 1, "Update the supports database automatically",
	  TYPE_FLAG, 
	  "If set, the etc/supports file will be updated automatically "
	  "from roxen.com now and then. This is recomended, since "
	  "you will then automatically get supports info for new "
	  "clients, and new versions of old ones.");

  globvar("next_supports_update", time()+3600, "", TYPE_INT,"",0,1);
  
  setvars(retrieve("Variables", 0));

  if(QUERY(_v) < CONFIGURATION_FILE_LEVEL)
  {
    update_global_vars(retrieve("Variables", 0)->_v?QUERY(_v):0);
    QUERY(_v) = CONFIGURATION_FILE_LEVEL;
    store("Variables", variables, 0, 0);
    set("_v", CONFIGURATION_FILE_LEVEL);
  }

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



// To avoid stack error :-) This is really a bug in Pike, that is
// probably fixed by now, but since I needed a catch() as well, I
// never did come around to removing the hack.

void do_dest(object|void o)
{
  catch {
    destruct(o);
  };
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
				(program)("protocols/"+port[1])))
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
      if(Stdio.file_size(path+file) == -2)
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
	  _master->set_inhibit_compile_errors( "" );
	  o =  (compile_file(file))();
#ifdef MODULE_DEBUG
	  perror(" load ok - ");
#endif
	  foo =  o->register_module();
#ifdef MODULE_DEBUG
	  perror("registered.");
#endif	  
	  return ({ foo[1], foo[2]+"<p><i>"+
		      replace(o->file_name_and_stuff(), "0<br>", file+"<br>")
		      +"</i>", foo[0] });
	}(path + file))))
	{
	  _master->set_inhibit_compile_errors( 0 );
	  allmodules[ file-("."+extension(file)) ] = module_info;
	} else {
	  perror(file+": "+describe_backtrace(err[sizeof(err)-4..])+
		 _master->set_inhibit_compile_errors( 0 ));
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
    _master->set_inhibit_compile_errors("");
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
  if(catch(Stdio.write_file(where, sprintf("%d\n%d", getpid(), getppid()))))
    perror("I cannot create the pid file ("+where+").\n");
}

void init_shuffler();
// External multi-threaded data shuffler. This leaves roxen free to
// serve new requests. The file descriptors of the open files and the
// clients are sent to the program, then the shuffler just shuffles 
// the data to the client.
void _shuffle(object from, object to)
{
  if(shuffle_fd)
  {
    if(send_fd(shuffle_fd,from->query_fd())&&
       send_fd(shuffle_fd,to->query_fd()))
      return;
    init_shuffler();
  }
#if efun(Pipe)
  object p = Pipe();
  p->input(from);
  p->output(to);
#else
  perror("Shuffle: using fallback(Ouch!)\n");
  // Fallback. Very unlikely.
  from->set_id(to->write);
  from->set_nonblocking(lambda(function w,string s){w(s);},lambda(){},
                        lambda(function w){destruct(function_object(w));});
#endif
}

#ifdef THREADS
object shuffle_queue = Queue();

void shuffle_thread()
{
  while(mixed s=shuffle_queue->read())
    _shuffle(@s);
}
void shuffle(object a, object b)
{
  shuffle_queue->write(({a,b}));
}
#else
function shuffle = _shuffle;
#endif

#ifdef THREADS
object st=thread_create(shuffle_thread);
#endif

  
object shuffler;
void init_shuffler()
{
  object out;
  object out2;
  if(file_stat("bin/shuffle"))
  {
    if(shuffler)
      destruct(shuffler);
    out=files.file();
    out2=out->pipe();
    mark_fd(out->query_fd(), "Data shuffler local end of pipe.\n");
    spawne("bin/shuffle", ({}), ({}), out2, Stdio.stderr, Stdio.stderr, 0, 0);
    perror("Spawning data mover. (bin/shuffle)\n"); 
    destruct(out2);
    shuffler = out;
    shuffle_fd = out->query_fd();
  }
}
#endif

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
    kill(getpid(), 9);
    kill(0, -9);
    exit(0);
  }

  // First kill off all listening sockets.. 
  foreach(indices(portno)||({}), o) 
    do_dest(o);

  // Then wait for all sockets, but maximum 10 minutes.. 
#if efun(_pipe_debug)
  call_out(lambda() { 
    call_out(backtrace()[-1][-1], 5);
    if(!_pipe_debug()[0])
    {
      werror("Exiting roxen (all connections closed).\n");
      stop_all_modules();
      kill(getpid(), 9);
      kill(0, -9);
      perror("Odd. I am not dead yet.\n");
      exit(0);
    }
  }, 0.1);
#endif
  call_out(lambda(){
    werror("Exiting roxen (timeout).\n");
    stop_all_modules();
    kill(getpid(), 9);
    kill(0, -9);
    exit(0);
  }, 600, 0); // Slow buggers..
}

void exit_it()
{
  perror("Recursive signals.\n");
  kill(getpid(), 9);
  kill(0, -9);
  exit(0);
}

void fork_it()
{
#ifdef THREADS
  start_handler_threads();
#endif
#if efun(send_fd)
  init_shuffler(); // No locking here.. Each process need one on it's own.
#endif
  create_host_name_lookup_processes();
  signal(signum("SIGUSR1"), exit_when_done);
  signal(signum("SIGUSR2"), exit_when_done);
  signal(signum("SIGHUP"), exit_when_done);
  signal(signum("SIGINT"), exit_when_done);
}



// And then we have the main function, this is the oldest function in
// Roxen :) It has not changed all that much since Spider 2.0.

varargs int main(int argc, array (string) argv)
{
  mixed tmp;

  start_time=time(1);

  add_constant("write", perror);
  
  
  mark_fd(0, "Stdin");
  mark_fd(1, "Stdout");
  mark_fd(2, "Stderr");

  configuration_dir = find_arg(argv, "d",({"config-dir","configuration-directory" }),
			       ({ "ROXEN_CONFIGDIR", "CONFIGURATIONS" }),
			       "../configurations");

  if(configuration_dir[-1] != "/")
    configuration_dir += "/";


  startpid = (int)find_arg(argv, "s", ({ "start-script-pid" }),
			   ({ "ROXEN_START_SCRIPT_PID"}));
  
  create_pid_file(find_arg(argv, "p", "pid-file", "ROXEN_PID_FILE"));

  // Dangerous...
  if(tmp = find_arg(argv, "r", "root")) fix_root(tmp);

  argv -= ({ 0 });
  argc=sizeof(argv);

  perror("Restart initiated at "+ctime(time())); 
  
  define_global_variables(argc, argv);

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
  {
    destruct(configuration_interface());
    configuration_interface()->build_root(root);
  }
  
  call_out(update_supports_from_roxen_com,
	   QUERY(next_supports_update)-time());
  
  if(set_u_and_gid())
    perror("Setting UID and GID ...\n");

  fork_it();

  initiate_configuration_port( 1 );
  perror("Time to boot: "+(time()-start_time)+" seconds.\n");
  perror("-------------------------------------\n\n");

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


string checkfd(object id)
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
