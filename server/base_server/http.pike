// HTTP convenience functions.
// inherited by roxenlib, and thus by all files inheriting roxenlib.
// Copyright © 1996 - 2000, Roxen IS.
// $Id: http.pike,v 1.49 2000/09/19 09:53:50 jhs Exp $

//#pragma strict_types

#include <config.h>
#include <variables.h>

#define roxen roxenp()
class RequestID {};

#ifdef HTTP_DEBUG
# define HTTP_WERR(X) werror("HTTP: "+X+"\n");
#else
# define HTTP_WERR(X)
#endif

string http_res_to_string( mapping file, RequestID id )
{
  mapping(string:string|array(string)) heads=
    ([
      "Content-type":[string]file["type"],
      "Server":replace(roxen->version(), " ", "·"),
      "Date":http_date([int]id->time)
      ]);

  if(file->encoding)
    heads["Content-Encoding"] = [string]file->encoding;

  if(!file->error)
    file->error=200;

  if(file->expires)
      heads->Expires = http_date([int]file->expires);

  if(!file->len)
  {
    if(objectp(file->file))
      if(!file->stat && !(file->stat=([mapping(string:mixed)]id->misc)->stat))
	file->stat = (array(int))file->file->stat();
    array fstat;
    if(arrayp(fstat = file->stat))
    {
      if(file->file && !file->len)
	file->len = fstat[1];

      heads["Last-Modified"] = http_date([int]fstat[3]);
    }
    if(stringp(file->data))
      file->len += strlen([string]file->data);
  }

  if(mappingp(file->extra_heads))
    heads |= file->extra_heads;

  if(mappingp(([mapping(string:mixed)]id->misc)->moreheads))
    heads |= ([mapping(string:mixed)]id->misc)->moreheads;

  array myheads=({id->prot+" "+(file->rettext||errors[file->error])});
  foreach(indices(heads), string h)
    if(arrayp(heads[h]))
      foreach([array(string)]heads[h], string tmp)
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
    head_string+=(file->data||"")+(file->file?file->file->read():"");
  return head_string;
}

mapping http_low_answer( int errno, string data )
//! Return a result mapping with the error and data specified. The
//! error is infact the status response, so '200' is HTTP Document
//! follows, and 500 Internal Server error, etc.
{
  if(!data) data="";
  HTTP_WERR("Return code "+errno+" ("+data+")");
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
  HTTP_WERR("Pipe in progress");
  return ([ "file":-1, "pipe":1, ]);
}

mapping http_rxml_answer( string rxml, RequestID id,
                          void|Stdio.File file,
                          void|string type )
//! Convenience functions to use in Roxen modules. When you just want
//! to return a string of data, with an optional type, this is the
//! easiest way to do it if you don't want to worry about the internal
//! roxen structures.
{
  rxml = 
       ([function(string,RequestID,Stdio.File:string)]id->conf->parse_rxml)
       (rxml, id, file);
  HTTP_WERR("RXML answer ("+(type||"text/html")+")");
  return (["data":rxml,
	   "type":(type||"text/html"),
	   "stat":id->misc->defines[" _stat"],
	   "error":id->misc->defines[" _error"],
	   "rettext":id->misc->defines[" _rettext"],
	   "extra_heads":id->misc->defines[" _extra_heads"],
	   ]);
}

mapping http_try_again( float delay )
//! Causes the request to be retried in delay seconds.
{
  return ([ "try_again_later":delay ]);
}

mapping http_string_answer(string text, string|void type)
//! Generates a result mapping with the given text as the request body
//! with a content type of `type' (or "text/html" if none was given).
{
  HTTP_WERR("String answer ("+(type||"text/html")+")");
  return ([ "data":text, "type":(type||"text/html") ]);
}

mapping http_file_answer(Stdio.File text, string|void type, void|int len)
{
  HTTP_WERR("file answer ("+(type||"text/html")+")");
  return ([ "file":text, "type":(type||"text/html"), "len":len ]);
}

constant months = ({ "Jan", "Feb", "Mar", "Apr", "May", "Jun",
		     "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" });
constant days = ({ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" });



static int chd_lt;
static string chd_lf;
string cern_http_date(int t)
//! Return a date, used in the common log format
{
  if( t == chd_lt ) return chd_lf;

  string c;
  mapping(string:int) lt = localtime(t);
  int tzh = lt->timezone/3600 - lt->isdst;
  if(tzh > 0)
    c="-";
  else {
    tzh = -tzh;
    c="+";
  }
  chd_lt = t;
  return(chd_lf=sprintf("%02d/%s/%04d:%02d:%02d:%02d %s%02d00",
		 lt->mday, months[lt->mon], 1900+lt->year,
		 lt->hour, lt->min, lt->sec, c, tzh));
}

string http_date(int t)
//! Returns a http_date, as specified by the HTTP-protocol standard.
//! This is used for logging as well as the Last-Modified and Time
//! heads in the reply.
{
  mapping(string:int) l = gmtime( t );
  return(sprintf("%s, %02d %s %04d %02d:%02d:%02d GMT",
		 days[l->wday], l->mday, months[l->mon], 1900+l->year,
		 l->hour, l->min, l->sec));
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
  return replace (f, ({"\000", " ", "\t", "\n", "\r", "%", "'", "\"", "#",
		       "&", "?", "=", "/", ":"}),
		  ({"%00", "%20", "%09", "%0a", "%0d", "%25", "%27", "%22", "%23",
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

string add_pre_state( string url, multiset state )
{
  if(!url)
    error("URL needed for add_pre_state()\n");
  if(!state || !sizeof(state))
    return url;
  if(strlen(url)>5 && (url[1] == '(' || url[1] == '<'))
    return url;
  return "/(" + sort(indices(state)) * "," + ")" + url ;
}

mapping http_redirect( string url, RequestID|void id )
//! Simply returns a http-redirect message to the specified URL. If
//! the url parameter is just a virtual (possibly relative) path, the
//! current id object must be supplied to resolve the destination URL.
{
  if(strlen(url) && url[0] == '/')
  {
    if(id)
    {
      if( id->misc->site_prefix_path )
        url = replace( [string]id->misc->site_prefix_path + url, "//", "/" );
      url = add_pre_state(url, [multiset]id->prestate);
      if(id->misc->host)
      {
	array(string) h;
	HTTP_WERR(sprintf("(REDIR) id->port_obj:%O", id->port_obj));
	string prot = [string]id->port_obj->name + "://";
	string p = ":" + [string]id->port_obj->default_port;

	h = [string]id->misc->host / p  - ({""});
	if(sizeof(h) == 1)
	  // Remove redundant port number.
	  url=prot+h[0]+url;
	else
	  url=prot+[string]id->misc->host+url;
      } else
	url = [string]id->conf->query("MyWorldLocation") + url[1..];
    }
  }
  HTTP_WERR("Redirect -> "+http_encode_string(url));
  return http_low_answer( 302, "")
    + ([ "extra_heads":([ "Location":http_encode_string( url ) ]) ]);
}

mapping http_stream(Stdio.File from)
//! Returns a result mapping where the data returned to the client
//! will be streamed raw from the given Stdio.File object, instead of
//! being packaged by roxen. In other words, it's entirely up to you
//! to make sure what you send is HTTP data.
{
  return ([ "raw":1, "file":from, "len":-1, ]);
}

mapping http_auth_required(string realm, string|void message)
//! Generates a result mapping that will instruct the web browser that
//! the user needs to authorize himself before being allowed access.
//! `realm' is the name of the realm on the server, which will
//! typically end up in the browser's prompt for a name and password
//! (e g "Enter username for <i>realm</i> at <i>hostname</i>:"). The
//! optional message is the message body that the client typically
//! shows the user, should he decide not to authenticate himself, but
//! rather refraim from trying to authenticate himself.
//!
//! In HTTP terms, this sends a <tt>401 Auth Required</tt> response
//! with the header <tt>WWW-Authenticate: basic realm="`realm'"</tt>.
//! For more info, see RFC 2617.
{
  if(!message)
    message = "<h1>Authentication failed.\n</h1>";
  HTTP_WERR("Auth required ("+realm+")");
  return http_low_answer(401, message)
    + ([ "extra_heads":([ "WWW-Authenticate":"basic realm=\""+realm+"\"",]),]);
}

mapping http_proxy_auth_required(string realm, void|string message)
//! Generates a result mapping that will instruct the client end that
//! it needs to authenticate itself before being allowed access.
//! `realm' is the name of the realm on the server, which will
//! typically end up in the browser's prompt for a name and password
//! (e g "Enter username for <i>realm</i> at <i>hostname</i>:"). The
//! optional message is the message body that the client typically
//! shows the user, should he decide not to authenticate himself, but
//! rather refraim from trying to authenticate himself.
//!
//! In HTTP terms, this sends a <tt>407 Proxy authentication
//! failed</tt> response with the header <tt>Proxy-Authenticate: basic
//! realm="`realm'"</tt>. For more info, see RFC 2617.
{
  HTTP_WERR("Proxy auth required ("+realm+")");
  if(!message)
    message = "<h1>Proxy authentication failed.\n</h1>";
  return http_low_answer(407, message)
    + ([ "extra_heads":([ "Proxy-Authenticate":"basic realm=\""+realm+"\"",]),]);
}

mapping add_http_header(mapping to, string name, string value)
{
  if(to[name]) {
    if(arrayp(to[name]))
      to[name] += ({ value });
    else
      to[name] = ({ to[name], value });
  }
  else
    to[name] = value;
  return to;
}
