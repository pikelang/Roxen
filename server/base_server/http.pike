/* Roxen WWW-server version 1.0.
string cvs_version = "$Id: http.pike,v 1.21 1998/08/25 05:15:44 neotron Exp $";
 * http.pike: HTTP convenience functions.
 * inherited by roxenlib, and thus by all files inheriting roxenlib.
 */

#include <config.h>

#if !efun(roxen)
#define roxen roxenp()
#endif

string http_date(int t);

#include <variables.h>

string http_res_to_string( mapping file, object id )
{
  mapping heads=
    ([
      "Content-type":file["type"],
      "Server":replace(id->version(), " ", "·"),
      "Date":http_date(id->time)
      ]);
    
  if(file->encoding)
    heads["Content-Encoding"] = file->encoding;
    
  if(!file->error) 
    file->error=200;
    
  if(file->expires)
      heads->Expires = http_date(file->expires);

  if(!file->len)
  {
    if(objectp(file->file))
      if(!file->stat && !(file->stat=id->misc->stat))
	file->stat = (int *)file->file->stat();
    array fstat;
    if(arrayp(fstat = file->stat))
    {
      if(file->file && !file->len)
	file->len = fstat[1];
      
      heads["Last-Modified"] = http_date(fstat[3]);
    }
    if(stringp(file->data)) 
      file->len += strlen(file->data);
  }

  if(mappingp(file->extra_heads)) 
    heads |= file->extra_heads;

  if(mappingp(id->misc->moreheads))
    heads |= id->misc->moreheads;
    
  array myheads=({id->prot+" "+(file->rettext||errors[file->error])});
  foreach(indices(heads), string h)
    if(arrayp(heads[h]))
      foreach(heads[h], string tmp)
	myheads += ({ `+(h,": ", tmp)});
    else
      myheads +=  ({ `+(h, ": ", heads[h])});
  

  if(file->len > -1)
    myheads += ({"Content-length: " + file->len });
  string head_string = (myheads+({"",""}))*"\r\n";

  if(id->conf) {
    id->conf->hsent+=strlen(head_string||"");
    if(id->method != "HEAD")
      id->conf->sent+=(file->len>0 ? file->len : 1000);
  }
  if(id->method != "HEAD")
    head_string+=(file->data||"")+(file->file?file->file->read(0x7ffffff):"");
  return head_string;
}


/* Return a filled out struct with the error and data specified.  The
 * error is infact the status response, so '200' is HTTP Document
 * follows, and 500 Internal Server error, etc.
 */

mapping http_low_answer( int errno, string data )
{
  if(!data) data="";
#ifdef HTTP_DEBUG
  perror("HTTP: Return code "+errno+" ("+data+")\n");
#endif  
  return 
    ([ 
      "error" : errno,
      "data"  : data,
      "len"   : strlen( data ),
      "type"  : "text/html",
      ]);
}

mapping http_pipe_in_progress()
{
#ifdef HTTP_DEBUG
  perror("HTTP: Pipe in progress\n");
#endif  
  return ([ "file":-1, "pipe":1, ]);
}

/* Convenience functions to use in Roxen modules. When you just want
 * to return a string of data, with an optional type, this is the
 * easiest way to do it if you don't want to worry about the internal
 * roxen structures.  
 */

mapping http_string_answer(string text, string|void type)
{
#ifdef HTTP_DEBUG
  perror("HTTP: String answer ("+(type||"text/html")+")\n");
#endif  
  return ([ "data":text, "type":(type||"text/html") ]);
}

mapping http_file_answer(object text, string|void type, void|int len)
{
  return ([ "file":text, "type":(type||"text/html"), "len":len ]);
}

constant months = ({ "Jan", "Feb", "Mar", "Apr", "May", "Jun",
		     "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" });
constant days = ({ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" });

/* Return a date, used in the common log format */
string cern_http_date(int t)
{
  string c;
  mapping lt = localtime(t);
  int tzh = lt->timezone/3600 - lt->isdst;

  if(tzh > 0)
    c="-";
  else {
    tzh = -tzh;
    c="+";
  }

#if 1
  return(sprintf("%02d/%s/%04d:%02d:%02d:%02d %s%02d00",
		 lt->mday, months[lt->mon], 1900+lt->year,
		 lt->hour, lt->min, lt->sec, c, tzh));
#else
  string s = ctime(t);
  
  return sprintf("%02d/%s/%s:%s %s%02d00", (int)s[8..9], s[4..6], s[20..23], 
		 s[11..18], c ,tzh);
#endif /* 1 */
}

/* Returns a http_date, as specified by the HTTP-protocol standard. 
 * This is used for logging as well as the Last-Modified and Time
 * heads in the reply.  */

string http_date(int t)
{
  mapping l = localtime(t);

#if 1

  t += l->timezone - 3600*l->isdst;
  l = localtime(t);

  return(sprintf("%s, %02d %s %04d %02d:%02d:%02d GMT",
		 days[l->wday], l->mday, months[l->mon], 1900+l->year,
		 l->hour, l->min, l->sec));

#else
  string s=ctime(t + l->timezone - 3600*l->isdst);
  return (s[0..2] + sprintf(", %02d ", (int)s[8..9])
	  + s[4..6]+" "+(1900+l->year)
	  + s[10..18]+" GMT"); 
#endif /* 1 */
}


string http_encode_string(string f)
{
  return replace(f, ({ "\000", " ", "\t", "\n", "\r", "%", "'", "\"" }),
		 ({"%00", "%20", "%09", "%0a", "%0d", "%25", "%27", "%22"}));
}

string http_encode_cookie(string f)
{
  return replace(f, ({ "=", ",", ";", "%" }), ({ "%3d", "%2c", "%3b", "%25"}));
}

string http_encode_url (string f)
{
  return replace (f, ({"\000", " ", "\t", "\n", "\r", "%", "'", "\"",
		       "&", "?", "=", "/", ":"}),
		  ({"%00", "%20", "%09", "%0a", "%0d", "%25", "%27", "%22",
		    "%26", "%3f", "%3d", "%2f", "%3a"}));
}

string http_roxen_config_cookie(string from)
{
  return "RoxenConfig="+http_encode_cookie(from)
    +"; expires=" + http_date (3600*24*365*2 + time (1)) + "; path=/";
}

string http_roxen_id_cookie()
{
  return sprintf("RoxenUserID=0x%x; expires=" +
		 http_date (3600*24*365*2 + time (1)) + "; path=/",
		 roxen->increase_id());
}

static string add_pre_state( string url, multiset state )
{
  if(!url)
    error("URL needed for add_pre_state()\n");
  if(!state || !sizeof(state))
    return url;
  if(strlen(url)>5 && (url[1] == "(" || url[1] == "<"))
    return url;
  return "/(" + sort(indices(state)) * "," + ")" + url ;
}

/* Simply returns a http-redirect message to the specified URL.  */
mapping http_redirect( string url, object|void id )
{
  if(url[0] == '/')
  {
    if(id)
    {
      url = add_pre_state(url, id->prestate);
      if(id->misc->host) {
	string p = ":80", prot = "http://";
	array h;
	if(id->ssl_accept_callback) {
	  // This is an SSL port. Not a great check, but what is one to do?
	  p = ":443";
	  prot = "https://";
	}
	h = id->misc->host / p  - ({""});
	if(sizeof(h) == 1)
	  // Remove redundant port number.
	  url=prot+h[0]+url;
	else
	  url=prot+id->misc->host+url;
      } else
	url = id->conf->query("MyWorldLocation") + url[1..];
    }
  }
#ifdef HTTP_DEBUG
  perror("HTTP: Redirect -> "+http_encode_string(url)+"\n");
#endif  
  return http_low_answer( 302, "") 
    + ([ "extra_heads":([ "Location":http_encode_string( url ) ]) ]);
}

mapping http_stream(object from)
{
  return ([ "raw":1, "file":from, "len":-1, ]);
}


mapping http_auth_required(string realm, string|void message)
{
  if(!message)
    message = "<h1>Authentication failed.\n</h1>";
#ifdef HTTP_DEBUG
  perror("HTTP: Auth required ("+realm+")\n");
#endif  
  return http_low_answer(401, message)
    + ([ "extra_heads":([ "WWW-Authenticate":"basic realm=\""+realm+"\"",]),]);
}

#ifdef API_COMPAT
mapping http_auth_failed(string realm)
{
#ifdef HTTP_DEBUG
  perror("HTTP: Auth failed ("+realm+")\n");
#endif  
  return http_low_answer(401, "<h1>Authentication failed.\n</h1>")
    + ([ "extra_heads":([ "WWW-Authenticate":"basic realm=\""+realm+"\"",]),]);
}
#else
function http_auth_failed = http_auth_required;
#endif


mapping http_proxy_auth_required(string realm, void|string message)
{
#ifdef HTTP_DEBUG
  perror("HTTP: Proxy auth required ("+realm+")\n");
#endif  
  if(!message)
    message = "<h1>Proxy authentication failed.\n</h1>";
  return http_low_answer(407, message)
    + ([ "extra_heads":([ "Proxy-Authenticate":"basic realm=\""+realm+"\"",]),]);
}
 

