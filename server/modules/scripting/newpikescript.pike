#if !constant(Remote)
# error The remote module was not present
#endif

#if constant(roxen)
// Ok. This is a roxen module, then...


#include <config.h>
#include <module.h>
inherit "module";
inherit "roxenlib";

mixed *register_module()
{
  return ({ 
    MODULE_FILE_EXTENSION,
    "Pike script support mark II", 
    "This is an enhanced version of the normal 'pike scripts' module. "
    "Major features:<ul>\n"
    "<li> A separate process for each user."
    "<li> The processes are quite persistent"
    "</ul>"
    });
}


constant cvs_version="$Id: newpikescript.pike,v 1.2 1998/03/24 02:32:13 per Exp $";
constant thread_safe=1;

void create()
{
  defvar("exts", ({ "pike" }), "Extensions", TYPE_STRING_LIST,
	 "The extensions to parse");

  defvar("exec-mask", "0777", 
	 "Exec mask: Always run scripts matching this permission mask", 
	 TYPE_STRING|VAR_MORE,
	 "");

  defvar("noexec-mask", "0000", 
	 "Exec mask: Never run scripts matching this permission mask", 
	 TYPE_STRING|VAR_MORE,
	 "");
}

array query_file_extensions() { return query("exts"); }

mapping in_progress = ([ ]);
mapping servers_for = ([]);
object server_for(int uid, int gid)
{
  if(servers_for[uid])
    return servers_for[uid];
  string data;
  for(int i=0; i<5; i++)
  {
    if(data = Stdio.read_bytes(".pike-script-servers/"+uid))
    {
      string host, key;
      int port;
      sscanf(data, "%s %d\n%s", host, port, key);
      catch 
      {
	return servers_for[uid]=Remote.Client(host,port)->get( key );
      };
    }
    sleep(0.02);
  }
  // fallthrough..
  rm(".pike-script-servers/"+uid);
  // So. Now we have to start a new server....
  object pid = 
    Process.create_process(({"./start","--once","--program",
			     "modules/scripting/newpikescript.pike" }),
			   ([
			     "uid":uid,
			     "stdout":Stdio.stdout,
			     "stderr":Stdio.stderr,
			     "stdin":Stdio.stdin,
			     "gid":gid,
			     "nice":2,
			   ]));

  if(in_progress[uid]++)
  {
    while(in_progress[uid]) sleep(0.1);
    return server_for( uid,gid );
  }

  int num;
  while(!file_stat(".pike-script-servers/"+uid) && num<400)
  {
    num++;
    sleep(0.01);
  }
  in_progress[uid] = 0;
  if(num>399) return 0;
  return server_for(uid,gid);
}

mapping handle_file_extension(object file, string ext, object id)
{
  int mode = file->stat()[0];
  if(!(mode & (int)query("exec-mask")) ||
     (mode & (int)query("noexec-mask")))
    return 0;  // permissions does not match.


  // BLOCKING! (but threaded, if we have threads.)
  int uid, gid;
  // First, check for id->misc->is_user
  if(getuid())
  {
    uid = getuid();
    gid = getgid();
  } else if(id->misc->is_user)
    [uid,gid] = file_stat(id->misc->is_user)[4..5];
  else
    [uid,gid] = getpwnam("nodbody")[4..5];

  object server = server_for( uid,gid );
  string file_name = id->conf->real_file( id->not_query, id );

  if(!server) 
    throw(({"Failed to connect to pike-script server for "+uid,
	  backtrace()}));

  if(!file_name) 
  {
    werror("Copying temporary file... ["+id->not_query+"]\n");
    file_name = "/tmp/"+getpid()+"."+uid+".pike";
    rm(file_name);
    Stdio.write_file( file_name, file->read() );
  }
  array err;
  mixed res;
  if(err = catch(res=server->call_pikescript
		 (file_name, roxen,mkmapping(indices(id),values(id)))))
  {
    if(!id->misc->__idipikescripterror++)
    {
      destruct(server);
      return handle_file_extension(file,ext,id);
    }
    throw(err);
  }
  if(stringp(res))
    return http_string_answer(parse_rxml(res, id));
  return res;
}

#else

// This is now a stand-alone pike program.

// What to do:
// o Open the 'remote' socket
// o Write it's location to the file .pikescript_servers/uid
// o Provide the 'pikescript' service
// o Wait for calls from Roxen.

mapping globals = ([]);

mapping scripts = ([]);
int last_call;
object get_pikescript(string file, mixed id)
{
  last_call = time();
  if(!scripts[file] || id->pragma["no-cache"])
  {
    string data = cpp("#define roxen globals->roxen\n# 1 \""+file+"\"\n"
		      +Stdio.read_bytes(file), file);
    return scripts[file] = compile(data)();
  }
  return scripts[file];
}

mixed call_pikescript(string file, object roxen, mapping id)
{
  globals->roxen = roxen;
  return get_pikescript( file, id  )->parse( id );
}

string get_some_random_data()
{
  string res="";
  for(int i=0;i<random(20)+10;i++)
    res += sprintf("%c", random(256));
  return MIME.encode_base64(res);
}

object remote_server;

void die()
{
  rm(".pike-script-servers/"+getuid());
  kill(getpid(), 9);
}

string in_file;
void perhaps_die()
{
  if(Stdio.read_bytes(".pike-script-servers/"+getuid()) != in_file)   
    kill(getpid(), 9);
  else if(time()-last_call>1800) 
    die();
}

int main()
{
  object db;
  add_constant("globals", globals);
  string name = get_some_random_data();
  remote_server = Remote.Server(0,0);
  in_file=(replace(remote_server->port->query_address(),
		   "0.0.0.0",gethostname())+"\n"+name);
  remote_server->provide(name, this_object());

  master()->add_include_path("base_server");
  master()->add_program_path("base_server");
  master()->add_module_path("etc/modules");
  db=spider;
  add_constant("roxenp", lambda(){return globals->roxen;});
  add_constant("error", lambda(string what){throw(({ what, backtrace()}));});

  // ok.. Now write the location to the correct file.
  // pwd is the 'server' directory.
  
  mkdir(".pike-script-servers");
  chmod(".pike-script-servers", 07777);
  rm(".pike-script-servers/"+getuid());
  Stdio.write_file(".pike-script-servers/"+getuid(), in_file);
  chmod(".pike-script-servers/"+getuid(), 0644);

  call_out(perhaps_die, 300);
  return -1;
}
#endif
