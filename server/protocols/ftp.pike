/* Roxen FTP protocol.
 *
 * $Id: ftp.pike,v 1.41 1997/08/26 12:44:06 grubba Exp $
 *
 * Written by:
 *	Pontus Hagland <law@lysator.liu.se>,
 *	David Hedbor <neotron@infovav.se>,
 *	Henrik Grubbström <grubba@infovav.se> and
 *	Marcus Comstedt <marcus@infovav.se>
 *
 * Some of the features: 
 *
 *	* All files are parsed the same way as if they were fetched via WWW.
 *
 *	* If someone logs in with a non-anonymous name, normal
 *	authentification is done. This means that you for example can
 *	use .htaccess files to limit access to different directories.
 *
 *	* You can have 'user ftp directories'. Just add a user database
 *	and a user filesystem. Notice that _normal_ non-anonymous ftp
 *	should not be used, due to security reasons.
 */

inherit "http"; /* For the variables and such.. (Per) */ 
inherit "roxenlib";

#include <config.h>
#include <module.h>
#include <stat.h>

import Array;

#define perror	roxen_perror

string controlport_addr, dataport_addr, cwd ="/";
int controlport_port, dataport_port;
object cmd_fd, pasv_port;
int GRUK = random(_time(1));
function(object,mixed:void) pasv_callback;
mixed pasv_arg;
array(object) pasv_accepted;
array(string|int) session_auth = 0;
string username="";
#undef QUERY
#define QUERY(X) roxen->variables->X[VAR_VALUE]
#define Query(X) conf->variables[X][VAR_VALUE]  /* Per */

/********************************/
/* Flags for the simulated 'ls' */

#define LS_FLAG_A	1
#define LS_FLAG_a	2
#define LS_FLAG_C	4
#define LS_FLAG_d	8
#define LS_FLAG_F	16
#define LS_FLAG_l	32
#define LS_FLAG_r	128
#define LS_FLAG_t	256

constant decode_flags =
([
  "A":LS_FLAG_A,
  "a":(LS_FLAG_a|LS_FLAG_A),
  "C":LS_FLAG_C,
  "d":LS_FLAG_d,
  "F":LS_FLAG_F,
  "l":LS_FLAG_l,
  "r":LS_FLAG_r,
  "t":LS_FLAG_t
]);


/********************************/
/* private functions            */

void reply(string X)
{
  conf->hsent += strlen(X);
  cmd_fd->write(replace(X, "\n","\r\n"));
}

private string reply_enumerate(string s,string num)
{
   string *ss;
   ss=s/"\n";
   while (sizeof(ss)&&ss[-1]=="") ss=ss[0..sizeof(ss)-2];
   if (sizeof(ss)>1) 
      return num+"-"+(ss[0..sizeof(ss)-2]*("\n"+num+"-"))+
	     "\n"+num+" "+ss[-1]+"\n";
   return num+" "+ss[-1]+"\n";
}

private static multiset|int allowed_shells = 0;

private int check_shell(string shell)
{
  if (Query("shells") != "") {
    if (!allowed_shells) {
      object(files.file) file = files.file();

      if (file->open(Query("shells"), "r")) {
	allowed_shells = aggregate_multiset(@(map(file->read(0x7fffffff)/"\n",
						  lambda(string line) {
	  return((((line/"#")[0])/"" - ({" ", "\t"}))*"");
	} )-({""})));
#ifdef DEBUG
	perror(sprintf("ftp.pike: allowed_shells:%O\n", allowed_shells));
#endif /* DEBUG */
      } else {
	perror(sprintf("ftp.pike: Failed to open shell database (\"%s\")\n",
		       Query("shells")));
	return(0);
      }
    }
    return(allowed_shells[shell]);
  }
  return(1);
}

/********************************/
/* public methods               */

void end(string|void);

void disconnect()
{
  if(objectp(pipe) && pipe != Simulate.previous_object()) 
    destruct(pipe);
  cmd_fd = 0;
  if(pasv_port) {
    destruct(pasv_port);
    pasv_port = 0;
  }
  destruct(this_object());
}

void end(string|void s)
{
  if(objectp(cmd_fd))
  {
    if(s)
      cmd_fd->write(s);
    destruct(cmd_fd);
  }
  disconnect();
}

/* We got some data on a socket.
 * ================================================= */

void got_data(mixed fooid, string s);

mapping internal_error(array err)
{
  roxen->nwrite("Internal server error: " +
		  describe_backtrace(err) + "\n");
  cmd_fd->write(reply_enumerate("Internal server error: "+
			       describe_backtrace(err)+"\n"+
			       "Service not available, please try again","421"));
}

string name_from_uid(int uid)
{
  array(string) user = conf->auth_module &&
    conf->auth_module->user_from_uid(uid);
  return (user && user[0]) || (""+uid);
}

string file_ls(array (int) st, string file)
{
  int mode = st[0] & 007777;
  string perm;
  
  switch(st[1])
  {
   case -2: case -3:
    perm = "d";
    break;
    
   default:
    perm = "-";
  }
  
  if(mode & S_IRUSR)
    perm += "r";
  else 
    perm += "-";

  if(mode & S_IWUSR)
    perm += "w";
  else 
    perm += "-";

  if(mode & S_IXUSR)
    if(mode & S_ISUID)
      perm += "s";
    else 
      perm += "x";
  else 
    if(mode & S_ISUID)
      perm += "S";
    else
      perm += "-";

  if(mode & S_IRGRP)
    perm += "r";
  else 
    perm += "-";

  if(mode & S_IWGRP)
    perm += "w";
  else 
    perm += "-";

  if(mode & S_IXGRP)
    if(mode & S_ISGID)
      perm += "s";
    else 
      perm += "x";
  else 
    if(mode & S_ISGID)
      perm += "S";
    else
      perm += "-";

  if(mode & S_IROTH)
    perm += "r";
  else 
    perm += "-";

  if(mode & S_IWOTH)
    perm += "w";
  else 
    perm += "-";

  if(mode & S_IXOTH)
    if(mode & S_ISVTX)
      perm += "s";
    else 
      perm += "x";
  else 
    if(mode & S_ISVTX)
      perm += "S";
    else
      perm += "-";
  string ct = ctime(st[-4]);
  return sprintf("%s   1 %-10s %-6d%12d %s %s %s\r\n", perm,
		 name_from_uid(st[-2]), st[-1],
		 (st[1]<0? 512:st[1]), ct[4..9], ct[11..15], file);
}

void pasv_accept_callback(mixed id)
{
  if(pasv_port) {
    object fd = pasv_port->accept();
    if(fd) {
      array(string) remote = (fd->query_address()||"? ?")/" ";
      mark_fd(fd->query_fd(),
	      "ftp communication: -> "+remote[0]+":"+remote[1]);

      if(pasv_callback) {
	pasv_callback(fd, pasv_arg);
	pasv_callback = 0;
      } else
	pasv_accepted += ({ fd });
    }
  }
}

void ftp_async_accept(function(object,mixed:void) callback, mixed arg)
{
  if(sizeof(pasv_accepted)) {
    callback(pasv_accepted[0], arg);
    pasv_accepted = pasv_accepted[1..];
  } else {
    pasv_callback = callback;
    pasv_arg = arg;
  }
}

void done_callback(object fd)
{
  if(fd)
  {
    fd->close();
    destruct(fd);
  }
  reply("226 Transfer complete.\n");
  cmd_fd->set_read_callback(got_data);
  cmd_fd->set_write_callback(lambda(){});
  cmd_fd->set_close_callback(end);
  mark_fd(cmd_fd->query_fd(), GRUK+" cmd channel not sending data");
}

void connected_to_send(object fd,mapping file)
{
  object pipe=Pipe.pipe();

  if(!file->len)
    file->len = file->data?(stringp(file->data)?strlen(file->data):0):0;

  if(fd)
  {
    reply(sprintf("150 Opening BINARY mode data connection for %s "
		  "(%d bytes).\n", not_query, file->len));
  }
  else
  {
    reply("425 Can't build data connect: Connection refused.\n"); 
    return;
  }

  if(stringp(file->data))  pipe->write(file->data);
  if(file->file) {
    file->file->set_blocking();
    pipe->input(file->file);
  }

  pipe->set_done_callback(done_callback, fd);
  pipe->output(fd);
}

inherit "socket";
void ftp_async_connect(function(object,mixed:void) fun, mixed arg)
{
  // More or less copied from socket.pike
  
  object(files.file) f = files.file();

  object privs = ((program)"privs")("FTP: Opening the control-port.");

  if(!f->open_socket(controlport_port-1))
  {
#ifdef FTP_DEBUG
    perror("ftp: socket("+(controlport_port-1)+") failed. Trying with any port.\n");
#endif
    if (!f->open_socket()) {
#ifdef FTP_DEBUG
      perror("ftp: socket() failed. Out of sockets?\n");
#endif
      fun(0, arg);
      destruct(f);
      return;
    }
  }
  privs = 0;

  f->set_id( ({ fun, ({ arg }), f }) );
  f->set_nonblocking(0, lambda(array args) {
#ifdef FTP_DEBUG
    perror("ftp: async_connect ok.\n");
#endif
    args[2]->set_id(0);
    args[0](args[2], @args[1]);
  }, lambda(array args) {
#ifdef FTP_DEBUG
    perror("ftp: connect_and_send failed\n");
#endif
    args[2]->set_id(0);
    destruct(args[2]);
    args[0](0, @args[1]);
  });

  mark_fd(f->query_fd(),
	  "ftp communication: -> "+dataport_addr+":"+dataport_port);

  if(catch(f->connect(dataport_addr, dataport_port)))
  {
#ifdef FTP_DEBUG
    perror("ftp: Illegal internet address in connect in async comm.\n");
#endif
    fun(0, arg);
    destruct(f);
    return;
  }  
}

void connect_and_send(mapping file)
{
  if(pasv_port)
    ftp_async_accept(connected_to_send, file);
  else
    ftp_async_connect(connected_to_send, file);
}

class put_file_wrapper {

  inherit files.file;

  object id;
  string response;
  string gotdata;
  int done;

  int close(string|void how)
  {
    if(how != "w" && !done) {
      id->reply(response);
      done = 1;
      id->file = 0;
    }
    return (how? ::close(how) : ::close());
  }

  int write(string data)
  {
    int n, code;
    string msg;
    gotdata += data;
    while((n=search(gotdata, "\n"))>=0) {
      if(3==sscanf(gotdata[..n], "HTTP/%*s %d %[^\r\n]", code, msg)
	 && code>199) {
	if(code < 300)
	  code = 200;
	else
	  code = 550;
	response = code + " " + msg + "\n";
      }
      gotdata = gotdata[n+1..];
    }
    return strlen(data);
  }

  void create(object i, object f)
  {
    id = i;
    assign(f);
    response = "200 Stored.\n";
    gotdata = "";
    done = 0;
  }

}

int open_file(string arg, int|void noport);

void connected_to_receive(object fd, string arg)
{
  if(fd)
  {
    reply(sprintf("150 Opening BINARY mode data connection for %s.\n", arg));
  }
  else
  {
    reply("425 Can't build data connect: Connection refused.\n"); 
    return;
  }

  method = "PUT";
  my_fd = put_file_wrapper(this_object(), fd);
  data = 0;
  misc->len = 0x7fffffff;

  if(open_file(arg)) {
    if(!(file->pipe)) {
      fd->close();
      switch(file->error) {
      case 401:
	reply("532 "+arg+": Need account for storing files.\n");
	break;
      case 501:
	reply("502 "+arg+": Command not implemented.\n");
	break;
      default:
	reply("550 "+arg+": Error opening file.\n");
      }
    }
  } else
    fd->close();
}

void connect_and_receive(string arg)
{
  if(pasv_port)
    ftp_async_accept(connected_to_receive, arg);
  else
    ftp_async_connect(connected_to_receive, arg);
}

// NOTE: base is modified destructably!
array(string) my_combine_path_array(array(string) base, string part)
{
  if ((part == ".") || (part == "")) {
    if ((part == "") && (!sizeof(base))) {
      return(({""}));
    } else {
      return(base);
    }
  } else if ((part == "..") && sizeof(base) &&
	     (base[-1] != "..") && (base[-1] != "")) {
    base[-1] = part;
    return(base);
  } else {
    return(base + ({ part }));
  }
}

string my_combine_path(string base, string part)
{
  if ((sizeof(part) && (part[0] == '/')) ||
      (sizeof(base) && (base[0] == '/'))) {
    return(combine_path(base, part));
  }
  // Combine two relative paths.
  int i;
  array(string) arr = ((base/"/") + (part/"/")) - ({ ".", "" });
  foreach(arr, string part) {
    if ((part == "..") && i && (arr[i-1] != "..")) {
      i--;
    } else {
      arr[i++] = part;
    }
  }
  if (i) {
    return(arr[..i-1]*"/");
  } else {
    return("");
  }
}

string list_files(array(string) files, string dir,
		  mapping(string:string) comb_path,
		  mapping(string:array) stat_cache,
		  int flags)
{
  array(int) times = allocate(sizeof(files));
  int i;
  for (i=0; i < sizeof(files); i++) {
    string long;
    if (!(long = comb_path[files[i]])) {
      long = comb_path[files[i]] = combine_path(dir, files[i]);
    }
    array st;
    if (!(st = stat_cache[long])) {
      st = stat_cache[long] = roxen->stat_file(long, this_object());
    }
    if (st) {
      times[i] = st[-4];
    } else {
      files[i] = 0;
    }
  }
  if (flags & LS_FLAG_t) {
    sort(times, files);
    if (!(flags & LS_FLAG_r)) {
      reverse(files);
    }
  } else {
    files = sort(files);
    if (flags & LS_FLAG_r) {
      files = reverse(files);
    }
  }
  files -= ({ 0 });
  if (!sizeof(files)) {
    return(0);
  }
  string res = "";
  foreach(files, string short) {
    string long = comb_path[short];
    array st = stat_cache[long];
    if (flags & LS_FLAG_F) {
      if (st[1] < 0) {
	// directory
	short += "/";
      } else if (st[0] & 0111) {
	// executable
	short += "*";
      }
    }
    if (flags & LS_FLAG_l) {
      res += file_ls(st, short);
    } else {
      res += short + "\n";
    }
  }
  if (!(flags & LS_FLAG_l) && (flags & LS_FLAG_C)) {
    res = sprintf("%-#79s\n", res);
  }
  return(res);
}

varargs int|string list_file(string arg, int flags)
{
  string filename;
  array (int) st;
  
  method="LIST";

  /*
   * Glob-expand the filename.
   *
   * If there are no matches:
   *   print("No such file or directory").
   * else if there is only one match:
   *   If it's a dir
   *     If d is specified
   *       file_ls(path, last_part).
   *     else
   *       file_ls(contents(file)).
   *   else
   *     file_ls(path, last_part).
   * else
   *   If it's a dir
   *     If d is specified
   *       file_ls(cwd, file).
   *     else
   *       print(file+":\n").
   *       print("total "+num_blocks).
   *       file_ls(contents(file)).
   *   else
   *     file_ls(cwd, file).
   */

  // Glob-expand the filename

  mapping(string:string) comb_path=([]);

  if (replace(arg, ({"*", "?"}), ({ "", "" })) != arg) {
    // Globs in the file-name.
    array(array(string)) matches = ({ ({ }) });
    multiset(string) paths; // Used to filter out duplicates.
    int i;
    foreach(my_combine_path("", arg)/"/", string part) {
      paths = (<>);
      if (replace(part, ({"*", "?"}), ({ "", "" })) != part) {
	// Got a glob.
	array(array(string)) new_matches = ({});
	foreach(matches, array(string) path) {
	  array(string) dir;
	  dir = roxen->find_dir(combine_path(cwd, path*"/")+"/",
				this_object());
	  if (dir && sizeof(dir)) {
	    dir = glob(part, dir);
	    if ((< '*', '?' >)[part[0]]) {
	      // Glob-expanding does not expand to files starting with '.'
	      dir = filter(dir, lambda(string f) {
		return (sizeof(f) && (f[0] != '.'));
	      });
	    }
	    foreach(sort(dir), string f) {
	      array(string) arr = my_combine_path_array(path, f);
	      string p = arr*"/";
	      if (!paths[p]) {
		paths[p] = 1;
		new_matches += ({ arr });
	      }
	    }
	  }
	}
	matches = new_matches;
      } else {
	// No glob
	// Just add the part. Modify matches in-place.
	for(i=0; i<sizeof(matches); i++) {
	  matches[i] = my_combine_path_array(matches[i], part);
	  string path = matches[i]*"/";
	  if (paths[path]) {
	    matches[i] = 0;
	  } else {
	    paths[path] = 1;
	  }
	}
	matches -= ({ 0 });
      }
      if (!sizeof(matches)) {
	break;
      }
    }
    // Array => string
    for (i=0; i < sizeof(matches); i++) {
      string f = matches[i] * "/";
      comb_path[f] = combine_path(cwd, f);	// NOTE: Ordinary comb_path.
    }
  } else {
    // No globs
    string f = my_combine_path("", arg);
    comb_path[f] = combine_path(cwd, f);	// NOTE: Ordinary comb_path.
  }

  mapping(string:array) stat_cache=([]);
  mapping(string:int) dirs=([]);
  mapping(string:int) files=([]);

  // Filter out non-existing or forbiden files/directories

  foreach(indices(comb_path), string short) {
    this_object()->not_query = comb_path[short];
    st = roxen->stat_file(comb_path[short], this_object());
    if (st) {
      stat_cache[comb_path[short]] = st;
      if (st[1] > -2) {
	files[short] = 1;
      } else {
	dirs[short] = 1;
      }
    } else {
      m_delete(comb_path, short);
    }
  }

  if (!sizeof(comb_path)) {
    roxen->log(([ "error": 404, "len": -1 ]), this_object());
    return 0;
  }

  // Glob-expand done!

  if (flags & LS_FLAG_d) {
    files += dirs;
    dirs = ([]);
  }

  string|array(string) res = ({});
  if (sizeof(files)) {
    string s = list_files(indices(files), cwd, comb_path, stat_cache, flags);
    if (s) {
      res += ({ s });
    } else {
      files = ([]);	// To get correct output.
    }
  }
  foreach(sort(indices(dirs)), string short) {
    array(string) dir = roxen->find_dir(comb_path[short]+"/", this_object());
    if ((flags & LS_FLAG_a) &&
	(comb_path[short] != "") &&
	(comb_path[short] != "/")) {
      if (dir) {
	dir = ({ ".." }) + dir;
      } else {
	dir = ({ ".." });
      }
    }
    string s = "";
    if (dir && sizeof(dir)) {
      if (!(flags & LS_FLAG_A)) {
	dir = filter(dir, lambda(string f){return(f[0] != '.');});
      } else if (!(flags & LS_FLAG_a)) {
	dir = filter(dir, lambda(string f){return((f-".") != "");});
      }
      if (sizeof(dir)) {
	s = list_files(dir, comb_path[short]+"/",
		       comb_path, stat_cache, flags) || "";
      }
    }
    if (sizeof(files) || (sizeof(dirs) > 1)) {
      s = short + ":\n" + s;
    }
    res += ({ s });
  }

  res *= "\n";
  res = replace(res, "\n", "\r\n");
  roxen->log(([ "error": 200, "len": strlen(res) ]), this_object());
  return(res);
}

int open_file(string arg, int|void noport)
{
  array (int) st;
  if(!noport)
    if(!dataport_addr || !dataport_port)
    {
      reply("425 Can't build data connect: Connection refused.\n"); 
      return 0;
    }
  
  if(arg[0] == '~')
    this_object()->not_query = combine_path("/", arg);
  else if(arg[0] == '/')
    this_object()->not_query = simplify_path(arg);
  else 
    this_object()->not_query = combine_path(cwd, arg);


  if(1 || !file || (file->full_path != not_query))
  {
    if(file && file->file)
      destruct(file->file);
    file=0;
    foreach(conf->first_modules(), function funp)
      if(file = funp( this_object())) break;
    if (!file) {
      st = roxen->stat_file(not_query, this_object());
      if(st && st[1] < 0)
	file = -1;
      else if(catch(file = roxen->get_file(this_object())))
	file = 1;
    }
  }

  if(file == -1) {
    reply("550 "+arg+": not a plain file.\n");
    file = 0;
    return 0;
  } else if(file == 1) {
    file = 0;
    reply("550 "+arg+": Error, can't open file.\n");
    return 0;
  } else if(!file || (file->error && (file->error/100 != 2))) {
    switch(misc->error_code) {
    case 401:
    case 403:
      reply("550 "+arg+": Access denied.\n");
      break;
    case 405:
      reply("550 "+arg+": Method not allowed.\n");
      break;
    default:
      reply("550 "+arg+": No such file or directory.\n");
      break;
    }
    return 0;
  } else 
    file->full_path = not_query;
  
  if(!file->len)
  {
    if(file->data)   file->len = strlen(file->data);
    if(objectp(file->file))   file->len += file->file->stat()[1];
  }
  if(file->len > 0)
    conf->sent += file->len;
  if(file->error == 403)
  {
    reply("550 "+arg+": Permission denied by rule.\n");
    roxen->log(file, this_object());
    return 0;
  } 
  if(file->error == 302 || file->error == 301)
  {
    reply("550 "+arg+": Redirect to "+file->Location+".\n");
    roxen->log(file, this_object());
    return 0;
  } 
  return 1;
}

mapping(string:string) cmd_help = ([
  "user":"<sp> username",
  "pass":"<sp> password",
  "quit":"(terminate service)",
  "noop":"",
  "syst":"(get type of operating system)",
  "pwd":"(return current directory)",
  "cdup":"(change to parent directory)",
  "cwd":"[ <sp> directory-name ]",
  "type":"<sp> [ A | E | I | L ]",
  "port":"<sp> b0, b1, b2, b3, b4",
  "nlst":"[ <sp> path-name ]",
  "list":"[ <sp> path-name ]",
  "retr":"<sp> file-name",
  "stat":"<sp> path-name",
  "size":"<sp> path-name",
  "stor":"<sp> file-name",
  "dele":"<sp> file-name",
  "pasv":"(set server in passive mode)",
  "help":"[ <sp> <string> ]"
]);

mapping(string:string) site_help = ([
  "prestate":"<sp> prestate"
]);

void timeout()
{
  reply("421 Timeout (3600 seconds): closing connection.\n");
  end();
}

void got_data(mixed fooid, string s)
{
  string cmdlin;
  time = _time(1);
  if (!objectp(cmd_fd)) return;
  array y;
  conf->received += strlen(s);
  remove_call_out(timeout);
  call_out(timeout, 3600);
  remoteaddr = cmd_fd->query_address();
  supports = (< "ftp", "images", "tables", >);
  prot = "FTP";
  method = "GET";
  while (sscanf(s,"%s\r\n%s",cmdlin,s)==2)
  {
    string cmd,arg;
    if (sscanf(cmdlin,"%s %s",cmd,arg)<2) 
      arg="",cmd=cmdlin;
    cmd=lower_case(cmd);
#ifdef DEBUG
    if(cmd == "pass")
      perror("recieved 'PASS xxxxxxxx' "+GRUK+"\n");
    else
      perror("recieved '"+cmdlin+"' "+GRUK+"\n");
#endif
    if (!conf->extra_statistics->ftp) {
      conf->extra_statistics->ftp = (["commands":([ cmd:1 ])]);
    } else if (!conf->extra_statistics->ftp->commands) {
      conf->extra_statistics->ftp->commands = ([ cmd:1 ]);
    } else {
      conf->extra_statistics->ftp->commands[cmd]++;
    }
    if (!((session_auth && session_auth[0]) ||
	  Query("anonymous_ftp") ||
	  (< "user", "pass", "rein" >)[cmd])) {
      reply("530 Please login with USER and PASS.\n");
      continue;
    }
    switch (cmd) {
    case "rein":
      reply("220 Server ready for new user.\n");
      session_auth = 0;
      rawauth = 0;
      auth = 0;
      cwd = "/";
      break;
    case "user":
      if(!arg || arg == "ftp" || arg == "anonymous") {
	if (Query("anonymous_ftp")) {
	  reply("230 Anonymous ftp, at your service\n");
	} else {
	  reply("532 Anonymous ftp disabled\n");
	}
	session_auth = 0;
	rawauth = 0;
	auth = 0;
      } else {
	session_auth = 0;
	rawauth = username = arg;
	auth = 0;
	if (Query("anonymous_ftp")) {
	  reply("331 Give me a password, then!\n");
	} else {
	  reply(sprintf("331 Password required for %s.\n", arg));
	}
      }
      cwd = "/";
      break;
      
    case "pass": 
      if(!rawauth) {
	if (Query("anonymous_ftp")) {
	  reply("230 Guest login ok, access restrictions apply.\n"); 
	} else {
	  reply("503 Login with USER first.\n");
	}
      } else {	
	method="LOGIN";
	y = ({ "Basic", username+":"+arg});
	realauth = y[1];
	if(conf && conf->auth_module) {
	  y = conf->auth_module->auth( y, this_object() );

	  if (y[0] == 1) {
	    /* Authentification successfull */
	    if (!Query("named_ftp") || !check_shell(misc->shell)) {
	      reply("532 You are not allowed to use named-ftp. Try using anonymous\n");
	      /* roxen->(({ "error":403, "len":-1 ]), this_object()); */
	      break;
	    }
	  } else if (!Query("anonymous_ftp")) {
	    reply(sprintf("530 User %s access denied.\n", username));
	    break;
	  }
	} else if (!Query("anonymous_ftp")) {
	  reply("532 Need account to login.\n");
	  break;
	}
	session_auth = auth = y;
	if(auth[0] == 1) {
	  if (stringp(misc->home)) {
	    // Check if it is possible to cd to the users home-directory.
	    if ((misc->home == "") || (misc->home[-1] != '/')) {
	      misc->home += "/";
	    }
	    array(int) st = roxen->stat_file(misc->home, this_object());
	    if (st && (st[1] < 0)) {
	      cwd = misc->home;
	    }
	  }
	  reply("230 User "+username+" logged in.\n"); 
	} else
	  reply("230 Guest user "+username+" logged in.\n"); 
	/* roxen->log(([ "error": 202, "len":-1 ]), this_object()); */
      }
      break;

    case "quit": 
      reply("221 Bye! It was nice talking to you!\n"); 
      end(); 
      return;

    case "noop":
      reply("220 Nothing done ok\n");
      break;
    case "syst":
      reply("215 UNIX Type: L8: Roxen Challenger Information Server\n");
      break;
    case "pwd":
      reply("257 \""+cwd+"\" is current directory.\n");
      break;
    case "cdup":
      arg = "..";
    case "cwd":  
      string ncwd, f;
      array (int) st;
      array (string) dir;

      if(!arg || !strlen(arg))
      {
	reply ("500 Syntax: CWD <new directory>\n");
	break;
      }
      if(arg[0] == '~')
	ncwd = combine_path("/", arg);
      else if(arg[0] == '/')
	ncwd = simplify_path(arg);
      else 
	ncwd = combine_path(cwd, arg);
      
      if ((ncwd == "") || (ncwd[-1] != '/')) {
	ncwd += "/";
      }

      // Restore auth-info
      auth = session_auth;

      st = roxen->stat_file(ncwd, this_object());

      if(!st) {
	reply("550 "+arg+": No such file or directory, or access denied.\n");
	break;
      }
      if(st[1] > -1) {
	reply("550 "+arg+": Not a directory.\n");
	break;
      }
      cwd = ncwd;
      not_query = cwd;
      if(dir = roxen->find_dir(cwd, this_object()))
      {
	string message = "";
	array (string) readme = ({});
	foreach(dir, f)
	{
	  if(f == ".message")
	    message = roxen->try_get_file(cwd + f, this_object()) ||"";
	  if(f[0..5] == "README")
	  {
	    if(st = roxen->stat_file(cwd + f, this_object()))
	      readme += ({ sprintf("Please read the file %s\n  it was last "
				   "modified on %s - %d days ago\n", 
				   f, ctime(st[-4]) - "\n", 
				   (time - st[-4]) / 86400) });
	  }
	}
	if(sizeof(readme))
	  message += "\n" + readme * "\n";
	if(strlen(message))
	  reply(reply_enumerate(message+"\nCWD command successful.\n","250"));
	else 
	  reply("250 CWD command successful.\n");
	break;	  
      }
      reply("250 CWD command successful.\n");
      break;
      
    case "type": 
       /*  if (arg!="I") reply("504 Only binary mode supported (sorry)\n"); 
	   else */
      reply("200 Using binary mode for transferring files\n");
      break;

    case "port": 
      int a,b,c,d,e,f;
      if (sscanf(arg,"%d,%d,%d,%d,%d,%d",a,b,c,d,e,f)<6) 
	reply("501 I don't understand your parameters\n");
      else {
	dataport_addr=sprintf("%d.%d.%d.%d",a,b,c,d);
	dataport_port=e*256+f;
	if (pasv_port) {
	  destruct(pasv_port);
	}
	reply("200 PORT command ok ("+dataport_addr+
	      " port "+dataport_port+")\n");
      }
      break;
      
    case "nlst":
    case "list": 
      int flags = 0;
      mapping f;
      string args;

      if (cmd == "list") {
	flags = LS_FLAG_l;
      }

      // Count this as a request.
      conf->requests++;

      // Restore auth-info
      auth = session_auth;

      if(!dataport_addr || !dataport_port)
      {
	reply("425 Can't build data connect: Connection refused.\n"); 
	break;
      }

      if(sscanf(arg, "-%s %s", args, arg)!=2)
      {
	if(!strlen(arg))
	  arg = cwd;
	else if(arg[0] == '-')
	{
	  args = arg;
	  arg = cwd;
	}
      }

      string file_arg;
      if(arg[0] == '~')
	file_arg = combine_path("/", arg);
      else if(arg[0] == '/')
	file_arg = simplify_path(arg);
      else 
	file_arg = combine_path(cwd, arg);

      if(args) {
	foreach((args/""), string flg) {
	  flags |= decode_flags[flg];
	}
      }

      // This is needed to get .htaccess to be read from the correct directory
      if (file_arg[-1] != '/') {
	array st = roxen->stat_file(file_arg, this_object());
	if (st && (st[1]<0)) {
	  file_arg+="/";
	}
      }

      not_query = file_arg;

      foreach(conf->first_modules(), function funp)
	if(f = funp( this_object())) break;
      if(!f)
      {
	f = ([ "data":list_file(arg, flags) ]);
	if(f->data == 0)
	  reply("550 "+arg+": No such file or directory.\n");
	else if(f->data == -1)
	  reply("550 "+arg+": Permission denied.\n");
	else
	  connect_and_send(f);
      } else {
	reply(reply_enumerate("Permission denied\n"+(f->data||""), "550"));
      }
      break;
	      
    case "retr": 
      // Count this as a request
      conf->requests++;

      string f;

      if(!arg || !strlen(arg))
      {
	reply("501 'RETR': Missing argument\n");
	break;
      }

      // Restore auth-info
      auth = session_auth;

      if(!open_file(arg))
	break;
      connect_and_send(file);
      roxen->log(file, this_object());
      break;

    case "stat":
      // Count this as a request
      conf->requests++;

      string|int dirlist;
      if(!arg || !strlen(arg))
      {
	reply("501 'STAT': Missing argument\n");
	break;
      }
      method="HEAD";
      reply("211-status of "+arg+":\n");

      // Restore auth-info
      auth = session_auth;

      not_query = arg = combine_path(cwd, arg);
      foreach(conf->first_modules(), function funp)
	if(f = funp( this_object())) break;
      if(f) dirlist = -1;
      else dirlist = list_file(arg, 0, 0, 0, 0);
      
      if(!dirlist)
      {
	reply("Unknown file: "+arg+" doesn't exist.\n");
      } else if(dirlist == -1)
	reply("Access denied\n");
      else 
	reply(dirlist);
      reply("211 End of Status\n");
      break;
      
    case "size":
      // Count this a request
      conf->requests++;

      if(!arg || !strlen(arg))
      {
	reply("501 'SIZE': Missing argument\n");
	break;
      }

      // Restore auth-info
      auth = session_auth;

      if(!open_file(arg))
	break;
      reply("213 "+ file->len +"\n");
      break;
    case "stor": // Store file..
      // Count this as a request
      conf->requests++;

      string f;
      if(!arg || !strlen(arg))
      {
	reply("501 'STOR': Missing argument\n");
	break;
      }

      // Restore auth-info
      auth = session_auth;

      connect_and_receive(arg);
      break;

    case "dele":
      // Count this as a request
      conf->requests++;

      if(!arg || !strlen(arg))
      {
	reply("501 'DELE': Missing argument\n");
	break;
      }

      // Restore auth-info
      auth = session_auth;

      method = "DELETE";
      data = 0;
      misc->len = 0;
      if(open_file(arg, 1))
	reply("254 Delete completed\n");

      break;

    case "pasv":
      if(pasv_port)
	destruct(pasv_port);
      pasv_port = files.port(0, pasv_accept_callback);
      int port=(int)((pasv_port->query_address()/" ")[1]);
      reply("227 Entering Passive Mode. "+replace(controlport_addr, ".", ",")+
	    ","+(port>>8)+","+(port&0xff)+"\n");
      break;

    case "help":
      if(!arg || !strlen(arg)) {
	reply(reply_enumerate(sprintf("The following commands are recognized:"
				      "\n%-#72;8s\n",
				      map(sort(indices(cmd_help)),
					  upper_case)*"\n"), "214"));
	break;
      }
      if(cmd_help[lower_case(arg)]) {
	reply(reply_enumerate("Syntax: "+upper_case(arg)+" "+
			      cmd_help[lower_case(arg)]+"\n", "214"));
	break;
      }
      if(2==sscanf(lower_case(arg), "site%*[ ]%s", arg)) {
	if(!strlen(arg)) {
	  reply(reply_enumerate(sprintf("The following SITE commands are "
					"recognized:\n%-#72;8s\n",
					map(sort(indices(site_help)),
					    upper_case)*"\n"), "214"));
	  break;
	}
	if(site_help[lower_case(arg)]) {
	  reply(reply_enumerate("Syntax: "+upper_case(arg)+" "+
				site_help[lower_case(arg)]+"\n", "214"));
	  break;
	}
      }
      reply("502 Unknown command "+upper_case(arg)+".\n");
      break;

      // Extended commands
    case "site":
      array(string) arr;

      if (!arg || !strlen(arg) || !sizeof(arr = (arg/" ")-({""}))) {
	reply(reply_enumerate("The following site dependant commands are available:\n"
			      "SITE PRESTATE <prestate>\tSet the prestate.\n",
			      "220"));
	break;
      }
      if (lower_case(arr[0]) != "prestate") {
	reply("504 Bad SITE command\n");
	break;
      }
      if (sizeof(arr) == 1) {
	reply("220 Prestate cleared\n");
	prestate = (<>);
	break;
      }
      
      prestate = aggregate_multiset(@((arr[1..]*" ")/","-({""})));
      reply("220 Prestate set\n");
      break;

    case "":
      /* The empty command, some stupid ftp-proxies send this. */
      break;
    default:
      reply("502 command '"+ cmd +"' unimplemented.\n");
    }
  }
}

void create(object f, object c)
{
  if(f)
  {
    string fi;
    conf = c;
    cmd_fd = f;
    cmd_fd->set_id(0);

    cmd_fd->set_read_callback(got_data);
    cmd_fd->set_write_callback(lambda(){});
    cmd_fd->set_close_callback(end);

    sscanf(cmd_fd->query_address(17)||"", "%s %d",
	   controlport_addr, controlport_port);

    sscanf(cmd_fd->query_address()||"", "%s %d", dataport_addr, dataport_port);

    pasv_port = 0;
    pasv_callback = 0;
    pasv_accepted = ({ });

    not_query = "/welcome.msg";
    call_out(timeout, 3600);
    
#if 0
    if((fi = roxen->try_get_file("/welcome.msg", this_object()))||
       (fi = roxen->try_get_file("/.message", this_object())))
      reply(reply_enumerate(fi, "220"));
    else
#endif /* 0 */
      reply(reply_enumerate(Query("FTPWelcome"),"220"));
  }
}

