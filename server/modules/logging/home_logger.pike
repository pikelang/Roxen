// This is a roxen module. (c) Informationsvävarna AB 1996.

// This module log the accesses of each user in their home dirs, if
// they create a file named 'AccessLog' in that directory, and allow
// write access for roxen.

string cvs_version = "$Id: home_logger.pike,v 1.9 1997/08/12 06:32:25 per Exp $";
#include <module.h>
inherit "module";
inherit "roxenlib";


mixed register_module()
{
  return ({ MODULE_LOGGER,
	    "User logger",
	    ("This module log the accesses of each user in their home dirs, "
	     "if they create a file named 'AccessLog' (or whatever is configurated in the configuration interface) in that directory, and "
	     "allow write access for roxen."), ({}), 1 });
}

// Parse the logging format strings.
private inline string fix_logging(string s)
{
  string pre, post, c;
  sscanf(s, "%*[\t ]", s);
  s = replace(s, ({"\\t", "\\n", "\\r" }), ({"\t", "\n", "\r" }));
  while(s[0] == ' ') s = s[1..10000];
  while(s[0] == '\t') s = s[1..10000];
  while(sscanf(s, "%s$char(%d)%s", pre, c, post)==3)
    s=sprintf("%s%c%s", pre, c, post);
  while(sscanf(s, "%s$wchar(%d)%s", pre, c, post)==3)
    s=sprintf("%s%2c%s", pre, c, post);
  while(sscanf(s, "%s$int(%d)%s", pre, c, post)==3)
    s=sprintf("%s%4c%s", pre, c, post);
  if(!sscanf(s, "%s$^%s", pre, post))
    s+="\n";
  else
    s=pre+post;
  return s;
}

// Really write an entry to the log.
private void write_to_log( string host, string rest, string oh, function fun )
{
  int s;
  if(!host) host=oh;
  if(!stringp(host))
    host = "error:no_host";
  if(fun) fun(replace(rest, "$host", host));
}

// Logging format support functions.
nomask private inline string host_ip_to_int(string s)
{
  int a, b, c, d;
  sscanf(s, "%d.%d.%d.%d", a, b, c, d);
  return sprintf("%c%c%c%c",a, b, c, d);
}

nomask private inline string unsigned_to_bin(int a)
{
  return sprintf("%4c", a);
}

nomask private inline string unsigned_short_to_bin(int a)
{
  return sprintf("%2c", a);
}

nomask private inline string extract_user(string from)
{
  array tmp;
  if (!from || sizeof(tmp = from/":")<2)
    return "-";
  
  return tmp[0];      // username only, no password
}

mapping (string:string) log_format = ([]);

private void parse_log_formats()
{
  string b;
  array foo=query("LogFormat")/"\n";
  log_format = ([]);
  foreach(foo, b)
    if(strlen(b) && b[0] != '#' && sizeof(b/":")>1)
      log_format[(b/":")[0]] = fix_logging((b/":")[1..100000]*":");
}



string create()
{
  defvar("num", 5, "Maximum number of open user logfiles.", TYPE_INT|VAR_MORE,
	 "How many logfiles to keep open for speed (the same user often has "
	 " her files accessed many times in a row)");

  defvar("delay", 600, "Logfile garb timeout", TYPE_INT|VAR_MORE,
	 "After how many seconds should the file be closed?");

  defvar("block", 0, "Only log in userlog", TYPE_FLAG,
	 "If set, no entry will be written to the normal log.\n");

  defvar("LogFormat", 
 "404: $host $referer - [$cern_date] \"$method $resource $protocol\" 404 -\n"
 "500: $host ERROR - [$cern_date] \"$method $resource $protocol\" 500 -\n"
 "*: $host - - [$cern_date] \"$method $resource $protocol\" $response $length"
	 ,

	 "Logging Format", 
	 TYPE_TEXT_FIELD,
	 
	 "What format to use for logging. The syntax is:\n"
	 "<pre>"
	 "response-code or *: Log format for that response acode\n\n"
	 "Log format is normal characters, or one or more of the "
	 "variables below:\n"
	 "\n"
	 "\\n \\t \\r       -- As in C, newline, tab and linefeed\n"
	 "$char(int)     -- Insert the (1 byte) character specified by the integer.\n"
	 "$wchar(int)    -- Insert the (2 byte) word specified by the integer.\n"
	 "$int(int)      -- Insert the (4 byte) word specified by the integer.\n"
	 "$^             -- Supress newline at the end of the logentry\n"
	 "$host          -- The remote host name, or ip number.\n"
	 "$ip_number     -- The remote ip number.\n"
	 "$bin-ip_number -- The remote host id as a binary integer number.\n"
	 "\n"
	 "$cern_date     -- Cern Common Log file format date.\n"
       "$bin-date      -- Time, but as an 32 bit iteger in network byteorder\n"
	 "\n"
	 "$method        -- Request method\n"
	 "$resource      -- Resource identifier\n"
	 "$protocol      -- The protocol used (normally HTTP/1.0)\n"
	 "$response      -- The response code sent\n"
	 "$bin-response  -- The response code sent as a binary short number\n"
	 "$length        -- The length of the data section of the reply\n"
       "$bin-length    -- Same, but as an 32 bit iteger in network byteorder\n"
	 "$referer       -- the header 'referer' from the request, or '-'.\n"
      "$user_agent    -- the header 'User-Agent' from the request, or '-'.\n\n"
	 "$user          -- the name of the auth user used, if any\n"
	 "$user_id       -- A unique user ID, if cookies are supported,\n"
	 "                  by the client, otherwise '0'\n"
	 "</pre>");

  
  defvar("Logs", ({ "/~%s/" }), "Private logs", TYPE_STRING_LIST,
	 "These directories want their own log files."
	 "Either use a specific path, or a pattern, /foo/ will check "
         "/foo/AccessLog, /users/%s/ will check for an AccessLog in "
         "all subdirectories in the users directory. All filenames are "
         "in the virtual filesystem, not the physical one.\n");

  defvar("AccessLog", "AccessLog", "AccessLog filename", TYPE_STRING,
	 "The filename of the access log file.");
}


program CacheFile = class {
  inherit files.file;
  string file;
  int ready = 1, d, n;
  object next;
  object master;

  void move_this_to_tail();

  void timeout()
  {
    close();
    ready = 1;
    move_this_to_tail();
  }

  int open(string s, string|void mode)
  {
    int st;
    st = file::open(s, "wa");
    file = s;
    ready = !st;
    call_out(timeout, d);
    return st;
  }
  
  string status()
  {
    return ((ready?"Free (closed) cache file ("+n+").\n":"Open: "+file+"\n") +
	    (next?next->status():"")+"("+n+")");
  }

  void move_this_to_head()
  {
    object tmp, tmp2;
    
    tmp2 = tmp = master->cache_head;

    if(tmp == this_object()) return;

    master->cache_head = this_object();
    while(tmp && (tmp->next != this_object()))
      tmp = tmp->next;
    if(tmp)
      tmp->next = next;
    next = tmp2;
  }

  void move_this_to_tail()
  {
    object tmp;

    if(this_object() == master->cache_head)
    {
      master->cache_head = next;
      tmp = next;
    }
    else
    {
      tmp = master->cache_head;
      while(tmp->next != this_object())
	tmp = tmp->next;
      tmp->next = next;
    }

    // Now this_object() is removed.
    while (tmp->next)
      tmp = tmp->next;
    tmp->next = this_object();
    next = 0;
  }

  void write(string s)
  {
    move_this_to_head();
    remove_call_out(timeout);
    call_out(timeout, d);
    ::write(s);
  }

  void create(int num, int delay, object m)
  {
    n = num;
    d = delay;
    master = m;
    if(num > 1)
      next = object_program(this_object())( --num, delay, m );
  }

  void destroy()
  {
    if(next) destruct(next);
  }
};


object cache_head;

string start()
{
  object f;
  if(cache_head) destruct(cache_head);
  cache_head = CacheFile(QUERY(num), QUERY(delay), this_object());
  parse_log_formats();
}

static void do_log(mapping file, object request_id, function log_function)
{
  string a;
  string form;
  function f;

  if(!log_function) return;// No file is open for logging.

  if(!(form=log_format[(string)file->error]))
    form = log_format["*"];
  
  if(!form) return;
  
  form=replace(form, 
	       ({ 
		 "$ip_number", "$bin-ip_number", "$cern_date",
		 "$bin-date", "$method", "$resource", "$protocol",
		 "$response", "$bin-response", "$length", "$bin-length",
		 "$referer", "$user_agent", "$user", "$user_id",
	       }), ({
		 (string)request_id->remoteaddr,
		   host_ip_to_int(request_id->remoteaddr),
		   cern_http_date(time(1)),
		   unsigned_to_bin(time(1)),
		   (string)request_id->method,
		   http_encode_string(request_id->not_query+
				      (request_id->query?"?"+request_id->query:
				       "")),
		   (string)request_id->prot,
		   (string)(file->error||200),
		   unsigned_short_to_bin(file->error||200),
		   (string)(file->len>=0?file->len:"?"),
		   unsigned_to_bin(file->len),
		   (string)
		   (sizeof(request_id->referer)?request_id->referer[0]:"-"),
		   http_encode_string(sizeof(request_id->client)?request_id->client*" ":"-"),
		   extract_user(request_id->realauth),
		   (string)request_id->cookies->RoxenUserID,
		 }));
  
  if(search(form, "host") != -1)
    roxen->ip_to_host(request_id->remoteaddr, write_to_log, form,
		      request_id->remoteaddr, log_function);
  else
    log_function(form);
}


string status()
{
 if (!cache_head)
   start();
 if (!cache_head)
 {
   werror("logger.lpc->status(): cache_head = 0\n");
   return "Error";
 }
  return "Logfile cache status:\n<pre>\n" + cache_head->status() + "</pre>";
}

object find_cache_file(string f)
{
  if(!cache_head)
    start();
  
  object c = cache_head;
  do {
    if((c->file == f) && !c->ready)
      return c;

    if(c->ready)
    {
      if(c->open(f))
	return c;
      return 0;
    }
  } while(c->next && (c=c->next));

  c->close();
  if(c->open(f))
    return c;
  return 0;
}

mapping cached_homes = ([]);

string home(string of, object id)
{
  string l, f;
  foreach(QUERY(Logs), l)
  {
    if(!search(of, l))
    {
      if(cached_homes[l] && !(cached_homes[l]==-1 && id->pragma["no-cache"]))
	return (l=cached_homes[l])==-1?0:l;
      f=l;
      l=roxen->real_file(l+QUERY(AccessLog), id);
      if(l) cached_homes[f]=l;
      else cached_homes[f]=-1;
      return l;
    }
    else if(sscanf(of, l, f))
    {
      catch{f=sprintf(l,f);};
      if(cached_homes[f] && !(cached_homes[f]==-1 && id->pragma["no-cache"]))
	return (l=cached_homes[f])==-1?0:l;
      l=roxen->real_file(f+QUERY(AccessLog), id);
      if(l) cached_homes[f]=l;
      else cached_homes[f]=-1;
      return l;
    }
  }
}



inline string format_log(object id, mapping file)
{
  return sprintf("%s %s %s [%s] \"%s %s %s\" %s %s\n",
		 roxen->quick_ip_to_host(id->remoteaddr),
		 (string)(sizeof(id->referer)?id->referer*", ":"-"),
		 replace((string)(id->client?id->client*" ":"-")," ","%20"),
		 cern_http_date(id->time),
		 (string)id->method, (string)id->raw_url,
		 (string)id->prot,   (string)file->error,
		 (string)(file->len>=0?file->len:"?"));
}

mixed log(object id, mapping file)
{
  string s;
  object fnord;

  if((s = home(id->not_query, id)) && 
     (fnord=find_cache_file(s)))
    do_log(file,id,fnord->write);
  if(QUERY(block) && fnord)
    return 1;
}
