// This is a roxen module. Copyright © 1996 - 1998, Idonex AB.

// Support for the <a
// href="http://hoohoo.ncsa.uiuc.edu/docs/cgi/interface.html">CGI/1.1
// interface</a> (and more, the documented interface does _not_ cover
// the current implementation in NCSA/Apache)

string cvs_version = "$Id: cgi.pike,v 1.109 1999/03/25 20:27:30 grubba Exp $";
int thread_safe=1;

#include <module.h>

inherit "module";
inherit "roxenlib";

// #define CGI_DEBUG
// #define CGI_WRAPPER_DEBUG

import Simulate;

static mapping env=([]);
static array runuser;
static function log_function;

import String;
import Stdio;

// Some logging stuff, should probably move to either the actual
// configuration object, or into a module. That would be much more
// beautiful, really. 
void init_log_file()
{
  remove_call_out(init_log_file);

  if(log_function)
  {
    destruct(function_object(log_function)); 
    // Free the old one.
  }
  
  if(QUERY(stderr) == "custom log file")
    // Only try to open the log file if logging is enabled!!
  {
    mapping m = localtime(time());
    string logfile = QUERY(cgilog);
    m->year += 1900;	/* Adjust for years being counted since 1900 */
    m->mon++;		/* Adjust for months being counted 0-11 */
    if(m->mon < 10) m->mon = "0"+m->mon;
    if(m->mday < 10) m->mday = "0"+m->mday;
    if(m->hour < 10) m->hour = "0"+m->hour;
    logfile = replace(logfile,({"%d","%m","%y","%h" }),
		      ({ (string)m->mday, (string)(m->mon),
			 (string)(m->year),(string)m->hour,}));
    if(strlen(logfile))
    {
      do {
// 	object privs;
//      catch(privs = Privs("Opening logfile \""+logfile+"\""));
	object lf=open( logfile, "wac");
//         if(privs) destruct(privs);
// #if efun(chmod)
// #if efun(geteuid)
// 	if(geteuid() != getuid()) catch {chmod(logfile,0666);};
// #endif
// #endif
	if(!lf) {
	  mkdirhier(logfile);
	  if(!(lf=open( logfile, "wac"))) {
	    report_error("Failed to open logfile. ("+logfile+")\n" +
			 "No logging will take place!\n");
	    log_function=0;
	    break;
	  }
	}
	log_function=lf->write;	
	// Function pointer, speeds everything up (a little..).
	lf=0;
      } while(0);
    } else
      log_function=0;	
    call_out(init_log_file, 60);
  } else
    log_function=0;	
}


mapping my_build_env_vars(string f, object id, string|void path_info)
{
  mapping new = build_env_vars(f, id, path_info);

  if(QUERY(Enhancements))
    new |= build_roxen_env_vars(id);

#if 0
  // Not needed here...
  if (QUERY(ApacheBugCompliance)) {
    new->SERVER_PORT = "80";
  }
#endif /* 0 */

  if(id->misc->ssi_env)
    new |= id->misc->ssi_env;

  if(id->misc->is_redirected)
    new["REDIRECT_STATUS"] = "1";
  
  if(QUERY(rawauth) && id->rawauth) {
    new["HTTP_AUTHORIZATION"] = (string)id->rawauth;
  } else {
    m_delete(new, "HTTP_AUTHORIZATION");
  }
  if(QUERY(clearpass) && id->auth && id->realauth ) {
    new["REMOTE_USER"] = (id->realauth/":")[0];
    new["REMOTE_PASSWORD"] = (id->realauth/":")[1];
  } else {
    m_delete(new, "REMOTE_PASSWORD");
  }

  new["AUTH_TYPE"] = "Basic";

  return new|env|(QUERY(env)?getenv():([]));
}


void nil(){}

#define ipaddr(x,y) (((x)/" ")[y])

int uid_was_zero()
{
  return !(getuid() == 0); // Somewhat misnamed function.. :-)
}

int run_as_user_enabled()
{
  // Return 0 if run_as_user is enabled...
  return(uid_was_zero() || !QUERY(user));
}

void create(object c)
{
  defvar("Enhancements", 1, "Roxen CGI Enhancements", TYPE_FLAG|VAR_MORE,
	 "If defined, Roxen will export a few extra varaibles, namely "
	 "VAR_variable_name: Parsed form variable (like CGI parse)<br>"
	 "QUERY_variable_name: Parsed form variable<br>"
	 "VARIABLES: A space separated list of all form variables<br>"
	 "PRESTATE_name: True if the prestate is present<br>"
	 "PRESTATES: A space separated list of all states");

  defvar("mountpoint", "/cgi-bin/", "CGI-bin path", TYPE_LOCATION, 
	 "This is where the module will be inserted in the "
	 "namespace of your server. The module will, per default, also"
	 " service one or more extensions, from anywhere in the "
	 "namespace.");

  defvar("searchpath", "NONE/", "Search path", TYPE_DIR,
	 "This is where the module will find the files in the <b>real</b> "
	 "file system.");

  defvar("noexec", 1, "Ignore non-executable files", TYPE_FLAG,
	 "If this flag is set, non-executable files will be returned "
	 "as normal files to the client.");

  defvar("ls", 0, "Allow listing of cgi-bin directory", TYPE_FLAG,
	 "If set, the users can get a listing of all files in the CGI-bin "
	 "directory.");

  defvar("ex", 1, "Handle *.cgi", TYPE_FLAG,
	 "Also handle all '.cgi' files as CGI-scripts, as well "
	 " as files in the cgi-bin directory. This emulates the behaviour "
	 "of the NCSA server (the extensions to handle can be set in the "
	 "CGI-script extensions variable).");

  defvar("ext", ({"cgi"}), "CGI-script extensions", TYPE_STRING_LIST,
	 "All files ending with these extensions, will be parsed as "+
	 "CGI-scripts.");

  defvar("env", 0, "Pass environment variables", TYPE_FLAG|VAR_MORE,
	 "If this is set, all environment variables will be passed to CGI "
	 "scripts, not only those defined in the CGI/1.1 standard (with "
	 "Roxen CGI enhancements added, if defined). This include LOGNAME "
	 "and all the other ones (For a quick test, try this script with "
	 "and without this variable set:"
	 "<pre>"
	 "#!/bin/sh\n\n"
         "echo Content-type: text/plain\n"
	 "echo ''\n"
	 "env\n"
	 "</pre>)");

  defvar("stderr","main log file",	 
	 "Log CGI errors to...", TYPE_STRING_LIST,
	 "By changing this variable you can select where error messages "
	 "(which means all text written to stderr) from "
	 "CGI scripts should be sent. By default they will be written to the "
	 "main log file - logs/debug/[name-of-configdir].1. You can also "
	 "choose to send the error messages to a special log file or to the "
	 "browser.\n",
	 ({ "main log file",
	    "custom log file",
	    "browser" }));
  defvar("cgilog", GLOBVAR(logdirprefix)+
	 short_name(c? c->name:".")+"/cgi.log", 
	 "Log file", TYPE_STRING,
	 "Where to log errors from CGI scripts. You can also choose to send "
	 "the errors to the browser or to the main Roxen log file. "
	 " Some substitutions of the file name will be done to allow "
	 "automatic rotating:"
	 "<pre>"
	 "%y    Year  (i.e. '1997')\n"
	 "%m    Month (i.e. '08')\n"
	 "%d    Date  (i.e. '10' for the tenth)\n"
	 "%h    Hour  (i.e. '00')\n</pre>", 0,
	 lambda() { if(QUERY(stderr) != "custom log file") return 1; });

  defvar("virtual_cgi", 0, "Support dynamically generated CGI scripts",
	 TYPE_FLAG|VAR_MORE,
	 "If set, attempt to execute CGI's that only exist as virtual "
	 "files, by copying them to /tmp/.<br>\n"
	 "Not recomended.");

  defvar("rawauth", 0, "Raw user info", TYPE_FLAG|VAR_MORE,
	 "If set, the raw, unparsed, user info will be sent to the script, "
	 " in the HTTP_AUTHORIZATION environment variable. This is not "
	 "recommended, but some scripts need it. Please note that this "
	 "will give the scripts access to the password used.");

  defvar("clearpass", 0, "Send decoded password", TYPE_FLAG|VAR_MORE,
	 "If set, the variable REMOTE_PASSWORD will be set to the decoded "
	 "password value.");

  defvar("use_wrapper", 
#ifdef __NT__
         0
#else
         (getcwd()==""?0:1)
#endif
, "Use cgi wrapper", 
	 TYPE_FLAG|VAR_EXPERT,
	 "If set, an external wrapper will be used to start the CGI script.\n"
	 "<br>This will:<ul>\n"
	 "<li>Enable Roxen to send redirects from cgi scripts\n"
	 "<li>Work around the fact that stdout is set to nonblocking mode\n"
	 "    for the script. It simply will _not_ work for most scripts\n"
	 "<li>Make scripts start somewhat slower...\n"
	 "</ul>"
	 "<p>"
	 "You only need this if you plan to send more than 8Kb of data from "
	 " a script, or use Location: headers in a non-nph script.\n"
	 "<p>More or less always, that is..");

  defvar("wrapper", "bin/cgi", "The wrapper to use",
	 TYPE_STRING|VAR_EXPERT,
	 "This is the pathname of the wrapper to use.\n");
  
  defvar("runuser", "", "Run scripts as", TYPE_STRING,
	 "If you start roxen as root, and this variable is set, CGI scripts "
	 "will be run as this user. You can use either the user name or the "
	 "UID. Note however, that if you don't have a working user database "
	 "enabled, only UID's will work correctly. If unset, scripts will "
	 "be run as nobody.", 0, uid_was_zero);

  defvar("user", 1, "Run user scripts as owner", TYPE_FLAG,
	 "If set, scripts in the home-dirs of users will be run as the "
	 "user. This overrides the Run scripts as variable.", 0, uid_was_zero);

#if constant(Process.create_process)
  defvar("setgroups", 1, "Set the supplementary group access list", TYPE_FLAG,
	 "If set, the supplementary group access list will be set for "
	 "the CGI scripts. This can slow down CGI-scripts significantly "
	 "if you are using eg NIS+. If not set, the supplementary group "
	 "access list will be cleared.");
#endif /* constant(Process.create_process) */

  defvar("allow_symlinks", 1, "Allow symlinks", TYPE_FLAG,
	 "If set, allows symbolic links to binaries owned by the directory "
	 "owner. Other symlinks are still disabled.<br>\n"
	 "NOTE: This option only has effect if scripts are run as owner.",
	 0, run_as_user_enabled);

  defvar("nice", 1, "Nice value", TYPE_INT|VAR_MORE,
	 "The nice level to use when running scripts. "
	 "20 is nicest, and 0 is the most aggressive available to "
	 "normal users.");
  
  defvar("coresize", 0, "Limits: Core dump size", TYPE_INT|VAR_MORE,
	 "The maximum size of a core-dump, in 512 byte blocks."
	 " -2 is unlimited.");

  defvar("maxtime", 60, "Limits: Maximum CPU time", TYPE_INT_LIST|VAR_MORE,
	 "The maximum CPU time the script might use in seconds. -2 is unlimited.",
	 ({ -2, 10, 30, 60, 120, 240 }));

  defvar("kill_call_out", 0, "Limits: Time before killing scripts",
	 TYPE_INT_LIST|VAR_MORE,
	 "The maximum real time the script might run in minutes before it's "
	 "killed. 0 means unlimited.", ({ 0, 1, 2, 3, 4, 5, 7, 10, 15 }));

  defvar("datasize", -2, "Limits: Memory size", TYPE_INT|VAR_EXPERT,
	 "The maximum size of the memory used, in Kb. -2 is unlimited.");

  defvar("filesize", -2, "Limits: Maximum file size", TYPE_INT|VAR_EXPERT,
	 "The maximum size of any file created, in 512 byte blocks. -2 "
	 "is unlimited.");

  defvar("open_files", 64, "Limits: Maximum number of open files",
	 TYPE_INT_LIST|VAR_MORE,
	 "The maximum number of files the script can keep open at any time.",
	 ({64,128,256,512,1024,2048}));

  defvar("stack", -2, "Limits: Stack size", TYPE_INT|VAR_EXPERT,
	 "The maximum size of the stack used, in b. -2 is unlimited.");

  defvar("extra_env", "", "Extra environment variables", TYPE_TEXT_FIELD|VAR_MORE,
	 "Extra variables to be sent to the script, format:<pre>"
	 "NAME=value\n"
	 "NAME=value\n"
	 "</pre>Please note that normal CGI variables will override these.");
}


mixed *register_module()
{
  return ({ 
    MODULE_LOCATION | MODULE_FILE_EXTENSION,
    "CGI executable support", 
    "Support for the <a href=\"http://hoohoo.ncsa.uiuc.edu/docs/cgi/"
      "interface.html\">CGI/1.1 interface</a>, and more. It is too bad "
      "that the CGI specification is a moving target, it is hard to "
      "implement a fully compatible copy of it."
    });
}

string check_variable(string name, string value)
{
  if(name == "mountpoint" && value[-1] != '/')
    call_out(set, 0, "mountpoint", value+"/");
}

static string search_path;

void start(int n, object conf)
{
  if(n==2) return;

  if(intp(QUERY(wrapper)))
    QUERY(wrapper)="bin/cgi";

  if(!conf) return;

  module_dependencies(conf, ({ "pathinfo" }));

  init_log_file();

  string tmp;
  array us;
  search_path = query("searchpath");
#if efun(getpwnam)
  if(us = getpwnam(  QUERY(runuser) ))
    runuser = ({ (int)us[2], (int)us[3] });
  else
#endif
    if(strlen(QUERY(runuser)))
      if (sizeof(us = (QUERY(runuser)/":")) == 2) 
	runuser = ({ (int)us[0], (int)us[1] });
      else
	runuser = ({ (int)QUERY(runuser), (int)QUERY(runuser) });

  tmp=conf->query("MyWorldLocation");
  sscanf(tmp, "%*s//%s", tmp);
  sscanf(tmp, "%s:", tmp);
  sscanf(tmp, "%s/", tmp);

  env["SERVER_NAME"]=tmp;
  env["SERVER_SOFTWARE"]=roxen->version();
  env["GATEWAY_INTERFACE"]="CGI/1.1";
  env["SERVER_PROTOCOL"]="HTTP/1.0";
  env["SERVER_URL"]=conf->query("MyWorldLocation");
  env["AUTH_TYPE"]="Basic";
  env["ROXEN_CGI_NICE_LEVEL"] = (string)query("nice");
  env["ROXEN_CGI_LIMITS"] = ("core_dump_size:"+query("coresize")+
			     ";time_cpu:"+query("maxtime")+
			     ";data_size:"+query("datasize")+
			     ";file_size:"+query("filesize")+
			     ";open_files:"+query("open_files")+
			     ";stack_size:"+query("stack"));
  
  us = ({ "", "" });

  foreach(query("extra_env")/"\n", tmp)
    if(sscanf(tmp, "%s=%s", us[0], us[1])==2)
      env[us[0]] = us[1];
}

string query_location() 
{ 
  return QUERY(mountpoint); 
}

string query_name() 
{ 
  return sprintf("CGI-bin path: <i>%s</i>, CGI-searchpath: <i>%s</i>"+
		 (QUERY(ex)?", CGI-extensions: <i>%s</i>":""),
		 QUERY(mountpoint), QUERY(searchpath),
		 implode_nicely(QUERY(ext)));
}

static inline array make_args( string rest_query )
{
  if(!rest_query || !strlen(rest_query))
    return (array (string))({});  return replace(rest_query,"\000", " ")/" ";
}

array stat_file(string f, object id) 
{
#ifdef CGI_DEBUG
  roxen_perror("CGI: stat_file(\"" + f + "\")\n");
#endif /* CGI_DEBUG */

  return file_stat(search_path+f);
}

string real_file( mixed f, mixed id )
{
#ifdef CGI_DEBUG
  roxen_perror("CGI: real_file(\"" + f + "\")\n");
#endif /* CGI_DEBUG */

  if(stat_file( f, id )) 
    return search_path+f;
}

array find_dir(string f, object id) 
{
#ifdef CGI_DEBUG
  roxen_perror("CGI: find_dir(\"" + f + "\")\n");
#endif /* CGI_DEBUG */

  if(QUERY(ls)) 
    return get_dir(search_path+f);
}

mapping cached_groups = ([]);
array get_cached_groups_for_user( int uid )
{
#if constant(get_groups_for_user)
  if(cached_groups[ uid ] && cached_groups[ uid ][1]+3600>time(1))
    return cached_groups[ uid ][0];
  return (cached_groups[ uid ] = ({ get_groups_for_user( uid ), time(1) }))[0];
#else
  return ({});
#endif
}

class spawn_cgi
{
  // This program asserts that fork() is called from the backend to
  // avoid some problems with threads, fork() and buggy OS's.
  string wrapper;
  string f;
  array(string) args;
  mapping env;
  string wd;
  int|string uid;
  object pipe1, pipe2;	// Stdout/Stderr for the CGI
  object pipe3, pipe4;	// Stdin for the CGI
  object pipe5, pipe6;  // CGI log file
  int kill_call_out;
  array(object)| int dup_err;
  int setgroups;
  object cgi_pipe;


  class nat_wrapper // Wrapper emulator when not using the binary wrapper.
  {
    static string buffer;
    static int nonblocking;
    static function rcb, wcb, ccb;
    static object realfd;
    static string headers = "";
    static int inread;
    static object proc;

    static void handle_headers()
    {
      string retcode = "200 Ok";
      int pointer;
#ifdef CGI_WRAPPER_DEBUG
      werror("CGI wrapper: handle_headers()\n");
#endif
      if(((pointer = strstr(headers, "Location:"))!=-1||
          ((pointer = strstr(headers, "location:")))!=-1))
      {
        retcode = "302 Redirection";
      }

      if(((pointer = strstr(headers, "status:"))!=-1||
          ((pointer = strstr(headers, "Status:")))!=-1))
      {
        int end;
        sscanf(headers[pointer+7..], "%s%n\n", retcode, end);
        sscanf(retcode, "%*[ \t]%s", retcode);
        sscanf(retcode, "%s\r", retcode);
        headers = headers[..pointer-1]+headers[pointer+7+end+1..];
      }
      buffer = "HTTP/1.1 "+retcode+"\r\n" + headers +"\r\n\r\n"+ buffer;
#ifdef CGI_WRAPPER_DEBUG
      werror("CGI wrapper: handle_headers() --->\n"+buffer);
#endif
    }

    void close()
    {
      int killed;
#ifdef CGI_WRAPPER_DEBUG
      werror("CGI wrapper: Closing down...\n");
      werror("Killing "+proc->pid()+"\n");
#endif
      if(!kill(proc, signum("SIGKILL")) && !closed)
      {
        object privs;
        catch(privs = Privs("Killing CGI script."));
        kill(proc, signum("SIGKILL"));
      }
      set_blocking();
      destruct(realfd);
    }

#ifdef CGI_WRAPPER_DEBUG
    void destroy()
    {
      werror("CGI wrapper done!\n");
      close();
    }
#endif

    
    void set_read_callback( function to )
    {
#ifdef CGI_WRAPPER_DEBUG
      werror("CGI wrapper: set_read_callback(%O)\n", to);
#endif
      rcb = to;
      if(buffer && sizeof(buffer) && to)
      {
        to(realfd->query_id(), buffer);
        buffer=0;
      }
    }

    void set_write_callback( function to )
    {
#ifdef CGI_WRAPPER_DEBUG
      werror("CGI wrapper: set_write_callback(%O)\n", to);
#endif
      wcb = to;
    }

    void set_close_callback( function to )
    {
#ifdef CGI_WRAPPER_DEBUG
      werror("CGI wrapper: set_close_callback(%O)\n", to);
#endif
      ccb = to;
      if(closed && to)
        to(realfd->query_id());
    }

    void set_nonblocking( function r, function w, function c )
    {
      nonblocking = 1;
#ifdef CGI_WRAPPER_DEBUG
      werror("CGI wrapper: set_nonblocking(%O,%O,%O)\n", r,w,c);
#endif
      set_read_callback( r );
      set_write_callback( w );
      set_close_callback( c );
    }

    void set_blocking()
    {
#ifdef CGI_WRAPPER_DEBUG
      werror("CGI wrapper: set_blocking()\n");
#endif
      nonblocking = 0;
      set_read_callback( 0 );
      set_write_callback( 0 );
      set_close_callback( 0 );
    }


#if constant(thread_create)
    static void data_fetcher(  )
    {
      string data;
      while(1)
      {
#ifdef CGI_WRAPPER_DEBUG
        werror("CGI wrapper: reading... ->");
#endif
        
        if(!realfd)
        {
          if(headers)
          {
            if(!buffer)
              buffer = "";
            handle_headers( );
            headers=0;
            if(rcb && !inread)
            {
              rcb(realfd->query_id(), buffer);
              buffer = "";
            }
          }
          closed = 1;
          if(ccb) 
            ccb(realfd->query_id());
          return;
        }
        data = realfd->read(1024,1);
#ifdef CGI_WRAPPER_DEBUG
        werror("%O(%d)<--\n", data, data&&strlen(data));
#endif
        if(!data || !strlen(data))
        {
#ifdef CGI_WRAPPER_DEBUG
          werror("Closed!\n");
#endif
          if(headers)
          {
            if(!buffer)
              buffer = "";
            handle_headers( );
            headers=0;
            if(rcb && !inread)
            {
              rcb(realfd->query_id(), buffer);
              buffer = "";
            }
          }
          closed = 1;
          if(ccb) 
            ccb(realfd->query_id());
          return;
        }
//#ifdef CGI_WRAPPER_DEBUG
//   werror("CGI wrapper: get_some_data(%s)\n", data);
//#endif

        if(headers)
        {
          headers += data;
          if((sscanf(headers, "%s\r\n\r\n%s", headers, buffer) == 2) ||
             (sscanf(headers, "%s\n\n%s", headers, buffer) == 2) ||
             strlen(headers)>16536)
          {
            if(!buffer)
              buffer = "";
            handle_headers( );
            headers=0;
            if(rcb && !inread)
            {
              rcb(realfd->query_id(), buffer);
              buffer = "";
            }
          }
          continue;
        }
        buffer += data;
        if(rcb && !inread)
        {
          call_out(rcb,0,realfd->query_id(),buffer);
          buffer = "";
        }
      }
    }

    int closed;
    string read(int nbytes, int less_is_enough)
    {
      if(closed) {
        if(buffer)
        {
          string s = buffer[..nbytes-1];
          buffer = buffer[nbytes..];
	  if (buffer == "") {
	    buffer = 0;
	  }
          return s;
        }
        return 0;
      }
#ifdef CGI_WRAPPER_DEBUG
      werror("CGI wrapper: read(%d,%d)\n",nbytes,less_is_enough);
#endif
      if(!nbytes)
        nbytes = 0x7fffffff;
      string ret;
      if(buffer && strlen(buffer))
      {
        if(strlen(buffer) >= nbytes || less_is_enough || nonblocking)
        {
          ret = buffer[..nbytes-1];
          buffer = buffer[nbytes..];
#ifdef CGI_WRAPPER_DEBUG
          werror("returning "+ret+"\n");
#endif
          return ret;
        }
      }
      if(nonblocking)
        return "";

      inread = 1;
      while(!closed && (!buffer || strlen(buffer)<nbytes))
      {
#ifdef CGI_WRAPPER_DEBUG
        werror("Wrapper: Waiting for data <%d,%d>->%d...\n",
               nbytes, less_is_enough, buffer&&strlen(buffer));
#endif
        sleep(0.01);
        if(less_is_enough && buffer && strlen(buffer))
          break;
      }
      inread = 0;
      if(buffer)
      {
        ret = buffer[..nbytes-1];
        buffer = buffer[nbytes..];
      }
      else
        ret=0;
#ifdef CGI_WRAPPER_DEBUG
      werror("returning "+ret+"\n");
#endif
      return ret;
    }

    int query_fd()
    {
#ifdef CGI_WRAPPER_DEBUG
      werror("CGI wrapper: query_fd()\n");
#endif
      return -1;
    }

    void create( object _realfd, object _proc )
    {
#ifdef CGI_WRAPPER_DEBUG
      werror("Creating new CGI wrapper\n");
#endif
      proc = _proc;
      realfd = _realfd;
      thread_create( data_fetcher );
    }
#else
    static void get_some_data( mixed f, string data )
    {
      if(!data)
      {
        data = realfd->read(1024,1);
        if(!data || !strlen(data))
        {
          closed = 1;
          return;
        }
      }

//#ifdef CGI_WRAPPER_DEBUG
//   werror("CGI wrapper: get_some_data(%s)\n", data);
//#endif

      if(headers)
      {
        headers += data;
        if((sscanf(headers, "%s\r\n\r\n%s", headers, buffer) == 2) ||
           (sscanf(headers, "%s\n\n%s", headers, buffer) == 2) ||
           strlen(headers)>16536)
        {
          if(!buffer)
            buffer = "";
          handle_headers( );
          headers=0;
          if(rcb && !inread)
          {
            rcb(realfd->query_id(), buffer);
            buffer = "";
          }
        }
        return;
      }
      buffer += data;
      if(rcb && !inread)
      {
        rcb(realfd->query_id(), buffer);
        buffer = "";
      }
    }

    int closed;
    string read(int nbytes, int less_is_enough)
    {
      if(closed) {
        if(buffer)
        {
          string s = buffer;
          buffer = 0;
          return s;
        }
        return 0;
      }
#ifdef CGI_WRAPPER_DEBUG
      werror("CGI wrapper: read(%d,%d)\n",nbytes,less_is_enough);
#endif
      if(!nbytes)
        nbytes = 0x7fffffff;
      string ret;
      if(buffer && strlen(buffer))
      {
        if(strlen(buffer) >= nbytes || less_is_enough || nonblocking)
        {
          ret = buffer[..nbytes-1];
          buffer = buffer[nbytes..];
#ifdef CGI_WRAPPER_DEBUG
          werror("returning "+ret+"\n");
#endif
          return ret;
        }
      }
      if(nonblocking)
        return "";

      realfd->set_blocking();
      inread = 1;
      while(!closed && (!buffer || strlen(buffer)<nbytes))
      {
#ifdef CGI_WRAPPER_DEBUG
        werror("Wrapper: Waiting for data <%d,%d>->%d...\n",
               nbytes, less_is_enough, buffer&&strlen(buffer));
#endif
        get_some_data(0,0);
        if(less_is_enough && buffer && strlen(buffer))
          break;
      }
      inread = 0;
      realfd->set_nonblocking(get_some_data, write_more, done_closed);
      if(buffer)
      {
        ret = buffer[..nbytes-1];
        buffer = buffer[nbytes..];
      }
      else
        ret=0;
#ifdef CGI_WRAPPER_DEBUG
      werror("returning "+ret+"\n");
#endif
      return ret;
    }

    void done_closed()
    {
      closed = 1;
      if(ccb) 
        ccb(realfd->query_id());
    }

    int query_fd()
    {
#ifdef CGI_WRAPPER_DEBUG
      werror("CGI wrapper: query_fd()\n");
#endif
      return -1;
    }
    
    void write_more(mixed foo)
    {
#ifdef CGI_WRAPPER_DEBUG
      werror("CGI wrapper: write_more(%O)\n", wcb);
#endif
      if(wcb) wcb(foo);
    }

    void create( object _realfd, object _proc )
    {
#ifdef CGI_WRAPPER_DEBUG
      werror("Creating new CGI wrapper\n");
#endif
      proc = _proc;
      realfd = _realfd;
      realfd->set_nonblocking(get_some_data, write_more, done_closed);
    }
#endif
  }


  void got_some_data(object to, string d)
  {
    to->write( d );
  }

  void cgi_fail(int errcode, string err)
  {
    string to_write = sprintf("HTTP/1.0 %d %s\r\n"
			      "\r\n"
			      "<title>%s</title>\n"
			      "<h2>%s</h2>\n", errcode, err, err, err);

    object(Stdio.File) output = Stdio.File("stdout");
    int bytes;
    
    while ((bytes = output->write(to_write)) > 0) {
      if ((to_write = to_write[bytes..]) == "") {
	break;
      }
    }

    exit(0);
  }
  
  void do_cgi()
  {
    int pid;
    int use_native_wrapper;
#ifdef CGI_DEBUG
    roxen_perror("do_cgi()\n");
#endif /* CGI_DEBUG */

#if constant(Process.create_process)

    if(wrapper) 
    {
      array us;
      wrapper = combine_path(getcwd(), wrapper);
      if(!(us = file_stat(wrapper)) ||
	 !(us[0]&0111)) 
      {
	report_error(sprintf("Wrapper \"%s\" doesn't exist, or "
			     "is not executable\n", wrapper));
	return;
      }
      args = ({ wrapper, f }) + args;
    } 
    else 
    {
      args = ({ f }) + args;
      if(sscanf(f, "%*s/nph%*s" )< 2)
      {
#ifdef CGI_WRAPPER_DEBUG
        werror("Will use internal wrapper.\n");
#endif
        use_native_wrapper = 1;
      }
    }

    /* Be sure they are closed in the forked copy */
    pipe2->set_close_on_exec(1);
    pipe4->set_close_on_exec(1);
    mapping options = ([ "cwd":wd,
			 "stdin":pipe3,
			 "stdout":pipe1,
                         "noinitgroups":1,
			 "env":env,
    ]);

    if (!getuid()) {
      options["uid"] = uid || 65534;
      if (!setgroups) {
#if constant(cleargroups)
	options["setgroups"] = ({});
#endif /* constant(cleargroups) */
      } else
        options["setgroups"] = get_cached_groups_for_user( uid||65534 );
    }

    if (dup_err == 1) 
    {
      options["stderr"] = pipe1;
    } 
    else if(dup_err) 
    { 
      dup_err[1]->set_close_on_exec(1);
      options["stderr"] = dup_err[0];
    }
#ifdef CGI_WRAPPER_DEBUG
    werror("Starting CGI.\n");
#endif
#ifdef CGI_DEBUG
    roxen_perror(sprintf("create_process(%O, %O)...\n", args, options));
#endif /* CGI_DEBUG */

    object proc;
    mixed err = catch {
      proc = Process.create_process(args, options);
#ifdef CGI_DEBUG
      if (!proc) {
	roxen_perror(sprintf("CGI: Process.create_process() returned 0.\n"));
      }
#endif /* CGI_DEBUG */
    };

#ifdef CGI_WRAPPER_DEBUG
    werror("CGI started.\n");
#endif

    /* We don't want to keep these. */
    destruct(pipe1);
    destruct(pipe3);
    if(arrayp(dup_err))
      destruct(dup_err[0]);
    if (err) {
      int e = errno();
#if constant(strerror)
      report_error(sprintf("CGI: create_process() failed:\n"
			   "errno: %d: %s\n"
			   "%s\n",
			   e, strerror(e),
			   describe_backtrace(err)));
#else /* !constant(strerror) */
      report_error(sprintf("CGI: create_process() failed:\n"
			   "errno: %d\n"
			   "%s\n",
			   e, describe_backtrace(err)));
#endif /* constant(strerror) */
    }

#ifdef CGI_WRAPPER_DEBUG
    werror("Starting wrapper.\n");
#endif
    if(use_native_wrapper)
      cgi_pipe = nat_wrapper( pipe2, proc );
    else 
      cgi_pipe = pipe2;

    if(kill_call_out && proc && proc->pid() > 1) {
      call_out(lambda (object proc) {
#ifndef THREADS
                 if(!kill(proc, signum("SIGKILL")))
                 {
                   object privs;
                   catch(privs = Privs("Killing CGI script."));
                   kill(proc, signum("SIGKILL"));
                 }
#else
                 if(proc->pid() > 1)
                   kill(proc, signum("SIGKILL"));
#endif
      }, kill_call_out * 60 , proc);
    }
#endif /* constant(Process.create_process) */

  }
  
  void create(string wrapper_, string f_, array(string) args_, mapping env_,
	      string wd_, int|string uid_, object pipe1_, object pipe2_,
	      object pipe3_, object pipe4_, array(object)|int dup_err_,
	      int kill_call_out_,
	      int setgroups_)
  {
#ifdef CGI_DEBUG
    roxen_perror(sprintf("spawn_cgi(%O, %O, %O, %O, "
			 "%O, %O, X, X, "
			 "X, X, %O, %O, %O)\n",
			 wrapper_, f_, args_, env_,
			 wd_, uid_, dup_err_, kill_call_out_, setgroups_));
#endif /* CGI_DEBUG */
    wrapper = wrapper_;
    f = f_;
    args = args_;
    env = env_;
    wd = wd_;
    uid = uid_;
    pipe1 = pipe1_;
    pipe2 = pipe2_;
    pipe3 = pipe3_;
    pipe4 = pipe4_;
    dup_err = dup_err_;
    kill_call_out = kill_call_out_;
    setgroups = setgroups_;
#ifdef THREADS
    call_out(do_cgi, 0);
#else /* THREADS */
    do_cgi();
#endif /* THREADS */
  }
};

// Used to close the stdin of the CGI-script.
class closer
{
  object fd;
  void close_cb()
  {
    fd->close();
  }
  void create(object fd_)
  {
    fd = fd_;
    fd->set_nonblocking(close_cb, close_cb, close_cb);
  }
};

// Used to send some data to the CGI-script.
class sender
{
  string to_send;
  object fd;

  void write_cb()
  {
    if (sizeof(to_send)) {
      int len = fd->write(to_send);
      if ((to_send = to_send[len..]) == "") {
	fd->close();
      }
    } else {
      fd->close();
    }
  }
  void close_cb()
  {
    fd->close();
  }
  void create(object fd_, string to_send_)
  {
    fd = fd_;
    // fd->close("r");	// We aren't interrested in reading from the fd.
    to_send = to_send_;
    fd->set_nonblocking(0, write_cb, close_cb);
  }
};

mixed low_find_file(string f, object id, string path)
{
  array tmp2;
  object pipe1, pipe2;
  object pipe3, pipe4;
  object pipe5, pipe6; // This is for logging stderr to a separate file.
  string path_info, wd;
  int pid;

  NOCACHE();

#ifdef CGI_DEBUG
  roxen_perror(sprintf("CGI: find_file(%O, X, %O)...\n", f, path));
#endif /* CGI_DEBUG */

  if (sizeof(path) && (path[-1] != '/')) {
    f = path + "/" + f;
  } else {
    f = path + f;
  }

#ifdef CGI_DEBUG
  roxen_perror("CGI: => f = \"" + f + "\"\n");
#endif /* CGI_DEBUG */

  if(id->misc->path_info)
    // From the PATH_INFO last-try module.
    path_info = id->misc->path_info;
  else 
  {
    int sz;
    if((sz = file_size( f )) < 0) {
      return (sz == -2)?-1:0; // It's a directory...
    } else if (f[-1] == '/') {
      // Special case.
      // Most UNIXen ignore the trailing /
      // but we have to make path-info out of it.
      path_info = "/";
      f = f[..sizeof(f)-2];
    }
  }
  
#ifdef CGI_DEBUG
  roxen_perror("CGI: Starting '"+f+"'...\n");
#endif

  wd = dirname(f);
  if ((!(pipe1=Stdio.File())) || (!(pipe2=pipe1->pipe()))) {
    int e = errno();
#if constant(strerror)
    report_error(sprintf("cgi->find_file(\"%s\"): Can't open pipe "
			 "-- Out of fd's?\n"
			 "errno: %d: %s\n", f, e, strerror(e)));
#else /* !constant(strerror) */
    report_error(sprintf("cgi->find_file(\"%s\"): Can't open pipe "
			 "-- Out of fd's?\n"
			 "errno: %d\n", f, e));
#endif /* constant(strerror) */
    return(0);
  }
  pipe2->set_blocking(); pipe1->set_blocking();
  pipe2->set_id(pipe2);

  if ((!(pipe3=Stdio.File())) || (!(pipe4=pipe3->pipe()))) {
    int e = errno();
#if constant(strerror)
    report_error(sprintf("cgi->find_file(\"%s\"): Can't open input pipe "
			 "-- Out of fd's?\n"
			 "errno: %d: %s\n", f, e, strerror(e)));
#else /* !constant(strerror) */
    report_error(sprintf("cgi->find_file(\"%s\"): Can't open input pipe "
			 "-- Out of fd's?\n"
			 "errno: %d\n", f, e));
#endif /* constant(strerror) */
    return(0);
  }
  pipe4->set_blocking(); pipe3->set_blocking();
  pipe4->set_id(pipe4);
  if(log_function)
  {
    if ((!(pipe5=Stdio.File())) || (!(pipe6=pipe5->pipe()))) {
      int e = errno();
#if constant(strerror)
      report_error(sprintf("cgi->find_file(\"%s\"): Can't open pipe "
			   "-- Out of fd's?\n"
			   "errno: %d: %s\n", f, e, strerror(e)));
#else /* !constant(strerror) */
      report_error(sprintf("cgi->find_file(\"%s\"): Can't open pipe "
			   "-- Out of fd's?\n"
			   "errno: %d\n", f, e));
#endif /* constant(strerror) */
      return(0);
    }
    pipe6->set_nonblocking();
    pipe6->set_id(pipe6);
    pipe6->set_read_callback(lambda(object this, string s) {
			       if(stringp(s) && functionp(log_function))
				 log_function(s);
			     });
    pipe6->set_close_callback(lambda(object this)
			      {
				if(this)
				  destruct(this);
			      });
    pipe5->set_blocking();
    //    pipe6->set_id(pipe6);

  }
  
  mixed uid;
  array us;
  if(query("noexec"))
  {
    us = file_stat(f);
    if(us && !(us[0]&0111)) // Not executable...
      return open(f,"r");
  }
  
  if(!getuid())
  {
    if(QUERY(user) && id->misc->is_user &&
       (us = file_stat(id->misc->is_user)) &&
       (us[5] >= 10)) {
      // Scan for symlinks
      string fname = "";
      array a,b;
      foreach(id->misc->is_user/"/", string part) {
	fname += part;
	if ((fname != "") &&
	    ((!(a = file_stat(fname, 1))) ||
	     ((< -3, -4 >)[a[1]]))) {
	  // Symlink or device encountered.
	  // Don't allow symlinks from directories not owned by the
	  // same user as the file itself.
	  // Assume that symlinks from directories owned by users 1-9 are safe.
	  if (!a || (a[1] == -4) ||
	      !b || ((b[5] != us[5]) && (b[5] >= 10)) ||
	      !QUERY(allow_symlinks)) {
	    report_notice(sprintf("CGI: Bad symlink or device encountered: "
				  "\"%s\"\n", fname));
	    fname = 0;
	    break;
	  }
	  a = file_stat(fname);		// Get the permissions from the directory.
	} else {
	  a = file_stat("/");
	}
	b = a;
	fname += "/";
      }
      if (fname) {
	uid = us[5..6];
      }
    }
    else if(runuser)
      uid = runuser;
  }
  if(!uid)
    uid = "nobody";

  if (arrayp(uid)) {
    uid = uid[0];
  }
  mixed stderr;
  if(QUERY(stderr) != "main log file") {
    if(QUERY(stderr) == "custom log file")
      stderr = ({ pipe5, pipe6 });
    else
      stderr = 1;
  }
  
  object cgi = spawn_cgi(QUERY(use_wrapper) && (QUERY(wrapper) || "/bin/cgi"),
			 f, make_args(id->rest_query),
			 my_build_env_vars(f, id, path_info),
			 wd, uid, pipe1, pipe2, pipe3, pipe4,
			 stderr,QUERY(kill_call_out),
#if constant(Process.create_process)
			 QUERY(setgroups)
#else /* !constant(Process.create_process) */
			 /* Ignored anyway */
			 0
#endif /* constant(Process.create_process) */
			 );
  
  if(id->my_fd && id->data) {
    sender(pipe4, id->data);
    id->my_fd->set_id( pipe4 );                       // for put.. post?
    id->my_fd->set_read_callback(cgi->got_some_data); // lets try, atleast..
    id->my_fd->set_nonblocking();
  } else {
    closer(pipe4);
  }
  return http_stream(cgi->cgi_pipe);
}

mixed find_file(string f, object id)
{
  return(low_find_file(f, id, search_path));
}

array (string) query_file_extensions()
{
  return query("ext");
}

mapping handle_file_extension(object o, string e, object id)
{
  string f, q, w;
  mixed toret;
  string path;
  mixed err;

  if(!QUERY(ex))
    return 0;

  if(QUERY(noexec) && !(o->stat()[0]&0111))
    return 0;

  if(id->realfile) 
  {
    array c;

    c=id->realfile/"/";
    
    // Handle the request with the location code.
    // This is done by setting the cgi-bin dir to the path of the 
    // script, and then calling the location dependant code.
    //
    // This isn't thread-safe (discovered by Wilhelm Köhler), so send
    // the path to be used directly to find_file() instead.
    destruct( o );
    o = 0;
    path=c[0..sizeof(c)-2]*"/" + "/";

    //  use full path in case of path_info                         1-Nov-96-wk
    // FIXME: Why?	/grubba 1998-10-02
    // if(id->misc->path_info)
    //   err=catch(toret = low_find_file(id->realfile, id, path));
    // else
    err=catch(toret = low_find_file(c[-1], id, path));

    if(err) throw(err);
    return toret;
  }

  if (!QUERY(virtual_cgi))
    return 0;

  // Fallback for odd location modules that do not set the
  // realfile entry in the id object.
  // This could be useful when the data is not really a file, but instead
  // generated internally, or if it is a socket.

  // FIXME: This should probably use a configurable directory
  // instead of /tmp/ but I don't think this code has ever been
  // used.	/grubba 1998-10-02
#ifdef CGI_DEBUG
  roxen_perror("CGI: Handling "+e+" by copying to /tmp/....\n");
#endif
  
  o->set_blocking();
  f=o->read(0x7ffffff);         // We really hope that this is not located on 
                               // a NFS server far-far away...
  destruct(o);
  q="/tmp/"+(w=(((id->not_query/"/")[-1][0..2])+"Roxen_tmp"));
  rm(q);
  write_file(q, f);

#if constant(chmod)
  chmod(q, 0555);
#else /* !constant(chmod) */
  popen("chmod u+x "+q);
#endif /* constant(chmod) */

  err=catch(toret = low_find_file(w, id, "/tmp/"));

  if(err) throw(err);
  return toret;
}
