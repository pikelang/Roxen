constant cvs_version = "$Id: roxen.pike,v 1.176 1998/03/20 12:18:52 js Exp $";
#define IN_ROXEN
#include <roxen.h>
#include <config.h>
#ifdef THREADS
#include <fifo.h>
#endif
#include <module.h>
#include <variables.h>

inherit "read_config";
#ifdef __NT__
#define NO_DNS
#endif
#ifdef NO_DNS
inherit "dummy_hosts";
#else
inherit "hosts";
#endif
inherit "module_support";
inherit "socket";
inherit "disk_cache";
inherit "language";

#if constant(spider.shuffle)
program pipe = (program)"smartpipe";
#else
program pipe = Pipe.pipe;
#endif

// This is the real Roxen version. It should be changed before each
// release
constant __roxen_version__ = "1.2";
constant __roxen_build__ = "21";

#ifdef __NT__
constant real_version = "Roxen Challenger/"+__roxen_version__+"."+__roxen_build__+" NT";
#else
constant real_version = "Roxen Challenger/"+__roxen_version__+"."+__roxen_build__;
#endif

#if _DEBUG_HTTP_OBJECTS
mapping httpobjects = ([]);
static int idcount;
int new_id(){ return idcount++; }
#endif

#ifdef MODULE_DEBUG
#define MD_PERROR(X)	perror X;
#else
#define MD_PERROR(X)
#endif /* MODULE_DEBUG */

object roxen=this_object(), current_configuration;

private program Configuration;	/*set in create*/

array configurations = ({});
object main_configuration_port;
mapping allmodules, somemodules=([]);

// A mapping from ports (objects, that is) to an array of information
// about that port.  This will hopefully be moved to objects cloned
// from the configuration object in the future.
mapping portno=([]);

constant decode = MIME.decode_base64;

// Function pointer and the root of the configuration interface
// object.
private function build_root;
private object root;

#ifdef THREADS
// This mutex is used by privs.pike
object euid_egid_lock = Thread.Mutex();
#endif /* THREADS */

int privs_level;
int die_die_die;

// Fork, and then do a 'slow-quit' in the forked copy. Exit the
// original copy, after all listen ports are closed.
// Then the forked copy can finish all current connections.
private static void fork_or_quit()
{
  int i;
  object *f;
  int pid;
  perror("Exiting Roxen.\n");

#ifdef SOCKET_DEBUG
  perror("SOCKETS: fork_or_quit()\n                 Bye!\n");
#endif

#if constant(fork) && !defined(THREADS)

  if(fork()) 
    exit(-1);	// Restart.
  // Now we're running in the forked copy.

  // FIXME: This probably doesn't work correctly on threaded servers,
  // since only one thread is left running after the fork().
#if efun(_pipe_debug)
  call_out(lambda() {  // Wait for all connections to finish
    call_out(Simulate.this_function(), 20);
    if(!_pipe_debug()[0]) exit(0);
  }, 1);
#endif /* efun(_pipe_debug) */
  call_out(lambda(){ exit(0); }, 600); // Slow buggers..
  f=indices(portno);
  for(i=0; i<sizeof(f); i++)
    catch(destruct(f[i]));
#else /* !constant(fork) */

  // FIXME:
  // Should probably attempt something similar to the above,
  // but this should be sufficient for the time being.
  exit(-1);	// Restart

#endif /* constant(fork) */
}

// This is called for each incoming connection.
private static void accept_callback( object port )
{
  object file;
  int q=QUERY(NumAccept);
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
#if constant(real_perror)
	real_perror();
#endif
#endif /* DEBUG */
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

void unthreaded_handle(function f, mixed ... args)
{
  f(@args);
}

function handle = unthreaded_handle;

#ifdef THREADS
#define THREAD_DEBUG

object do_thread_create(string id, function f, mixed ... args)
{
  object t = thread_create(f, @args);
  catch(t->set_name( id ));
  werror(id+" started\n");
  return t;
}

object (Queue) handle_queue = Queue();

void handler_thread(int id)
{
  array (mixed) h, q;
  while(1)
  {
    if(q=catch {
      do {
	if((h=handle_queue->read()) && h && h[0]) {
	  h[0](@h[1]);
	  h=0;
	}
      } while(1);
    }) {
      report_error("Uncaught error in handler thread: " +
		   describe_backtrace(q) +
		   "Client will not get any response from Roxen.\n");
      if (q = catch {h = 0;}) {
	report_error("Uncaught error in handler thread: " +
		     describe_backtrace(q) +
		     "Client will not get any response from Roxen.\n");
		     
      }
      
    }
  }
}

void threaded_handle(function f, mixed ... args)
{
  handle_queue->write(({f, args }));
}

int number_of_threads;
void start_handler_threads()
{
  if (QUERY(numthreads) <= 1) {
    QUERY(numthreads) = 1;
    perror("Starting 1 thread to handle requests.\n");
  } else {
    perror("Starting "+QUERY(numthreads)+" threads to handle requests.\n");
  }
  for(; number_of_threads < QUERY(numthreads); number_of_threads++)
    do_thread_create( "Handle thread ["+number_of_threads+"]",
		   handler_thread, number_of_threads );
  if(number_of_threads > 0)
    handle = threaded_handle;
}

mapping accept_threads = ([]);
void accept_thread(object port,array pn)
{
  accept_threads[port] = this_thread();
  program port_program = pn[-1];
  mixed foo = pn[1];
  array err;
  object o;
  while(!die_die_die)
  {
    o = port->accept();
    err = catch {
      if(o) port_program(o,foo);
    };
    if(err)
      perror("Error in accept_thread: %O\n",describe_backtrace(err));
  }
}

#endif /* THREADS */



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
			    string|void ether, program requestprogram,
			    array prt)
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
    port = Stdio.Port( "stdin", accept_callback );
    port->set_id(port);
    if(port->errno())
    {
      report_error("Cannot listen to stdin.\n"
		   "Errno is "+port->errno()+"\n");
    }
  } else {
    port = Stdio.Port();
    port->set_id(port);
    if(!stringp(ether) || (lower_case(ether) == "any"))
      ether=0;
    if(ether)
      sscanf(ether, "addr:%s", ether);
#if defined(THREADS) && 0
    if(!port->bind(port_no, 0, ether))
#else
    if(!port->bind(port_no, accept_callback, ether))
#endif
    {
#ifdef SOCKET_DEBUG
      perror("SOCKETS:    -> Failed.\n");
#endif
      report_error("Failed to open socket on "+ether+":"+port_no+
		   " (already bound?)\nErrno is: "+ port->errno()+"\n");
      return 0;
    }
  }
  portno[port]=({ port_no, conf, ether||"Any", 0, requestprogram });
#if defined(THREADS) && 0
  call_out(do_thread_create,0,"Accept thread ["+port_no+":"+(ether||"ANY]"),
	   accept_thread, port,portno[port]);
#endif
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
    array err = catch {
      configuration_interface_obj=((program)"mainconfig")();
      root = configuration_interface_obj->root;
    };
    loading_config_interface = 0;
    if(!configuration_interface_obj) {
      report_error(sprintf("Failed to load the configuration interface!\n"));
    }
  }
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
#ifdef THREADS
object configuration_lock = Thread.Mutex();
#endif

mixed configuration_parse(mixed ... args)
{
#ifdef THREADS
  object key;
  catch(key = configuration_lock->lock());
#endif
  if(args)
    return configuration_interface()->configuration_parse(@args);
}

mapping(string:array(int)) error_log=([]);

string last_error="";

// Write a string to the configuration interface error log and to stderr.
void nwrite(string s, int|void perr, int|void type)
{
  last_error = s;
  if (!error_log[type+","+s]) {
    error_log[type+","+s] = ({ time() });
  } else {
    error_log[type+","+s] += ({ time() });
  }
  if(type>1) roxen_perror(s);
}
 


// When was Roxen started?
int start_time;

string version()
{
  return QUERY(default_ident)?real_version:QUERY(ident);
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
  new = (new/"\r\n\r\n")[1..]*"\r\n\r\n";
  old = Stdio.read_bytes( "etc/supports" );
  
  if(strlen(new) < strlen(old)-200) // Error in transfer?
    return;
  
  if(old != new) {
    perror("Got new supports data from www.roxen.com\n");
    perror("Replacing old file with new data.\n");
#ifndef THREADS
    object privs=Privs("Replacing etc/supports");
#endif
    mv("etc/supports", "etc/supports~");
    Stdio.write_file("etc/supports", new);
    old = Stdio.read_bytes( "etc/supports" );
#if efun(chmod)
#if efun(geteuid)
    if(geteuid() != getuid()) chmod("etc/supports",0660);
#endif
#endif
    if(old != new)
    {
      perror("FAILED to update the supports file.\n");
      mv("etc/supports~", "etc/supports");
#ifndef THREADS
      privs = 0;
#endif
    } else {
#ifndef THREADS
      privs = 0;
#endif
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
  string v = version();
  if (v != real_version) {
    v = v + " (" + real_version + ")";
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
  if(QUERY(next_supports_update) <= time())
  {
    if(QUERY(AutoUpdate))
    {
      async_connect("www.roxen.com.", 80, connected_to_roxen_com);
#ifdef DEBUG
      perror("Connecting to www.roxen.com.:80\n");
#endif
    }
    remove_call_out( update_supports_from_roxen_com );

  // Check again in one week.
    QUERY(next_supports_update)=3600*24*7 + time();
    store("Variables", variables, 0, 0);
  }
  call_out(update_supports_from_roxen_com, QUERY(next_supports_update)-time());
}

// Return a list of 'supports' values for the current connection.

public multiset find_supports(string from)
{
  multiset (string) sup = (< >);
  multiset (string) nsup = (< >);

  array (function|multiset) s;
  string v;
  array f;
  
  if(!(< "unknown", "" >)[from])
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
      perror("Unknown client: \""+from+"\"\n");
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
  
  foreach(configurations, object conf)
  {
    if(!conf->sent
       ||!conf->received
       ||!conf->hsent)
      continue;
    foo[0] += conf->sent->mb()/(float)(time(1)-start_time+1);
    foo[1] += conf->sent->mb();
    foo[2] += conf->hsent->mb();
    foo[3] += conf->received->mb();
    foo[4] += conf->requests;
  }

  for(tmp = 1; tmp < 4; tmp ++)
  {
    if(foo[tmp] < 1024.0)     
      foo[tmp] = sprintf("%.2f MB", foo[tmp]);
    else
      foo[tmp] = sprintf("%.2f GB", foo[tmp]/1024.0);
  }

  res = sprintf("<table><tr><td><b>Sent data:</b></td><td>%s"
		"</td><td>%.2f Kbit/sec</td></tr><tr>\n",
		foo[1], foo[0] * 8192.0);
  
  res += "<td><b>Sent headers:</b></td><td>"+ foo[2] +"</td></tr>\n";
	    
  tmp=(int)(foo[4]*600.0)/((time(1)-start_time)+1);

  res += (sprintf("<tr><td><b>Number of requests:</b></td>"
		  "<td>%8d</td><td>%.2f/min</td></tr>\n"
		  "<tr><td><b>Received data:</b></td>"
		  "<td>%s</td></tr>\n",
		  foo[4], (float)tmp/(float)10, foo[3]));
  
  return res +"</table>";
}


// These are now more or less outdated, the modules really _should_
// pass the information about the current configuration to roxen,
// to enable async operations. This information is in id->conf.
//
// In the future, most, if not all, of these functions will be moved
// to the configuration object. The functions will still be here for
// compatibility for a while, though.

public string *userlist(void|object id)
{
  if(id) current_configuration = id->conf;
  if(current_configuration && current_configuration->auth_module)
    return current_configuration->auth_module->userlist();
  return 0;
}

public string *user_from_uid(int u, void|object id)
{
  if(id) current_configuration = id->conf;
  if(current_configuration && current_configuration->auth_module)
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
public array|string type_from_filename( string|void file, int|void to )
{
  mixed tmp;
  object current_configuration;
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
    return to?tmp:tmp[0]; // Per..
  }
  return 0;
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

int config_ports_changed = 0;
// Called from the configuration interface.
string check_variable(string name, string value)
{
  switch(name)
  {
   case "ConfigPorts":
     config_ports_changed = 1;
     break;
   case "cachedir":
    if(!sscanf(value, "%*s/roxen_cache"))
    {
      object node;
      node = (configuration_interface()->root->descend("Globals", 1)->
	      descend("Proxy disk cache: Base Cache Dir", 1));
      if(node && !node->changed) node->change(1);
      mkdirhier(value+"roxen_cache/foo");
      call_out(set, 0, "cachedir", value+"roxen_cache/");
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
  call_out(fork_or_quit, 5, -1);
  return ([ "data": replace(Stdio.read_bytes("etc/restart.html"),
			    ({"$docurl", "$PWD"}), ({roxen->docurl, getcwd()})),
		  "type":"text/html" ]);
} 

private array configuration_ports = ({  });
int startpid, roxenpid;



// This has to be refined in some way. It is not all that nice to do
// it like this (write a file in /tmp, and then exit.)  The major part
// of code to support this is in the 'start' script.
void kill_me()
{
  // Change to root user if possible ( to kill the start script... )
#if efun(seteuid)
  seteuid(getuid());
  setegid(getgid());
#endif
#if efun(setuid)
  setuid(0);
#endif
  stop_all_modules();
  
  if(main_configuration_port && objectp(main_configuration_port))
  {
    // Only _really_ do something in the main process.
    int pid;
    perror("Shutting down Roxen.\n");

#ifdef USE_SHUTDOWN_FILE

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

#endif /* USE_SHUTDOWN_FILE */
  }
  // Die nicely (we're shutting down).
  call_out(exit, 2, 0);
}

mapping shutdown() 
{
  call_out(kill_me, 5, 0);
  return ([ "data":replace(Stdio.read_bytes("etc/shutdown.html"),
			   ({"$docurl", "$PWD"}), ({roxen->docurl, getcwd()})),
	    "type":"text/html" ]);
} 

private string docurl;

// I will remove this in a future version of roxen.
private program __p;
private mapping my_loaded = ([]);
program last_loaded() { return __p; }

string last_module_name;

string filename(object o)
{
  return my_loaded[object_program(o)]||last_module_name;
}

program my_compile_file(string file)
{
  return compile_file( file );
}

// ([ filename:stat_array ])
mapping(string:array) module_stat_cache = ([]);
object load(string s, object conf)   // Should perhaps be renamed to 'reload'. 
{
  string cvs;
  array st;
  sscanf(s, "/cvs:%s", cvs);

//  perror("Module is "+s+"?");
  if(st=file_stat(s+".pike"))
  {
//    perror("Yes, compile "+s+"?");
    if((cvs?(__p=master()->cvs_load_file( cvs+".pike" ))
	:(__p=my_compile_file(s+".pike"))))
    {
//      perror("Yes.");
      my_loaded[__p]=s+".pike";
      module_stat_cache[s-dirname(s)]=st;
      return __p(conf);
    } else
      perror(s+".pike exists, but compilation failed.\n");
  }
  if(st=file_stat(s+".lpc"))
    if(cvs?(__p=master()->cvs_load_file( cvs+".lpc" )):
       (__p=my_compile_file(s+".lpc")))
    {
      my_loaded[__p]=s+".lpc";
      module_stat_cache[s-dirname(s)]=st;
      return __p(conf);
    } else
      perror(s+".lpc exists, but compilation failed.\n");
  if(st=file_stat(s+".module"))
    if(__p=load_module(s+".so"))
    {
      my_loaded[__p]=s+".so";
      module_stat_cache[s-dirname(s)]=st;
      return __p(conf);
    } else
      perror(s+".so exists, but compilation failed.\n");
  return 0; // FAILED..
}

array(string) expand_dir(string d)
{
  string nd;
  array(string) dirs=({d});

//perror("Expand dir "+d+"\n");
  catch {
    foreach((get_dir(d) || ({})) - ({"CVS"}) , nd) 
      if(file_stat(d+nd)[1]==-2)
	dirs+=expand_dir(d+nd+"/");
  }; // This catch is needed....
  return dirs;
}

array(string) last_dirs=0,last_dirs_expand;


object load_from_dirs(array dirs, string f, object conf)
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
     if ( (o=load(dir+f, conf)) ) return o;

  return 0;
}

void create()
{
  catch
  {
    module_stat_cache = decode_value(Stdio.read_bytes(".module_stat_cache"));
    allmodules = decode_value(Stdio.read_bytes(".allmodules"));
  };
  add_constant("roxen", this_object());
  add_constant("spinner", this_object());
  add_constant("load",    load);
  (object)"color.pike";
  (object)"fonts.pike";
  Configuration = (program)"configuration";
}


// Get the current domain. This is not as easy as one could think.
private string get_domain(int|void l)
{
  array f;
  string t, s;

//  ConfigurationURL is set by the 'install' script.
  if(!(!l && sscanf(QUERY(ConfigurationURL), "http://%s:%*s", s)))
  {
#if efun(gethostbyname)
#if efun(gethostname)
    f = gethostbyname(gethostname()); // First try..
    if(f)
      foreach(f, f) if (arrayp(f)) { 
	foreach(f, t) if(search(t, ".") != -1 && !(int)t)
	  if(!s || strlen(s) < strlen(t))
	    s=t;
      }
#endif
#endif
    if(!s)
    {
      t = Stdio.read_bytes("/etc/resolv.conf");
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
#if efun(gethostname)
  s = (gethostname()/".")[0] + "." + query("Domain");
#else
  s = "localhost";
#endif
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
#ifndef __NT__
  string u, g;
  array pw;
  
  u=QUERY(User);
  sscanf(u, "%s:%s", u, g);
  if(strlen(u))
  {
    if(getuid())
    {
      perror("It is not possible to change uid and gid if the server\n"
             "is not started as root.\n");
    } else {
      if(pw = getpwnam(u))
      {
	u = (string)pw[2];
	if(!g) g = (string)pw[3];
      } else
	pw = getpwuid((int)u);
#if efun(initgroups)
      catch {
	if(pw)
	  initgroups(pw[0], (int)g);
	// Doesn't always work - David.
      };
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
      report_notice("Setting UID to "+u+" and GID to "+g);
      return 1;
    }
  }
#endif
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

    if(search(QUERY(ident), "Spinner")!=-1) {
      QUERY(ident) = real_version;
      perr("Updating version field to "+real_version+"\n");
    }

    if(search(QUERY(ident), "Enterprice")!=-1)
      QUERY(ident) = real_version;
    else if(search(QUERY(ident), "Challenger")!=-1)
      QUERY(ident) = real_version;
    if(((!search(QUERY(ident), "Roxen Challenger/1.0")) ||
	(!search(QUERY(ident), "Roxen Challenger/1.1"))) &&
       (replace(QUERY(ident),"·"," ") != real_version)) {
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
  current_configuration = cf;
  report_notice("Enabled the virtual server \""+name+"\".");
  
  return cf;
}

// Enable all configurations
void enable_configurations()
{
  array err;

  enabling_configurations = 1;
  configurations = ({});
  foreach(list_all_configurations(), string config)
  {
    if(err=catch { enable_configuration(config)->start();  })
      perror("Error while loading configuration "+config+":\n"+
	     describe_backtrace(err)+"\n");
  };
  foreach(configurations, object config)
  {
    if(err=catch { config->enable_all_modules();  })
      perror("Error while loading modules in configuration "+config->name+":\n"+
	     describe_backtrace(err)+"\n");
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
    if(tmp[1][0..2]=="ssl") 
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

  prot = (port[1][0..2]!="ssl"?port[1]:"https");
  p = port[0];

  return (prot+"://"+host+":"+p+"/");
}


// The following three functions are used to hide variables when they
// are not used. This makes the user-interface clearer and quite a lot
// less clobbered.
  
int cache_disabled_p() { return !QUERY(cache);         }
int syslog_disabled()  { return QUERY(LogA)!="syslog"; }
private int ident_disabled_p() { return QUERY(default_ident); }

private void define_global_variables( int argc, array (string) argv )
{
  int p;
  globvar("set_cookie", 0, "Set unique user id cookies", TYPE_FLAG,
	  "If set to Yes, all users of your server whose clients support "
	  "cookies will get a unique 'user-id-cookie', this can then be "
	  "used in the log and in scripts to track individual users.");

  globvar("set_cookie_only_once",1,"Set ID cookies only once",TYPE_FLAG,
	  "If set to Yes, Roxen will attempt to set unique user ID cookies "
	  "only upon receiving the first request (and again after some "
	  "minutes). Thus, if the user doesn't allow the cookie to be set, "
	  "he won't be bothered with multiple requests",0,
	  lambda() {return !QUERY(set_cookie);});

  globvar("show_internals", 1, "Show the internals", TYPE_FLAG,
	  "Show 'Internal server error' messages to the user. "
	  "This is very useful if you are debugging your own modules "
	  "or writing Pike scripts.");
  
  
  // Hidden variables (compatibility ones, or internal or too
  // dangerous
/*  globvar("BS", 0, "Configuration interface: Compact layout",*/
/*	  TYPE_FLAG|VAR_EXPERT,*/
/*	  "Sick and tired of all those images? Set this variable to 'Yes'!");*/
/*  globvar("BG", 1,  "Configuration interface: Background",*/
/*	  TYPE_FLAG|VAR_EXPERT,*/
/*	  "Should the background be set by the configuration interface?");*/

  globvar("_v", CONFIGURATION_FILE_LEVEL, 0, TYPE_INT, 0, 0, 1);
  globvar("default_font_size", 32, 0, TYPE_INT, 0, 0, 1);


  globvar("default_font", "lucida", "Fonts: Default font", TYPE_FONT,
	  "The default font to use when modules request a font.");

  globvar("font_dirs", ({"../local/nfonts/", "nfonts/" }),
	  "Fonts: Font directories", TYPE_DIR_LIST,
	  "This is where the fonts are located.");

  globvar("logdirprefix", "../logs/", "Log directory prefix",
	  TYPE_DIR|VAR_MORE,
	  "This is the default file path that will be prepended to the log "
	  " file path in all the default modules and the virtual server.");
  

  // Cache variables. The actual code recides in the file
  // 'disk_cache.pike'
  
  globvar("cache", 0, "Proxy disk cache: Enabled", TYPE_FLAG,
	  "If set to Yes, caching will be enabled.");
  
  globvar("garb_min_garb", 1, "Proxy disk cache: Clean size", TYPE_INT,
	 "Minimum number of Megabytes removed when a garbage collect is done",
	  0, cache_disabled_p);

  globvar("cache_minimum_left", 5, "Proxy disk cache: Minimum "
	  "available free space and inodes (in %)", TYPE_INT,
	  "If less than this amount of disk space or inodes (in %) is left, "
	  "the cache will remove a few files. This check may work "
	  "half-hearted if the diskcache is spread over several filesystems.",
	  0,
#if efun(filesystem_stat)
	  cache_disabled_p
#else
	  1
#endif /* filesystem_stat */
	  );
  
  globvar("cache_size", 25, "Proxy disk cache: Size", TYPE_INT,
        "How many MB may the cache grow to before a garbage collect is done?",
	  0, cache_disabled_p);

  globvar("cache_max_num_files", 0, "Proxy disk cache: Maximum number "
	  "of files", TYPE_INT, "How many cache files (inodes) may "
	  "be on disk before a garbage collect is done ? May be left "
	  "zero to disable this check.",
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
  
  globvar("cache_keep_without_content_length", 1, "Proxy disk cache: "
	  "Keep without Content-Length", TYPE_FLAG, "Keep files "
	  "without Content-Length header information in the cache ?",
	  0, cache_disabled_p);

  globvar("cache_check_last_modified", 0, "Proxy disk cache: "
	  "Refresh on Last-Modified", TYPE_FLAG,
	  "If set, refreshes files without Expire header information "
	  "when they have reached double the age they had when they got "
	  "cached. This may be useful for some regularly updated docs as "
	  "online newspapers.",
	  0, cache_disabled_p);

  globvar("cache_last_resort", 0, "Proxy disk cache: "
	  "Last resort (in days)", TYPE_INT,
	  "How many days shall files without Expires and without "
	  "Last-Modified header information be kept ?",
	  0, cache_disabled_p);

  globvar("cache_gc_logfile",  "",
	  "Proxy disk cache: "
	  "Garbage collector logfile", TYPE_FILE,
	  "Information about garbage collector runs, removed and refreshed "
	  "files, cache and disk status goes here.",
	  0, cache_disabled_p);

  /// End of cache variables..
  
  globvar("docurl2", "http://www.roxen.com/documentation/context.pike?page=",
	  "Documentation URL", TYPE_STRING|VAR_MORE,
	 "The URL to prepend to all documentation urls throughout the "
	 "server. This URL should _not_ end with a '/'.");

  globvar("pidfile", "/tmp/roxen_pid:$uid", "PID file",
	  TYPE_FILE|VAR_MORE,
	  "In this file, the server will write out it's PID, and the PID "
	  "of the start script. $pid will be replaced with the pid, and "
	  "$uid with the uid of the user running the process.");

  globvar("default_ident", 1, "Identify: Use default identification string",
	  TYPE_FLAG|VAR_MORE,
	  "Setting this variable to No will display the \"Identify as\" node "
	  "where you can state what Roxen should call itself when talking "
	  "to clients, otherwise it will present it self as \""+ real_version
	  +"\".<br>"
	  "It is possible to disable this so that you can enter an "
	  "identification-string that does not include the actual version of "
	  "Roxen, as recommended by the HTTP/1.0 draft 03:<p><blockquote><i>"
	  "Note: Revealing the specific software version of the server "
	  "may allow the server machine to become more vulnerable to "
	  "attacks against software that is known to contain security "
	  "holes. Server implementors are encouraged to make this field "
	  "a configurable option.</i></blockquote>");

  globvar("ident", replace(real_version," ","·"), "Identify: Identify as",
	  TYPE_STRING /* |VAR_MORE */,
	  "Enter the name that Roxen should use when talking to clients. ",
	  0, ident_disabled_p);


  globvar("DOC", 1, "Configuration interface: Help texts", TYPE_FLAG|VAR_MORE,
	  "Do you want documentation? (this is an example of documentation)");


  globvar("NumAccept", 1, "Number of accepts to attempt",
	  TYPE_INT_LIST|VAR_MORE,
	  "You can here state the maximum number of accepts to attempt for "
	  "each read callback from the main socket. <p> Increasing this value "
	  "will make the server "
	  "faster for users making many simultaneous connections to it, or"
	  " if you have a very busy server. <p> It won't work on some systems"
	  ", though, eg. IBM AIX 3.2<p> To see if it works, change this"
	  " variable, <b> but don't press save</b>, and then try connecting to"
	  " your server. If it works, come back here and press the save button"
	  ". <p> If it doesn't work, just restart the server and be happy "
	  "with having '1' in this field.<p>"
	  "The higher you set this value, the less load balancing between "
	  "virtual servers. (If there are 256 more or less simultaneous "
	  "requests to server 1, and one to server 2, and this variable is "
	  "set to 256, the 256 accesses to the first server might very well "
	  "be handled before the one to the second server.)",
	  ({ 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024 }));
  

  globvar("ConfigPorts", ({ ({ 22202, "http", "ANY", "" }) }),
	  "Configuration interface: Ports",
	  TYPE_PORTS,
	  "These are the ports through which you can configure the"
	  "server.<br>Note that you should at least have one open port, since "
	  "otherwise you won't be able to configure your server.");
  
  globvar("ConfigurationURL", 
	  "",
          "Configuration interface: URL", TYPE_STRING,
	  "The URL of the configuration interface. This is used to "
	  "generate redirects now and then (when you press save, when "
	  "a module is added, etc.).");
  
  globvar("ConfigurationPassword", "", "Configuration interface: Password", 
	  TYPE_PASSWORD|VAR_EXPERT,
	  "The password you will have to enter to use the configuration "
	  "interface. Please note that changing this password in the "
	  "configuration interface will _not_ require an additional entry "
	  "of the password, so it is easy to make a typo. It is recommended "
	  "that you use the <a href=/(changepass)/Globals/>form instead</a>.");
  
  globvar("ConfigurationUser", "", "Configuration interface: User", 
	  TYPE_STRING|VAR_EXPERT,
	  "The username you will have to enter to use the configuration "
	  "interface");
  
  globvar("ConfigurationIPpattern","*", "Configuration interface: IP-Pattern", 
	  TYPE_STRING|VAR_MORE,
	  "Only clients running on computers with IP numbers matching"
	  "this pattern will be able to use the configuration"
	  "interface.");
  
  globvar("User", "", "Change uid and gid to", TYPE_STRING,
	  "When roxen is run as root, to be able to open port 80 "
	  "for listening, change to this user-id and group-id when the port "
	  " has been opened. If you specify a symbolic username, the "
	  "default group of that user will be used. "
	  "The syntax is user[:group].");

#ifdef EXTERNAL_HOSTNAME_PROCESS
  globvar("NumHostnameLookup", 2, "Number of hostname lookup processes", 
	  TYPE_INT|VAR_MORE,
	  "You can here state the number of simultaneos host-name lookup "
	  "processes Roxen should run. Roxen must be restarted for a change "
	  "of this variable to take effect. If you constantly see a large "
	  "host name lookup queue size in the configuration interface "
	  "'Actions->Status' section, consider increasing this variable. "
	  "A good guidline is: "
	  "<ul>\n"
	  "<li> 1 for normal operation\n"
	  "<li> 1 extra for each 300 000 accesses/day\n"
	  "<li> 1 for each proxy\n"
	  "<li> 1 for each 100 proxy users\n"
	  "</ul>\n",0,1);
#endif
  
  globvar("ModuleDirs", ({ "../local/modules/", "modules/" }),
	  "Module directories", TYPE_DIR_LIST,
	  "This is a list of directories where Roxen should look for "
	  "modules. Can be relative paths, from the "
	  "directory you started roxen, " + getcwd() + " this time."
	  " The directories are searched in order for modules.");
  
  globvar("Supports", "#include <etc/supports>\n", 
	  "Client supports regexps", TYPE_TEXT_FIELD|VAR_MORE,
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
  
  globvar("audit", 0, "Audit trail", TYPE_FLAG,
	  "If Audit trail is set to Yes, all changes of uid will be "
	  "logged in the Event log.");
  
#if efun(syslog)
  globvar("LogA", "file", "Logging method", TYPE_STRING_LIST|VAR_MORE, 
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
	  "When syslog is used, this will be the identification of the"
	  "Roxen daemon. The entered value will be appended to all logs.",
	  0, syslog_disabled);
#endif

#ifdef THREADS
  globvar("numthreads", 5, "Number of threads to run", TYPE_INT,
	  "The number of simultaneous threads roxen will use.\n"
	  "<p>Please note that even if this is one, Roxen will still "
	  "be able to serve multiple requests, using a select loop based "
	  "system.\n"
	  "<i>This is quite useful if you have more than one CPU in "
	  "your machine, or if you have a lot of slow NFS accesses.</i>");
#endif
  
  globvar("AutoUpdate", 1, "Update the supports database automatically",
	  TYPE_FLAG, 
	  "If set to Yes, the etc/supports file will be updated automatically "
	  "from www.roxen.com now and then. This is recomended, since "
	  "you will then automatically get supports information for new "
	  "clients, and new versions of old ones.");

  globvar("next_supports_update", time()+3600, "", TYPE_INT,"",0,1);
  
#ifdef ENABLE_NEIGHBOURHOOD
  globvar("neighborhood", 0,
	  "Neighborhood: Register with other Roxen servers on the local network"
	  ,TYPE_FLAG|VAR_MORE,
	  "If this option is set, Roxen will automatically broadcast it's "
	  "existence to other Roxen servers on the local network");

  globvar("neigh_tcp_ips",  ({}), "Neighborhood: TCP hosts",
  TYPE_STRING_LIST|VAR_MORE,
  "This is the list of direct host<-->host links to establish. "
  "The local host is always present (if the neighbourhood functionality "
    "is at all enabled)");


  globvar("neigh_ips",  ({lambda(){
    catch {
      mixed foo = gethostbyname(gethostname());
      string n = reverse(foo[1][0]);
      sscanf(n,"%*d.%s", n);
      n=reverse(n)+".";
    // Currently only defaults to C-nets..
      return n+"255";
    };
    return "0.0.0.0";
  }()}), "Neighborhood: Broadcast addresses", TYPE_STRING_LIST|VAR_MORE,
  "");

  globvar("neigh_com", "", "Neighborhood: Server informational comment",
	  TYPE_TEXT|VAR_MORE, "A short string describing this server");
#endif /* ENABLE_NEIGHBOURHOOD */  

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
  docurl=QUERY(docurl2);
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

// return all available fonts. Taken from the font_dirs list.
array font_cache;
array available_fonts(int cache)
{
  array res = ({});
  if(cache && font_cache) return font_cache;
  foreach(QUERY(font_dirs), string dir)
  {
    dir+="32/";
    array d;
    if(array d = get_dir(dir))
    {
      foreach(d,string f)
      {
	if(f=="CVS") continue;
	array a;
	if((a=file_stat(dir+f)) && (a[1]==-2))
	  res |= ({ replace(f,"_"," ") });
      }
    }
  }
  sort(res);
  return font_cache = res;
}


// Somewhat misnamed, since there can be more then one
// configuration-interface port nowdays. But, anyway, this function
// opens and listens to all configuration interface ports.

void initiate_configuration_port( int|void first )
{
  object o;
  array port;

  // Hm.
  if(!first && !config_ports_changed )
    return 0;
  
  config_ports_changed = 0;

#ifndef THREADS  
  if(catch(Array.map(configuration_ports, destruct)))
    catch(Array.map(configuration_ports, do_dest));
  
  catch(do_dest(main_configuration_port));
  
  configuration_ports = ({ });
#endif
  main_configuration_port=0;

  current_configuration = 0;
  if(sizeof(QUERY(ConfigPorts)))
  {
    foreach(QUERY(ConfigPorts), port)
    {
      array old = port;
      mixed erro;
      erro = catch {
	if ((< "ssl", "ssleay" >)[port[1]]) {
	  // Obsolete versions of the SSL protocol.
	  report_warning("Obsolete SSL protocol-module \""+port[1]+"\".\n"
			 "Converted to SSL3.\n");
	  port[1] = "ssl3";
	}
	program requestprogram = (program)(getcwd()+"/protocols/"+port[1]);
	function rp;
	array tmp;
	if(!requestprogram) {
	  report_error("No request program for "+port[1]+"\n");
	  continue;
	}
	if(rp = requestprogram()->real_port)
	  if(tmp = rp(port, 0))
	    port = tmp;
	
	object privs;
	if(port[0] < 1024)
	  privs = Privs("Opening listen port below 1024");
	if(o=create_listen_socket(port[0],0,port[2],requestprogram,port)) {
	  perror("Configuration port: "+port[1]+" port number "+
		 port[0]+" interface " +port[2]+"\n");
	  main_configuration_port = o;
	  configuration_ports += ({ o });
	} else {
	  report_error("The configuration port " + port[0] +
		       " on the interface " + port[2] + " (" + port[1] + ") "
		       "could not be opened\n");
	}
      };
      if (erro) {
	report_error("Failed to open configuration port " +
		     old[0] + " at " + old[2] + " (" + old[1] + "): " +
		     (stringp(erro)?erro:describe_backtrace(erro)));
      }
    }
    if(!main_configuration_port)
    {
      report_error("No configuration ports could be created.\n"
		   "Is roxen already running?\n");
      if(first)
	exit( -1 );	// Restart.
    }
  } else {
    perror("No configuration port. I hope this is what you want.\n"
	   "Unless the configuration interface as a location module\n"
	   "is enabled, you will not be allowed access to the configuration\n"
	   "interface. You can re-enable the configuration port like this:\n"
	   "./configvar ConfigurationPort=22202\n");
  }
}
#include <stat.h>
// Find all modules, so a list of them can be presented to the
// user. This is not needed when the server is started.
void scan_module_dir(string d)
{
  if(sscanf(d, "%*s.pmod")!=0) return;
  MD_PERROR(("\n\nLooking for modules in "+d+" "));

  string file,path=d;
  mixed err;
  array q  = (get_dir( d )||({})) - ({".","..","CVS","RCS" });
  if(!sizeof(q)) {
    MD_PERROR(("No modules in here. Continuing elsewhere\n"));
    return;
  }
  if(search(q, ".no_modules")!=-1) {
    MD_PERROR(("No modules in here. Continuing elsewhere\n"));
    return;
  }
  MD_PERROR(("There are "+language("en","number")(sizeof(q))+" files.\n"));

  foreach( q, file )
  {
    _master->set_inhibit_compile_errors("");
    if ( file[0]!='.' && !backup_extension(file) && (file[-1]!='z'))
    {
      array stat = file_stat(path+file);
      if(!stat || (stat[ST_SIZE] < 0))
      {
	if(err = catch ( scan_module_dir(path+file+"/") ))
	  MD_PERROR((sprintf("Error in module rescanning directory code:"
			     " %s\n",describe_backtrace(err))));
      } else {
	MD_PERROR(("Considering "+file+" - "));
	if((module_stat_cache[path+file] &&
	    module_stat_cache[path+file][ST_MTIME])==stat[ST_MTIME])
	{
	  MD_PERROR(("Already tried this one.\n"));
	  continue;
	}
	module_stat_cache[path+file]=stat;
	
	switch(extension(file))
	{
	case "pike":
	case "lpc":
	  if(catch{
	    if((open(path+file,"r")->read(4))=="#!NO") {
	      MD_PERROR(("Not a module\n"));
	      file=0;
	    }
	  }) {
	    MD_PERROR(("Couldn't open file\n"));
	    file=0;
	  }
	  if(!file) break;
	case "mod":
	case "so":
	  string *module_info;
	  if (!(err=catch( module_info = lambda ( string file ) {
	    array foo;
	    object o;
	    program p;
	     
	    if (catch(p = my_compile_file(file)) || (!p)) {
	      MD_PERROR((" compilation failed"));
	      throw("Compilation failed.\n");
	    }

	    // Set the module-filename, so that create in the
	    // new object can get it.
	    roxen->last_module_name = file;

	    array err = catch(o =  p());

	    roxen->last_module_name = 0;

	    if (err) {
	      MD_PERROR((" load failed"));
	      throw(err);
	    } else if (!o) {
	      MD_PERROR((" load failed"));
	      throw("Failed to initialize module.\n");
	    } else {
	      MD_PERROR((" load ok - "));
	      if (!o->register_module) {
		MD_PERROR(("register_module missing"));
		throw("No registration function in module.\n");
	      }
	    }

	    foo = o->register_module();
	    if (!foo) {
	      MD_PERROR(("registration failed"));
	      throw("Failed to register module.\n");
	    } else {
	      MD_PERROR(("registered."));
	    }
	    return({ foo[1], foo[2]+"<p><i>"+
		       replace(o->file_name_and_stuff(), "0<br>", file+"<br>")
		       +"</i>", foo[0] });
	  }(path + file)))) {
	    // Load OK
	    allmodules[ file-("."+extension(file)) ] = module_info;
	  } else {
	    // Load failed.
	    module_stat_cache[path+file]=0;
	    _master->errors += "\n";
	    if (arrayp(err)) {
	      _master->errors += path + file + ": " +
		describe_backtrace(err) + "\n";
	    } else {
	      _master->errors += path + file + ": " + err;
	    }
	  }
	}
	MD_PERROR(("\n"));
      }
    }
    if(strlen(_master->errors)) {
      report_debug("Compilation errors found while scanning modules in "+
		    d+":\n"+ _master->errors+"\n");
    }
    _master->set_inhibit_compile_errors(0);
  }
}

void rescan_modules()
{
  string file, path;
  mixed err;
  report_notice("Scanning module directories for modules");
  if (!allmodules) {
    allmodules=copy_value(somemodules);
  }

  foreach(QUERY(ModuleDirs), path)
  {
    array err;
    err = catch(scan_module_dir( path ));
    if(err) {
      report_error("While scanning module dir (\""+path+"\"): " +
		   describe_backtrace(err) + "\n");
    }
  }
  catch {
    rm(".module_stat_cache");
    rm(".allmodules");
    Stdio.write_file(".module_stat_cache", encode_value(module_stat_cache));
    Stdio.write_file(".allmodules", encode_value(allmodules));
  };
  report_notice("Done with module directory scan. Found "+
		sizeof(allmodules)+" modules.");
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
	  if(arrayp(longform) && search(longform, tmp[2..]) != -1)
	  {
	    argv[i] = 0;
	    if(i < sizeof(argv)-1)
	      argv[i+nf] = 0;
	    return value;
	  } else if(longform && longform == tmp[2..]) {
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
	      value=argv[i][2..];
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
#ifndef __NT__
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
#endif
}

void create_pid_file(string where)
{
#ifndef __NT__
  if(!where) return;
  where = replace(where, ({ "$pid", "$uid" }), 
		  ({ (string)getpid(), (string)getuid() }));

  rm(where);
  if(catch(Stdio.write_file(where, sprintf("%d\n%d", getpid(), getppid()))))
    perror("I cannot create the pid file ("+where+").\n");
#endif
}

// External multi-threaded data shuffler. This leaves roxen free to
// serve new requests. The file descriptors of the open files and the
// clients are sent to the program, then the shuffler just shuffles 
// the data to the client.
void shuffle(object from, object to,
	      object|void to2, function(:void)|void callback)
{
#if efun(spider.shuffle)
  if(!to2)
  {
    object p = pipe();
    p->input(from);
    p->set_done_callback(callback);
    p->output(to);
  } else {
#endif
    // 'smartpipe' does not support multiple outputs.
    object p = Pipe.pipe();
    if (callback) p->set_done_callback(callback);
    p->output(to);
    if(to2) p->output(to2);
    p->input(from);
#if efun(spider.shuffle)
  }
#endif
}


static private int _recurse;

void exit_when_done()
{
  object o;
  int i;
  perror("Interrupt request received. Exiting,\n");
  die_die_die=1;
//   trace(9);
  if(++_recurse > 4)
  {
    werror("Exiting roxen (spurious signals received).\n");
    stop_all_modules();
    exit(-1);	// Restart.
    // kill(getpid(), 9);
    // kill(0, -9);
  }

  // First kill off all listening sockets.. 
  foreach(indices(portno)||({}), o)
  {
#ifdef THREADS
    object fd = files.file();
    fd->connect( portno[o][2]!="Any"?portno[o][2]:"127.0.0.1", portno[o][0] );
    destruct(fd);
#endif
    do_dest(o);
  }
  
  // Then wait for all sockets, but maximum 10 minutes.. 
  call_out(lambda() { 
    call_out(Simulate.this_function(), 5);
    if(!_pipe_debug()[0])
    {
      werror("Exiting roxen (all connections closed).\n");
      stop_all_modules();
      exit(-1);	// Restart.
      perror("Odd. I am not dead yet.\n");
    }
  }, 0.1);
  call_out(lambda(){
    werror("Exiting roxen (timeout).\n");
    stop_all_modules();
    exit(0); // Restart.
  }, 600, 0); // Slow buggers..
}

void exit_it()
{
  perror("Recursive signals.\n");
  exit(-1);	// Restart.
}

#ifdef ENABLE_NEIGHBOURHOOD
object neighborhood;
#endif /* ENABLE_NEIGHBOURHOOD */


// And then we have the main function, this is the oldest function in
// Roxen :) It has not changed all that much since Spider 2.0.
int main(int|void argc, array (string)|void argv)
{
  initiate_languages();
  mixed tmp;

  start_time=time(1);

  add_constant("write", perror);

  report_notice("Starting roxen\n");
  
  
  mark_fd(0, "Stdin");
  mark_fd(1, "Stdout");
  mark_fd(2, "Stderr");

  configuration_dir =
    find_arg(argv, "d",({"config-dir","configuration-directory" }),
	     ({ "ROXEN_CONFIGDIR", "CONFIGURATIONS" }), "../configurations");

  if(configuration_dir[-1] != '/')
    configuration_dir += "/";


  startpid = getppid();
  roxenpid = getpid();
  create_pid_file(find_arg(argv, "p", "pid-file", "ROXEN_PID_FILE"));

  // Dangerous...
  if(tmp = find_arg(argv, "r", "root")) fix_root(tmp);

  argv -= ({ 0 });
  argc = sizeof(argv);

  perror("Restart initiated at "+ctime(time())); 

  define_global_variables(argc, argv);
#ifdef ENABLE_NEIGHBOURHOOD
  neighborhood = (object)"neighborhood";
#endif /* ENABLE_NEIGHBOURHOOD */
  
  create_pid_file(QUERY(pidfile));

#if efun(syslog)
  init_logger();
#endif

  init_garber();
  initiate_supports();
  
  initiate_configuration_port( 1 );
  enable_configurations();
#if 0
  restore_current_user_id_number();
#endif
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

#ifdef THREADS
  start_handler_threads();
  catch( this_thread()->set_name("Backend") );
#if efun(thread_set_concurrency)
  thread_set_concurrency(QUERY(numthreads)+1);
#endif

#endif /* THREADS */

  // Signals which cause a restart (exitcode != 0)
  foreach( ({ "SIGUSR1", "SIGUSR2", "SIGHUP", "SIGINT" }), string sig) {
    catch { signal(signum(sig), exit_when_done); };
  }
  // Signals which cause a shutdown (exitcode == 0)
  foreach( ({ "SIGQUIT" }), string sig) {
    catch { signal(signum(sig), kill_me); };
  }

  report_notice("Roxen started in "+(time()-start_time)+" seconds.\n");
#ifdef __RUN_TRACE
  trace(1);
#endif
//  start_time=time();		// Used by the "uptime" info later on.
  return -1;
}



// Debug functions.  List _all_ open filedescriptors
inline static private string checkfd_fix_line(string l)
{
  string *s;
  s=l/",";
  if (sizeof(s) > 1) {
    s[0]=decode_mode((int)("0"+s[0]));
    if((int)s[1])
      s[1]=sizetostring((int)s[1]);
    else
      s[1]="-";
    
    s[2]=(int)s[3]?s[3]:"-";
    return s[0..2]*",";
  }
  return l;
}


string checkfd(object|void id)
{
//  perror(sprintf("%O\n", get_all_active_fd()));
  
  return
    ("<h1>Active filedescriptors</h1>\n"+
     "<br clear=left><hr>\n"+
     "<table width=100% cellspacing=0 cellpadding=0>\n"+
     "<tr align=right><td>fd</td><td>type</td><td>mode</td>"+
     "<td>size</td><td>inode</td></tr>\n"+
     (Array.map(get_all_active_fd(),
	  lambda(int fd) 
	  {
	    return ("<tr align=right><th>"+fd+"</th><td>"+
 		    replace(checkfd_fix_line(fd_info(fd)),",",
			    "</td><td>")
		    +"</td><td align=left>"
		    +(mark_fd(fd)||"?")+"<br></td></tr>"); 
	  })*"\n")+
     "</table>");
}
