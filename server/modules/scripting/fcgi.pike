// This is a roxen module. (c) Informationsvävarna AB 1996.

// Support for the FastCGI interface, using an external fast-cgi
// wrapper. This should be handled internally.

string cvs_version = "$Id: fcgi.pike,v 1.7 1997/03/11 01:19:44 per Exp $";
#include <module.h>
inherit "modules/scripting/cgi";

import Stdio;

#define ipaddr(x,y) (((x)/" ")[y])

void create()
{
  ::create();

  set("mountpoint", "/fcgi-bin/");

  defvar("numsimul", 1,
	 "Number of simultaneous copies to run", TYPE_INT,
	 "This many copies will be started simultaneousy of each script. "
	 "This is very "
	 "useful for scripts that take a long time to finish. A tip is to "
	 "us another extension and/or cgi-bin directory for these scripts. "
	 "Remember to code your scripts multi-process safe.");
  
  defvar("ex", 1, "Handle *.fcgi", TYPE_FLAG,
	 "Also handle all '.fcgi' files as Fast-CGI scripts, as well "
	 " as files in the cgi-bin directory. This emulates the behaviour "
	 "of the NCSA server (the extensions to handle can be set in the "
	 "CGI-script extensions variable).");

  set("ext", ({"fcgi"}));
  mkdir("/tmp/.Roxen_fcgi_pipes");
}


mixed *register_module()
{
  if(file_stat("bin/fcgi"))
    return ({ 
      MODULE_FIRST | MODULE_LOCATION | MODULE_FILE_EXTENSION,
	"Fast-CGI executable support", 
	"Partial support for the <a href=http://www.fastcgi.com>Fast-CGI interface</a>. This module is useful, but not finished."
	});
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

mixed find_file(string f, object id)
{
  object pipe1, pipe2;
  string path_info;
  
  if(!id->misc->path_info)
  {
    array tmp2;
    tmp2 = ::extract_path_info(f);
    if(!tmp2) {
      array st2;
      if((st2=file_stat( path + f )) && (st2[1]==-2))
	return -1; // It's a directory...
      return 0;
    }
    path_info = tmp2[0];
    f = tmp2[1];
  } else
    path_info = id->misc->path_info;

#ifdef CGI_DEBUG
  perror("FCGI: Starting '"+f+"'...\n");
#endif
    
  pipe1=files.file();
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
  perror("Starting '"+cwd()+"/bin/fcgi -connect "+make_pipe_name(f)+" "+ f +
	 " "+QUERY(numsimul)+"\n");
#endif
  
  spawne(getcwd()+"/bin/fcgi", ({"-connect", make_pipe_name(f), f,
				 QUERY(numsimul)+"" }),
	 ::build_env_vars(f, id, path_info),
	 pipe1, pipe1, QUERY(err)?pipe1:stderr, dirname(f),
	 uid);

  destruct(pipe1);

  if(id->data)
    pipe2->write(id->data);
  
  return http_stream(pipe2);
}



