// This is a roxen module. (c) Informationsvävarna AB 1996.

// Support for the <a
// href="http://hoohoo.ncsa.uiuc.edu/docs/cgi/interface.html">CGI/1.1
// interface</a> (and more, the documented interface does _not_ cover
// the current implementation in NCSA/Apache)


string cvs_version = "$Id: cgi.pike,v 1.41 1997/09/26 21:30:38 grubba Exp $";
int thread_safe=1;

#include <module.h>

inherit "module";
inherit "roxenlib";

import Simulate;

static mapping env=([]);
static array runuser;

import String;
import Stdio;

#if !constant(Privs)
constant Privs=((program)"privs");
#endif /* !constant(Privs) */

mapping my_build_env_vars(string f, object id, string|void path_info)
{
  mapping new = build_env_vars(f, id, path_info);

  if(QUERY(Enhancements))
    new |= build_roxen_env_vars(id);
  
  if(id->misc->ssi_env)
    new |= id->misc->ssi_env;
  
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

void create()
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

  defvar("err", 0, "Send stderr to client", TYPE_FLAG|VAR_MORE,
	 "It you set this, standard error from the scripts will be redirected"
	 " to the client instead of the logs/debug/[name-of-configdir].1 "
	 "log.\n");

  defvar("rawauth", 0, "Raw user info", TYPE_FLAG|VAR_MORE,
	 "If set, the raw, unparsed, user info will be sent to the script, "
	 " in the HTTP_AUTHORIZATION environment variable. This is not "
	 "recommended, but some scripts need it. Please note that this "
	 "will give the scripts access to the password used.");

  defvar("clearpass", 0, "Send decoded password", TYPE_FLAG|VAR_MORE,
	 "If set, the variable REMOTE_PASSWORD will be set to the decoded "
	 "password value.");

  defvar("use_wrapper", (getcwd()==""?0:1), "Use cgi wrapper", 
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
	 TYPE_INT_LIST|VAR_EXPERT,
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
    MODULE_LAST | MODULE_LOCATION | MODULE_FILE_EXTENSION,
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

static string path;

void start(int n, object conf)
{
  if(n==2) return;

  if(intp(QUERY(wrapper)))
    QUERY(wrapper)="bin/cgi";

  if(!conf) conf=roxen->current_configuration;
  if(!conf) return;

  string tmp;
  array us;
  if(!conf) // When reloading, no conf is sent.
    return; 
  path = query("searchpath");
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
  return sprintf("CGI-bin path: <i>%s</i>"+
		 (QUERY(ex)?", CGI-extensions: <i>%s</i>":""),
		 QUERY(mountpoint), implode_nicely(QUERY(ext)));
}

static inline array make_args( string rest_query )
{
  if(!rest_query || !strlen(rest_query))
    return (array (string))({});  return replace(rest_query,"\000", " ")/" ";
}

array stat_file(string f, object id) 
{
  return file_stat(path+f);
}

string real_file( mixed f, mixed id )
{
  if(stat_file( f, id )) 
    return path+f;
}

array find_dir(string f, object id) 
{
  if(QUERY(ls)) 
    return get_dir(path+f);
}


array extract_path_info(string f)
{
  string hmm, tmp_path=path, path_info="";
  int found;
  
  foreach(f/"/", hmm)
  {
    if(!found)
    {
      switch(file_size(tmp_path + hmm))
      {
       case -1:
	return 0;

       case -2:
	 tmp_path += hmm + "/";
	break;
	
       default:
	f = tmp_path + hmm;
	found = 1;
	break;
      }
    } else {
      if(path_info)
	path_info += "/" + hmm;
      else
	path_info = strlen(hmm) ? hmm : "/";
    }
  }
  if(!found)  return 0;
  return ({ path_info, f });
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
  object pipe1, pipe2;
  int kill_call_out;
  int dup_err;
  object my_fd;
  string data;

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

    object(files.file) output = files.file("stdout");
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
    if (!(pid = fork())) {
      mixed err = catch {
	array us;
	/* The COREDUMPSIZE should be set to zero here !!
	 * This should be done at least before the change of directory
	 */
	string oldwd = getcwd() + "/";
	destruct(pipe2);
	pipe1->dup2(files.file("stdin"));
	pipe1->dup2(files.file("stdout"));
	if(dup_err)
	  pipe1->dup2(files.file("stderr"));

	object privs;
	if (!getuid()) {
	  // We are running as root -- change!
	  privs = Privs("CGI script", uid);
	} else {
	  // Try to change user anyway, but don't throw an error if we fail.
	  catch(privs = Privs("CGI script", uid));
	}
	setgid(getegid()||65534);
	setuid(geteuid()||65534);
	
	/* Now that the correct privileges are set, the current working
	 * directory can be changed. This implies a check for user permissions
	 * Also some technical requirements for execution can be checked
	 * before control is given to the wrapper or the script.
	 */
	if(!cd(wd) ||
	   !(us = file_stat(f)) ||
	   !((us[0]&0111) ||
	     ((us[0]&0100) && (uid == us[5])) ||
	     (us[0]&0444) ||
	     ((us[0]&0400) && (uid == us[5])))) {
	  cgi_fail(403, "File exists, but access forbidden by user");
	}
	
	if(wrapper) {
	  if(!(us = file_stat(combine_path(oldwd, wrapper))) ||
	     !(us[0]&0111)) {
	    cgi_fail(403,
		     "Wrapper exists, but access forbidden for user");
	  }
	  exece(combine_path(oldwd, wrapper), ({ f }) + args, env);
	} else {
	  exece(f, args, env);
	}
      };
      catch(roxen_perror("CGI: Exec failed!\n%O\n",
			 describe_backtrace((array)err)));
      exit(0);
    }
    destruct(pipe1);
    if(kill_call_out) {
      call_out(lambda (int pid) {
	object privs;
	catch(privs = Privs("Killing CGI script."));
	int killed;
	killed = kill(pid, signum("SIGINTR"));
	if(!killed)
	  killed = kill(pid, signum("SIGHUP"));
	if(!killed)
	  killed = kill(pid, signum("SIGKILL"));
	if(killed)
	  perror("Killed CGI pid "+pid+"\n");
      }, kill_call_out * 60 , pid);
    }

    if(my_fd && data && sizeof(data)) {
      pipe2->write(data);
      my_fd->set_id( pipe2 );                      // for put..
      my_fd->set_nonblocking(got_some_data, 0, 0); // lets try, atleast..
    }
  }
  
  void create(string wrapper_, string f_, array(string) args_, mapping env_,
	      string wd_, int|string uid_, object pipe1_, object pipe2_,
	      int dup_err_, int kill_call_out_, object my_fd_, string data_)
  {
    wrapper = wrapper_;
    f = f_;
    args = args_;
    env = env_;
    wd = wd_;
    uid = uid_;
    pipe1 = pipe1_;
    pipe2 = pipe2_;
    dup_err = dup_err_;
    kill_call_out = kill_call_out_;
    my_fd = my_fd_;
    data = data_;
    call_out(do_cgi, 0);
  }
};

mixed find_file(string f, object id)
{
  array tmp2;
  object pipe1, pipe2;
  string path_info, wd;
  int pid;
  if(id->misc->path_info && strlen(id->misc->path_info))
    // From last_try code below..
    path_info = id->misc->path_info;
  else 
  {
    if(!(tmp2 = extract_path_info( f )))
    {
      if(file_size( path + f ) == -2)
	return -1; // It's a directory...
      return 0;
    }
    path_info = tmp2[0];
    f = tmp2[1];
  }
  
#ifdef CGI_DEBUG
  perror("CGI: Starting '"+f+"'...\n");
#endif

  wd = dirname(f);
  if ((!(pipe1=files.file())) || (!(pipe2=pipe1->pipe()))) {
    report_error(sprintf("cgi->find_file(\"%s\"): Can't open pipe "
			 "-- Out of fd's?\n", f));
    return(0);
  }
  pipe2->set_blocking(); pipe1->set_blocking();
  pipe2->set_id(pipe2);

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
    if(QUERY(user) && id->misc->is_user && (us = file_stat(id->misc->is_user)))
      uid = us[5..6];
    else if(runuser)
      uid = runuser;
  }
  if(!uid)
    uid = "nobody";

  if (arrayp(uid)) {
    uid = uid[0];
  }

  spawn_cgi(QUERY(use_wrapper) && (QUERY(wrapper) || "/bin/cgi"), f,
	    make_args(id->rest_query),
	    my_build_env_vars(f, id, path_info),
	    wd, uid, pipe1, pipe2, QUERY(err), QUERY(kill_call_out),
	    id->my_fd, id->data);
  
  return http_stream(pipe2);
}


array (string) query_file_extensions()
{
  return query("ext");
}

mapping handle_file_extension(object o, string e, object id)
{
  string f, q, w;
  string oldp;
  mixed toret;
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
    destruct( o );
    o = 0;
    oldp=path;
    path=c[0..sizeof(c)-2]*"/" + "/";

    //  use full path in case of path_info                         1-Nov-96-wk
    if(id->misc->path_info)
      err=catch(toret = find_file(id->realfile, id));
    else
      err=catch(toret = find_file(c[-1], id));
    path=oldp;
    if(err) throw(err);
    return toret;
  }

  // Fallback for odd location modules that does not set the
  // realfile entry in the id object.
  // This could be useful when the data is not really a file, but instead
  // generated internally, or if it is a socket.
#ifdef CGI_DEBUG
  perror("CGI: Handling "+e+" by copying to /tmp/....\n");
#endif
  
  oldp=path;
  o->set_blocking();
  f=o->read(0x7ffffff);         // We really hope that this is not located on 
                               // a NFS server far-far away...
  destruct(o);
  q="/tmp/"+(w=(((id->not_query/"/")[-1][0..2])+"Roxen_tmp"));
  rm(q);
  write_file(q, f);

  popen("chmod u+x "+q);
  path="/tmp/";
  err=catch(toret = find_file(w, id));
  path=oldp;
  if(err) throw(err);
  return toret;
}

mapping last_resort(object id)
{
  if(QUERY(ex)) // Handle path_info for *.ext files as well.
  {            // but only if extensions are used.
    string a, b, e;
    object fid; // As in fake id.. :-)
    mapping res;

    foreach(query_file_extensions(), e)
    {
      if(strlen(e) && sscanf(id->not_query, "%s."+e+"%s", a, b))
      {
	if (sizeof(b) && !((<'?','/'>)[b[0]])) {
	  continue;
	}
	fid = id->clone_me();
	fid->not_query = a+"."+e;
	fid->misc->path_info = b;
	res = roxen->get_file(fid); // Recurse.
	if(res) return res;
      }
    }
  }
}
