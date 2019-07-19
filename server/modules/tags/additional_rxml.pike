// This is a roxen module. Copyright © 2000 - 2009, Roxen IS.
//

#include <module.h>
inherit "module";

#define _ok RXML_CONTEXT->misc[" _ok"]

constant cvs_version = "$Id$";
constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Tags: Additional RXML tags";
constant module_doc  = "This module provides some more complex and not as widely used RXML tags.";

//#define OUTGOING_PROXY_DEBUG

//  Cached copy of conf->query("compat_level").
float compat_level = (float) my_configuration()->query("compat_level");

void create() {
  defvar("insert_href",
#ifdef THREADS
	 1
#else
	 0
#endif
	 , "Allow tags that might hang",
	 TYPE_FLAG, #"\
<p>If set, it will be possible to use <tt>&lt;insert href&gt;</tt> and
<tt>&lt;xml-rpc-call&gt;</tt> to retrieve responses from other
servers.</p>

<p>These tags will block the handler thread while they wait for the
remote server, so if enough requests are made to an unresponding
external web server, this server might also cease to respond.</p>");

  defvar ("default_timeout", 300, "Default timeout for <insert href>",
	  TYPE_INT, #"\
Maximum waiting time in seconds for a response from the other web
server when <tt>&lt;insert href&gt;</tt> is used. This can be
overridden with the <tt>timeout</tt> attribute. Set it to zero to wait
indefinitely by default.

<p>Timeout is not available if your run the server without threads."
#ifndef THREADS
	  " <strong>You are currently running without threads.</strong>"
#endif
	 );

  defvar("recursion_limit", 2, "Maximum recursion depth for <insert href>",
	 TYPE_INT|VAR_MORE,
	 "Maxumum number of nested <tt>&lt;insert href&gt;</tt>'s allowed. "
	 "May be set to zero to disable the limit.");
}

#ifdef THREADS

class AsyncHTTPClient {
  int status;
  object con;
  Standards.URI url;
  string path, query, req_data,method;
  mapping request_headers;

  Thread.Queue queue = Thread.Queue();

  void do_method(string _method,
		 string|Standards.URI _url,
		 void|mapping post_variables,
		 void|mapping _request_headers,
		 void|Protocols.HTTP.Query _con, void|string _data)
  {
    if(!_con) {
      con = Protocols.HTTP.Query();
    }
    else
      con = _con;

    method = _method;

    if(!_request_headers)
      request_headers = ([]);
    else
      request_headers = _request_headers;

    if(post_variables) {
      request_headers += 
		   (["content-type":
		     "application/x-www-form-urlencoded"]);
      _data = Protocols.HTTP.http_encode_query(post_variables);
    }

    req_data = _data;

    if(stringp(_url)) {
      if (mixed err = catch (url=Standards.URI(_url)))
	RXML.parse_error ("Invalid URL: %s\n", describe_error (err));
    }
    else
      url = _url;

#if constant(SSL.sslfile) 	
    if(url->scheme!="http" && url->scheme!="https")
      error("Protocols.HTTP can't handle %O or any other protocols than HTTP or HTTPS\n",
	    url->scheme);
    
    con->https= (url->scheme=="https")? 1 : 0;
#else
    if(url->scheme!="http"	)
      error("Protocols.HTTP can't handle %O or any other protocol than HTTP\n",
	    url->scheme);
    
#endif
    
    if(!request_headers)
      request_headers = ([]);
    mapping default_headers = ([
      "user-agent" : "Mozilla/4.0 compatible (Pike HTTP client)",
      "host" : url->host + ( (url->scheme=="http" && url->port != 80) ||
                             (url->scheme=="https" && url->port != 443) ?
                             ":"+ url->port : "")
    ]);
    
    if(url->user)
      default_headers->authorization = "Basic "
	+ MIME.encode_base64(url->user + ":" +
			     (url->password || ""));
    request_headers = default_headers | request_headers;
    
    query=url->query;
    /*
    if(query_variables && sizeof(query_variables))
      {
	if(query)
	  query+="&"+Protocols.HTTP.http_encode_query(query_variables);
	else
	  query=Protocols.HTTP.http_encode_query(query_variables);
      }
    */

    
    path=url->path;
    if(path=="") path="/";
  }


  string data() {
    if(!con->ok)
      return 0;
    return con->data();
  }
 
  void req_ok() {
    status = con->status;
    con->timed_async_fetch(data_ok, data_fail);
  }
  
  void req_fail() {
    status = 0;
    // Wake up handler thread
    queue->write("@");
  }

  void data_ok() {
    // Wake up handler thread
    queue->write("@");
  }
  
  void data_fail() {
    status = 0;
    // Wake up handler thread
    queue->write("@");
  }

  void run() {
    /*
    con->sync_request(url->host,url->port,
		      method+" "+path+(query?("?"+query):"")+" HTTP/1.0",
		      request_headers, req_data);
    
    */

    con->set_callbacks(req_ok, req_fail);

#ifdef ENABLE_OUTGOING_PROXY
    if (roxen.query("use_proxy") && sizeof(roxen.query("proxy_url"))) {
#ifdef OUTGOING_PROXY_DEBUG
      werror("Insert href: Using proxy: %O to fetch %O...\n",
	     roxen.query("proxy_url"), url);
#endif
      Protocols.HTTP.do_async_proxied_method(roxen.query("proxy_url"),
					     roxen.query("proxy_username"), 
					     roxen.query("proxy_password"),
					     method, url, 0,
					     request_headers, con,
					     req_data);
    } else {
      con->async_request(url->host,url->port,
			 method+" "+path+(query?("?"+query):"")+" HTTP/1.0",
			 request_headers, req_data);
    }
#else
    con->async_request(url->host,url->port,
		       method+" "+path+(query?("?"+query):"")+" HTTP/1.0",
		       request_headers, req_data);
#endif

    status = con->status;
    queue->read();
  }
  
  void destroy()
  {
    if(con)
      destruct(con);
  }

  void create(string method, mapping args, mapping|void headers) {
    if(method == "POST") {
      mapping vars = ([ ]);
      string data;
#if constant(roxen)
      data = args["post-data"];
      foreach( (args["post-variables"] || "") / ",", string var) {
	array a = var / "=";
	if(sizeof(a) == 2)
	  vars[String.trim_whites(a[0])] = RXML.user_get_var(String.trim_whites(a[1]));
      }
      if(data && sizeof(data) && sizeof(vars))
	RXML.run_error("The 'post-variables' and the 'post-data' arguments "
		       "are mutually exclusive.");
#endif
      do_method("POST", args->href, sizeof(vars) && vars, headers,
		0, data);
    }
    else
      do_method("GET", args->href, 0, headers);

    if(args->timeout) {
      con->timeout = (int) args->timeout;
      con->data_timeout = (int) args->timeout;
    } else if (int t = global::query ("default_timeout")) {
      con->timeout = t;
      con->data_timeout = t;
    } else {
      // There ought to be a way to disable the timeout in
      // Protocols.HTTP.Query.
      con->timeout = 214748364;
      con->data_timeout = 214748364;
    }
  }
  
}
#endif

class TagInsertHref {
  inherit RXML.Tag;
  constant name = "insert";
  constant plugin_name = "href";

  string get_data(string var, mapping args, RequestID id) {
    if(!query("insert_href")) RXML.run_error("Insert href is not allowed.\n");

    int recursion_depth = (int)id->request_headers["x-roxen-recursion-depth"];

    if (query("recursion_limit") &&
	(recursion_depth >= query("recursion_limit")))
      RXML.run_error("Too deep insert href recursion.");

    recursion_depth++;

    if(args->nocache)
      NOCACHE();
    else
      CACHE(60);

    string method = "GET";
    if(args->method && lower_case(args->method) == "post")
      method = "POST";

    object /*Protocols.HTTP|AsyncHTTPClient*/ q;

    mapping(string:string) headers = ([ "X-Roxen-Recursion-Depth":
					(string)recursion_depth ]);
    if (args["request-headers"])
      foreach (args["request-headers"] / ",", string header)
	if (sscanf (header, "%[^=]=%s", string name, string val) == 2)
	  headers[name] = val;

#ifdef THREADS
    q = AsyncHTTPClient(method, args, headers);
    q->run();
#else
    mixed err;
    if(method == "POST") {
      mapping vars = ([ ]);
      foreach( (args["post-variables"] || "") / ",", string var) {
	array a = var / "=";
	if(sizeof(a) == 2)
	  vars[String.trim_whites(a[0])] = RXML.user_get_var(String.trim_whites(a[1]));
      }
      err = catch {
	  q = Protocols.HTTP.post_url(args->href, vars, headers);
	};
    }
    else
      err = catch {
	  q = Protocols.HTTP.get_url(args->href, 0, headers);
	};
    if (err) {
      string msg = describe_error (err);
      if (has_prefix (msg, "Standards.URI:"))
	RXML.parse_error ("Invalid URL: %s\n", msg);
    }
#endif
    
    _ok = 1;
    
    if(args["status-variable"] && q && q->status)
      RXML.user_set_var(args["status-variable"],q->status);
    
    if(q && q->status>0 && q->status<400) {
      mapping headers = q->con->headers;
      string data = q->data();
      // Explicitly destruct the connection object to avoid garbage
      // and CLOSE_WAIT sockets. Reported in [RT 18335].
      destruct(q);
      return Roxen.low_parse_http_response (headers, data, 0, 1,
					    (int)args["ignore-unknown-ce"]);
    }

    _ok = 0;

    if(!args->silent)
      RXML.run_error((q && q->status_desc) || "No server response");
    // Explicitly destruct the connection object to avoid garbage
    // and CLOSE_WAIT sockets. Reported in [RT 18335].
    destruct(q);
    return "";
  }
}

class TagXmlRpcCall
// FIXME: This tag should also implement timeout using AsyncHTTPClient
// or similar.
{
  inherit RXML.Tag;
  constant name = "xml-rpc-call";
  constant flags = RXML.FLAG_DONT_RECOVER;
  mapping(string:RXML.Type) req_arg_types = ([
    "href": RXML.t_text (RXML.PXml),
    "method": RXML.t_text (RXML.PXml),
  ]);

  class TagSimpleParam
  {
    inherit RXML.Tag;
    constant flags = RXML.FLAG_DONT_RECOVER;
    constant allow_empty = 0;
    class Frame
    {
      inherit RXML.Frame;
      array do_return (RequestID id)
      {
	if (content == RXML.nil) {
	  if (!allow_empty)
	    RXML.parse_error ("Missing value.\n");
	  up->params += ({content_type->empty_value});
	}
	else
	  up->params += ({content});
	result = RXML.nil;
	return 0;
      }
    }
  }

  class TagString
  {
    inherit TagSimpleParam;
    constant name = "string";
    RXML.Type content_type = RXML.t_string (RXML.PXml);
    constant allow_empty = 1;
  }

  class TagInt
  {
    inherit TagSimpleParam;
    constant name = "int";
    RXML.Type content_type = RXML.t_int (RXML.PXml);
  }

  class TagFloat
  {
    inherit TagSimpleParam;
    constant name = "float";
    RXML.Type content_type = RXML.t_float (RXML.PXml);
  }

  class TagIsoDateTime
  {
    inherit RXML.Tag;
    constant name = "iso-date-time";
    RXML.Type content_type = RXML.t_string (RXML.PXml);
    constant flags = RXML.FLAG_DONT_RECOVER;
    class Frame
    {
      inherit RXML.Frame;
      array do_return (RequestID id)
      {
	int t;
	int year, month, day, hour, minute, second;
	if (sscanf (content || "", "%d-%d-%d%*c%d:%d:%d",
		    year, month, day, hour, minute, second) < 3)
	  RXML.parse_error ("Need at least yyyy-mm-dd specified.\n");
	if (mixed err = catch (t = mktime (([
					     "year": year - 1900,
					     "mon": month - 1,
					     "mday": day,
					     "hour": hour,
					     "min": minute,
					     "sec": second,
					   ]))))
	  RXML.run_error (describe_error (err));
	up->params += ({Calendar.ISO.Second (t)});
	result = RXML.nil;
	return 0;
      }
    }
  }

  class TagArray
  {
    inherit RXML.Tag;
    constant name = "array";
    constant flags = RXML.FLAG_DONT_RECOVER;
    class Frame
    {
      inherit RXML.Frame;
      RXML.TagSet local_tags = param_tags;
      array params = ({});
      array do_return (RequestID id)
      {
	up->params += ({params});
	result = RXML.nil;
	return 0;
      }
    }
  }

  class TagMember
  {
    inherit RXML.Tag;
    constant name = "member";
    constant flags = RXML.FLAG_DONT_RECOVER;
    mapping(string:RXML.Type) req_arg_types = ([
      "name": RXML.t_text (RXML.PXml),
    ]);
    class Frame
    {
      inherit RXML.Frame;
      RXML.TagSet local_tags = param_tags;
      array params = ({});
      array do_return (RequestID id)
      {
	if (sizeof (params) > 1)
	  RXML.parse_error ("Cannot take more than one value.\n");
	if (sizeof (params) < 1)
	  RXML.parse_error ("Missing value.\n");
	if (!zero_type (up->members[args->name]))
	  RXML.parse_error ("Cannot handle several members "
			    "with the same name.\n");
	up->members[args->name] = params[0];
	result = RXML.nil;
	return 0;
      }
    }
  }

  RXML.TagSet struct_tags = RXML.TagSet (this_module(), "xml-rpc-call/struct",
					 ({TagMember()}));

  class TagStruct
  {
    inherit RXML.Tag;
    constant name = "struct";
    constant flags = RXML.FLAG_DONT_RECOVER;
    class Frame
    {
      inherit RXML.Frame;
      RXML.TagSet local_tags = struct_tags;
      mapping(string:mixed) members = ([]);
      array do_return (RequestID id)
      {
	up->params += ({members});
	result = RXML.nil;
	return 0;
      }
    }
  }

  RXML.TagSet param_tags = RXML.TagSet (this_module(), "xml-rpc-call",
					({TagString(),
					  TagInt(),
					  TagFloat(),
					  TagIsoDateTime(),
					  TagArray(),
					  TagStruct(),
					}));

  class Frame
  {
    inherit RXML.Frame;
    RXML.TagSet local_tags = param_tags;
    array params = ({});

    void format_response (array res, String.Buffer buf)
    {
      foreach (res, mixed val) {
	if (stringp (val))
	  buf->add ("<string>", Roxen.html_encode_string (val), "</string>\n");
	else if (intp (val))
	  buf->add ("<int>", (string) val, "</int>\n");
	else if (floatp (val))
	  buf->add ("<float>", val, "</float>\n");
	else if (arrayp (val)) {
	  buf->add ("<array>\n");
	  format_response (val, buf);
	  buf->add ("</array>\n");
	}
	else if (mappingp (val)) {
	  buf->add ("<struct>\n");
	  foreach (val; string name; mixed val) {
	    buf->add ("<member name='",
		      Roxen.html_encode_string (name), "'>\n");
	    format_response (({val}), buf);
	    buf->add ("</member>\n");
	  }
	  buf->add ("</struct>\n");
	}
	else {			// Gotta be a Calendar object.
	  // Format this to be compatible with the iso-time attribute
	  // to the <date> tag.
	  buf->add ("<iso-date-time>", val->format_time(),
		    "</iso-date-time>\n");
	}
      }
    }

    array do_return (RequestID id)
    {
      if (!query ("insert_href"))
	RXML.run_error ("This tag is disabled.\n");

      // FIXME: Should provide a way to avoid having the href in the
      // rxml pages since it might contain user and password.

      Protocols.XMLRPC.Client client =
	Protocols.XMLRPC.Client (args->href);
      array|Protocols.XMLRPC.Fault res;

      if (mixed err = catch (res = client[args->method] (@params)))
	RXML.run_error ("Failed to make XML-RPC call %O: %s",
			args->method, describe_error (err));

      if (objectp (res)) {
	if (string var = args["fault-code"])
	  RXML_CONTEXT->user_set_var (var, res->fault_code);
	if (string var = args["fault-string"])
	  RXML_CONTEXT->user_set_var (var, res->fault_string);
	result = RXML.nil;
	RXML_CONTEXT->misc[" _ok"] = 0;
	return 0;
      }

      String.Buffer buf = String.Buffer();
      format_response (res, buf);
      result = buf->get();
      RXML_CONTEXT->misc[" _ok"] = 1;
      return 0;
    }
  }
}

string container_recursive_output (string tagname, mapping args,
				  string contents, RequestID id)
// This tag only exists for historical amusement.
{
  int limit;
  array(string) inside, outside;
  if (id->misc->recout_limit)
  {
    limit = id->misc->recout_limit - 1;
    inside = id->misc->recout_outside, outside = id->misc->recout_inside;
  }
  else
  {
    limit = (int) args->limit || 100;
    inside = args->inside ? args->inside / (args->separator || ",") : ({});
    outside = args->outside ? args->outside / (args->separator || ",") : ({});
    if (sizeof (inside) != sizeof (outside))
      RXML.parse_error("'inside' and 'outside' replacement sequences "
		       "aren't of same length.\n");
  }

  if (limit <= 0) return contents;

  int save_limit = id->misc->recout_limit;
  string save_inside = id->misc->recout_inside, save_outside = id->misc->recout_outside;

  id->misc->recout_limit = limit;
  id->misc->recout_inside = inside;
  id->misc->recout_outside = outside;

  string res = Roxen.parse_rxml (
    parse_html (
      contents,
      (["recurse": lambda (string t, mapping a, string c) {return c;}]),
      ([]),
      "<" + tagname + ">" + replace (contents, inside, outside) +
      "</" + tagname + ">"),
    id);

  id->misc->recout_limit = save_limit;
  id->misc->recout_inside = save_inside;
  id->misc->recout_outside = save_outside;

  return res;
}

class TagSprintf {
  inherit RXML.Tag;
  constant name = "sprintf";

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      array(mixed) in;
      if(args->split)
	in=(content || "")/args->split;
      else
	in=({content || ""});

      array f=((args->format-"%%")/"%")[1..];
      if(sizeof(in)!=sizeof(f))
	RXML.run_error("Indata hasn't the same size as format data (%d, %d).\n", sizeof(in), sizeof(f));

      // Do some casting
      for(int i; i<sizeof(in); i++) {
	int quit;
	foreach(f[i]/1, string char) {
	  if(quit) break;
	  switch(char) {
	  case "d":
	  case "u":
	  case "o":
	  case "x":
	  case "X":
	  case "c":
	  case "b":
	    in[i]=(int)in[i];
	    quit=1;
	    break;
	  case "f":
	  case "g":
	  case "e":
	  case "G":
	  case "E":
	  case "F":
	    in[i]=(float)in[i];
	    quit=1;
	    break;
	  case "s":
	  case "O":
	  case "n":
	  case "t":
	    quit=1;
	    break;
	  }
	}
      }

      result=sprintf(args->format, @in);
      return 0;
    }
  }
}

class TagSscanf {
  inherit RXML.Tag;
  constant name = "sscanf";

  RXML.Type content_type = RXML.t_any_text (RXML.PXml);
  array(RXML.Type) result_types =
    compat_level < 5.2 ? ::result_types : ({RXML.t_nil}); // No result.

  mapping(string:RXML.Type) req_arg_types = ([ "variables" : RXML.t_text(RXML.PEnt),
					       "format"    : RXML.t_text(RXML.PEnt)
  ]);
  mapping(string:RXML.Type) opt_arg_types = ([ "return"    : RXML.t_text(RXML.PEnt),
					       "scope"     : RXML.t_text(RXML.PEnt)
  ]);

  class Frame {
    inherit RXML.Frame;

    string do_return(RequestID id) {
      array(string) vars=args->variables/",";
      vars=map(vars, String.trim_all_whites);
      array(string) vals;
      mixed err = catch {
	  vals = array_sscanf(content || "", args->format);
	};
      if(err) {
        string msg = "Unknown error.\n";
        if(arrayp(err) && sizeof(err) && stringp(err[0]))
          msg = err[0];
        RXML.run_error(msg);
      }
      if(sizeof(vars)<sizeof(vals))
	RXML.run_error("Too few variables.\n");

      int var=0;
      foreach(vals, string val)
	RXML.user_set_var(vars[var++], val, args->scope);

      if(args->return)
	RXML.user_set_var(args->return, sizeof(vals), args->scope);
      return 0;
    }
  }
}

class TagBaseName {
  inherit RXML.Tag;
  constant name = "basename";

  class Frame 
  {
    inherit RXML.Frame;

    string do_return(RequestID id) 
    {
      mixed err = catch {
	result = basename(replace(content || "", "\\", "/"));
      };
      if(err) 
      {
        string msg = "Unknown error.\n";
        if(arrayp(err) && sizeof(err) && stringp(err[0]))
          msg = err[0];
        RXML.run_error(msg);
      }

      return 0;
    }
  }
}

class TagDirName {
  inherit RXML.Tag;
  constant name = "dirname";

  class Frame 
  {
    inherit RXML.Frame;

    string do_return(RequestID id) 
    {
      mixed err = catch {
	result = dirname(replace(content || "", "\\", "/"));
      };
      if(err) 
      {
        string msg = "Unknown error.\n";
        if(arrayp(err) && sizeof(err) && stringp(err[0]))
          msg = err[0];
        RXML.run_error(msg);
      }

      return 0;
    }
  }
}

class TagDice {
  inherit RXML.Tag;
  constant name = "dice";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    string do_return(RequestID id) {
      NOCACHE();
      if(!args->type) args->type="D6";
      args->type = replace( args->type, "T", "D" );
      int value;
      args->type=replace(args->type, "-", "+-");
      foreach(args->type/"+", string dice) {
	if(has_value(dice, "D")) {
	  if(dice[0]=='D')
	    value+=random((int)dice[1..])+1;
	  else {
	    array(int) x=(array(int))(dice/"D");
	    if(sizeof(x)!=2)
	      RXML.parse_error("Malformed dice type.\n");
	    value+=x[0]*(random(x[1])+1);
	  }
	}
	else
	  value+=(int)dice;
      }

      if(args->variable)
	RXML.user_set_var(args->variable, value, args->scope);
      else
	result=(string)value;

      return 0;
    }
  }
}

class TagEmitKnownLangs
{
  inherit RXML.Tag;
  constant name = "emit", plugin_name = "known-langs";
  array get_dataset(mapping m, RequestID id)
  {
    return map(roxenp()->list_languages(),
	       lambda(string id)
	       {
		 object language = roxenp()->language_low(id);
		 string eng_name = language->id()[1];
		 if(eng_name == "standard")
		   eng_name = "english";
		 return ([ "id" : id,
			 "name" : language->id()[2],
		  "englishname" : eng_name ]);
	       });
  }
}

class TagFormatNumber
{
  inherit RXML.Tag;
  constant name  = "format-number";

  mapping(string:RXML.Type) req_arg_types = 
    ([ /* "value"                : RXML.t_text(RXML.PEnt), */
       "pattern"              : RXML.t_text(RXML.PEnt)
    ]);
  mapping(string:RXML.Type) opt_arg_types = 
    ([ "decimal-separator"    : RXML.t_text(RXML.PEnt),
       "group-separator"      : RXML.t_text(RXML.PEnt)
    ]); 

  class Frame {
    inherit RXML.Frame;

    string do_return(RequestID req_id) {
      //constant PERCENT   = 0x01;
      //constant PER_MILLE = 0x02;
      constant TRUE      = 0x01;
      constant FALSE     = 0x00;
      constant FRAC_PART = 1;
      constant INT_PART  = 0;
      
      string grp_sep     = ",";
      string dec_sep     = "."; 
      if (args["group-separator"])
      {
	grp_sep = args["group-separator"];
      }
      if (args["decimal-separator"])
      {
	dec_sep = args["decimal-separator"];
      }

      // Get rid of white-space.
      content = replace(content,
			({ " ", "\t", "\r", "\n" }),
			({ "", "", "", "" }));

      // Parse the number.
      string sgn = "", int_part = "", frac_part = "", rest = "";
      if (sscanf(content, "%[-+]%[0-9]%s", sgn, int_part, rest) <= 1) {
	RXML.parse_error("No number to be formatted was given.");
      }
      sscanf(rest, ".%[0-9]%s", frac_part, rest);

      if (!(sizeof(sgn/"-") & 1)) int_part = "-" + int_part;

      // FIXME: Consider checking whether rest contains junk.

      /* We need to break down the pattern, first by ";" and make sure that ";"
         is not an escaped character. */
      array(string) temp_pattern = args->pattern / ";";
      array(string) pattern = ({ "", "" });
      int is_pos = TRUE;
      for (int i = 0; i < sizeof(temp_pattern); i++)
      {
	pattern[is_pos] += temp_pattern[i];
	if (sizeof(pattern[is_pos]) > 0 &&
	    pattern[is_pos][sizeof(pattern[is_pos]) - 1] == "'"[0])
	{
	  pattern[is_pos][sizeof(pattern[is_pos]) - 1] = ";"[0];
	}
	else if (is_pos)
	{
	  is_pos = FALSE;
	}
      }

      /* Now that we have extracted the patterns for positive and negative 
         numbers, we can reuse the is_pos flag to reflect which pattern we
	 should use. */
      if (has_prefix(int_part, "-") && sizeof(pattern[0]) > 0)
      {
	is_pos = FALSE;
	// Trim away the minus sign.
	int_part = int_part[1..];
      }
      else if (sizeof(pattern[1]) > 0)
      {
	is_pos = TRUE;
      }
      else
      {
	RXML.parse_error("The value was positive but no pattern " +
			 "for positive values was defined.\n");
      }
      
      // Now do the same thing as above to find the fraction delimiter.
      temp_pattern = pattern[is_pos] / ".";
      pattern = ({"", ""});
      int is_frac = FALSE;

      pattern[INT_PART] = temp_pattern[0];
      if (sizeof(pattern[INT_PART]) > 0 &&
	  pattern[INT_PART][-1] == "'"[0])
      {
	pattern[INT_PART][sizeof(pattern[INT_PART]) - 1] = "."[0];
      }
      else
      {
	is_frac = TRUE;
      }

      if (sizeof(temp_pattern) > 1)
      {
	for (int i = 1; i < sizeof(temp_pattern); i++)
	{
	  pattern[is_frac] += temp_pattern[i];
	  if (sizeof(pattern[is_frac]) > 0 &&
	      pattern[is_frac][-1] == "'"[0])
	  {
	    pattern[is_frac][-1] = "."[0];
	  }
	  else if (!is_frac)
	  {
	    is_frac = TRUE;
	  }
	  else if (i < (sizeof(temp_pattern) - 1))
	  {
	    pattern[is_frac] += ".";
	  }
	}
      }

      // Handle percent and per-mille
      int log_ten = 0;
      if (search(pattern[FRAC_PART], "%") >= 0 ||
	  search(pattern[INT_PART], "%") >= 0)
      {
	log_ten = 2;
      }
      else if (search(pattern[FRAC_PART], "\x2030") >= 0 ||
	       search(pattern[INT_PART], "\x2030") >= 0)
      {
	log_ten = 3;
      }

      for (int i = log_ten; i > 0; i--)
      {
	if (frac_part != "")
	{
	  int_part += frac_part[0..0];
	  frac_part = frac_part[1..];
	}
        else 
	{
	  int_part += "0";
	}
      }

      // Trim away leading zeros
      sscanf(int_part, "%*[0]%s", int_part);
      if (int_part == "") int_part = "0";

      // Start with the fractional part.
      int val_length     = strlen(frac_part);
      int ptn_length     = strlen(pattern[FRAC_PART]);
      int vi             = 0;
      string frac_result = "";
      
      foreach(pattern[FRAC_PART]/1, string s)
      {
	switch(s)
	{
	  case "'":
	    break;
	  case "#":
	    if (vi < val_length)
	    {
	      frac_result += frac_part[vi..vi];
	      vi++;
	    }
	    break;
	  case "0":
	    if (vi < val_length)
	    {
	      frac_result += frac_part[vi..vi];
	      vi++;
	    } 
	    else
	    {
	      frac_result += "0";
	    }
	    break;
	  default:
	    frac_result += s;
	}
      }

      // Round the last digit.    
      if (vi < val_length && (frac_part[vi] > '5' ||
			      (frac_part[vi] == '5' && is_pos)))
      {
	vi = sizeof(frac_result);
	while(vi > 0) {
	  if (frac_result[vi-1] == '9') {
	    // Carry.
	    vi--;
	    frac_result[vi] = '0';
	    continue;
	  }
	  frac_result[vi-1] += 1;
	  break;
	}
	if (!vi)
	{
	  int_part = (string)(((int)int_part) + 1);
	}
      }
      
      // Now for the integral part. We traverse it in reverse.
      val_length        = strlen(int_part);
      ptn_length        = strlen(pattern[INT_PART]);
      vi                = 0;
      int num_wid       = 0; 
      string rev_val    = reverse(int_part);
      string int_result = "";
      string minus_sign = "";
      foreach(reverse(pattern[INT_PART])/1, string s)
      {
	switch(s)
	{
	  case "'":
	    break;
	  case "#":
	    if (vi < val_length)
	    {
	      int_result += rev_val[vi..vi];
	      vi++;
	    }
	    if (num_wid <= 0)
	    {
	      num_wid--;
	    }
	    break;
	  case "0":
	    if (vi < val_length)
	    {
	      int_result += rev_val[vi..vi];
	      vi++;
	    } 
	    else
	    {
	      int_result += "0";
	    }
	    if (num_wid <= 0)
	    {
	      num_wid--;
	    }
	    break;
	  case ",":
	    if (num_wid <= 0)
	    {
	      num_wid *= -1;
	    }
	    if (vi < val_length)
	    {
	      int_result += grp_sep;
	    }
	    break;
	  case "-":
	    if (is_pos)
	    {
	      int_result += s;
	    }
	    else if (minus_sign = "")
	    {
	      minus_sign = "-";
	    }
	    break;
	  case "%":
	  case "\x2030":
	    frac_result = s;
	    break;
	  default:
	    int_result += s;
	}
      }
      for (;vi < val_length;vi++)
	{
	  if (num_wid > 0 && vi%num_wid == 0)
	  {
	    int_result += grp_sep;
	  }
	  int_result += rev_val[vi..vi];
      }

      if (strlen(frac_result) == 0)
      {
	result += minus_sign + reverse(int_result);
      }
      else if (frac_result[0..0] == "%" ||
	       frac_result[0..0] == "\x2030")
      {
	result += minus_sign + reverse(int_result) + frac_result[0..0];
      }
      else 
      {
	result += minus_sign + reverse(int_result) + dec_sep + frac_result;
      }
    }
  } 
}



TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
  "dice":#"<desc type='tag'><p><short>
 Simulates a D&amp;D style dice algorithm.</short></p></desc>

<attr name='type' value='string' default='D6'><p>
 Describes the dices. A six sided dice is called 'D6' or '1D6', while
 two eight sided dices is called '2D8' or 'D8+D8'. Constants may also
 be used, so that a random number between 10 and 20 could be written
 as 'D9+10' (excluding 10 and 20, including 10 and 20 would be 'D11+9').
 The character 'T' may be used instead of 'D'.</p>
</attr>",

  "insert#href":#"<desc type='plugin'><p><short>
 Inserts the contents at that URL.</short> This function has to be
 enabled in the <module>Additional RXML tags</module> module in the
 Roxen WebServer configuration interface. The page download will block
 the current thread, and if running unthreaded, the whole server.</p>
 <p><b>Note:</b> Requests are made in HTTP/1.0.</p></desc>

<attr name='href' value='string'><p>
 The URL to the page that should be inserted.</p>
</attr>

<attr name='nocache' value='string'><p>
 If provided the resulting page will get a zero cache time in the RAM cache.
 The default time is up to 60 seconds depending on the cache limit imposed by
 other RXML tags on the same page.</p>
</attr>

<attr name='method' value='string' default='GET'><p>
 Method to use when requesting the page. GET or POST.</p>
</attr>

<attr name='silent' value='string' ><p>
 Do not print any error messages.</p>
</attr>

<attr name='status-variable' value='variable' ><p>
  Prints the return code for the request in the specified varible.</p>
  <ex-box>
    <insert href='http://www.somesite.com/news/' status-variable='var.status-code' />
  </ex-box>
</attr>

<attr name='timeout' value='int' ><p>
 Timeout for the request in seconds. This is not available if your run the server without threads.</p>
<ex-box>
<insert href='http://www.somesite.com/news/' silent='silent' timeout='10' />
<else>
   Site did not respond within 10 seconds. Try again later.
</else>
</ex-box>
</attr>

<attr name='post-variables' value='\"variable=rxml variable[,variable2=rxml variable2,...]\"'><p>
 Comma separated list of variables to send in a POST request.</p>
<ex-box>
<insert href='http://www.somesite.com/news/' 
         method='POST' post-variables='action=var.action,data=form.data' />
</ex-box> 
</attr>

<attr name='post-data' value='string'><p>
 String to send as the body content of the POST request. Mutually exclusive with the 'post-variables' argument.</p>
<ex-box>
<insert href='http://www.somesite.com/webservice/' 
         method='POST' post-data='&var.data;' />
</ex-box> 
</attr>

<attr name='request-headers' value='\"header=value[,header2=value2,...]\"'><p>
 Comma separated list of extra headers to send in the request.</p>
</attr>

<attr name='ignore-unknown-ce' value='int'><p>
  If set, unknown Content-Encoding headers in the response will be ignored. Some
servers specify the character set (e.g. 'UTF-8') in the Content-Encoding header
in addition to the Content-Type header. (The real purpose of the 
Content-Encoding header is described here: 
http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.11)</p>
</attr>
",

 "xml-rpc-call":
 #"<desc type='cont'><p><short>
 Perform a synchronous XML-RPC call.</short> The content specifies the
 call parameters, and the result of the tag is the return parameters
 (if the call is successful). The result is expressed using the same
 kind of tags that specifies the parameters (this is a more compact
 and rxml-friendly format than the actual XML-RPC form; see
 below).</p>

 <p>If the call fails on a high level, i.e. if the remote side returns
 a fault, then the result is empty and the fault code and string gets
 stored in the variables specified by the \"fault-code\" and
 \"fault-string\" attributes (if they exist).</p>

 <p>If the call fails on a low level, i.e. connection error or due to
 some kind of syntactic error in the result, then an RXML run error is
 thrown.</p>

 <p>The boolean status is set to true if the call is successful, false
 otherwise.</p>

 <p>Example:</p>

 <ex-box><set variable='var.xml-rpc-result'>
  <xml-rpc-call href='http://xmlrpchost.foo.com/xmlrpc/'
		method='service.doSomething'
		fault-code='var.fault-code'
		fault-string='var.fault-string'>
    <string>abc</string>
    <if variable='var.rpc-use-float'>
      <float>3.14159</float>
    </if>
    <else>
      <int>3</int>
    </else>
    <array>
      <int>1</int>
      <string>&amp;page.path;</string>
    </array>
    <struct>
      <member name='x'><float>-37.45</float></member>
      <member name='y'><float>0.055</float></member>
    </struct>
    <iso-date-time><date type='iso'/></iso-date-time>
  </xml-rpc-call>
</set>
<then>
  <p>XML-RPC call successful: &var.xml-rpc-result;</p>
</then>
<else>
  <p>XML-RPC call failed: &var.fault-string; (code &var.fault-code;)</p>
</else></ex-box>
</desc>

<attr name='href' value='URL' required='yes'>
 <p>URL to the server to make the call to.</p>
</attr>

<attr name='method' value='string' required='yes'>
 <p>The name of the method.</p>
</attr>

<attr name='fault-code' value='variable'>
 <p>If this attribute is present, the variable it specifies will
 receive the fault code if the call fails.</p>
</attr>

<attr name='fault-string' value='variable'>
 <p>If this attribute is present, the variable it specifies will
 receive the fault string if the call fails.</p>
</attr>",
    // FIXME: Document content tags.


"sscanf":#"<desc type='cont'><p><short>
 Extract parts of a string and put them in other variables.</short> Refer to
 the sscanf function in the Pike reference manual for a complete
 description.</p>
</desc>

<attr name='format' value='pattern' required='required'><p>
The sscanf pattern.
</p>
</attr>

<attr name='variables' value='list' required='required'><p>
 A comma separated list with the name of the variables that should be set.</p>
<ex>
<sscanf variables='form.year,var.month,var.day'
format='%4d%2d%2d'>19771003</sscanf>
&form.year;-&var.month;-&var.day;
</ex>
</attr>

<attr name='scope' value='name' required='required'><p>
 The name of the fallback scope to be used when no scope is given.</p>
<ex>
<sscanf variables='year,month,day' scope='var'
 format='%4d%2d%2d'>19801228</sscanf>
&var.year;-&var.month;-&var.day;<br />
<sscanf variables='form.year,var.month,var.day'
 format='%4d%2d%2d'>19801228</sscanf>
&form.year;-&var.month;-&var.day;
</ex>
</attr>

<attr name='return' value='name'><p>
 If used, the number of successful variable 'extractions' will be
 available in the given variable.</p>
</attr>",

  "sprintf":#"<desc type='cont'><p><short>
 Prints out variables with the formating functions availble in the
 Pike function sprintf.</short> Refer to the Pike reference manual for
 a complete description.</p></desc>

<attr name='format' value='string'><p>
  The formatting string.</p>
</attr>

<attr name='split' value='charater'><p>
  If used, the tag content will be split with the given string.</p>
<ex>
<sprintf format='#%02x%02x%02x' split=','>250,0,33</sprintf>
</ex>
</attr>",

  "basename":#"<desc type='cont'><p><short>
Returns the last segment of a path.</short></p>
<p><ex><basename>/some/path/file.name</basename></ex></p>
</desc>",

  "dirname":#"<desc type='cont'><p><short>
Returns all but the last segment of a path. </short>Some example inputs and outputs:</p>
<p><ex>1 <dirname>/a/b</dirname><br/>
2 <dirname>/a/</dirname><br/>
3 <dirname>/a</dirname><br/>
4 <dirname>/</dirname><br/>
5 <dirname></dirname></ex></p>
</desc>",

  "format-number":#"<desc type='cont'><p><short>
Formats a number according to pattern passed as an argument. </short>
Useful for adding grouping and rounding numbers to a fixed number 
of fraction digit characters.
</p>
<p>
<ex><set variable='var.foo'>2318543.78</set>

<p><format-number pattern='0.000'>&var.foo;</format-number></p>

<p>
  <format-number pattern='#,###' 
		 group-separator=' '
		 decimal-separator=','>
    &var.foo;
  </format-number>
</p></ex>
</p>
<p>
  It's important that the guidelines for the pattern are followed. 
  Bad patterns will normally not cause an RXML-parse error, 
  instead <tag>format-number</tag> will try to format the number 
  according to the given pattern anyway.
</p>
<p>
  <tag>format-number</tag> does not handle infinity.
</p>
</desc>

<attr name='pattern' value='string' required='required'>
<p>
  The format pattern that dictates how the digits should be represented on
  screen.
</p>
<p>
  The following symbols are allowed:
</p>
<list type=\"dl\">
  <item name=\"# - Digit\">
    <p>
      Placeholder for optional digits. The number of # after the decimal 
      separator indicates number fo fraction digits to be shown.
    </p>
    <p>      
<ex><set variable='var.foo'>18543.78903</set>

<p><format-number pattern='###'>&var.foo;</format-number></p>
      
<p><format-number pattern='#.###'>&var.foo;</format-number></p></ex>
    </p>
  </item>
  <item name=\"0 - Zero Digit\">
    <p>
      Placeholder for required digits.
      If there are more digits required than given, the remaining positions
      will be filled with zeros. 
    </p>
    <p>
      0 should be placed to the right of # in the 
      pattern in the integral part and to the left of # in the fraction part.
      If they are not and there are less digits than #, the zeros will be 
      concatenated to the beginning of the integral part or the end of the
      fractional part giving unwanted results.
    </p>
    <p>
<ex><set variable='var.foo'>543.78</set>

<p><format-number pattern='#00.00'>&var.foo;</format-number></p>

<p><format-number pattern='0000.000'>&var.foo;</format-number></p>
</ex>
    </p>
  </item>
  <item name=\". - Decimal separator\">
    <p>
      Placeholder for decimal separator. If more than one are present then the
      leftmost will be used. And the remaining will be printed out \"as is\".
    </p>
    <p>
      The character used as decimal separator in the output can be changed 
      with attribute \"decimal-separator\".
    </p>
    <p>
<ex><set variable='var.foo'>543.789</set>
<p><format-number pattern='##.##'>&var.foo;</format-number></p>

<p>
  <format-number pattern='.######' decimal-separator=','>
    &var.foo;
  </format-number>
</p>
</ex>
    </p>
  </item>
  <item name=\", - Grouping separator\">
    <p>
      Placeholder for group separator. The character in output can be changed
      with attribute \"group-separator\".
    </p>
    <p>
<ex>
<p><format-number pattern='#,###'>1677518543</format-number></p>

<p><format-number pattern='#,###,###'>8543</format-number></p>
</ex>
    </p>
  </item>
  <item name=\"; - Pattern separator\">
  <p>
    Separates pattern for positive and negative result respectively. If more 
    than one ; is present, everything after the second one will be ignored.
  </p>
  <p>
<ex>
<p><format-number pattern='#,###.##;-#'>1000.50</format-number></p>
<p><format-number pattern='#,###.##;-#'>-1000.50</format-number></p>
</ex>
  </p>
  </item>
  <item name=\"% -  Percent\">
    <p>
      The number will be multiplied by 100 and a percent sign will be added
      to the output.
    </p>
    <p>
<ex>
<p><format-number pattern='#,###%'>10.50</format-number></p>

<p><format-number pattern='#.####%'>0.0003</format-number></p>
</ex>
    </p>
  </item>
  <item name=\"&#x2030; - Per-mille\">
    <p>
      The number will be multiplied by 1000 and a per-mille sign will be added
      to the output.
    </p>
    <p>
<ex>
<p><format-number pattern='##&#x2030;'>0.003</format-number></p>
</ex>
    </p>      
  </item>
  <item name=\"- - minus sign\">
    <p>
      Default negative prefix
    </p>
  </item>
  <item name=\"' - escape character\">
    <p>
      Can be used to escape characters that normally has another meaning.
    </p>
    <p>
<ex>
<p><format-number pattern=\"#'.###\">1255.34</format-number></p>
</ex>
    </p>
  </item>
</list>
</attr>

<attr name='decimal-separator' value='' default='.'>
  <p>
    A character to be used as decimal separator. Can be useful for european
    formatting.
  </p>
  <p>
<ex>
<p>
  <format-number pattern='###.##' decimal-separator=','>
    543.78
  </format-number>
</p>

<p>Even this attribute can be abused:</p>
<p>
  <format-number pattern='###.##' 
	         decimal-separator=' &lt;--integral part, fractional part--&gt; '>
    5023.643
  </format-number>
</p></ex>
  </p>
</attr>

<attr name='group-separator' value='' default=','>
  <p>
    A character to be used as group separator. Can be useful for european
    formatting.
  </p>
  <p>
<ex><set variable='var.foo'>20070901</set>
<p>
  <format-number pattern='#,###' group-separator='.'>
    &var.foo;
  </format-number>
</p>
<p>
  <format-number pattern='####,##,##' group-separator='-'>
    &var.foo; 
  </format-number>
</p>
</ex>
  </p>
</attr>",

"emit#known-langs":({ #"<desc type='plugin'><p><short>
 Outputs all languages partially supported by roxen for writing
 numbers, weekdays et c.</short>
 Outputs all languages partially supported by roxen for writing
 numbers, weekdays et c (for example for the number and date tags).
 </p>
</desc>

 <ex><emit source='known-langs' sort='englishname'>
  4711 in &_.englishname;: <number lang='&_.id;' num='4711'/><br />
</emit></ex>",
			([
			  "&_.id;":#"<desc type='entity'>
 <p>Prints the three-character ISO 639-2 id of the language, for
 example \"eng\" for english and \"deu\" for german.</p>
</desc>",
			  "&_.name;":#"<desc type='entity'>
 <p>The name of the language in the language itself, for example
 \"français\" for french.</p>
</desc>",
			  "&_.englishname;":#"<desc type='entity'>
 <p>The name of the language in English.</p>
</desc>",
			]) }),

#if 0
  // This applies to the old rxml 1.x parser. The doc for this tag is
  // here only for historical interest, to serve as a monument over
  // the quoting horrors that do_output_tag and its likes incurred.
  "recursive-output": #"\
<desc type='cont'>
  <p>This container provides a way to implement recursive output,
  which is mainly useful when you want to create arbitrarily nested
  trees from some external data, e.g. an SQL database. Put simply, the
  <tag>recurse</tag> tag is replaced by everything inside and
  including the <tag>recursive-output</tag> container. Although simple
  in theory, it tends to get a little bit messy in practice.</p>

  <p>To make it work you have to pay some attention to the parsing
  order of the involved tags. After the <tag>recursive-output</tag>
  container have replaced every <tag>recurse</tag> with itself, the
  whole thing is parsed again. Therefore, to make it terminate, you
  must always put the <tag>recurse</tag> inside a conditional
  container (typically an <tag>if</tag>) that does not preparse its
  contents.</p>

  <p>So far so good, but you'll almost always want to use some sort of
  output container, e.g. <tag>formoutput</tag> or
  <tag>sqloutput</tag>, together with this tag, which makes it
  slightly more complex due to the necessary treatment of the quote
  characters. Since the contents of <tag>recursive-output</tag> is
  expanded two levels at any time, each level needs its own set of
  quotes. To accomplish this, <tag>recursive-output</tag> can rotate
  two quote sets which are specified by the `inside' and `outside'
  arguments. Each time a <tag>recurse</tag> is replaced, every string
  in the `inside' set is replaced by the string in the corresponding
  position in the `outside' set, then the two sets trade places. Thus,
  you should put all quote characters you use inside
  <tag>recursive-output</tag> in the `inside' set and some other
  characters that doesn't clash with anything in the `outside' set.
  You might also have to quote the quote characters when writing these
  sets, which is done by doubling them.</p>
</desc>

<attr name='inside' value='string,...'><p>
  The list of quotes `inside' the container, to be replaced in with the
  `outside' set in every other round of recursion.</p>
</attr>

<attr name='outside' value='string,...'><p>
  The list of quotes `outside' the container, to be replaced in with
  the `inside' set in every other round of recursion.</p>
</attr>

<attr name='multisep' value='separator'><p>
  The given value is used as the separator between the strings in the
  two sets. It defaults to ','.</p>
</attr>

<attr name='limit' value='number'><p>
  Specifies the maximum nesting depth. As a safeguard it defaults to
  100.</p>
</attr>",
#endif

]);
#endif
