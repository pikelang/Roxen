// This is a roxen module. Copyright © 1996 - 1998, Idonex AB.

// Support for the FastCGI interface, using an external fast-cgi
// wrapper. This should be handled internally.

string cvs_version = "$Id: fcgi.pike,v 1.20 1999/03/17 23:47:16 grubba Exp $";

#include <module.h>
inherit "modules/scripting/cgi";

#define ipaddr(x,y) (((x)/" ")[y])

void create(object c)
{
  ::create(c);

  set("mountpoint", "/fcgi-bin/");

  defvar("numsimul", 1,
	 "Number of simultaneous copies to run", TYPE_INT,
	 "This many copies will be started simultaneousy of each script. "
	 "This is very useful for scripts that take a long time to finish. "
	 "A tip is to use another extension and/or cgi-bin directory for "
	 "these scripts. Remember to code your scripts multi-process safe.");
  
  defvar("ex", 1, "Handle *.fcgi", TYPE_FLAG,
	 "Also handle all '.fcgi' files as Fast-CGI scripts, as well "
	 "as files in the cgi-bin directory. This emulates the behaviour "
	 "of the NCSA server (the extensions to handle can be set in the "
	 "CGI-script extensions variable).");

  set("ext", ({"fcgi"}));
  if (mkdir("/tmp/.Roxen_fcgi_pipes")) {
    chmod("/tmp/.Roxen_fcgi_pipes/.", 01777);
  }
}


mixed *register_module()
{
  if(file_stat("bin/fcgi")) {
    return ({ 
      MODULE_FIRST | MODULE_LOCATION | MODULE_FILE_EXTENSION,
      "Fast-CGI executable support", 
      "Partial support for the "
      "<a href=http://www.fastcgi.com>Fast-CGI interface</a>. "
      "This module is useful, but not finished."
    });
  }
}


string query_name() 
{ 
  return sprintf("Fast-CGI support, mounted on "+query_location());
}

int last;

mapping stof = ([]);


string make_pipe_name(string from)
{
  string s;
  
  if(s = stof[from])
    return s;
  s = "/tmp/.Roxen_fcgi_pipes/"+hash(from);
  while(search(stof,s))
    s+=".2";
  return stof[from] = s;
}

mixed low_find_file(string f, object id, string path)
{
  object pipe1, pipe2;
  string path_info;
  NOCACHE();
  
  array st2;
  if(!(st2=file_stat( path + f )))
    return 0; // File not found.
  if (st2[1]==-2)
    return -1; // It's a directory...

  path_info = id->misc->path_info;

#ifdef CGI_DEBUG
  roxen_perror("FCGI: Starting '"+f+"'...\n");
#endif
    
  pipe1=Stdio.File();
  pipe2=pipe1->pipe();
    
  array (int) uid;
    
  if(!getuid())
  {
    array us;
    if(QUERY(user)&&id->misc->is_user&&(us = file_stat(id->misc->is_user)))
      uid = us[5..6];
    else if(runuser)
      uid = runuser;
    if(!uid)
      uid = ({ 65534, 65534 });
  }

#ifdef CGI_DEBUG
  roxen_perror("Starting '"+getcwd()+"/bin/fcgi -connect "+make_pipe_name(f)+" "+ f +
	       " "+QUERY(numsimul)+"\n");
#endif
  
  spawne(getcwd()+"/bin/fcgi", ({"-connect", make_pipe_name(f), f,
				 QUERY(numsimul)+"" }),
	 my_build_env_vars(f, id, path_info),
	 pipe1, pipe1, QUERY(err)?pipe1:Stdio.stderr, dirname(f),
	 uid);

  destruct(pipe1);

  if(id->data)
    pipe2->write(id->data);
  
  return http_stream(pipe2);
}

mixed find_file(string f, object id)
{
  low_find_file(f, id, ::search_path);
}
