// This is a roxen module. Copyright © 1996 - 2009, Roxen IS.
// This module implements an ftp proxy

string cvs_version = "$Id$";
#include <module.h>
#include <config.h>

import Stdio;

#ifdef PROXY_DEBUG
# define PROXY_WERR(X) werror("FTP PROXY: "+X+"\n")
#else
# define PROXY_WERR(X)
#endif

#ifdef DESTRUCT_CHECK
# define DESTRUCT_WERR(X) if(i_am_destructed){werror("I AM DESTRUCTED: "+X+"\n\n\n");}
#else
# define DESTRUCT_WERR(X)
#endif

// If this is defined, the session log will be included in a HTML
// comment on the returned page.
#define SESSION_INFO


string CONNECTION_REFUSED=#"
HTTP/1.0 500 Connection refused by remote host\r\n
Content-type: text/html\r\n
\r\n
<title>Roxen internal error</title>\n
<h1>Proxy request failed</h1>
<hr>
<font size=\"+2\"><i>Host unknown or connection refused</i></font>
<hr>
<font size=\"-2\"><a href=\"http://www.roxen.com/\">"+roxen->version()+"</a></font>";

string INFOSTRING="<font size=\"-2\"><a href=\"http://www.roxen.com/\">"+roxen->version()+
                  "</a> FTP Gateway "+("$Revision: 1.43 $"-"$")+"</font>";

#define _ERROR_MESSAGE(XXXX) ("HTTP/1.0 500 FTP gateway error\r\nContent-type: text/html\r\n\r\n<title>Ftp gateway error</title>\n<h2>FTP Gateway failed:</h2><hr><font size=+1>"XXXX"</font><hr>"+INFOSTRING)

#ifdef SESSION_INFO
#define ERROR_MESSAGE(XXXX) (_ERROR_MESSAGE(XXXX)+"\n\n<!-- session information:\n\n"+session+"\n\n-->\n")
#else
#define ERROR_MESSAGE(XXXX) _ERROR_MESSAGE(XXXX)
#endif

#define AUTH_REQUIRED "HTTP/1.0 401 Auth Required\r\nWWW-Authenticate: Basic realm=\"ftp server password needed\""


inherit "module";
inherit "socket";

#include <proxyauth.pike>

class Request {
  inherit "socket";

#define CONNECTION_TIMEOUT (master->query("connection_timeout"))
#define ACTIVE_CONNECT_TIMEOUT (master->query("data_connection_timeout"))
#define SERVER_INFO (master->query("server_info")=="Yes")
#define MAX_PARSE_DIR 500000

  object id,master;
  object server,datacon,dataport;

  string host,file,effect,user,passw;
  int port;
  int portno;
  function read_state;
  int bytes_size=-2;
  int getting_list=0,trystat;
  int dontsaveserver=0,usedoldconnection=0;
  int serial;

  string last_read="";
  string buffer;
  string what_now;
  array(string) links=({});
#ifdef SESSION_INFO
  string session="";
#endif
  string server_info="";

  int i_am_destructed=0;

  void connection_timeout(object con);
  void data_connect_timeout();
  void connected(object con);
  void open_connection();

  void save_stuff()
  {
    if (objectp(dataport)) master->save_dataport(({portno,dataport}));
    if (objectp(server))
      if (dontsaveserver)
      {
	server->set_blocking();
	destruct(server);
      }
      else
      {
	master->save_connection((user||"")+"@"+host+":"+port,
				server,server_info);
      }

    dataport=0;
    server=0;
    if (objectp(datacon))
    {
      destruct(datacon);
      datacon=0;
    }
  }

#ifdef PROXY_DEBUG
  void set_what_now(string s)
  {
    PROXY_WERR("#"+serial+" "+host+"/"+file+": "+s);
    what_now=s;
  }
#else
#define set_what_now(s) (what_now=(s))
#endif

  void selfdestruct()
  {
    set_what_now("selfdestructing");
    /*
      if (objectp(dataport)) { werror("had dataport\n"); destruct(dataport); }
      if (objectp(datacon)) { werror("had datacon\n"); destruct(datacon); }
      if (objectp(server)) { werror("had server\n"); destruct(server); }
      if (objectp(id)) { werror("had id\n"); id->end(); }
      */
    i_am_destructed=1;
    call_out(lambda() { set_what_now("bye"); destruct(); },10);
    remove_call_out(connection_timeout);
    remove_call_out(data_connect_timeout);
  }

  void write_server(string s)
  {
#ifdef DEBUG
    werror("write "+s+"\n");
#endif
    server->write(s+"\r\n");
#ifdef SESSION_INFO
    session+="-> "+s+"\n";
#endif
  }

  void buffer_read(mixed foo,string s)
  {
    buffer+=s;
  }

  string directory_line(string filename,string typename,string href,
			int size,string date,int spacelen,
			void|string type,void|string icon, void|string desc)
  {
    if(desc)
    {
      desc = (desc/" " - ({""})) * " ";
      if(strlen(desc) && desc[0] == ' ')
	desc = desc[1..];
    }
    if (!type)
    {
      array tmp;
      tmp=id->conf->type_from_filename(filename,1);
      if (tmp&&tmp[0])
      {
	type=tmp[0];
	if (tmp[1]) type+=" ("+tmp[1]+")";
      }
      else type="unknown";
      if (master->query("icons")=="Yes") icon=Roxen.image_from_type(type);
    }
    else if (!icon && master->query("icons")=="Yes")
    {
      array tmp;
      string type2;
      tmp=id->conf->type_from_filename(typename,1);
      if (tmp&&tmp[0])
      {
	type2=tmp[0];
	if (tmp[1]) type2+=" ("+tmp[1]+")";
	icon=Roxen.image_from_type(type2);
      }
      else icon="internal-gopher-menu";
    }
    if (effect=="inline")
    {
      if (master->query("icons")=="Yes")
	return sprintf("<a href=\"%s\"><img src=%s border=0 alt=\"\"> %-*s"
		       "</a>%12s %s %s\n<a href=\"%s\"><img src=%s></a>\n",
		       href,icon,spacelen,filename,size?(string)size:"",date,
		       desc?sprintf(" %-15s %s", type, desc): type,href,href);
      else
	return sprintf("<a href=\"%s\">%-*s</a>%12s %s %s\n<a href=\"%s\">"
		       "<img src=%s></a>\n",
		       href,spacelen,filename,size?(string)size:"",date,
		       desc?sprintf(" %-15s %s", type, desc): type,href,href);
    }
    if (master->query("icons")=="Yes"&& effect!="noicons")
      return sprintf("<a href=\"%s\"><img src=%s border=0 alt=\"\"> %-*s</a>"
		     "%12s %s %s \n",
		     href,icon,spacelen,filename,size?(string)size:"",
		     date, desc?sprintf(" %-15s %s", type, desc): type);
    else
      return sprintf("<a href=\"%s\">%-*s</a>%12s %s %s\n",
		     href,spacelen,filename,size?(string)size:"",
		     date, desc?sprintf(" %-15s %s", type, desc): type);
  }

  string parse_uwp_directory() /* ftp.uwp.edu... */
  {
    array(string) dir;
    string s,filename,link,rest;
    int size,maxlen;
    string res="";
    array dirl=({}), q;

    rest=((buffer/"\r")*"");
    dir=((rest/"\n ")*" ")/"\n"; /* remove wrapped */

    foreach (dir-({""}),s)
    {
      if (sscanf(s,"%s/%*[ ]%*[=-]  %s",filename, rest)==4 &&
	  sizeof(filename/" ")==1)
	dirl+=({({filename+"/","*dir*",filename+"/",0,"directory",
		    "internal-gopher-menu", rest})});
      else if (sscanf(s,"%s%*[ ]%d  -> %s",filename,size,link)==4)
      {
	dirl+=({({filename+"@",link,link,size,"-> "+link,0,""})});
	links+=({link});
      }
      else if (sscanf(s,"%s%*[ ]%*[=-]  -> %s",filename,link)==4)
      {
	dirl+=({({filename+"@",link,link,0,"-> "+link,0, ""})});
	links+=({link});
      }
      else if (sscanf(s,"%s%*[ ]%d  %s",filename,size,rest)==4)
	dirl+=({({filename,filename,filename,size,0,0,rest})});
      else return 0;
    }
    maxlen=1;
    foreach (dirl,q)
      if (maxlen<strlen(q[0])) maxlen=strlen(q[0]);
    foreach (dirl,q)
      res+=directory_line(q[0], q[1], q[2], q[3],""/*date*/,
			  maxlen, q[4], q[5], q[6]);


    return "<pre>"+res+"</pre>";
  }


  int|string parse_unix_ls_directory()
  {
    array(string) dir;
    string res,f,a;
    int date_position,i,maxlen;

    dir=((buffer/"\r")*"")/"\n";

    if (sizeof(dir)<1) return 0; /* nope */
    if (sscanf(dir[0],"total %*d")) {
      dir=dir[1..sizeof(dir)-1]; /* not first line */
    }
    res="";

    if (sizeof(dir)<1) return 0; /* nope */

    if (sscanf(dir[0],"%*[drwxahsSl-]%*[ ]")<2) return 0; /* nope */

    if((sscanf(dir[0], "l%*s "+file+" -> %s", f) == 2) && (f != "."))
    {
      if(search(f, "../") == 0)
	f = "../" +f;
      file = combine_path(file, f) + (f[-1] == '/' ? "" : "/");
      buffer="";
      return -1;
    }


    /* search for date */
    a=dir[0];
    for (i=strlen(a)-14; i>2; i--)
      if (a[i+0]==' '&&a[i+4]==' '&&a[i+7]==' '&&a[i+13]==' '&&
	  (a[i+6]>='0'&&a[i+6]<='9')&&
	  (a[i-1]>='0'&&a[i-1]<='9')&&
	  (a[i+10]==':'||a[i+12]==' ')) break;
    if (i<3) return 0; /* nope */
    date_position=i;

    maxlen=12+date_position+14;
    foreach (dir-({""}),f)
    {
      if (sscanf(f+date_position,"%s -> %*s",a)) f=a;
      if (maxlen<strlen(f)) maxlen=strlen(f);
    }
    maxlen-=date_position+13;

    foreach (dir-({""}),f)
    {
      string filename,date,type;
      int size, offset;
      for (offset=0; (f[date_position+offset]!=' ')&&
	     (strlen(f) > date_position+offset+14); offset++) ;
      date_position+=offset ; // If size has > 7 digits

      if (!(f[date_position+0]==' '&&f[date_position+4]==' '&&
	    f[date_position+7]==' '&&f[date_position+13]==' '&&
	    (f[date_position-1]>='0'&&f[date_position-1]<='9')))
	return 0; /* not this type of format */

      filename=f[date_position+14..];
      date=f[date_position+1..date_position+12];
      for (i=1; i<20&&(f[date_position-i]>='0'&&f[date_position-i]<='9'); i++);
      size=(int)f[date_position-i..];
      if (f[0]=='d')
      {
	type="directory";
	res+=directory_line(filename+"/","*dir*",filename+"/",size,date,
			    maxlen,"directory","internal-gopher-menu");
      }
      else if (f[0]=='l')
      {
	sscanf(filename,"%s -> %s",filename,type);
	res+=directory_line(filename+"@",type,type/*to*/,size,date,
			    maxlen,"-> "+type);
	links+=({type});
      }
      else
	res+=directory_line(filename,filename,filename,size,date,maxlen);
      date_position-=offset ; // Reset to previous position
    }
    return "<pre>"+res+"</pre>";
  }

  string parse_unix_ls_directory_floating_date()
  {
    array(string) dir;
    string res,f,a;
    int i,maxlen,date_position;

    dir=((buffer/"\r")*"")/"\n";
    // This was commented out in a patch by Wilhelm Koehler.
    // if (sizeof(dir)<1)
    // 	 return 0; /* nope */
    while (sizeof(dir) && (dir[0]==""))
      dir=dir[1..sizeof(dir)-1];
    if (sizeof(dir) && sscanf(dir[0],"total %*d"))
      dir=dir[1..sizeof(dir)-1]; /* not first line */
    if (sizeof(dir)&&dir[0][0..0]=="/") dir=dir[1..sizeof(dir)-1];
    res="";

    if (sizeof(dir)<1) return 0; /* nope */

    if (sscanf(dir[0],"%*[drwxsSl-]%*[ ]")<2) return 0; /* nope */

    if((f = dir[0]) == "")
      for(i=1; i < sizeof(dir); i++)
	if(dir[i] != "")
	{
	  f=dir[i];
	  break;
	}
    for (i = strlen(f) - 14; i > 2; i--)
    {
      if ((f[i+0]&127) == ' ' && (f[i+4]&127)  == ' ' &&
	  (f[i+7]&127) == ' ' && (f[i+13]&127) == ' ' &&
	  (f[i+6]  >= '0' && f[i+6]  <= '9') &&
	  (f[i-1]  >= '0' && f[i-1]  <= '9') &&
	  (f[i+12] >= '0' && f[i+12] <= '9'))
	break;
    }
    if (i<3) return 0; /* nope */
    date_position=i;

    maxlen=12+date_position+14;
    foreach (dir-({""}),f)
    {
      if (sscanf(f+date_position,"%s -> %*s",a)) f=a;
      if (maxlen<strlen(f)) maxlen=strlen(f);
    }
    maxlen-=date_position+13;

    foreach (dir-({""}),f)
    {
      string filename,date,type;
      int size;

      for (i=strlen(f)-12; i>2; i--)
	if (f[i+0]==' '&&f[i+4]==' '&&f[i+7]==' '&&f[i+13]==' '&&
	    (f[i+6]>='0'&&f[i+6]<='9')&&
	    (f[i-1]>='0'&&f[i-1]<='9')&&
	    (f[i+12]>='0'&&f[i+12]<='9')) break;
      if (i<3) return 0; /* nope */

      date_position=i;

      filename=f[date_position+14..];
      date=f[date_position+1..date_position+12];
      for (i = 1; i < 20 && (f[date_position - i] >= '0' &&
			     f[date_position-i] <= '9'); i++);
      size=(int)f[date_position-i..];
      if (f[0]=='d')
      {
	type="directory";
	res+=directory_line(filename+"/","*dir*",filename+"/",size,date,maxlen,"directory","internal-gopher-menu");
      }
      else if (f[0]=='l')
      {
	sscanf(filename,"%s -> %s",filename,type);
	res+=directory_line(filename+"@",type,type/*to*/,size,date,maxlen,"-> "+type,"internal-gopher-menu");
	links+=({type});
      }
      else
	res+=directory_line(filename,filename,filename,size,date,maxlen);
    }
    return "<pre>"+res+"</pre>";
  }

  string parse_directory_without_first_line()
  {
    string res;
    array(string) dir;
    dir=((buffer/"\r")*"")/"\n";
    if (sizeof(dir)<1) return 0; /* nope */

    while (dir[0]=="") dir=dir[1..sizeof(dir)-1];
    dir=dir[1..sizeof(dir)-1] ;

    if (sizeof(dir)<1) return 0; /* nope */

    buffer=dir*"\n" ;
    if (!(res=parse_unix_ls_directory()) &&
	!(res=parse_unix_ls_directory_floating_date()) &&
	!(res=parse_uwp_directory()))
      return 0 ;
    return res ;
  }

  string parse_directory()
  {
    string s, r, t;
    array(string) path;
    string|int res;
    /* check if known format */
    if (effect=="raw"||buffer=="")
    {
      res="\n<pre>"+buffer+"</pre>";
    }
    else if (strlen(buffer)>MAX_PARSE_DIR)
    {
      res="\nDirectory too large for parsing, sorry:\n<pre>"+buffer+"</pre>";
    }
    else if (!(res=parse_unix_ls_directory()) &&
	     !(res=parse_unix_ls_directory_floating_date()) &&
	     !(res=parse_uwp_directory()) &&
	     !(res=parse_directory_without_first_line()))
    {
      /* unknown, return preformatted */
      report_debug("FTP GATEWAY: unknown list format at "+
		   (user?user+"@":"")+host+":"+port+"/"+file+"\n");
      res="(Unrecognized directory type)<br>\n<pre>"+buffer+"</pre>";
    }
    if(res == -1)
      return res;
    r="<html><head><title>"+
      "FTP: Index of "+file+" on "+host+"</title></head>"+
      "<body>\n<h2>Index of <a href=/>/";
    t="/";
    if (effect) t+="("+effect+")/";
    path=file/"/"-({""});
    if (sizeof(path))
    {
      foreach(path[0..sizeof(path)-2],s)
      {
	t+=s+"/";
	r+="</a><wbr><a href="+t+">"+s+"/";
      }
      if (file[strlen(file)-1]!='/')
	r+="</a><wbr><a href="+t+path[-1]+">"+path[-1];
      else
	r+="</a><wbr><a href="+t+path[-1]+"/>"+path[-1]+"/";
    }
    res=r+"</a>:<hr></h2>\n"+res;
    if (SERVER_INFO)
      if (server_info!="")
	res+="\n<hr>\n<font size=-1>Information from ftp server:<pre>"+server_info+"</pre></font>\n";
    res+="<hr>"+INFOSTRING+"</body></html>";
#ifdef SESSION_INFO
    res+="\n\n\n<!-- session information\n\n"+session+"\n\n-->\n";
#endif
    return res;
  }

  void dir_completed()
  {
    object pipe;
    string res;

    dontsaveserver=0;
    set_what_now("transfer in progress (directory)");

    res=parse_directory();
    if(intp(res)) {
      open_connection();
      return;
    }
    if (sizeof(links)==1&&file!="/"&&sizeof(res/"\n")==1) // only one redirect, send it...
    {
      res=links[0];
      while (res[0..2]=="../"||res=="..")
      {
	res=res[3..];
	if (file!="/") file=((file/"/")[0..sizeof(file/"/")-3])*"/"+"/";
      }
      id->end("HTTP/1.0 302 try this instead... following links\r\nLocation: ftp://"+host+(port==21?"":":"+port)+(effect?"/("+effect+")":"")+file+res+"\r\n\r\n");
      save_stuff();
      return;
    }

    pipe=Pipe.pipe();
    pipe->write("HTTP/1.0 200 Yeah, it's a FTP directory\r\n"
		"Content-type: text/html\r\n"
		"Content-length: "+strlen(res)+"\r\n");
    pipe->write("\r\n");
    pipe->write(res);
    pipe->output(id->my_fd);
    id->disconnect();
    id=0;
    save_stuff();
  }


  void buffer_completed()
  {
    if (objectp(datacon)) { datacon->set_blocking(); destruct(datacon); }
    dir_completed();
    selfdestruct();
  }

  void transfer_completed() /* called from pipe */
  {
    DESTRUCT_WERR("transfer_completed");
    id->end();
    save_stuff();
    destruct();
    remove_call_out(connection_timeout);
    remove_call_out(data_connect_timeout);
  }

  void transfer_expect_done(string r,string arg)
  {
    set_what_now("done");
  }

  void transfer()
  {
    object pipe;
    array(string) type;
    array tmp;

    if (getting_list)
    {
      if (getting_list==2) /* redirect */
      {
	id->end("HTTP/1.0 302 try this instead...\r\nLocation: ftp://"+host+(port==21?"":":"+port)+(effect?"/("+effect+")":"")+file+"\r\n\r\n");
	return;
      }
//      buffer="";
      datacon->set_id(0);
      datacon->set_nonblocking(buffer_read,0,buffer_completed);
      return;
    }

    type=id->conf->type_from_filename(file);

    pipe=Pipe.pipe();
    pipe->write("HTTP/1.0 200 FTP transfer initiated\r\n");

    tmp=id->conf->type_from_filename(file,1);
    if (arrayp(tmp)&&tmp[0])
    {
      pipe->write("Content-type: "+tmp[0]+"\r\n");
      if (tmp[1])
	pipe->write("Content-encoding: "+tmp[1]+"\r\n");
    }
    else pipe->write("Content-type: text/plain\r\n");

    if (bytes_size>=0) pipe->write("Content-length: "+bytes_size+"\r\n");
    pipe->write("\r\n");
    pipe->input(datacon);
    pipe->output(id->my_fd);
    pipe->set_done_callback(transfer_completed,0);
    read_state=transfer_expect_done;
    set_what_now("transfer in progress");
  }

  void transfer_response(string r,string arg)
  {
    if (r=="425")
    {
      id->end(ERROR_MESSAGE("Transfer failed: Remote server failed to open connection:\n<pre>"+r+" "+arg+"</pre>"));
    }
    else if ( (r=="150") || (r=="226") || (r=="213") )  /* ok */
    {
      if (sscanf(arg,"%*s(%d bytes",bytes_size)<2) bytes_size=-1;
      transfer();
    }
    else if (r=="550")  /* Not a plain file */  /* a dir maybe? */
    {
      if (!trystat &&
	  (sscanf(lower_case(arg),"%*sno such file or directory%*s")>1||
	   file[strlen(file)-1]=='/'))
	id->end(ERROR_MESSAGE("Error:\n<pre>"+r+" "+arg+"\n</pre>\n"));
      else if (!trystat &&
	       (sscanf(lower_case(arg),"%*sdenied%*s")>1||
		file[strlen(file)-1]=='/'))
	id->end(ERROR_MESSAGE("Error:\n<pre>"+r+" "+arg+"\n</pre>\n"));
      else
      {
	set_what_now("not a plain file, try dir...\n");
	if (!trystat) file+="/";
	write_server("list "+file);
	getting_list=2; /* if list, redirect */
	trystat=0;
      }
    }
    else if (r=="451") /* Requested action aborted: local error in processing  */
      id->end(ERROR_MESSAGE("Transfer aborted; Remote server failed:\n<pre>"+r+" "+arg+"\n</pre>"));
    else
      id->end(ERROR_MESSAGE("Unhandled response, aborting:\n<pre>"+r+" "+arg+"\n</pre>(transfer_response)"));
  }

  void transfer_now()
  {
    if (file[strlen(file)-1]=='/')
    {
      write_server("list "+(file=="/"?"/.":file));
      buffer="" ;
      getting_list=1;
    }
    else {
      write_server("retr "+file);
    }
    read_state=transfer_response;
  }

  void active_transfer_accept(object port)
  {
    DESTRUCT_WERR("active_transfer_accept");
    remove_call_out(data_connect_timeout);
    datacon=port->accept();
    if (!datacon) return; /* huh? out of fd's maybe. FTP server will complain. */
    if (bytes_size!=-2 ||
	master->query("hold")=="No") transfer();
    master->save_dataport(({portno,dataport}));
    dataport=0;
  }

  void active_before_connect(string r,string arg)
  {
    if (r=="150")
    {
      if (sscanf(arg,"%*s(%d bytes",bytes_size)<2) bytes_size=-1;
      if (datacon) transfer();
      /* else, wait for connect */
    }
    else if (r=="550") /* Not a plain file */  /* a dir maybe? */
    {

      if (!trystat &&
	  (sscanf(lower_case(arg),"%*sno such file or directory%*s")>1||
	   file[strlen(file)-1]=='/'))
	id->end(ERROR_MESSAGE("Error:\n<pre>"+r+" "+arg+"\n</pre>\n"));
      else if (!trystat &&
	       (sscanf(lower_case(arg),"%*sdenied%*s")>1||
		file[strlen(file)-1]=='/'))
	id->end(ERROR_MESSAGE("Error:\n<pre>"+r+" "+arg+"\n</pre>\n"));
      else
      {
	set_what_now("not a plain file, try dir...\n");
	if (!trystat) file+="/";
	write_server("list "+file);
	getting_list=2; /* if list, redirect */
	trystat=0;
      }
    }
    else if (r=="425")
      id->end(ERROR_MESSAGE("Transfer failed: Remote server failed to open connection:\n<pre>"+r+" "+arg+"\n</pre>"));
    else if (r=="226") /* transfer complete */
      ; /* ignore... well get it soon */
    else if (r=="213") /* Size of a document */
      ;
    else if (r=="230") /* login correct */
      ;
    else
      id->end(ERROR_MESSAGE("Unhandled response, aborting:\n<pre>"+r+" "+arg+"\n</pre>(active_before_connect)"));
  }

  void data_connect_timeout()
  {
    /* fnskpt */
    if (objectp(id))
      id->end(ERROR_MESSAGE("Connection timeout: <tt>"+host+"</tt>"));
    if (objectp(server))
    {
      server->set_blocking();
      destruct(server);
      server=0;
    }
    if (objectp(dataport))
    {
      destruct(dataport);
      dataport=0;
    }
    selfdestruct();
  }

  void active_transfer_file()
  {
    array dataportid;
    if (!(dataportid=master->get_dataport(active_transfer_accept)))
    {
      id->end(ERROR_MESSAGE("failed to listen on too many ports; this ought not to happen."));
      return;
    }
    else
    {
      portno=dataportid[0];
      dataport=dataportid[1];
    }
    int a1,a2,a3,a4;
    sscanf(server->query_address(17),"%d.%d.%d.%d",a1,a2,a3,a4); /* our address */
    write_server(sprintf("port %d,%d,%d,%d,%d,%d",a1,a2,a3,a4,portno>>8,portno&255));
    transfer_now();
    read_state=active_before_connect;
    call_out(data_connect_timeout,ACTIVE_CONNECT_TIMEOUT);
  }

  void got_passive_connection(object d)
  {
    DESTRUCT_WERR("got_passive_connection");
    if (!d)
    {
      id->end(ERROR_MESSAGE("Failed to open PASSIVE connection"));
      selfdestruct();
    }
    datacon=d;
    remove_call_out(data_connect_timeout);
    transfer_now();
  }

  void passive_connect(string r,string arg)
  {
    if (r=="227") /* entering passive mode */
    {
      int a1,a2,a3,a4;
      int p1,p2;
      if (sscanf(arg,"%*s(%d,%d,%d,%d,%d,%d)%*s",a1,a2,a3,a4,p1,p2)<7)
      {
	id->end(ERROR_MESSAGE("Illegal reply from "+host+":\n<pre>"+r+" "+arg+"\n</pre>"));
	return;
      }
      async_connect(sprintf("%d.%d.%d.%d",a1,a2,a3,a4),(p1*256)|p2,got_passive_connection);
      call_out(data_connect_timeout,ACTIVE_CONNECT_TIMEOUT);
    }
    else
      id->end(ERROR_MESSAGE("Unhandled response, aborting:\n<pre>"+r+" "+arg+"\n</pre>(passive_connect)"));
  }

  void passive_transfer_file()
  {
    write_server("pasv");
    read_state=passive_connect;
  }

  void stat_result(string r,string arg)
  {
    if (r=="226") return; /* message from previous session? */
    if (r=="230") return; /* login ok (?) */
    // Should check for 213 in the next check, according to Jason Rumney
    if (r=="211" || r=="212" || r == "213") /* stat done */
    {
      dir_completed();
      dontsaveserver=0;
      return;
    }
    else if (r=="502"||r=="500"||r=="550") /* command not implemented *sigh* */
    {
      set_what_now("opening data connection");
      switch (master->query("method"))
      {
      case "Active": active_transfer_file(); break;
      case "Passive": passive_transfer_file(); break;
      default: id->end(ERROR_MESSAGE("Internal error: illegal method"));
      }
      return;
    }
    else
      id->end(ERROR_MESSAGE("Unhandled response, aborting:\n<pre>"+r+" "+arg+"\n</pre>(stat_result)"));
  }

  void open_connection()
  {
#ifdef DEBUG
    write("open_connection...\n");
#endif
    dontsaveserver=0;
    if (trystat||file[strlen(file)-1]=='/') /* dir, try stat */
    {
      set_what_now("doing 'stat' for directory "+file );
      buffer="";
      dontsaveserver=1;
      write_server("stat "+(file=="/"?"/.":file)+"");
      read_state=stat_result;
      return;
    }
    set_what_now("opening data connection");
    switch (master->query("method"))
    {
    case "Active": active_transfer_file(); break;
    case "Passive": passive_transfer_file(); break;
    default: id->end(ERROR_MESSAGE("Internal error: illegal method"));
    }
  }

  void password_response(string r,string arg)
  {
    if (r=="230") /* user logged in, proceed */
    {
      write_server("type i");
      open_connection();
    }
    else if (r=="220") /* service ready */
      return; /* ignore */
    else
      id->end(ERROR_MESSAGE("Unhandled response, aborting:\n<pre>"+r+" "+arg+"\n</pre>(password_response)"));
  }

  void passwd(string r,string arg)
  {
    if (r=="331") /* Send your password, please */
    {
      array f;
      if(0) // Silly
	if(id->realauth && sizeof(f = id->realauth/":") == 2)
	  write_server("pass "+(f[1..]*":"));
	else
	  id->end(AUTH_REQUIRED);
      else if (passw)
	write_server("pass "+passw);
      else
	// I WANT a query() function in conf. hrmpf! /kg
	write_server("pass roxen_ftp_gateway@"+id->conf->variables->Domain[0]);
      read_state=password_response;
    } else if (r=="230") /* user logged in, proceed */
    {
      write_server("type i");
      open_connection();
    } else if (r=="220") /* service ready */
      return; /* ignore */
    else {
      id->end(ERROR_MESSAGE("Unhandled response, aborting:\n<pre>"+r
			    +" "+arg+"\n</pre>(passwd)"));
    }
  }

  void login()
  {
    set_what_now("logging in");
    if (!id)
    {
      save_stuff();
      selfdestruct();
      return;
    }
    if(user)
      write_server("user "+user);
    else
      write_server("user anonymous");
    read_state=passwd;
  }

  void read_server(mixed dummy_id,string s)
  {
    array(string) ss;

    DESTRUCT_WERR("read_server");

    if (!objectp(id))
    {
      save_stuff();
      selfdestruct();
      return;
    }

    s=last_read+s;
    ss=s/"\n";
    last_read=ss[-1]; /* last element */
    foreach(ss[0..sizeof(ss)-2],s)
    {
#ifdef SESSION_INFO
      session+="<- "+s+"\n";
#endif
#ifdef DEBUG
      werror("parse "+s+"\n");
#endif
      if (strlen(s)<4||s[3]!=' '||
	  s[0]<'0'||s[0]>'9'||
 	  s[1]<'0'||s[1]>'9'||
 	  s[2]<'0'||s[2]>'9')
      {
	if (read_state==stat_result)
	{
	  if (s[0..3]!="211-"&&s[0..3]!="212-"&&
	      s[0..7]!="getsvc: ") buffer+=s+"\n"; /* keep output */
	}
	else if (s[0..3]=="530-") buffer+=s+"\n"; /* keep error */
	else if (s[0..3]=="230-"||s[0..3]=="220-") server_info+=s+"\n"; /* keep server information */
	/* ignore */
      }
      else if (s[0]>'5') ; /* ignore */
      else if (s[0..2]=="200") ; /* command ok, ignore */
      else if (s[0..2]=="530") /* Not logged in */
      {
	server->set_blocking();
	destruct(server); /* kill it */
	if (usedoldconnection)
	{
	  set_what_now("connecting to server (old connection wierd)");
	  async_connect(host,port,connected);
	  return;
	}
	else
	  id->end(ERROR_MESSAGE("Failed to log in:\n<pre>"+buffer+s+"</pre>"));
      }
      else if (s[0..2]=="120") /* Service ready in N minutes */
      {
	id->end(ERROR_MESSAGE("Failed to log in; service not currently available:<pre>"+s+"\n</pre>\n"));
	server->set_blocking();
	destruct(server); /* kill it */
      }
      else if (s[0..2]=="421") /* Service not available  */
      {
	id->end(ERROR_MESSAGE("Failed to log in, service not available:\n<pre>"+s+"</pre>"));
	server->set_blocking();
	destruct(server); /* kill it */
      }
      else
      {
	if (s[0..2]=="230"||s[0..2]=="220") server_info+=s+"\n";
	(read_state)(s[0..2],s[4..]);
      }
      if (!objectp(id))
      {
	save_stuff();
	selfdestruct();
	return;
      }
    }
  }

  void server_close(mixed dummy_id)
  {
    DESTRUCT_WERR("server_close");
    if (id)
      id->end(ERROR_MESSAGE("Connection closed by <tt>"+host+"</tt>"));
    if (objectp(server)) { server->set_blocking(); destruct(server); }
    server=0;
    save_stuff();
    selfdestruct();
  }

  void connection_timeout(object con)
  {
    DESTRUCT_WERR("connected");
    if (objectp(id))
    {
      async_connect(host,port,connected);
      call_out(connection_timeout,CONNECTION_TIMEOUT,0);
      return;
      /* retry */
    }
    selfdestruct();
  }

  void connected(object con)
  {
    DESTRUCT_WERR("connected");
    remove_call_out(connection_timeout);
    if (!objectp(id))
    {
      selfdestruct();
      return;
    }
    if (!con)
    {
      id->end(ERROR_MESSAGE("Connection refused by <tt>"+host+"</tt>"));
      selfdestruct();
    }
    else
    {
      if (server) { destruct(con); return; }  /* already had a connection */
      server=con;
      server->set_id(0);
      server->set_nonblocking(read_server,0/*write callback*/,server_close);
      dontsaveserver=1;
      login();
    }
  }

  void create(object|void rid,object|void rmaster,
	      string|void rhost,int|void rport,
	      string|void rfile, string|void u, string|void p)
  {
    mixed m;

    buffer="";
    serial=random(32768);
    master=rmaster;
    id=rid;
    host=rhost;
    user = u;
    passw = p;
    if (rfile!=""&&rfile[0]=='(')
      sscanf(rfile,"(%s)%s",effect,rfile);
    else effect=0;

    file="/"+rfile;
    if (search(file,"*")!=-1||
	search(file,"?")!=-1) trystat=1; else trystat=0;

    port=rport;
    if ((m=master->ftp_connection((user||"")+"@"+host+":"+port)) && m[0])
    {
      server=m[0];
      server_info=m[1];
      usedoldconnection=1;
      server->set_id(0);
      server->set_nonblocking(read_server,0/*write callback*/,server_close);
      open_connection();
      return;
    }
    set_what_now("connecting to server");
    async_connect(host,port,connected);
    call_out(connection_timeout,CONNECTION_TIMEOUT,0);
  }

  string comment()
  {
    string url;
    url="ftp://"+(user?user+"@":"")+host+(port!=21?":"+port:"")+"/";
    return "<a href="+url+">"+(user?user+"@":"")+host+"</a>; <a href="+url+
      (file[0]=='/'?file[1..]:file)+">"+file+"</a> - "+what_now;
  }
}; /* End of class Request */



multiset requests=(<>);
object logfile;

function nf=lambda(){};

mapping ftp_connections=([]);
multiset dataports=(<>);
int serial=0;
mapping request_port=([]);

void init_proxies();

import Stdio;
void start()
{
  string pos;
  pos=query("mountpoint");
  init_proxies();
  if(strlen(pos)>2 && (pos[-1] == pos[-2]) && pos[-1] == '/')
    set("mountpoint", pos[0..strlen(pos)-2]); // Evil me..

  if(logfile)
    destruct(logfile);

  if(!strlen(query("logfile")))
    return;

  PROXY_WERR("FTP gateway online.");

  if(query("logfile") == "stdout")
  {
    logfile=stdout;
  } else if(query("logfile") == "stderr") {
    logfile=stderr;
  } else {
    logfile=open(query("logfile"), "wac");
  }
}

void do_write(string host, string oh, string id, string more)
{
  if(!host)     host=oh;
  logfile->write("[" + cern_http_date(time(1)) + "] ftp://" +
		 host + ":" + id + "\t" + more + "\n");
}

void log(string file, string more)
{
  string user, host, rest;

  if(!logfile) return;
  sscanf(file, "%s@%s:%s", user, host, rest);
  roxen->ip_to_host(host, do_write, host, rest, more);
}


array proxies=({});
void init_proxies()
{
  string foo;
  array err;

  proxies = ({ });
  foreach(query("Proxies")/"\n", foo)
  {
    array bar;

    if(!strlen(foo) || foo[0] == '#')
      continue;

    bar = replace(foo, "\t", " ")/" " -({ "" });
    if(sizeof(bar) < 3) continue;
    if(err=catch(proxies += ({ ({ Regexp(bar[0])->match,
				  ({ bar[1], (int)bar[2] }) }) })))
      report_error("Syntax error in regular expression in gateway: "
                   +bar[0]+"\n"+err[0]);
  }
}

string check_variable(string name, mixed value)
{
  if(name == "Proxies")
  {
    array tmp,c;
    string tmp2;
    tmp = proxies;
    tmp2 = query("Proxies");

    set("Proxies", value);
    if(c=catch(init_proxies()))
    {
      proxies = tmp;
      set("Proxies", tmp2);
      return "Error while compiling regular expression. Syntax error: "
	     +c[0]+"\n";
    }
    proxies = tmp;
    set("Proxies", tmp2);
  }
}

void create(object c)
{
  defvar("logfile", GLOBVAR(logdirprefix)+
	 Roxen.short_name(c?c->name:".")+"/ftp_proxy_log",
	 "Logfile", TYPE_FILE,  "Empty the field for no log at all");

  defvar("mountpoint", "ftp:/", "Location", TYPE_LOCATION|VAR_MORE,
	 "By default, this is ftp:/. If you set anything else, all "
	 "normal WWW-clients will fail. But, other might be useful"
	 ", like /ftp/. if you set this location, a link formed like "
	 " this: &lt;a href=\"/ftp/\"&lt;my.www.server&gt;/a&gt; will enable"
	 " accesses to local WWW-servers through a firewall.<p>"
	 "Please consider security, though.");

  defvar("Proxies", "", "Remote gateway regular expressions",
	 TYPE_TEXT_FIELD|VAR_MORE,
	 "Here you can add redirects to remote gateways. If a file is "
	 "requested from a host matching a pattern, the gateway will query the "
	 "Ftp gateway server at the host and port specified.<p> "
	 "Hopefully, that gateway will then connect to the remote ftp server.<br>"
	 "Currently, <b>remote gateway has to be a http-ftp gateway</b> like this one."
	 "<p>"
	 "Example:<hr noshade>"
	 "<pre>"
	 "# All hosts inside *.rydnet.lysator.liu.se has to be\n"
	 "# accessed through lysator.liu.se\n"
	 ".*\\.rydnet\\.lysator\\.liu\\.se        130.236.253.11  21\n"
	 "</pre>"
	 "Please note that this <b>must</b> be "
	 "<a href=$configurl/regexp.html>Regular Expressions</a>.");

  defvar("method", "Active", "FTP transfer method", TYPE_STRING_LIST|VAR_MORE,
	 "What method to use to transfer files. ",
	 ({"Active","Passive"}));

  defvar("keeptime", 60, "Connection timeout", TYPE_INT|VAR_MORE,
	 "How long time in <b>seconds</b> a connection to a ftp server is kept without usage before "+
	 "it's killed");
  defvar("portkeeptime", 60, "Port timeout", TYPE_INT|VAR_MORE,
	 "How long time in <b>seconds</b> a dataport is kept open without usage before closage");
  defvar("icons", "Yes", "Icons", TYPE_STRING_LIST|VAR_MORE,
	 "Icons in directory listnings",({"Yes","No"}));
  defvar("hold", "Yes", "Hold until response", TYPE_STRING_LIST|VAR_MORE,
	 "Hold data transfer until response from server; "+
	 "if the server sends file size, size will be sent to the http client. "+
	 "This may slow down a minimum of time.",({"Yes","No"}));
  defvar("connection_timeout", 120, "Connection timeout", TYPE_INT|VAR_MORE,
	 "Time in seconds before a <i>connection attempt</i> is retried (!).");
  defvar("data_connection_timeout", 30, "Data connection timeout", TYPE_INT|VAR_MORE,
	 "Time in seconds before a <i>data connection</i> is timeouted and cancelled.");
  defvar("save_dataports", "No", "Save dataports", TYPE_STRING_LIST|VAR_MORE,
	 "Some ftpd's have problems when the same port is reused. Try this out on your own. :)",
	 ({"Yes","No"}));
  defvar("server_info", "Yes", "Show server information", TYPE_STRING_LIST|VAR_MORE,
	 "Should the gateway show information that the server gives at point of login at the bottom of directory listnings?",
	 /*                  (    ((                              )                 )    (                               ) */
	 ({"Yes","No"}));
}

constant module_type = MODULE_PROXY|MODULE_LOCATION;
constant module_name = "FTP gateway";
constant module_doc  = "FTP gateway, currently not caching";

string query_location()  { return query("mountpoint"); }

string status()
{
  string res="";
  object foo;

  res += "<h2>Current connections: "+sizeof(requests-(<0>))+"</h2>";
  foreach( indices(requests), foo )
     if(objectp(foo))
	res += foo->comment() + "<br>\n";
#if 0
  res += "<h2>Server connections unused: "+sizeof(ftp_connections)+"</h2>";

  foreach( indices(ftp_connections), foo )
    res += foo + ":"+sizeof(ftp_connections[foo])+"<br>\n";
#endif
  res += "<h2>Ports unused: "+sizeof(dataports)+"</h2>";

  return res;
}

string process_request(object id, int is_remote)
{
  if(!id) return 0;
}

string hostname(string s)
{
  return roxen->quick_ip_to_host(s);
}

void connected_to_server(object o, string file, object id, int is_remote)
{
  if(!o)
  {
    id->end(CONNECTION_REFUSED);
    return;
  }

  PROXY_WERR("Connected.");

//  new_request=Request();
  if(o->query_address())
  {
    string to_send;
    to_send=replace(id->raw, "\n", "\r\n");
    if(!to_send)
    {
      id->do_not_disconnect = 0;
      id->disconnect();

      log(file, "- Clientabort "+hostname(id->remoteaddr));
      return;
    }
    log(file, "- RemoteNew "+hostname(id->remoteaddr));
    o->write(to_send);
    //new_request->assign(o, file, id, 0);
    id->disconnect();
  } else {
    log(file, "- RemoteCache "+hostname(id->remoteaddr));
    //new_request->assign(o, file, id, 1);
  }

  // if(objectp(new_request)) requests[new_request] = 1;
}

array is_remote_proxy(string hmm)
{
  array tmp;
  foreach(proxies, tmp) if(tmp[0](hmm)) return tmp[1];
}

mixed|mapping find_file( string f, object id )
{
  string host, file, key, user, passw;
  mixed tmp;
  array more;
  int port;

  f=id->raw_url[strlen(query("mountpoint")) .. ];
  while(sizeof(f) && f[0]=='/')
    f=f[1..];

  if(search(f, "/") == -1)
    return http_redirect(f+"/");

  if(sscanf(f, "%[^/]/%s", host, file) < 2)
  {
    host = f;
    file = "";
  }

  if(sscanf(host, "%[^@]@%s", user, host) < 2)
  {
    // No user specified
    user = 0;
  } else {
     sscanf(user, "%[^:]:%s", user, passw);
  }

  if (sscanf(host, "%[^:]:%d", host, port) < 2)
  {
     port = 21;
  }

  PROXY_WERR(sprintf("Request for %s\n"
		     "  file:  %s\n"
		     "  user:  %s\n"
		     "  passw: %s\n"
		     "  host:  %s\n"
		     "  port:  %d", f, file,
		     (user||"ANON"), (passw||"N/A"), host, port));

  // if(sscanf(f, "%[^:/]:%d/%s", host, port, file) < 2)
  // {
  //   if(sscanf(f, "%[^/]/%s", host, file) < 2)
  //   {
  // 	 if(strstr(f, "/") == -1)
  // 	 {
  // 	   host = f;
  // 	   file="/";
  // 	 } else {
  // 	   report_debug("I cannot find a hostname and a filename in "+f+"\n");
  // 	   return 0; // This is not a proxy request.
  // 	 }
  //   }
  //   port=21; // Default FTP port. Really! :-)
  // }

  if(tmp = proxy_auth_needed(id))
    return tmp;

  // sscanf(host, "%s@%s", user, host);

  if(!file)
    file="/";

  key = (user||"")+"@"+host+":"+port+"/"+file;
  id->do_not_disconnect = 1;

  // Using a remote proxy?
  if(more = is_remote_proxy(host))
    async_connect(more[0], more[1], connected_to_server,  key, id, 1);

  requests[Request(id,this_object(),host,port,file, user, passw)]=1;
  log(key, "- New "+hostname(id->remoteaddr));
  return http_pipe_in_progress();
}	

/************ optimization ************/

object ftp_connection(string hostid)
{
   multiset lo;
   mixed o;
   array oa;

   if (!(lo=ftp_connections[hostid])) return 0; /* no list */
   if (!sizeof(oa=indices(lo))) return 0; /* empty list */
   lo[o=oa[0]]=0; /* remove from list */
   return o[0..1];
}

void remove_connection(string hostid,mixed m)
{
   if (!ftp_connections[hostid][m]) return;
   ftp_connections[hostid][m]=0;
   if (!sizeof(indices(ftp_connections[hostid])))
      m_delete(ftp_connections,hostid);
   if (!objectp(m[0])) return;
   m[0]->close();
   destruct(m[0]);
}


void save_connection(string hostid,object server,string info)
{
   mixed m;

   if (!(ftp_connections[hostid])) ftp_connections[hostid]=(<m=({server,info,serial++})>);
   else ftp_connections[hostid][m=({server,info,serial++})]=1;
   call_out(remove_connection, query("keeptime"),hostid,m);
   server->set_id(server);
   server->set_nonblocking(lambda() {},0,
			   lambda(object serv) { if (objectp(serv)) { serv->set_id(0); destruct(serv); } });
}

void remove_dataport(mixed m)
{
   if (!dataports[m]) return;
   if (!objectp(m[1])) return;
   dataports[m]=0;

   if (objectp(m[1])) destruct(m[1]);
}

void dataport_accept(object u)
{
  if(!u){
    report_debug("FTP GATEWAY: no arguments to dataport_accept()\n");
    return;
  }
  if (request_port[u])
    (request_port[u])(u);
  else
  {
    object con;
    report_debug("FTP GATEWAY: accept on forgotten port, "
		 "cancelling connection\n");
    con=u->accept();
    if (con) { destruct(con); }
  }
}

mixed create_dataport(function acceptfunc)
{
  int i, ii;
  object dataport;
  dataport=Stdio.Port();
  ii=random(20000)+20000;
  for (i=0; i<500&&ii<65535; i++)
  {
    if (!dataport->bind(ii,dataport_accept))
      ii+=random(200);
    else break;
  }
  if (dataport->query_id() != dataport){
    PROXY_WERR("id set to dataport");
    dataport->set_id(dataport);
  }

  if (i>=500||ii>65535)
  {
    return 0;
  }
  request_port[dataport]=acceptfunc;
  return ({ii,dataport});
}

mixed get_dataport(function acceptfunc)
{
   mixed o;
   array oa;
   for (;;)
   {
      if (!sizeof(oa=indices(dataports))) return create_dataport(acceptfunc); /* no dataports left */
      dataports[o=oa[0]]=0; /* delete */
      if (objectp(o[1]))
      {
	 request_port[o[1]]=acceptfunc;
	 return o[0..1];
      }
   }
}

void save_dataport(array m) /* ({portno,object}) */
{
   if (query("save_dataports")=="Yes")
   {
      m+=({serial++});
      dataports[m]=1;
      m_delete(request_port,m[1]);
      call_out(remove_dataport,query("portkeeptime"),m);
   }
   if(objectp(m[1])) destruct(m[1]);
}
