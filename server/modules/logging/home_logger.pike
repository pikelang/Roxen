#include <module.h>
inherit "module";
inherit "roxenlib";


mixed register_module()
{
  return ({ MODULE_LOGGER,
	    "User logger",
	    ("This module log the accesses of each user in their home dirs, "
	     "iff they create a file named 'AccessLog' in that directory, and "
	     "allow write access for roxen."), ({}), 1 });
}

string create()
{
  defvar("num", 5, "Maximum number of open user logfiles.", TYPE_INT,
	 "How many logfiles to keep open for speed (the same user often has "
	 " her files accessed many times in a row)");

  defvar("delay", 600, "Logfile garb timeout", TYPE_INT,
	 "After how many seconds should the file be closed?");

  defvar("block", 0, "Only log in userlog", TYPE_FLAG,
	 "If set, no entry will be written to the normal log.\n");
  
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
  inherit "/precompiled/file";
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

string home(string of, object id)
{
  string l, f;
  foreach(QUERY(Logs), l)
  {
    if(!search(of, l))
      return roxen->real_file(l, id);
    else if(sscanf(of, l, f)) 
      return roxen->real_file(sprintf(l, f), id);
  }
}

inline string format_log(object id, mapping file)
{
  return sprintf("%s %s %s [%s] \"%s %s %s\" %s %s\n",
		 roxen->quick_ip_to_host(id->remoteaddr),
		 (string)(id->referer?id->referer*", ":"-"),
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
  if((s = home(id->not_query, id)) && (fnord=find_cache_file(s+QUERY(AccessLog))))
    fnord->write(format_log(id, file));
  if(QUERY(block) && fnord)
    return 1;
}
