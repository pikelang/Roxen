/* Roxen WWW-server version 1.0.
string cvs_version = "$Id: http.pike,v 1.8 1997/04/12 15:25:19 per Exp $";
 * http.pike: HTTP convenience functions.
 * inherited by roxenlib, and thus by all files inheriting roxenlib.
 */

#include <config.h>

#if !efun(roxen)
#define roxen roxenp()
#endif

string http_date(int t);

string http_res_to_string( mapping file, object id )
{
#include <variables.h>
  mapping heads=
    ([
      "Content-type":file["type"],
      "Server":id->version(),
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
#if 0
      if(since)
      {
	if(is_modified(since, fstat[3], fstat[1]))
	{
	  file->error = 304;
	  id->method="HEAD";
	}
      }
#endif
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

/* Return a date, used in the common log format */
string cern_http_date(int t)
{
  string s, c, tz;
  int tzh;

  if(timezone()>0)
    c="-";
  else
    c="+";

  if((tzh = (timezone()/3600)) < 0)
    tzh = -tzh;

  s = ctime(t);
  
  return sprintf("%02d/%s/%s:%s %s%02d00", (int)s[8..9], s[4..6], s[20..23], 
		 s[11..18], c ,tzh);
}

/* Returns a http_date, as specified by the HTTP-protocol standard. 
 * This is used for logging as well as the Last-Modified and Time
 * heads in the reply.  */

string http_date(int t)
{
  string s;
  s=ctime(t+timezone());
  return (s[0..2] + sprintf(", %02d ", (int)s[8..9])
	  + s[4..6]+" "+(1900+(int)s[22..23])
	  + s[10..18]+" +0000"); 
}


string http_encode_string(string f)
{
  return replace(f, ({ "\000", " ", "%","\n","\r" }),
		 ({"%00", "%20", "%25", "%0a", "%0d" }));
}

string http_encode_cookie(string f)
{
  return replace(f, ({ "=", ",", ";", "%" }), ({ "%3d", "%2c", "%3b", "%25"}));
}

string http_roxen_config_cookie(string from)
{
  return "RoxenConfig="+http_encode_cookie(from)
    +"; expires=Sun, 29-Dec-99 23:59:59 GMT; path=/";
}

string http_roxen_id_cookie()
{
  return sprintf("RoxenUserID=0x%x; expires=Sun, 29-Dec-99 23:59:59 GMT; path=/",
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
      url = id->conf->query("MyWorldLocation") + url[1..1000000];
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
 

