
#define VERSION "1.7b4"
// changelog:
// 1.7b4 oct4 david
//       Fixed the case when you open a directory that is a link.
//       Some 'stat' replies with 212 instead of 211. 
//	 The proxy now supports them as well.
// 1.7b3 aug28 per
//       Fixed all 'spinner' -> 'roxen'
// 1.7b2 feb24 per
//       Fixed all 'spider' -> 'spinner'
// 1.7b  jan 11 law
//       bugfix in stat_result
//       (handle "ok" from "PASS" and 500 as stat is unknown command)
// 1.7   nov 29 law
//       remembers and show server information
//       show session information (if SESSION_INFO is #defined) as comment in html
// 1.6d  nov 25 law
//       bugfix in one-link-only-in-directory-redirect
//       effect is kept in links
// 1.6c  nov 24 david h
//       decription support in uwp directory type
// 1.6b  nov 23 law
//       ...version information in footers
// 1.6   nov 23 law
//       new directory format (used by ftp.uwp.edu) 

#define SESSION_INFO

inherit "socket";
inherit "roxenlib";

#define INFOSTRING "<font size=-2><a href=http://roxen.com/>"+roxen->version()+"</a> FTP Gateway "+VERSION+" / <i>law@infovav.se</i></font>"

#define _ERROR_MESSAGE(XXXX) ("HTTP/1.0 500 FTP gateway error\r\nContent-type: text/html\r\n\r\n<title>Ftp gateway error</title>\n<h2>FTP Gateway failed:</h2><hr><font size=+1>"XXXX"</font><hr>"+INFOSTRING)
#ifdef SESSION_INFO
#define ERROR_MESSAGE(XXXX) (_ERROR_MESSAGE(XXXX)+"\n\n<!-- session information:\n\n"+session+"\n\n-->\n")
#else
#define ERROR_MESSAGE(XXXX) _ERROR_MESSAGE(XXXX)
#endif

#define AUTH_REQUIRED "HTTP/1.0 401 Auth Required\r\nWWW-Authenticate: Basic realm=\"ftp server password needed\""


#define CONNECTION_TIMEOUT (master->query("connection_timeout"))
#define ACTIVE_CONNECT_TIMEOUT (master->query("data_connection_timeout"))
#define SERVER_INFO (master->query("server_info")=="Yes")
#define MAX_PARSE_DIR 50000

object id,master;
object server,datacon,dataport;

string host,file,effect,user;
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
string *links=({});
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
	 master->save_connection(host+":"+port,server,server_info);
      }
   
   dataport=0;
   server=0;
   if (objectp(datacon))
   {
      destruct(datacon);
      datacon=0;
   }
}

#ifdef FTP_GATEWAY_DEBUG
void set_what_now(string s)
{
   perror("FTP GATEWAY: #"+serial+" "+host+"/"+file+": "+s+"\n");
   what_now=s;
}
#else
#define set_what_now(s) (what_now=(s))
#endif

void selfdestruct()
{
   set_what_now("selfdestructing");
/*
   if (objectp(dataport)) { perror("had dataport\n"); destruct(dataport); }
   if (objectp(datacon)) { perror("had datacon\n"); destruct(datacon); }
   if (objectp(server)) { perror("had server\n"); destruct(server); }
   if (objectp(id)) { perror("had id\n"); id->end(); }
*/
   i_am_destructed=1;
   call_out(lambda() { set_what_now("bye"); destruct(); },10);
   remove_call_out(connection_timeout);
   remove_call_out(data_connect_timeout);
}

void write_server(string s)
{
#ifdef DEBUG
   write("write "+s+"\n");
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
      desc = desc[1..100000];
  }
  if (!type)
  {
    array tmp;
    tmp=roxen->type_from_filename(filename,1);
    if (tmp&&tmp[0]) 
    {
      type=tmp[0]; 
      if (tmp[1]) type+=" ("+tmp[1]+")";
    }
    else type="unknown";
    if (master->query("icons")=="Yes") icon=image_from_type(type);
  }
  else if (!icon && master->query("icons")=="Yes")
  {
    array tmp;
    string type2;
    tmp=roxen->type_from_filename(typename,1);
    if (tmp&&tmp[0]) 
    {
      type2=tmp[0]; 
      if (tmp[1]) type2+=" ("+tmp[1]+")";
      icon=image_from_type(type2);
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
   string *dir,s,filename,link,rest;
   int size,maxlen;
   string res="";
   mixed *dirl=({}),*q;

   rest=((buffer/"\r")*"");
   dir=((rest/"\n ")*" ")/"\n"; /* remove wrapped */

   foreach (dir-({""}),s)
   {
     if (sscanf(s,"%s/%*[ ]%*[=-]  %s",filename, rest)==4 && 
	 sizeof(filename/" ")==1)
       dirl+=({({filename+"/","*dir*",filename+"/",0,"directory",
		 "internal-gopher-menu", rest})});
     else if (sscanf(s,"%s%*[ ]%d  -> %s",filename,size,link)==4)
       dirl+=({({filename+"@",link,link,size,"-> "+link,0,""})}),links+=({link});
     else if (sscanf(s,"%s%*[ ]%*[=-]  -> %s",filename,link)==4)
       dirl+=({({filename+"@",link,link,0,"-> "+link,0, ""})}),links+=({link});
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
  string *dir;
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
  
  if(sscanf(dir[0], "l%*s "+file+" -> %s", f) == 2)
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
    string filename,date,link,type;
    int size, offset;
    for (offset=0; (f[date_position+offset]!=' ')&&
	   (strlen(f) > date_position+offset+14); offset++) ;
    date_position+=offset ; // If size has > 7 digits
    
    if (!(f[date_position+0]==' '&&f[date_position+4]==' '&&
	  f[date_position+7]==' '&&f[date_position+13]==' '&&
	  (f[date_position-1]>='0'&&f[date_position-1]<='9')))
      return 0; /* not this type of format */
    
    filename=f[date_position+14..100000];
    date=f[date_position+1..date_position+12];
    for (i=1; i<20&&(f[date_position-i]>='0'&&f[date_position-i]<='9'); i++);
    size=(int)f[date_position-i..10000];
    if (f[0]=='d')
    {
      type="directory";
      res+=directory_line(filename+"/","*dir*",filename+"/",size,date,maxlen,"directory","internal-gopher-menu");
    }
    else if (f[0]=='l') 
    {
      sscanf(filename,"%s -> %s",filename,type);
      res+=directory_line(filename+"@",type,type/*to*/,size,date,maxlen,"-> "+type);
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
   string *dir;
   string res,f,a;
   int i,maxlen,date_position;

   dir=((buffer/"\r")*"")/"\n";
   if (sizeof(dir)<1)
     return 0; /* nope */
   while (dir[0]=="")
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
     string filename,date,link,type;
     int size;
     
     for (i=strlen(f)-12; i>2; i--)
       if (f[i+0]==' '&&f[i+4]==' '&&f[i+7]==' '&&f[i+13]==' '&&
	   (f[i+6]>='0'&&f[i+6]<='9')&&
	   (f[i-1]>='0'&&f[i-1]<='9')&&
	   (f[i+12]>='0'&&f[i+12]<='9')) break;
     if (i<3) return 0; /* nope */

     date_position=i;
     
     filename=f[date_position+14..100000];
     date=f[date_position+1..date_position+12];
     for (i = 1; i < 20 && (f[date_position - i] >= '0' && 
			    f[date_position-i] <= '9'); i++);
     size=(int)f[date_position-i..10000];
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

string parse_directory()
{
   string res,s,r,t;
   string *path;
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
	    !(res=parse_uwp_directory()))
   {
      /* unknown, return preformatted */
      perror("FTP GATEWAY: unknown list format at "+host+":"+port+"/"+file+"\n");
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
	 string s;
	 res=res[3..100000];
	 if (file!="/") file=((file/"/")[0..sizeof(file/"/")-3])*"/"+"/";
      }
      id->end("HTTP/1.0 302 try this instead... following links\r\nLocation: ftp://"+host+(port==21?"":":"+port)+(effect?"/("+effect+")":"")+file+res+"\r\n\r\n");
      return;
   }

   pipe=clone((program)"/precompiled/pipe");
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
#ifdef DESTRUCT_CHECK
   if (i_am_destructed) perror("I AM DESTRUCTED: transfer_completed\n");
#endif
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
   string *type,stype;
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

   type=id->conf->types_fun(file);

   pipe=clone((program)"/precompiled/pipe");
   pipe->write("HTTP/1.0 200 FTP transfer initiated\r\n");

   tmp=roxen->type_from_filename(file,1);
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
   else if ( (r=="150") || (r=="226") )  /* ok */
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
#ifdef DESTRUCT_CHECK
   if (i_am_destructed) perror("I AM DESTRUCTED: active_transfer_accept\n\n\n");
#endif
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
   mixed *dataportid;
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
#ifdef DESTRUCT_CHECK
   if (i_am_destructed) perror("I AM DESTRUCTED: got_passive_connection\n");
#endif
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
   if (r=="211" || r=="212") /* stat done */
   {
      dir_completed();
      dontsaveserver=0;
      return;
   }
   else if (r=="502"||r=="500") /* command not implemented *sigh* */
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
    if(user && 0)
      if(id->realauth && sizeof(f = id->realauth/":") == 2)
	write_server("pass "+f[1]);
      else
	id->end(AUTH_REQUIRED);
    else
      write_server("pass roxen_ftp_gateway@"+roxen->query("Domain"));
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
  if(user && 0)
    write_server("user "+user);
  else    
    write_server("user ftp");
  read_state=passwd;
}

void read_server(mixed dummy_id,string s)
{
   string *ss;

#ifdef DESTRUCT_CHECK
   if (i_am_destructed) perror("I AM DESTRUCTED: read_server\n");
#endif

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
     perror("parse "+s+"\n");
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
	 (read_state)(s[0..2],s[4..1000000]);
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
#ifdef DESTRUCT_CHECK
   if (i_am_destructed) perror("I AM DESTRUCTED: server_close\n");
#endif
   if (id) 
      id->end(ERROR_MESSAGE("Connection closed by <tt>"+host+"</tt>"));
   if (objectp(server)) { server->set_blocking(); destruct(server); }
   server=0;
   save_stuff();
   selfdestruct();
}

void connection_timeout(object con)
{
#ifdef DESTRUCT_CHECK
   if (i_am_destructed) perror("I AM DESTRUCTED: connected\n\n\n");
#endif
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
#ifdef DESTRUCT_CHECK
   if (i_am_destructed) perror("I AM DESTRUCTED: connected\n\n\n");
#endif
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

void create(object rid,object rmaster,
	    string rhost,int rport,string rfile, string u)
{
   mixed m;

   buffer="";
   serial=random(32768);
   master=rmaster;
   id=rid;
   host=rhost;
   user = u;
   if (rfile!=""&&rfile[0]=='(')
      sscanf(rfile,"(%s)%s",effect,rfile);
   else effect=0;

   file="/"+rfile; 
   if (search(file,"*")!=-1||
       search(file,"?")!=-1) trystat=1; else trystat=0;
   
   port=rport;
   if ((m=master->ftp_connection(host+":"+port)) && m[0])
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
   url="ftp://"+host+(port!=21?":"+port:"")+"/";
   return "<a href="+url+">"+host+"</a>; <a href="+url+
          (file[0]=='/'?file[1..10000]:file)+">"+file+"</a> - "+what_now;
}





