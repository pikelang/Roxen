constant cvs_version="$Id: newpikescript.pike,v 1.8 1998/09/11 22:20:04 per Exp $";
constant thread_safe=1;

#if !constant(Remote)
# error The remote module was not present
#else /* constant(Remote) */
#define SERVERDIR ".pike-script-servers/"

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


void create()
{
  defvar("exts", ({ "pike" }), "Extensions", TYPE_STRING_LIST,
	 "The extensions to parse");

  defvar("isuser_overrides", 1, "Exec as user overrides patterns", TYPE_FLAG,
	 "The user filesystem module sets the 'exec as user' flag, indicating "
	 "that the script should be executed with the UID of the owner, "
	 "if possible. If this flag is set to 'Yes', this vill have "
	 "precedence over the 'Local URI to uid patterns' variable");

  defvar("permission maps", "*: STAT\n", "Local URI to uid patterns",TYPE_TEXT,
	 "Use these user/groups. Syntax: \"pattern: STAT\" or "
	 "\"pattern: uid[/gid]\"<br>STAT means 'use file owner uid/gid',"
	 " otherwise the specified uid is used.");

  defvar("exec-mask", "0777", 
	 "Exec mask: Always run scripts matching this permission mask", 
	 TYPE_STRING|VAR_MORE,	 "");

  defvar("noexec-mask", "0000", 
	 "Exec mask: Never run scripts matching this permission mask", 
	 TYPE_STRING|VAR_MORE, "");
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
    if(data = Stdio.read_bytes(SERVERDIR+uid))
    {
      string host, key;
      int port;
      sscanf(data, "%s %d\n%s", host, port, key);
      catch 
      {
	return servers_for[uid]=Remote.Client(host,port)->get( key );
      };
    }
    sleep(0.2);
  }
  // fallthrough..
  report_debug("Failed to connect to old pike-script server.\n");
  rm(SERVERDIR+uid);
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
  while(!file_stat(SERVERDIR+uid) && num<400)
  {
    num++;
    sleep(0.01);
  }
  in_progress[uid] = 0;
  if(num>399) return 0;
  return server_for(uid,gid);
}

class FakedRoxen
{
  // So. What do we allow?

#define FAKE(x) case #x: return roxen->x;
  mixed `[](string what)
  {
    switch(what)
    {
      FAKE(set_var);
      FAKE(query_var);
      FAKE(real_version);
      FAKE(version);
      FAKE(start_time);
      FAKE(find_supports);
      FAKE(full_status);
      FAKE(userlist);
      FAKE(user_from_uid);
      FAKE(last_modified_by);
      FAKE(type_from_filename);
      FAKE(config_url);
      FAKE(query);
      FAKE(available_fonts);
      
      FAKE(quick_host_to_ip);
      FAKE(quick_ip_to_host);
      FAKE(blocking_ip_to_host);
      FAKE(blocking_host_to_ip);
      FAKE(ip_to_host);
      FAKE(host_to_ip);
      FAKE(languages);
      FAKE(language);
    }
  } 
}

array uid_patterns = ({});
object faked_roxen;

void start()
{
  faked_roxen = FakedRoxen(  );

  foreach(query("permission maps")/"\n", string line)
    if(strlen(line) && line[0] != '#')
    {
      mixed uid, patt;
      if(sscanf(line, "%s:%s", patt, uid) == 2)
      {
	patt = reverse(patt);sscanf(patt, "%*[ \t]%s", patt);
	patt = reverse(patt);sscanf(patt, "%*[ \t]%s", patt);
	uid = reverse(uid);sscanf(uid, "%*[ \t]%s", uid);
	uid = reverse(uid);sscanf(uid, "%*[ \t]%s", uid);
	if(lower_case(uid) == "stat")
	  uid_patterns += ({ patt, 0 });
	else 
	{
	  mixed gid;
	  sscanf(uid, "%s/%s", uid, gid);
#if efun(getpwnam)
	  if(!(int)uid && (uid != "0"))
	  {
	    array t = getpwnam(uid);
	    if(!t) report_error("Failed to find UID "+uid+"\n");
	    else {
	      if(!gid) gid = t[3];
	      uid = t[2];
	    }
	  }
#endif
#if efun(getgrnam)
	  if(!(int)gid && ((string)gid != "0"))
	  {
	    array t = getgrnam(uid);
	    if(!t) report_error("Failed to find GID "+gid+"\n");
	    else gid = t[2];
	  }
#endif
	  uid_patterns += ({ patt, ({uid,gid}) });
	}
      }
    }
}

array (int) find_uid(string file, string isuser, object id)
{
  if(isuser && query("isuser_overrides"))
    return file_stat(isuser)[5..6]; // this overrides the patterns...

  foreach(uid_patterns, array p)
    if(glob(p[0], file))
      if(p[1]) 
	return p[1];
      else
	if(catch{ // if stat failes, skip to next...
	  return file_stat(id->realfile||id->conf->real_file(file,id))[5..6];
	})
	  report_error("newpikescript: Failed to stat "+
		       (id->realfile||id->conf->real_file(file,id))+"\n");

  if(isuser)return file_stat(isuser)[5..6];

  return getpwnam("nodbody")?getpwnam("nodbody")[2..3]:({65535,65535});
}

class Call
{
  object id;
  void create(object _id) { id = _id; }
  void done(mixed result, int is_error)
  {
    id->do_not_disconnect = 0;
    if(is_error)
    {
      result = id->internal_error( ({ result[0],
				      ({({__FILE__, __LINE__, done,
					  ({ result, is_error })})})+
				      ({"Result from remote server" })+
				      result[1]}));
      id->send_result( result );
    }
    else if(!result)
      id->send_result(0);
    else if(stringp(result))
      id->send_result( http_string_answer(parse_rxml(result,id),"text/html") );
    else
      id->send_result( result );

    destruct();
  }
}

mapping handle_file_extension(object file, string ext, object id)
{
  int mode = file->stat()[0];
  if(!(mode & (int)query("exec-mask")) ||
     (mode & (int)query("noexec-mask")))
    return 0;  // permissions does not match.

  NOCACHE();

  // BLOCKING! (but threaded, if we have threads.)
  int uid, gid;
  // First, check for id->misc->is_user
  if(getuid())
  {
    uid = getuid();
    gid = getgid();
  } else
    [uid,gid] = find_uid(id->not_query, id->misc->is_user, id);

  object server = server_for( uid,gid );
  string file_name = id->conf->real_file( id->not_query, id );

  if(!server)
    error("Failed to connect to pike-script server for "+uid+"\n");

  if(!file_name)
  {
//     werror("Copying temporary file... ["+id->not_query+"]\n");
    file_name = "/tmp/"+getpid()+"."+uid+".pike";
    rm(file_name);
    Stdio.write_file( file_name, file->read() );
  }
  array err;
  mixed res;

  /* Now it is time to call the script.. If possible, do this in a non
   * blocking fashion, otherwise a normal user can stop the server by
   * writing stupid pikescripts.
   *
   * If it is not possible to do this non-blocking, we should setup a
   * timeout instead. This is rather hard to do in a threaded server.
   * */


  if(id->misc->orig) /* Not a direct request. We must block */
  {
    if(err=catch(res=server->call_pikescript
		 (file_name, faked_roxen,mkmapping(indices(id),values(id)))))
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
  } else {
    object call = Call( id );
    if(err=catch(server->call_pikescript->async
		 (file_name, faked_roxen,
		  mkmapping(indices(id),values(id)),
		  call->done)))
    {
      destruct(call);
      if(!id->misc->__idipikescripterror++)
      {
	destruct(server);
	return handle_file_extension(file,ext,id);
      }
      throw(err);
    }
    id->do_not_disconnect = 1;
    return http_pipe_in_progress();
  }
}
#else

// This is now a stand-alone pike program.

// What to do:
// o Open the 'remote' socket
// o Write it's location to the file .pikescript_servers/uid
// o Provide the 'pikescript' service
// o Wait for calls from Roxen.

#define eventlog(X) do{ if(_eventlog) _eventlog(X); } while(0)
function _eventlog ;
mapping globals = ([]);
mapping scripts = ([]);
int last_call;

object _get_pikescript(string file, mixed id)
{
  last_call = time();
  if(!scripts[file] || id->pragma["no-cache"])
  {
    eventlog("Compile "+file+" "+
	     (id->pragma["no-cache"]?"Client reload":"New"));
    string data = cpp("#define roxen globals->roxen\n# 1 \""+file+"\"\n"
		      +Stdio.read_bytes(file), file);
    return scripts[file] = compile(data)();
  }
  return scripts[file];
}

function get_pikescript = _get_pikescript;
function set_roxen;
string errors;
void got_compile_error(string file, int line, string err)
{
  errors += sprintf("%s:%d:%s\n",file,line,err);
}

array trim_errormessage(array emsg)
{
  array res = ({});
  foreach(emsg[1], array q)
  {
    for(int i=0; i<sizeof(q); i++)
    {
      if(functionp(q[i]) || programp(q[i]) || objectp(q[i]))
	q[i] = sprintf("%O", q[i]);
    }
    res += ({ q });
  }
  return ({ emsg[0], res[3..] });
}

mixed _call_pikescript(string file, object roxen, mapping id, 
		       object|void done)
{
  eventlog("Call script "+file);
  globals->roxen = roxen;
  errors="";
  if(set_roxen) set_roxen(roxen, id->conf);
  array err;
  err = catch {
    mixed res=get_pikescript( file, id  )->parse( id );
    if(done) 
    {
      done->async( res );
      return 0;
    }
    return res;
  };
  if(err[0] == "Compilation failed.\n")
  {
    eventlog("Compilation failed:\n   "+replace(errors,"\n", "\n   "));
    if(done)
    {
      done->async("<h1>Compilation of "+
		  file+" failed</h1><pre>"+errors+"</pre>");
      return 0;
    }
    else
      return ("<h1>Compilation of "+file+" failed</h1><pre>"+errors+"</pre>");
  }
  if(done)
    done->async( trim_errormessage(err), 1 );
  else
    throw(err);
}

function call_pikescript = _call_pikescript;

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
  eventlog("Pike script server PID "+
	   getpid()+" exiting (no accesses for 30 minutes)");
  rm(basedir+SERVERDIR+getuid());
  kill(getpid(), 9);
}

string in_file, basedir;

void perhaps_die()
{
  if(Stdio.read_bytes(basedir+SERVERDIR+getuid()) != in_file)   
  {
    eventlog("Old pike script server PID "+
	   getpid()+" exiting (new available?)");
    kill(getpid(), 9);
  }
  else if(time()-last_call>1800)
    die();
}

int main()
{
  object db;
  basedir = getcwd()+"/";
  add_constant("globals", globals);
  string name = get_some_random_data();

  add_include_path(getcwd()+"/base_server/");
  add_program_path(getcwd()+"/base_server/");
  add_module_path(getcwd()+"/base_server/");
  add_module_path(getcwd()+"/etc/modules/");

  remote_server = Remote.Server("localhost",0);

  in_file=(replace(remote_server->port->query_address(),
		   "0.0.0.0",gethostname())+"\n"+name);

  remote_server->provide(name, this_object());

  array u = getpwuid(getuid());
  if(u)
  {
    report_notice("Starting a pike-script server for "+
		  u[4]+"; pid = "+getpid()+"\n");
    cd(u[5]);
    if(cd(".pikescripts"))
    {
      if(file_stat("rc.pike"))
      {
	object f = compile_file("rc.pike")(this_object(),remote_server);
	if(f->call_pikescript) call_pikescript = f->call_pikescript;
	if(f->get_pikescript)  get_pikescript = f->get_pikescript;
	if(f->set_roxen) set_roxen = f->set_roxen;
	if(f["eventlog"]) _eventlog = f["eventlog"];
      }
    }
  }

  master()->add_include_path("base_server");
  master()->add_program_path("base_server");
  master()->add_module_path("etc/modules");
  db=spider;
  add_constant("roxenp", lambda(){return globals->roxen;});
  add_constant("error", lambda(string what){array b = backtrace();
            throw(({ what, b[..sizeof(b)-2]}));});

  // ok.. Now write the location to the correct file.
  // pwd is the 'server' directory.
  
  string sd = basedir+SERVERDIR;
  mkdir(sd[..strlen(sd)-2]);
  catch(chmod(sd[..strlen(sd)-2], 07777));
  rm(sd+getuid());
  Stdio.write_file(sd+getuid(), in_file);
  chmod(sd+getuid(), 0644);
  call_out(perhaps_die, 300);
  eventlog("Pike script server started as PID "+
	   getpid()+" on "+gethostname());
  werror("Pike script server up and running\n");
  master()->set_inhibit_compile_errors( got_compile_error );
  return -1;
}
#endif

#endif /* constant(Remote) */
