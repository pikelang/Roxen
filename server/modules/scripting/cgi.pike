// This is a roxen module. (c) Informationsvävarna AB 1996.

// Support for the <a
// href="http://hoohoo.ncsa.uiuc.edu/docs/cgi/interface.html">CGI/1.1
// interface</a> (and more, the documented interface does _not_ cover
// the current implementation in NCSA/Apache)


string cvs_version = "$Id: cgi.pike,v 1.3 1996/11/27 13:48:13 per Exp $";
#include <module.h>

inherit "module";
inherit "roxenlib";

static mapping env=([]);
static array runuser;


mapping build_env_vars(string f, object id, string|void path_info)
{
  
  mapping new = ::build_env_vars(f,id,path_info);
  if(QUERY(rawauth) && id->rawauth)
    new["HTTP_AUTHORIZATION"] = id->rawauth;
  if(QUERY(clearpass) && id->realauth)
    new["REMOTE_PASSWORD"] = (id->realauth/":")[1];
    
  if(QUERY(Enhancements))
    new |= build_roxen_env_vars(id);
  
  return new|env|(QUERY(env)?environment:([]));
}


void nil(){}

string cvs_version = "$Id: cgi.pike,v 1.3 1996/11/27 13:48:13 per Exp $";
#define ipaddr(x,y) (((x)/" ")[y])

int uid_was_zero()
{
  return !(getuid() == 0); // Somewhat misnamed function.. :-)
}

void create()
{
  defvar("Enhancements", 1, "Roxen CGI Enhancements", TYPE_FLAG,
	 "If defined, Roxen will export a few extra varaibles, namely "
	 "VAR_variable_name: Parsed form variable (like CGI parse)<br>"
	 "QUERY_variable_name: Parsed form variable<br>"
	 "VARIABLES: A space separated list of all form variables<br>"
	 "STATE_variable_name: Parsed state<br>"
	 "STATES: A space separated list of all states");

  defvar("mountpoint", "/cgi-bin/", "CGI-bin path", TYPE_LOCATION, 
	 "This is where the module will be inserted in the "
	 "namespace of your server. The module will, per default, also"
	 " service one or more extensions, from anywhere in the "
	 "namespace.");

  defvar("searchpath", "", "Search path", TYPE_DIR,
	 "This is where the module will find the files in the real "
	 "file system.");

  defvar("noexec", 1, "Ignore non-executable files", TYPE_FLAG,
	 "If this flag is set, non-executable files will be returned "
	 "as-is to the client.");

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

  defvar("env", 0, "Pass environment variables", TYPE_FLAG,
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

  defvar("err", 0, "Send stderr to client", TYPE_FLAG,
	 "It you set this, standard error from the scripts will be redirected"
	 " to the client instead of the logs/debug/[name-of-configdir].1 "
	 "log.\n");

  defvar("rawauth", 0, "Raw user info", TYPE_FLAG,
	 "If set, the raw, unparsed, user info will be sent to the script, "
	 " in the HTTP_AUTHORIZATION environment variable. This is not "
	 "recommended, but some scripts need it. Please note that this "
	 "will give the scripts access to the password used.");

  defvar("clearpass", 0, "Send decoded password", TYPE_FLAG,
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

  defvar("runuser", "", "Run scripts as", TYPE_STRING,
	 "If you start roxen as root, and this variable is set, CGI scripts "
	 "will be run as this user. You can use either the user name or the "
	 "UID. Note however, that if you don't have a working user database "
	 "enabled, only UID's will work correctly. If unset, scripts will "
	 "be run as nobody.", 0, uid_was_zero);

  defvar("user", 1, "Run user scripts as owner", TYPE_FLAG,
	 "If set, scripts in the home-dirs of users will be run as the "
	 "user. This override the Run scripts as variable.", 0, uid_was_zero);

  defvar("extra_env", "", "Extra environment variables", TYPE_TEXT_FIELD,
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
     + "interface.html\">CGI/1.1 interface</a>"
    });
}


static string path;

void start()
{
  string tmp;
  array us;
  path = query("searchpath");

  if(roxen->userlist() && (us = roxen->userinfo( QUERY(runuser) )))
    runuser = ({ (int)us[2], (int)us[3] });
  else if((int)QUERY(runuser))
    runuser = ({ (int)QUERY(runuser), (int)QUERY(runuser) });

  tmp=roxen->query("MyWorldLocation");
  sscanf(tmp, "%*s//%s", tmp);
  sscanf(tmp, "%s:", tmp);
  sscanf(tmp, "%s/", tmp);

  env["SERVER_NAME"]=tmp;
  env["SERVER_SOFTWARE"]=roxen->version();
  env["GATEWAY_INTERFACE"]="CGI/1.1";
  env["SERVER_PROTOCOL"]="HTTP/1.0";
  env["SERVER_URL"]=roxen->query("MyWorldLocation");
  env["AUTH_TYPE"]="Basic";
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

void got_some_data(object to, string d)
{
  to->write( d );
}


mixed find_file(string f, object id)
{
  array tmp2;
  object pipe1, pipe2;
  string path_info, wd;
  
  if(id->misc->path_info && strlen(id->misc->path_info))
    // From last_try code below..
    path_info = id->misc->path_info;
  else 
  {
    if(!(tmp2 = extract_path_info( f ))) {
      if(file_size( path + f ) == -2)
	return -1; // It's a directory...
      return 0;
    }
    path_info = tmp2[0];
    f = tmp2[1];
  }
  
string cvs_version = "$Id: cgi.pike,v 1.3 1996/11/27 13:48:13 per Exp $";
#ifdef CGI_DEBUG
  perror("CGI: Starting '"+f+"'...\n");
string cvs_version = "$Id: cgi.pike,v 1.3 1996/11/27 13:48:13 per Exp $";
#endif
  
  wd = dirname(f);
  pipe1=File();
  pipe2=pipe1->pipe();
    
  array (int) uid;
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
    uid = ({ 65535, 65535 });
    
  if(QUERY(use_wrapper))
  {
    spawne(getcwd()+"/bin/cgi", ({ f }) +  make_args(id->rest_query), 
           build_env_vars(f, id, path_info), 
           pipe1, pipe1, QUERY(err)?pipe1:stderr, wd, uid);
  } else {
    spawne(f, make_args(id->rest_query), 
           build_env_vars(f, id, path_info), 
	   pipe1, pipe1, QUERY(err)?pipe1:stderr, wd, uid);
  }

  destruct(pipe1);

  if(id->data || id->misc->len)
  {
    pipe2->write(id->data);
    id->my_fd->set_nonblocking(got_some_data, 0, 0);
    id->my_fd->set_id( pipe2 );
  }

  pipe2->set_id(pipe2);
  
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
    err = catch(toret = find_file(c[-1], id));
    path=oldp;
    if(err) throw(err);
    return toret;
  }

  // Fallback for odd location modules that does not set the
  // realfile entry in the id object.
  // This could be useful when the data is not really a file, but instead
  // generated internally, or if it is a socket.
string cvs_version = "$Id: cgi.pike,v 1.3 1996/11/27 13:48:13 per Exp $";
#ifdef CGI_DEBUG
  perror("CGI: Handling "+e+" by copying to /tmp/....\n");
string cvs_version = "$Id: cgi.pike,v 1.3 1996/11/27 13:48:13 per Exp $";
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
	fid = id->clone_me();
	fid->not_query = a+"."+e;
	fid->misc->path_info = b;
	res = roxen->get_file(fid); // Recurse.
	if(res) return res;
      }
    }
  }
}



