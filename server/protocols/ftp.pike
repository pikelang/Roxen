/* Roxen FTP protocol. Written by Pontus Hagland
string cvs_version = "$Id: ftp.pike,v 1.7 1997/04/05 17:56:12 marcus Exp $";
   (law@lysator.liu.se) and David Hedbor (neotron@infovav.se).

   Some of the features: 

      * All files are parsed the same way as if they were fetched via WWW.

      * If someone login with a non anonymous name, normal
      authentification is done. This means that you for example can
      use .htaccess files to limit access to different directories.

      * You can have 'user ftp directories'. Just add a user database
      and a user filesystem. Notice that _normal_ non-anonymous ftp
      should not be used, due to security reasons. */


inherit "http"; /* For the variables and such.. (Per) */ 

#include <config.h>
#include <module.h>
#include <stat.h>

import Array;

#define perror	roxen_perror

string dataport_addr, cwd ="/";
int dataport_port;
int GRUK = random(_time(1));
#undef QUERY
#define QUERY(X) roxen->variables->X[VAR_VALUE]
#define Query(X) conf->variables[X][VAR_VALUE]  /* Per */

/********************************/
/* private functions            */

#define reply(X) do { conf->hsent += strlen(X); my_fd->write(replace(X, "\n","\r\n")); } while(0)

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
	perror(sprintf("ftp.pike(): allowed_shells:%O\n", allowed_shells));
#endif /* DEBUG */
      } else {
	perror(sprintf("ftp.pike: Failed to open shell database (\"%s\")\n",
		       Query("shells")));
	return(0);
      }
    }
    return(allowed_shells[shell]);
  }
  return(0);
}

/********************************/
/* public methods               */

void end(string|void);

void disconnect()
{
  if(objectp(pipe) && pipe != Simulate.previous_object()) 
    destruct(pipe);
  my_fd = 0;
  destruct(this_object());
}

void end(string|void s)
{
  if(objectp(my_fd))
  {
    if(s)
      my_fd->write(s);
    destruct(my_fd);
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
  my_fd->write(reply_enumerate("Internal server error: "+
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
  if(st[1] < 0)
    st[1] =  512;
  string ct = ctime(st[-4]);
  return sprintf("%s   1 %-10s %-6d%12d %s %s %s\r\n", perm,
		 name_from_uid(st[-2]), st[-1],
		 st[1], ct[4..9], ct[11..15], file);
}

void done_callback(object fd)
{
  if(fd)
  {
    fd->close();
    destruct(fd);
  }
  reply("226 Transfer complete.\n");
  my_fd->set_read_callback(got_data);
  my_fd->set_write_callback(lambda(){});
  my_fd->set_close_callback(end);
  mark_fd(my_fd->query_fd(), GRUK+" cmd channel not sending data");
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
  if(file->file)  pipe->input(file->file);

  pipe->set_done_callback(done_callback, fd);
  pipe->output(fd);
}

inherit "socket";
void connect_and_send(mapping file)
{
#if 0
  //  my_fd->set_blocking();
  async_connect(dataport_addr,dataport_port, connected_to_send, file);
#else
  // More or less copied from socket.pike
  
  object(files.file) f = files.file();

  object privs = (object)"privs";

  // FIXME: Should really use ftp_port - 1
  if(!f->open_socket(20))
  {
#ifdef FTP_DEBUG
    perror("ftp: socket(20) failed. Trying with any port.\n");
#endif
    if (!f->open_socket()) {
#ifdef FTP_DEBUG
      perror("ftp: socket() failed. Out of sockets?\n");
#endif
      connected_to_send(0, file);
      destruct(f);
      return;
    }
  }
  privs = 0;

  f->set_nonblocking(0, lambda(array args) {
#ifdef SOCKET_DEBUG
    perror("SOCKETS: async_connect ok.\n");
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
  f->set_id( ({ connected_to_send, ({ file }), f }) );

  mark_fd(f->query_fd(),
	  "ftp communication: -> "+dataport_addr+":"+dataport_port);

  if(catch(f->connect(dataport_addr, dataport_port))) // Illegal format...
  {
#ifdef FTP_DEBUG
    perror("ftp: Illegal internet address in connect in async comm.\n");
#endif
    connected_to_send(0, file);
    destruct(f);
    return;
  }
#endif /* 0 */
}

varargs int|string list_file(string arg, int srt, int short, int column, 
			     int F, int directory, int all_mode)
{
  string filename;
  array (int) st;
  
  method="LIST";

  if(!strlen(arg))
    arg = "/";
  if(arg[0] == '/')
    filename = arg; 
  else
    filename = combine_path(cwd, arg);

  this_object()->not_query = filename;
  st = roxen->stat_file(filename, this_object());
  if(!st) {
    roxen->log(([ "error": 404, "len": -1 ]), this_object());
    return 0;
  }
  int sent;
  string tmp;
  if(directory || st[1] > -2) { 
    if(st[1] == -2 && arg[-1] != '/')
      arg += "/";
    if(short)
      tmp = arg+"\r\n";
    else
      tmp = file_ls(st, arg);
    roxen->log(([ "error": 200, "len": strlen(tmp) ]), this_object());
    return tmp;
  } else {
    if(filename[-1] != '/')
      filename += "/";
    array (string) dir, parsed = ({});
    string s;
    mapping tsort = ([]);

    not_query = arg = filename;
    dir = roxen->find_dir(filename, this_object()) || ({});

    if(!srt)
      sort(dir);
    if(filename[-1] != '/')
      filename += "/";
    if(strlen(filename) != 1) {
      dir = ({".."}) + dir;
    }
    foreach(dir, s) {
      st = 0;
      if (((!all_mode) && (s[0]=='.')) ||
	  ((all_mode == 1) && (s - "." == ""))) {
	continue;
      }
      if(F && (st = roxen->stat_file(filename+s, this_object())) 
	 && st[1] < 0)
	s += "/";
      if(!short) {
	if(st || (st = roxen->stat_file(filename+s, this_object())))
	  if(srt)
	    tsort += ([ (time - st[-4]) : file_ls(st, s) ]);
	  else
	    parsed += ({ file_ls(st, s) });
      } else 
	parsed += ({ s });
    }
    if(srt) {
      parsed = values(tsort);
      sort(indices(tsort), parsed);
      tmp=parsed*"";
    } else if(!short) {
      tmp=parsed*"";
    } else {
      if(column) {
	tmp=replace(sprintf("%-#79s\n", parsed*" \n"), "\n", "\r\n");
      }
      else
	tmp=parsed*"\r\n"+"\r\n";
    }
    roxen->log(([ "error": 200, "len": strlen(tmp) ]), this_object());
    return tmp;
  }
}

int open_file(string arg)
{
  array (int) st;
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
    foreach(conf->first_modules(), function funp)
      if(file = funp( this_object())) break;
    if (!file) {
      if(st = roxen->stat_file(not_query, this_object()))
	if(st[1] < 0)
	  file = -1;
	else if(catch(file = roxen->get_file(this_object())))
	  file = 1;
    }
  }
  if(!file)
  {
    reply("550 "+arg+": No such file or directory.\n");
    return 0;
  } else if(file == -1) {
    reply("550 "+arg+": not a plain file.\n");
    file = 0;
    return 0;
  } else if(file == 1) {
    file = 0;
    reply("550 "+arg+": Error, can't open file.\n");
    return 0;
  } else
    file->full_path = not_query;
  
  if(!file->len)
  {
    if(file->data)   file->len = strlen(file->data);
    if(file->file)   file->len += file->file->stat()[1];
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

void got_data(mixed fooid, string s)
{
  string cmdlin;
  time = _time(1);
  if (!objectp(my_fd)) return;
  array y;
  conf->received += strlen(s);
  remove_call_out(end);
  call_out(end, 3600);
  remoteaddr = my_fd->query_address();
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
    switch (cmd)
    {
     case "user":
      if(!arg || arg == "ftp" || arg == "anonymous")
      {
	reply("230 Anonymous ftp, at your service\n");
	rawauth = 0;
	auth = 0;
      } else {
	rawauth = arg;
	auth = 0;
	reply("331 Give me a password, then!\n");
      }
      cwd = "/";
      break;
      
     case "pass": 
      if(!rawauth)
	reply("230 Guest login ok, access restrictions apply.\n"); 
      else {	
	method="LOGIN";
	y = ({ "Basic", rawauth+":"+arg});
	realauth = y[1];
	if(conf && conf->auth_module) {
	  y = conf->auth_module->auth( y, this_object() );

	  if (y[0] == 1) {
	    /* Authentification successfull */
	    if (Query("named_ftp") && !check_shell(misc->shell)) {
	      reply("432 You are not allowed to use named-ftp. Try using anonymous\n");
	      /* roxen->(({ "error":403, "len":-1 ]), this_object()); */
	      break;
	    }
	  }
	}
	auth=y;
	if(auth[0]) {
	  cwd = misc->home;
	  reply("230 User "+rawauth+" logged in.\n"); 
	} else
	  reply("230 Luser "+rawauth+" logged in.\n"); 
	/* roxen->log(([ "error": 202, "len":-1 ]), this_object()); */
      }
      break;

     case "quit": 
      reply("221 Bye! It was nice talking to you!\n"); 
      end(); 
      return;

     case "noop": reply("220 Nothing done ok\n"); break;
     case "syst": reply("215 UNIX Type: L8: Roxen Challenger Information Server\n"); break;
     case "pwd":  reply("257 \""+cwd+"\" is current directory.\n"); break;
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
      
      st = roxen->stat_file(ncwd, this_object());

      if(!st) {
	reply("550 "+arg+": No such file or directory.\n");
	break;
      }
      if(st[1] > -1) {
	reply("550 "+arg+": Not a directory.\n");
	break;
      }
      cwd = ncwd;
      if((cwd == "") || (cwd[-1] != '/'))
	cwd += "/";
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
	reply("501 i don't understand your parameters\n");
      else {
	dataport_addr=sprintf("%d.%d.%d.%d",a,b,c,d);
	dataport_port=e*256+f;
	reply("200 PORT command ok ("+dataport_addr+
	      " port "+dataport_port+")\n");
      }
      break;
      
     case "nlst": 
      int short=0, tsort=0, F=0, C=0, d=0, a=0;
      short = 1;

     case "list": 
      mapping f;
      string args;

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

      if(arg[0] == '~')
	arg = combine_path("/", arg);
      else if(arg[0] == '/')
	arg = simplify_path(arg);
      else 
	arg = combine_path(cwd, arg);

      if(args)
      {      
	if(search(args, "l") != -1)
	  short = 0;
	
	if(search(args, "t") != -1)
	  tsort = 1;
	
	if(search(args, "F") != -1)
	  F = 1;

	if(search(args, "C") != -1)
	  C = 1;

	if(search(args, "d") != -1)
	  d = 1;

	if(search(args, "A") != -1)
	  a = 1;

	if(search(args, "a") != -1)
	  a = 2;
      }
      not_query = arg;

      foreach(conf->first_modules(), function funp)
	if(f = funp( this_object())) break;
      if(!f)
      {
	f = ([ "data":list_file(arg, tsort, short, C, F, d, a) ]);
	if(f->data == 0)
	  reply("550 "+arg+": No such file or directory.\n");
	else if(f->data == -1)
	  reply("550 "+arg+": Permission denied.\n");
	connect_and_send(f);
      } else {
	reply(reply_enumerate("Permission denied\n"+(f->data||""), "550"));
      }
      break;
	      
     case "retr": 
      string f;
      if(!arg || !strlen(arg))
      {
	reply("501 'RETR': Missing argument\n");
	break;
      }
      if(!open_file(arg))
	break;
      connect_and_send(file);
      roxen->log(file, this_object());
      break;

     case "stat":
      string|int dirlist;
      if(!arg || !strlen(arg))
      {
	reply("501 'STAT': Missing argument\n");
	break;
      }
      method="HEAD";
      reply("211-status of "+arg+":\n");
      not_query = arg = combine_path(cwd, arg);
      foreach(conf->first_modules(), function funp)
	if(f = funp( this_object())) break;
      if(f) dirlist = -1;
      else dirlist = list_file(arg, 0, 0, 0);
      
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
      if(!arg || !strlen(arg))
      {
	reply("501 'SIZE': Missing argument\n");
	break;
      }
      if(!open_file(arg))
	break;
      reply("213 "+ file->len +"\n");
      break;
    case "stor": // Store file..
      // Does NOT work!
      //
      // Needs to check conf->first_modules().
      string f;
      if(!arg || !strlen(arg))
      {
	reply("501 'STOR': Missing argument\n");
	break;
      }
      method = "PUT";
      object fd;

      fd = files.file();
      if(catch {
	if(!fd->connect(dataport_addr, dataport_port))
	  throw("noconnect");
      })
	reply("425 Can't build data connection: Connection refused.\n"); 
      else {
	object ofd;
	mapping file;
	
	ofd = my_fd;
	my_fd = fd;
	
	file = roxen->get_file( this_object() );
	if(file && file->leave_me==1)
	  reply("200 Stored.\n");
	else
	  reply("425 Permission denied.\n");

	my_fd = ofd;
      }
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
    my_fd = f;
    my_fd->set_id(0);

    my_fd->set_read_callback(got_data);
    my_fd->set_write_callback(lambda(){});
    my_fd->set_close_callback(end);

    not_query = "/welcome.msg";
    call_out(end, 3600);
    
    if((fi = roxen->try_get_file("/welcome.msg", this_object())) ||
       (fi = roxen->try_get_file("/.message", this_object())))
      reply(reply_enumerate(fi, "220"));
    else
      reply(reply_enumerate(Query("FTPWelcome"),"220"));
  }
}

