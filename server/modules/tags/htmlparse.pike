// This is a roxen module. Copyright © 1996 - 1998, Idonex AB.
//
// The main RXML parser. If this module is not added to a configuration,
// no RXML parsing will be done at all for .html files. 
// This module also maintains an
// accessed database, to be used by the <accessed> tag.
//
// It is in severe need of a cleanup in the code.
//
// This file *should* be split into multiple files, one with all
// 'USER' related tags, one with all CLIENT related tags, etc.
// 
// the only thing that should be in this file is the main parser.  

#define _stat defines[" _stat"]
#define _error defines[" _error"]
#define _extra_heads defines[" _extra_heads"]
#define _rettext defines[" _rettext"]
#define _ok     defines[" _ok"]

constant cvs_version="$Id: htmlparse.pike,v 1.170 1999/05/19 09:33:26 peter Exp $";
constant thread_safe=1;

function call_user_tag, call_user_container;

#include <config.h>
#include <module.h>

inherit "module";
inherit "roxenlib";

constant language = roxen->language;

int cnum=0;
mapping fton=([]);
int bytes;

object database, names_file;

// If the string 'w' match any of the patterns in 'a', return 1, else 0.
int _match(string w, array (string) a)
{
  string q;
  foreach(a, q)
    if(stringp(w) && stringp(q) && glob(q, w))
      return 1;
}

// Configuration interface fluff.
string comment()
{
  return query("toparse")*", ";
}

string status()
{
  return (bytes/1024 + " Kb parsed<br>"+
	  sizeof(fton)+" entries in the accessed database<br>");
}

private int ac_is_not_set()
{
  return !QUERY(ac);
}

private int ssi_is_not_set()
{
  return !QUERY(ssi);
}

void create(object c)
{
  defvar("Accesslog", 
	 GLOBVAR(logdirprefix)+
	 short_name(c?c->name:".")+"/Accessed", 
	 "Access log file", TYPE_FILE|VAR_MORE,
	 "In this file all accesses to files using the &lt;accessed&gt;"
	 " tag will be logged.", 0, ac_is_not_set);

  defvar("noparse", ({  }), "Extensions to accesscount",
          TYPE_STRING_LIST,
         "Always access-count all files ending with these extensions.");
 
  
  defvar("toparse", ({ "rxml","spml", "html", "htm" }), "Extensions to parse", 
	 TYPE_STRING_LIST, "Parse all files ending with these extensions.");

  defvar("parse_exec", 0, "Require exec bit on files for parsing",
	 TYPE_FLAG|VAR_MORE,
	 "If set, files has to have the execute bit (any of them) set "
	 "in order for them to be parsed by this module. The exec bit "
	 "is the one that is set by 'chmod +x filename'");
	 
  defvar("no_parse_exec", 0, "Don't Parse files with exec bit",
	 TYPE_FLAG|VAR_MORE,
	 "If set, no files with the exec bit set will be parsed. This is the "
	 "reverse of the 'Require exec bit on files for parsing' flag. "
	 "It is not very useful to set both variables.");
	 
  defvar("ac", 1, "Access log", TYPE_FLAG,
	 "If unset, the &lt;accessed&gt; tag will not work, and no access log "
	 "will be needed. This will save one file descriptor.");

  defvar("max_parse", 100, "Maximum file size", TYPE_INT|VAR_MORE,
	 "Maximum file size to parse, in Kilo Bytes.");

  defvar("ssi", 1, "SSI support: NSCA and Apache SSI support", 
	 TYPE_FLAG,
	 "If set, Roxen will parse NCSA / Apache server side includes.");

  defvar("exec", 0, "SSI support: execute command", 
	 TYPE_FLAG,
	 "If set and if server side include support is enabled, Roxen "
	 "will accept NCSA / Apache &lt;!--#exec cmd=\"XXX\" --&gt;. "
	 "Note that this will allow your users to execute arbitrary "
	 "commands.",
	 ssi_is_not_set);

#if constant(getpwnam)
  array nobody = getpwnam("nobody") || ({ "nobody", "x", 65534, 65534 });
#else /* !constant(getpwnam) */
  array nobody = ({ "nobody", "x", 65534, 65534 });
#endif /* constant(getpwnam) */

  defvar("execuid", nobody[2] || 65534, "SSI support: execute command uid",
	 TYPE_INT,
	 "UID to run NCSA / Apache &lt;!--#exec cmd=\"XXX\" --&gt; "
	 "commands with.",
	 ssi_is_not_set);

  defvar("execgid", nobody[3] || 65534, "SSI support: execute command gid",
	 TYPE_INT,
	 "GID to run NCSA / Apache &lt;!--#exec cmd=\"XXX\" --&gt; "
	 "commands with.",
	 ssi_is_not_set);

  defvar("close_db", 1, "Close the database if it is not used",
	 TYPE_FLAG|VAR_MORE,
	 "If set, the accessed database will be closed if it is not used for "
	 "8 seconds");
}

static string olf; // Used to avoid reparsing of the accessed index file...
static mixed names_file_callout_id;
inline void open_names_file()
{
  if(objectp(names_file)) return;
  remove_call_out(names_file_callout_id);
  names_file=open(QUERY(Accesslog)+".names", "wrca");
  names_file_callout_id = call_out(destruct, 1, names_file);
}

#ifdef THREADS
object db_lock = Thread.Mutex();
#endif /* THREADS */

static void close_db_file(object db)
{
#ifdef THREADS
  mixed key = db_lock->lock();
#endif /* THREADS */
  if (db) {
    destruct(db);
  }
}

static mixed db_file_callout_id;
inline mixed open_db_file()
{
  mixed key;
#ifdef THREADS
  catch { key = db_lock->lock(); };
#endif /* THREADS */
  if(objectp(database)) return key;
  if(!database)
  {
    if(db_file_callout_id) remove_call_out(db_file_callout_id);
    database=open(QUERY(Accesslog)+".db", "wrc");
    if (!database) {
      throw(({ sprintf("Failed to open \"%s.db\". "
		       "Insufficient permissions or out of fd's?\n",
		       QUERY(Accesslog)), backtrace() }));
    }
    if (QUERY(close_db)) {
      db_file_callout_id = call_out(close_db_file, 9, database);
    }
  }
  return key;
}

void start(int q, object c)
{
  mixed tmp;
  if(!c) return;
  call_user_container = c->parse_module->call_user_container;
  call_user_tag = c->parse_module->call_user_tag;
  define_API_functions();
  
  if(!QUERY(ac))
  {
    if(database)  destruct(database);
    if(names_file) destruct(names_file);
    return;
  }

  if(olf != QUERY(Accesslog))
  {
    olf = QUERY(Accesslog);
    mkdirhier(query("Accesslog"));
    if(names_file=open(olf+".names", "wrca"))
    {
      cnum=0;
      tmp=parse_accessed_database(names_file->read(0x7ffffff));
      fton=tmp[0];
      cnum=tmp[1];
      names_file = 0;
    }
  }
}

static int mdc;
int main_database_created()
{
  if(!QUERY(ac)) return -1;

  if(!mdc)
  {
    mixed key = open_db_file();
    database->seek(0);
    sscanf(database->read(4), "%4c", mdc);
    return mdc;
  }
  return mdc;
}

int database_set_created(string file, void|int t)
{
  int p;

  if(!QUERY(ac)) return -1;

  p=fton[file];
  if(!p) return 0;
  mixed key = open_db_file();
  database->seek((p*8)+4);
  return database->write(sprintf("%4c", t||time(1)));
}

int database_created(string file)
{
  int p,w;

  if(!QUERY(ac)) return -1;

  p=fton[file];
  if(!p) return main_database_created();
  mixed key = open_db_file();
  database->seek((p*8)+4);
  sscanf(database->read(4), "%4c", w);
  if(!w)
  {
    w=main_database_created();
    database_set_created(file, w);
  }
  return w;
}


int query_num(string file, int count)
{
  int p, n;
  string f;

  if(!QUERY(ac)) return -1;

  mixed key = open_db_file();

  // if(lock) lock->aquire();
  
  if(!(p=fton[file]))
  {
    if(!cnum)
    {
      database->seek(0);
      database->write(sprintf("%4c", time(1)));
    }
    fton[file]=++cnum;
    p=cnum;

//  perror(file + ": New entry.\n");
    open_names_file();
//  perror(file + ": Created new entry.\n");
    names_file->write(file+":"+cnum+"\n");

    database->seek(p*8);
    database->write(sprintf("%4c", 0));
    database_set_created(file);
  }
  if(database->seek(p*8) > -1)
  {
    sscanf(database->read(4), "%4c", n);
//  perror("Old count: " + n + "\n");
    if (count) 
    { 
//    perror("Adding "+count+" to it..\n");
      n+=count; 
      database->seek(p*8);
      database->write(sprintf("%4c", n)); 
    }
    //lock->free();
    return n;
  } 
//perror("Seek failed\n");
  //lock->free();
  return 0;
}

array register_module()
{
  return ({ MODULE_FILE_EXTENSION|MODULE_PARSER, 
	    "RXML parser", 
	    ("This module adds a lot of RXML tags, it also handles the "
	     "mapping from .html to the rxml parser, and the "
	     "database for the &lr;accessed&gt; tag"), ({}), 1 });
}

array(string) query_file_extensions() 
{ 
  return query("toparse") + query("noparse"); 
}

mapping handle_file_extension( object file, string e, object id)
{
  string to_parse;
  mapping defines = id->misc->defines || ([]);
  array stat = defines[" _stat"] || id->misc->stat || file->stat();
  id->misc->defines = defines;
  if(search(QUERY(noparse),e)!=-1)
  {
    query_num(id->not_query, 1);
    defines->counted = "1";
    if(search(QUERY(toparse),e)==-1)  /* Parse anyway */
      return 0;
  }
  if(QUERY(parse_exec) &&   !(stat[0] & 07111)) return 0;
  if(QUERY(no_parse_exec) && (stat[0] & 07111)) return 0;

  id->misc->defines[" _stat"] = stat;
  bytes += strlen(to_parse = file->read());
  return http_rxml_answer( to_parse, id, file, "text/html" );
}

/* standard roxen tags */

string tagtime(int t,mapping m)
{
  string s;
  mixed eris;
  string res;

  if (m->adjust) t+=(int)m->adjust;

  if (m->part)
  {
    string sp;
    if(m->type == "ordered")
    {
      m->type="string";
      sp = "ordered";
    }

    switch (m->part)
    {
     case "year":
      return number2string((int)(localtime(t)->year+1900),m,
			   language(m->lang, sp||"number"));
     case "month":
      return number2string((int)(localtime(t)->mon+1),m,
			   language(m->lang, sp||"month"));
     case "day":
     case "wday":
      return number2string((int)(localtime(t)->wday+1),m,
			   language(m->lang, sp||"day"));
     case "date":
     case "mday":
      return number2string((int)(localtime(t)->mday),m,
			   language(m->lang, sp||"number"));
     case "hour":
      return number2string((int)(localtime(t)->hour),m,
			   language(m->lang, sp||"number"));
     case "min":
     case "minute":
      return number2string((int)(localtime(t)->min),m,
			   language(m->lang, sp||"number"));
     case "sec":
     case "second":
      return number2string((int)(localtime(t)->sec),m,
			   language(m->lang, sp||"number"));
     case "yday":
      return number2string((int)(localtime(t)->yday),m,
			   language(m->lang, sp||"number"));
     default: return "";
    }
  } else if(m->type) {
    switch(m->type)
    {
     case "iso":
      eris=localtime(t);
      return sprintf("%d-%02d-%02d", (eris->year+1900),
		     eris->mon+1, eris->mday);

     case "discordian":
     case "disc":
#if efun(discdate)
      eris=discdate(t);
      res=eris[0];
      if(m->year)
	res += " in the YOLD of "+eris[1];
      if(m->holiday && eris[2])
	res += ". Celebrate "+eris[2];
      return res;
#else
      return "Discordian date support disabled";
#endif
     case "stardate":
     case "star":
#if efun(stardate)
      return (string)stardate(t, (int)m->prec||1);
#else
      return "Stardate support disabled";
#endif
     default:
    }
  }
  s=language(m->lang, "date")(t,m);
  if (m->upper) s=upper_case(s);
  if (m->lower) s=lower_case(s);
  if (m->cap||m->capitalize) s=capitalize(s);
  return s;
}

string tag_date(string q, mapping m, object id)
{
  int t=(int)m->unix_time || time(1);
  if(m->day)    t += (int)m->day * 86400;
  if(m->hour)   t += (int)m->hour * 3600;
  if(m->minute) t += (int)m->minute * 60;
  if(m->min)    t += (int)m->min * 60;
  if(m->sec)    t += (int)m->sec;
  if(m->second) t += (int)m->second;

  if(!(m->brief || m->time || m->date))
    m->full=1;

  if(!m->date)
  {
    if(!m->unix_time)
      NOCACHE();
  } else
    CACHE(60); // One minute is good enough.

  return tagtime(t,m);
}

inline string do_replace(string s, mapping (string:string) m)
{
  return replace(s, indices(m), values(m));
}


constant permitted = ({ "1", "2", "3", "4", "5", "6", "7", "8", "9",
                        "x","a","b","c,","d","e","f", "n", "t", "\""
                        "X","A","B","C,","D","E","F", "l", "o",
                        "<",">", "=", "0", "-", "*", "+","/", "%", 
                        "&", "|", "(", ")" });

string sexpr_eval(string what)
{
  array q = what/"";
  what = "mixed foo(){ return "+(q-(q-permitted))*""+";}";
  return (string)compile_string( what )()->foo();
}

array(string) tag_scope(string tag, mapping m, string contents, object id)
{
  mapping old_variables = id->variables;
  id->variables = ([]);
  if (m->extend)
    id->variables += old_variables;
  contents = parse_rxml(contents, id);
  id->variables = old_variables;
  return ({ contents });
}

string tag_set( string tag, mapping m, object id )
{
  if(m->help) 
    return ("<b>&lt;unset variable=...&gt;</b>: Unset the variable specified "
	    "by the 'variable' argument");
  if (m->variable)
  {

    if (m->value)
      // Set variable to value.
      id->variables[ m->variable ] = m->value;
    else if (m->expr)
      id->variables[ m->variable ] = sexpr_eval( m->expr );
    else if (m->from)
      // Set variable to the value of another variable
      if (id->variables[ m->from ])
	id->variables[ m->variable ] = id->variables[ m->from ];
      else if (!m->debug || id->misc->debug)
	return "Set: from variable doesn't exist";
      else
	return "";
    else if (m->other)
      // Set variable to the value of a misc variable
      if (id->misc->variables && id->misc->variables[ m->other ])
	id->variables[ m->variable ] = id->misc->variables[ m->other ];
      else if (m->debug || id->misc->debug)
	return "Set: other variable doesn't exist";
      else 
	return "";
    else if(m->define)
      // Set variable to the value of a define
      id->variables[ m->variable ] = id->misc->defines[ m->define ];
    else if (m->eval)
      // Set variable to the result of some evaluated RXML
      id->variables[ m->variable ] = parse_rxml(m->eval, id);
    else
      // Unset variable.
      m_delete( id->variables, m->variable );
    return("");
  } else {
    if(id->misc->debug)
      return("set on (line "+id->misc->line+"): variable not specified");
    return("<!-- set (line "+id->misc->line+"): variable not specified -->");
  }
}

string tag_append( string tag, mapping m, object id )
{
  if (m->variable)
  {
    if (m->value)
      // Set variable to value.
      if (id->variables[ m->variable ])
	id->variables[ m->variable ] += m->value;
      else
	id->variables[ m->variable ] = m->value;
    else if (m->from)
      // Set variable to the value of another variable
      if (id->variables[ m->from ])
	if (id->variables[ m->variable ])
	  id->variables[ m->variable ] += id->variables[ m->from ];
	else
	  id->variables[ m->variable ] = id->variables[ m->from ];
      else if (m->debug || id->misc->debug)
	return "<b>Append: from variable doesn't exist</b>";
      else
	return "";
    else if (m->other)
      // Set variable to the value of a misc variable
      if (id->misc->variables[ m->other ])
	if (id->variables[ m->variable ])
	  id->variables[ m->variable ] += id->misc->variables[ m->other ];
	else
	  id->variables[ m->variable ] = id->misc->variables[ m->other ];
      else if (m->debug || id->misc->debug)
	return "<b>Append: other variable doesn't exist</b>";
      else
	return "";
    else if(m->define)
      // Set variable to the value of a define
      id->variables[ m->variable ] += id->misc->defines[ m->define ]||"";
    else if (m->debug || id->misc->debug)
      return "<b>Append: nothing to append from</b>";
    else
      return "";
    return("");
  }
  else if (m->debug || id->misc->debug)
    return("<b>Append: variable not specified</b>");
  else
    return "";
}

string tag_echo(string tag,mapping m,object id,object file,
			  mapping defines)
{
  if(m->help) 
    return ("This tag outputs the value of different configuration and "
            "request local variables. They are not really used by Roxen."
            " This tag is included only to provide compatibility "
            "with \"normal\" WWW-servers");
  if(!m->var)
  {
    if(sizeof(m) == 1)
      m->var = m[indices(m)[0]];
    else 
      return id->misc->debug?
        "Que? You have to select which variable to echo":"";
  } else if(tag == "insert")
    return "";
  if(tag == "!--#echo" && id->misc->ssi_variables &&
     id->misc->ssi_variables[m->var])
    // Variables set with !--#set.
    return id->misc->ssi_variables[m->var];

  mapping myenv =  build_env_vars(0,  id, 0);
  m->var = lower_case(replace(m->var, " ", "_"));
  switch(m->var)
  {
   case "sizefmt":
   case "errmsg":
    return defines[m->var] || "";
   case "timefmt":
    return defines[m->var] || "%c";
    
   case "date_local":
    NOCACHE();
    return strftime(defines->timefmt || "%c", time(1));

   case "date_gmt":
    NOCACHE();
    return strftime(defines->timefmt || "%c", time(1) + localtime(time(1))->timezone);
      
   case "query_string_unescaped":
    return id->query || "";

   case "last_modified":
     // FIXME: Use defines->timefmt
    return tag_modified(tag, m, id, file, defines);
      
   case "server_software":
    return roxen->version();
      
   case "server_name":
    string tmp;
    tmp=id->conf->query("MyWorldLocation");
    sscanf(tmp, "%*s//%s", tmp);
    sscanf(tmp, "%s:", tmp);
    sscanf(tmp, "%s/", tmp);
    return tmp;
      
   case "gateway_interface":
    return "CGI/1.1";
      
   case "server_protocol":
    return "HTTP/1.0";
      
   case "request_method":
    return id->method;

   case "auth_type":
    return "Basic";
      
   case "http_cookie": case "cookie":
    NOCACHE();
    return (id->misc->cookies || "");

   case "http_accept":
    NOCACHE();
    return (id->misc->accept && sizeof(id->misc->accept)? 
	    id->misc->accept*", ": "None");
      
   case "http_user_agent":
    NOCACHE();
    return id->client && sizeof(id->client)? 
      id->client*" " : "Unknown";
      
   case "http_referer":
    NOCACHE();
    return id->referer && sizeof(id->referer) ? 
      id->referer*", ": "Unknown";
      
   default:
    m->var = upper_case(m->var);
    if(myenv[m->var]) {
      NOCACHE();
      return myenv[m->var];
    }
    if(tag == "insert")
      return "";
    return "<i>Unknown variable</i>: '"+m->var+"'";
  }
}

string tag_insert(string tag,mapping m,object id,object file,mapping defines)
{
  string n;
  mapping fake_id=([]);

  if (n=m->name || m->define) 
  {
    m_delete(m, "name");
    return do_replace(defines[n]||
		      (id->misc->debug?"No such define: "+n:""), m);
  }

  if (n=m->variable) 
  {
    m_delete(m, "variable");
    return do_replace(id->variables[n]||
		      (id->misc->debug?"No such variable: "+n:""), m);
  }

  if (n=m->variables) 
  {
    if(n!="variables")
      return Array.map(indices(id->variables), lambda(string s, mapping m) {
	return s+"="+sprintf("%O", m[s])+"\n";
      }, id->variables)*"\n";
    return String.implode_nicely(indices(id->variables));
  }

  if (n=m->cookies) 
  {
    NOCACHE();
    if(n!="cookies")
      return Array.map(indices(id->cookies), lambda(string s, mapping m) {
	return s+"="+sprintf("%O", m[s])+"\n";
      }, id->cookies)*"\n";
    return String.implode_nicely(indices(id->cookies));
  }

  if (n=m->cookie) 
  {
    NOCACHE();
    m_delete(m, "cookie");
    return do_replace(id->cookies[n]||
		      (id->misc->debug?"No such cookie: "+n:""), m);
  }

  if (m->file) 
  {
    string s;
    string f;
    f = fix_relative(m->file, id);
    id = id->clone_me();

    if(m->nocache) id->pragma["no-cache"] = 1;
    if(id->scan_for_query)
      f = id->scan_for_query( f );
    s = id->conf->try_get_file(f, id);


    if(!s) {
      if ((sizeof(f)>2) && (f[sizeof(f)-2..] == "--")) {
	// Might be a compat insert. <!--#inclide file=foo.html-->
	s = id->conf->try_get_file(f[..sizeof(f)-3], id);
      }
      if (!s) {

	// Might be a PATH_INFO type URL.
	array a = id->conf->open_file( f, "r", id );
	if(a && a[0])
	{
	  s = a[0]->read();
	  if(a[1]->raw)
	  {
	    s -= "\r";
	    if(!sscanf(s, "%*s\n\n%s", s))
	      sscanf(s, "%*s\n%s", s);
	  }
	}
	if(!s)
	  return id->misc->debug?"No such file: "+f+"!":"";
      }
    }

    m_delete(m, "file");

    return do_replace(s, m);
  }
  return tag_echo(tag, m, id, file, defines);
}

string tag_compat_exec(string tag,mapping m,object id,object file,
		       mapping defines)
{
  if(!QUERY(ssi))
    return "SSI support disabled";

  if(m->help) 
    return ("See the Apache documentation. This tag is more or less "
            "equivalent to &lt;insert file=...&gt;, but you can run "
            "any command. Please note that this can present a severe "
            " security hole when allowed.");

  if(m->cgi)
  {
    m->file = http_decode_string(m->cgi);
    m_delete(m, "cgi");
    return tag_insert(tag, m, id, file, defines);
  }

  if(m->cmd)
  {
    if(QUERY(exec))
    {
      string tmp;
      tmp=id->conf->query("MyWorldLocation");
      sscanf(tmp, "%*s//%s", tmp);
      sscanf(tmp, "%s:", tmp);
      sscanf(tmp, "%s/", tmp);
      string user;
      user="Unknown";
      if(id->auth && id->auth[0])
	user=id->auth[1];
      string addr=id->remoteaddr || "Internal";
      NOCACHE();
      return popen(m->cmd,
		   getenv()
		   | build_roxen_env_vars(id)
		   | build_env_vars(id->not_query, id, 0),
		   QUERY(execuid) || -2, QUERY(execgid) || -2);
    } else {
      return "<b>Execute command support disabled."+
        (id->misc->debug?
	"Check \"Main RXML Parser\"/\"SSI support\".":
	"<!-- Check \"Main RXML Parser\"/\"SSI support\". -->"
        )+"</b>";
    }
  }
  return id->misc->debug?
    "No arguments given to SSI-#exec":
    "<!-- exec what? -->";
}

string tag_compat_config(string tag,mapping m,object id,object file,
			 mapping defines)
{
  if(m->help) 
    return ("See the Apache documentation.");
  if(!QUERY(ssi))
    return "SSI support disabled";

  if (m->sizefmt) {
    if ((< "abbrev", "bytes" >)[lower_case(m->sizefmt||"")]) {
      defines->sizefmt = lower_case(m->sizefmt);
    } else {
      return(sprintf("Unknown SSI sizefmt:%O", m->sizefmt));
    }
  }
  if (m->errmsg) {
    // FIXME: Not used yet. What would it be used for, really?
    defines->errmsg = m->errmsg;
  }
  if (m->timefmt) {
    // now used by echo tag and last modified
    defines->timefmt = m->timefmt;
  }
  return "";
}

string tag_compat_include(string tag,mapping m,object id,object file,
			  mapping defines)
{
  if(m->help) 
    return ("This tag is more or less equivalent to the "
            "'insert' RXML command.");
  if(!QUERY(ssi))
    return "SSI support disabled";

  if(m->virtual)
  {
    m->file = m->virtual;
    return tag_insert("insert", m, id, file, defines);
  }

  if(m->file)
  {
    mixed tmp;
    string fname1 = m->file;
    string fname2;
    if(m->file[0] != '/')
    {
      if(id->not_query[-1] == '/')
	m->file = id->not_query + m->file;
      else
	m->file = ((tmp = id->not_query / "/")[0..sizeof(tmp)-2] +
		   ({ m->file }))*"/";
      fname1 = id->conf->real_file(m->file, id);
      if ((sizeof(m->file) > 2) && (m->file[sizeof(m->file)-2..] == "--")) {
	fname2 = id->conf->real_file(m->file[..sizeof(m->file)-3], id);
      }
    } else if ((sizeof(fname1) > 2) && (fname1[sizeof(fname1)-2..] == "--")) {
      fname2 = fname1[..sizeof(fname1)-3];
    }
    return((fname1 && Stdio.read_bytes(fname1)) ||
	   (fname2 && Stdio.read_bytes(fname2)) ||
           (id->misc->debug?
	   ("No such file: " +
	    (fname1 || fname2 || m->file) +
	    "!"):
           ""));
  }
  return "<!-- Hm? #include what, my dear? -->";
}

string tag_compat_echo(string tag,mapping m,object id,object file,
			  mapping defines)
{
  if(!QUERY(ssi))
    return "SSI support disabled. Use &lt;echo var=name&gt; instead.";
  return tag_echo(tag, m, id, file, defines);
}

string tag_compat_set(string tag,mapping m,object id,object file,
			  mapping defines)
{
  if(!QUERY(ssi))
    return "SSI support disabled. Use &lt;set variable=name value=value&gt; instead.";
  if(m->var && m->value)
  {
    if(!id->misc->ssi_variables)
      id->misc->ssi_variables = ([]);
    id->misc->ssi_variables[m->var] = m->value;
  }
  return "";
}

string tag_compat_fsize(string tag,mapping m,object id,object file,
			mapping defines)
{
  if(m->help) 
    return ("Returns the size of the file specified (as virtual=... or file=...)");
  if(!QUERY(ssi))
    return "SSI support disabled";

  if(m->virtual && sizeof(m->virtual))
  {
    m->virtual = http_decode_string(m->virtual);
    if (m->virtual[0] != '/') {
      // Fix relative path.
      m->virtual = combine_path(id->not_query, "../" + m->virtual);
    }
    m->file = id->conf->real_file(m->virtual, id);
    m_delete(m, "virtual");
  } else if (m->file && sizeof(m->file) && (m->file[0] != '/')) {
    // Fix relative path
    m->file = combine_path(id->conf->real_file(id->not_query, id) || "/", "../" + m->file);
  }
  if(m->file)
  {
    array s;
    s = file_stat(m->file);
    CACHE(5);
    if(s)
    {
      if(tag == "!--#fsize")
      {
	if(defines->sizefmt=="bytes")
	  return (string)s[1];
	else
	  return sizetostring(s[1]);
      } else {
	return strftime(defines->timefmt || "%c", s[3]);
      }
    }
    return "Error: Cannot stat file";
  }
  return id->misc->debug?"No such file?":"";
}


string tag_accessed(string tag,mapping m,object id,object file,
		    mapping defines)
{
  int counts, n, prec, q, timep;
  string real, res;

  if(!QUERY(ac))
    return "Accessed support disabled.";

  NOCACHE();
  if(m->file)
  {
    m->file = fix_relative(m->file, id);
    if(m->add) 
      counts = query_num(m->file, (int)m->add||1);
    else
      counts = query_num(m->file, 0);
  } else {
    if(_match(id->remoteaddr, id->conf->query("NoLog")))
      counts = query_num(id->not_query, 0);
    else if(defines->counted != "1") 
    {
      counts =query_num(id->not_query, 1);
      defines->counted = "1";
    } else {
      counts = query_num(id->not_query, 0);
    }
      
    m->file=id->not_query;
  }
  
  int bar;

  if(m->reset)
  {
    // FIXME: There is a few cases where users can avoid this.
    if( !search( (dirname(m->file)+"/")-"//",
		 (dirname(id->not_query)+"/")-"//" ) )
    {
      query_num(m->file, -counts);
      database_set_created(m->file, time(1));
      return "Number of counts for "+m->file+" is now 0.<br>";
    } else {
      // On a web hotell you don't want the guests to be alowed to reset
      // eachothers counters.
      return "You do not have access to reset this counter.";
    }
  }

  if(m->silent)
    return "";

  if(m->since) 
  {
    if(m->database)
      return tagtime(database_created(0),m);
    return tagtime(database_created(m->file),m);
  }

  real="<!-- ("+counts+") -->";

  counts += (int)m->cheat;

  if(m->factor)
    counts = (counts * (int)m->factor) / 100;

  if(m->per)
  {
    timep=time(1) - database_created(m->file) + 1;
    
    switch(m->per)
    {
     case "second":
      counts /= timep;
      break;

     case "minute":
      counts = (int)((float)counts/((float)timep/60.0));
      break;

     case "hour":
      counts = (int)((float)counts/(((float)timep/60.0)/60.0));
      break;

     case "day":
      counts = (int)((float)counts/((((float)timep/60.0)/60.0)/24.0));
      break;

     case "week":
      counts = (int)((float)counts/(((((float)timep/60.0)/60.0)/24.0)/7.0));
      break;

     case "month":
      counts = (int)((float)counts/(((((float)timep/60.0)/60.0)/24.0)/30.42));
      break;

     case "year":
      counts=(int)((float)counts/(((((float)timep/60.0)/60.0)/24.0)/365.249));
      break;

    default:
      return (id->misc->debug?"Access count per what?":"");
    }
  }

  if(prec=(int)m->precision || (int)m->prec)
  {
    n=ipow(10, prec);
    while(counts>n) { counts=(counts+5)/10; q++; }
    counts*=ipow(10, q);
  }

  switch(m->type)
  {
   case "mcdonalds":
    q=0;
    while(counts>10) { counts/=10; q++; }
    res="More than "+roxen->language("eng", "number")(counts*ipow(10, q))
        + " served.";
    break;
    
   case "linus":
    res=counts+" since "+ctime(database_created(0));
    break;

   case "ordered":
    m->type="string";
    res=number2string(counts,m,language(m->lang, "ordered"));
    break;

   default:
    res=number2string(counts,m,language(m->lang, "number"));
  }
  return res+(m->addreal?real:"");
}                  

string tag_modified(string tag, mapping m, object id, object file,
		    mapping defines)
{
  array (int) s;
  object f;
  
  if(m->by && !m->file && !m->realfile)
  {
    if(!id->conf->auth_module)
      return id->misc->debug?"Modified by requires an user database!\n":"";
    m->name = id->conf->last_modified_by(file, id);
    CACHE(10);
    return tag_user(tag, m, id, file, defines);
  }

  if(m->file)
  {
    m->realfile = id->conf->real_file(fix_relative(m->file,id), id);
    m_delete(m, "file");
  }

  if(m->by && m->realfile)
  {
    if(!id->conf->auth_module)
      return id->misc->debug?"Modified by requires an user database!\n":"";

    if(f = open(m->realfile, "r"))
    {
      m->name = id->conf->last_modified_by(f, id);
      destruct(f);
      CACHE(10);
      return tag_user(tag, m, id, file,defines);
    }
    return "A. Nonymous.";
  }
  
  if(m->realfile)
    s = file_stat(m->realfile);

  if(!(_stat || s) && !m->realfile && id->realfile)
  {
    m->realfile = id->realfile;
    return tag_modified(tag, m, id, file, defines);
  }
  CACHE(10);
  if(!s) s = _stat;
  if(!s) s = id->conf->stat_file( id->not_query, id );
  if(s)
    if(tag[..2] == "!--")
      return strftime(defines->timefmt || "%c", s[3]);
    else
      return tagtime(s[3], m);
  else
    return "Error: Cannot stat file";
}

function tag_version = roxen.version;

string tag_clientname(string tag, mapping m, object id)
{
  NOCACHE();
  if (sizeof(id->client)) {
    if(m->full) 
      return id->client * " ";
    else 
      return id->client[0];
  } else {
    return "";
  } 
}

string tag_signature(string tag, mapping m, object id, object file,
		     mapping defines)
{
  return "<right><address>"+tag_user(tag, m, id, file,defines)+"</address></right>";
}

string tag_user(string tag, mapping m, object id, object file,mapping defines)
{
  string *u;
  string b, dom;

  if(!id->conf->auth_module)
    return id->misc->debug?"User requires an user database!\n":"";

  if (!(b=m->name)) {
    return(tag_modified("modified", m | ([ "by":"by" ]), id, file,defines));
  }

  b=m->name;

  dom=id->conf->query("Domain");
  if(dom[-1]=='.')
    dom=dom[0..strlen(dom)-2];
  if(!b) return "";
  u=id->conf->userinfo(b, id);
  if(!u) return "";
  
  if(m->realname && !m->email)
  {
    if(m->link && !m->nolink)
      return "<a href=\"/~"+b+"/\">"+u[4]+"</a>";
    return u[4];
  }
  if(m->email && !m->realname)
  {
    if(m->link && !m->nolink)
      return "<a href=\"mailto:" + b + "@" + dom + "\">"
	+ b + "@" + dom + "</a>";
    return b + "@" + dom;
  }
  if(m->nolink && !m->link)
    return u[4] + " &lt;" + b + "@" + dom + "&gt;";
  return ("<a href=\"/~"+b+"/\">"+u[4]+"</a>"+
	  " <a href=\"mailto:" + b + "@" + dom + "\"> &lt;"+
	  b + "@" + dom + "&gt;</a>");
}

string tag_configurl(string f, mapping m)
{
  return roxen->config_url();
}

string tag_configimage(string f, mapping m)
{
  string args="";

  while(sizeof(m))
  {
    string q;
    switch(q=indices(m)[0])
    {
     case "src":
      args += " src=\"/internal-roxen-"+ (m->src-".gif") + "\"";
      break;
     default:
      args += " "+q+"=\""+m[q]+"\"";
    }
    m_delete(m, q);
  }
  return ("<img border=0 "+args+">");
}

string tag_aprestate(string tag, mapping m, string q, object id)
{
  string href, s, *foo;
  multiset prestate=(< >);

  if(!(href = m->href))
    href=strip_prestate(strip_config(id->raw_url));
  else 
  {
    if ((sizeof(foo = href / ":") > 1) && (sizeof(foo[0] / "/") == 1))
      return make_container("a",m,q);
    href=fix_relative(href, id);
    m_delete(m, "href");
  }
  
  if(!strlen(href))
    href="";

  prestate = (< @indices(id->prestate) >);

  foreach(indices(m), s) {
    if(m[s]==s) {
      m_delete(m,s);

      if(strlen(s) && s[0] == '-')
	prestate[s[1..]]=0;
      else
	prestate[s]=1;
    }
  }
  m->href = add_pre_state(href, prestate);
  return make_container("a",m,q);
}

string tag_aconfig(string tag, mapping m, string q, object id)
{
  string href;
  mapping(string:string) cookies = ([]);
  
  if(m->help) return "Alias for &lt;aconf&gt;";

  if(!m->href)
    href=strip_prestate(strip_config(id->raw_url));
  else 
  {
    href=m->href;
    if (search(href, ":") == search(href, "//")-1)
      return sprintf((id->misc->debug?"It is not possible to add "
                      "configs to absolute URLs (yet, at least)\n":"")+
		     "<a href=\"%s\">%s</a>", href, q);
    href=fix_relative(href, id);
    m_delete(m, "href");
  }

  foreach(indices(m), string opt) {
    if(m[opt]==opt) {
      if(strlen(opt)) {
	switch(opt[0]) {
	case '+':
	  m_delete(m, opt);
	  cookies[opt[1..]] = opt;
	  break;
	case '-':
	  m_delete(m, opt);
	  cookies[opt] = opt;
	  break;
	}
      }
    }
  }
  m->href = add_config(href, indices(cookies), id->prestate);
  return make_container("a", m, q);
}

string add_header(mapping to, string name, string value)
{
  if(to[name])
    if(arrayp(to[name]))
      to[name] += ({ value });
    else
      to[name] = ({ to[name], value });
  else
    to[name] = value;
}

string tag_add_cookie(string tag, mapping m, object id, object file,
		      mapping defines)
{
  string cookies;
  int    t;     //time

  if(m->name)
    cookies = m->name+"="+http_encode_cookie(m->value||"");
  else
    return id->misc->debug?"set-cookie requires a `name'":"";

  if(m->persistent)
    t=(3600*(24*365*2));
  else
  {
    if (m->hours)   t+=((int)(m->hours))*3600;
    if (m->minutes) t+=((int)(m->minutes))*60;
    if (m->seconds) t+=((int)(m->seconds));
    if (m->days)    t+=((int)(m->days))*(24*3600);
    if (m->weeks)   t+=((int)(m->weeks))*(24*3600*7);
    if (m->months)  t+=((int)(m->months))*(24*3600*30+37800); /* 30.46d */
    if (m->years)   t+=((int)(m->years))*(3600*(24*365+6));   /* 365.25d */
  }

  if(t) cookies += "; expires="+http_date(t+time());

  //obs! no check of the parameter's usability
  cookies += "; path=" +(m->path||"/");

  add_header(_extra_heads, "Set-Cookie", cookies);

  return "";
}

string tag_remove_cookie(string tag, mapping m, object id, object file,
			 mapping defines)
{
  string cookies;
  if(m->name)
    cookies = m->name+"="+http_encode_cookie(m->value||"")+
      "; expires="+http_date(0)+"; path=/";
  else
    return id->misc->debug?"remove-cookie requires a `name'":"";

  add_header(_extra_heads, "Set-Cookie", cookies);
  return "";
}

string tag_return(string tag, mapping m, object id, object file,
		  mapping defines)
{
  if(m->code)_error=(int)m->code || 200;
  if(m->text)_rettext=m->text;
  return "";
}

string tag_referer(string tag, mapping m, object id, object file,
		   mapping defines)
{
  NOCACHE();

  if(m->help) 
    return ("Compatibility alias for referrer");
  if(id->referer)
    return sizeof(id->referer)?id->referer*"":m->alt?m->alt:"..";
  return m->alt?m->alt:"..";
}

string tag_header(string tag, mapping m, object id, object file,
		  mapping defines)
{
  if(m->name == "WWW-Authenticate")
  {
    string r;
    if(m->value)
    {
      if(!sscanf(m->value, "Realm=%s", r))
	r=m->value;
    } else {
      r="Users";
    }
    m->value="basic realm=\""+r+"\"";
  } else if(m->name=="URI") {
    m->value = "<" + m->value + ">";
  }
  
  if(!(m->value && m->name))
    return id->misc->debug?"Header requires both a name and a value.":"";

  add_header(_extra_heads, m->name, m->value);
  return "";
}

string tag_redirect(string tag, mapping m, object id, object file,
		    mapping defines)
{
  if (!m->to) {
    return(id->misc->debug?"Redirect requires attribute \"to\".":"");
  }

  multiset(string) orig_prestate = id->prestate;
  multiset(string) prestate = (< @indices(orig_prestate) >);
  foreach(indices(m), string s)
    if(m[s]==s && sizeof(s))
      switch (s[0]) {
	case '+': prestate[s[1..]] = 1; break;
	case '-': prestate[s[1..]] = 0; break;
      }
  id->prestate = prestate;
  mapping r = http_redirect(m->to, id);
  id->prestate = orig_prestate;

  if (r->error) {
    _error = r->error;
  }
  if (r->extra_heads) {
    _extra_heads += r->extra_heads;
  }
  if (m->text) {
    _rettext = m->text;
  }
  return("");
}

string tag_auth_required (string tagname, mapping args, object id,
			  object file, mapping defines)
{
  mapping hdrs = http_auth_required (args->realm, args->message);
  if (hdrs->error) _error = hdrs->error;
  if (hdrs->extra_heads) _extra_heads += hdrs->extra_heads;
  if (hdrs->text) _rettext = hdrs->text;
  return "";
}

string tag_expire_time(string tag, mapping m, object id, object file,
		       mapping defines)
{
  int t=time();
  if(!m->now)
  {
    if (m->hours) t+=((int)(m->hours))*3600;
    if (m->minutes) t+=((int)(m->minutes))*60;
    if (m->seconds) t+=((int)(m->seconds));
    if (m->days) t+=((int)(m->days))*(24*3600);
    if (m->weeks) t+=((int)(m->weeks))*(24*3600*7);
    if (m->months) t+=((int)(m->months))*(24*3600*30+37800); /* 30.46d */
    if (m->years) t+=((int)(m->years))*(3600*(24*365+6));   /* 365.25d */
    CACHE(max(t-time(),0));
  } else
    NOCACHE();

  add_header(_extra_heads, "Expires", http_date(t));
  return "";
}

string tag_file(string tag, mapping m, object id)
{
  if(m->raw)
    return id->raw_url;
  else
    return id->not_query;
}

string tag_realfile(string tag, mapping m, object id)
{
  return id->realfile || "unknown";
}

string tag_vfs(string tag, mapping m, object id)
{
  return id->virtfile || "unknown";
}

string tag_language(string tag, mapping m, object id)
{
  NOCACHE();

  if(!id->misc["accept-language"])
    return "None";

  if(m->full)
    return id->misc["accept-language"]*",";
  else
    return (id->misc["accept-language"][0]/";")[0];
}

string tag_quote(string tagname, mapping m)
{
#if efun(set_start_quote)
  if(m->start && strlen(m->start))
    set_start_quote(m->start[0]);
  if(m->end && strlen(m->end))
    set_end_quote(m->end[0]);
#endif
  return "";
}

string tag_ximage(string tagname, mapping m, object id)
{
  string img = id->conf->real_file(fix_relative(m->src||"", id), id);
  if(img && search(img, ".gif")!=-1) {
    object fd = open(img, "r");
    if(fd) {
      int x, y;
      sscanf(gif_size(fd), "width=%d height=%d", x, y);
      m->width=x;
      m->height=y;
    }
  }
  return make_tag("img", m);
}

mapping pr_sizes = ([]);
string get_pr_size(string size, string color)
{
  if(pr_sizes[size+color]) return pr_sizes[size+color];
  object fd = open("roxen-images/power-"+size+"-"+color+".gif", "r");
  if(!fd) return "NONEXISTANT COMBINATION";
  return pr_sizes[size+color] = gif_size( fd );
}

string tag_pr(string tagname, mapping m)
{
  string size = m->size || "small";
  string color = m->color || "blue";
  if(m->list)
  {
    string res = "<table><tr><td><b>size</b></td><td><b>color</b></td></tr>";
    foreach(sort(get_dir("roxen-images")), string f)
      if(sscanf(f, "power-%s", f))
	res += "<tr><td>"+replace(f-".gif","-","</td><td>")+"</tr>";
    return res + "</table>";
  }
  m_delete(m, "color");
  m_delete(m, "size");
  m->src = "/internal-roxen-power-"+size+"-"+color;
  int w;
  sscanf(get_pr_size(size,color), "%*swidth=%d", w);
  m->width = (string)w;
  sscanf(get_pr_size(size,color), "%*sheight=%d", w);
  m->height = (string)w;
  if(!m->alt) m->alt="Powered by Roxen";
  if(!m->border) m->border="0";
  return ("<a href=\"http://www.roxen.com/\">"+make_tag("img", m)+"</a>");
}

string tag_debug( string tag_name, mapping args, object id )
{
  if (args->off)
    id->misc->debug = 0;
  else if (args->toggle)
    id->misc->debug = !id->misc->debug;
  else
    id->misc->debug = 1;
  return "";
}

string tag_cache(string tag, mapping args, string contents, object id)
{
#define HASH(x) (x+id->not_query+id->query+id->realauth +id->conf->query("MyWorldLocation"))
#if constant(Crypto.md5)
  object md5 = Crypto.md5();
  md5->update(HASH(contents));
  string key=md5->digest();
#else
  string key = (string)hash(HASH(contents));
#endif
  if(args->key)
    key += args->key;
  string parsed = cache_lookup("tag_cache", key);
  if(!parsed) {
    parsed = parse_rxml(contents, id);
    cache_set("tag_cache", key, parsed);
  }
  return parsed;
#undef HASH
}

string tag_fsize(string tag, mapping args, object id)
{
  array s;
  catch
  {
    id->conf->stat_file( fix_relative( args->file, id ), id );
    return (string)s[1];
  };
  if(string s=id->conf->try_get_file(fix_relative(args->file, id), id ) )
    return (string)strlen(s);
}

mapping query_tag_callers()
{
   return (["accessed":tag_accessed,
	    "modified":tag_modified,
	    "pr":tag_pr,
	    "set-max-cache":
	    lambda(string t, mapping m, object id) { 
	      id->misc->cacheable = (int)m->time; 
	    },
	    "imgs":tag_ximage,
	    "version":tag_version,
	    "set":tag_set,
	    "append":tag_append,
	    "unset":tag_set,
 	    "set_cookie":tag_add_cookie,
 	    "remove_cookie":tag_remove_cookie,
	    "clientname":tag_clientname,
	    "configurl":tag_configurl,
	    "configimage":tag_configimage,
	    "date":tag_date,
	    "referer":tag_referer,
	    "referrer":tag_referer,
	    "refferrer":tag_referer,
	    "accept-language":tag_language,
	    "insert":tag_insert,
	    "return":tag_return,
	    "file":tag_file,
	    "realfile":tag_realfile,
	    "vfs":tag_vfs,
	    "header":tag_header,
	    "redirect":tag_redirect,
	    "auth-required":tag_auth_required,
	    "expire-time":tag_expire_time,
	    "signature":tag_signature,
	    "user":tag_user,
 	    "quote":tag_quote,
	    "echo":tag_echo,           
	    "fsize":tag_fsize,           
	    "!--#echo":tag_compat_echo,           /* These commands are */
	    "!--#exec":tag_compat_exec,           /* NCSA/Apache Server */
	    "!--#flastmod":tag_compat_fsize,      /* Side includes.     */
	    "!--#fsize":tag_compat_fsize, 
	    "!--#set":tag_compat_set, 
	    "!--#include":tag_compat_include, 
	    "!--#config":tag_compat_config,
	    "debug" : tag_debug,
   ]);
}

string tag_source(string tag, mapping m, string s, object id,object file)
{
  string sep;
  sep=m["separator"]||"";
  if(!m->nohr)
    sep="<hr><h2>"+sep+"</h2><hr>";
  return ("<pre>"+replace(s, ({"<",">","&"}),({"&lt;","&gt;","&amp;"}))
	  +"</pre>"+sep+s);
}

string tag_source2(string tag, mapping m, string s, object id,object file)
{
  if(!m["magic"])
    if(m["pre"])
      return "\n<pre>"+
	replace(s, ({"{","}","&"}),({"&lt;","&gt;","&amp;"}))+"</pre>\n";
    else
      return replace(s, ({ "{", "}", "&" }), ({ "&lt;", "&gt;", "&amp;" }));
  else 
    if(m["pre"])
      return "\n<pre>"+
	replace(s, ({"<",">","&"}),({"&lt;","&gt;","&amp;"}))+"</pre>\n";
    else
      return replace(s, ({ "<", ">", "&" }), ({ "&lt;", "&gt;", "&amp;" }));
}

string tag_autoformat(string tag, mapping m, string s, object id,object file)
{
  s-="\r";
  if(m->p)
    s = replace(s, "\n\n", "<p>");
  else if(!m->nobr)
    s = replace(s, "\n", "<br>\n");
  return s;
}

string tag_smallcaps(string t, mapping m, string s)
{
  string build="";
  int i,lc=1,j;
  string small=m->small;
  if (m->size)
  {
    build="<font size="+m->size+">";
    if (!small)
    {
      if (m->size[0]=='+') small="+"+(((int)m->size[1..10])-1);
      else if (m->size[0]=='-') small="-"+(((int)m->size[1..10])+1);
      else small=""+(((int)m->size)-1);
    }
  } else if (!small) small="-1";
  
  for (i=0; i<strlen(s); i++)
    if (s[i]=='<') 
    { 
      if (!lc) 
      { 
	build+="</font>";
	lc=1; 
      }
      for (j = i;j < strlen(s) && s[j] != '>'; j++);
      build += s[i..j];
      i = j;
    }
    else if (s[i]<=32) 
    { 
      if (!lc) build+="</font>"+s[i..i]; 
      else 
	build+=s[i..i]; 
      lc=1; 
    }
    else if (s[i]&64)
      if (s[i]&32) 
      { 
	if (lc) 
	  build+="<font size="+small+">"+sprintf("%c",s[i]-32)
	    +(m->space?"&nbsp;":""); 
	else 
	  build+=sprintf("%c",s[i]-32)+(m->space?"&nbsp;":""); lc=0; }
      else { 
	if (!lc) 
	  build+="</font>"+s[i..i]+(m->space?"&nbsp;":""); 
	else 
	  build+=s[i..i]+(m->space?"&nbsp;":""); 
	lc=1; 
      }
    else 
      build+=s[i..i]+(m->space?"&nbsp;":"");
  if (!lc) 
    build+="</font>"; 
  if (m->size) 
    build+="</font>";
  return build;
}

string tag_random(string tag, mapping m, string s)
{
  mixed q;
  if(!(q=m->separator || m->sep))
    return (q=s/"\n")[random(sizeof(q))];
  else
    return (q=s/q)[random(sizeof(q))];
}

string tag_formoutput(string tag_name, mapping args, string contents,
		      object id, mapping defines)
{
  return do_output_tag( args, ({ id->variables }), contents, id );
}

string tag_gauge(string t, mapping args, string contents, 
		 object id, object f, mapping defines)
{
  NOCACHE();

#if constant(gethrtime)
  int t = gethrtime();
  contents = parse_rxml( contents, id );
  t = gethrtime()-t;
#else
  int t = gauge {
    contents = parse_rxml( contents, id );
  } * 1000;
#endif
  string define = args->define?args->define:"gauge";

  defines[define+"_time"] = sprintf("%3.6f", t/1000000.0);
  defines[define+"_result"] = contents;

  if(args->silent) return "";
  if(args->timeonly) return sprintf("%3.6f", t/1000000.0);
  if(args->resultonly) return contents;
  return ("<br><font size=-1><b>Time: "+
	  sprintf("%3.6f", t/1000000.0)+
	  " seconds</b></font><br>"+contents);
} 

// Removes empty lines
mixed tag_trimlines( string tag_name, mapping args, string contents,
		      object id )
{
  contents = replace(parse_rxml( contents, id ),
		     ({ "\r\n","\r" }), ({"\n", "\n"}));
  return ({ (contents / "\n" - ({ "" })) * "\n" });
}

// Internal method for the default tag
private mixed tag_input( string tag_name, mapping args, string name,
			  multiset (string) value )
{
  if (name && args->name != name)
    return 0;
  if (args->type == "checkbox" || args->type == "radio")
    if (args->value)
      if (value[ args->value ])
	if (args->checked)
	  return 0;
	else
	  args->checked = "checked";
      else
	if (args->checked)
	  m_delete( args, "checked" );
	else
	  return 0;
    else
      if (value[ "on" ])
	if (args->checked)
	  return 0;
	else
	  args->checked = "checked";
      else
	if (args->checked)
	  m_delete( args, "checked" );
	else
	  return 0;
  else
    return 0;
  return ({ make_tag( tag_name, args ) });
}

private string remove_leading_trailing_ws( string str )
{
  sscanf( str, "%*[\t\n\r ]%s", str ); str = reverse( str ); 
  sscanf( str, "%*[\t\n\r ]%s", str ); str = reverse( str );
  return str;
}

// Internal method for the default tag
private mixed tag_option( string tag_name, mapping args, string contents,
				  multiset (string) value )
{
  if (args->value)
    if (value[ args->value ])
      if (args->selected)
	return 0;
      else
	args->selected = "selected";
    else
      return 0;
  else
    if (value[ remove_leading_trailing_ws( contents ) ])
      if (args->selected)
	return 0;
      else
	args->selected = "selected";
    else
      return 0;
  return ({make_container( tag_name, args, contents )});
}

// Internal method for the default tag
private mixed tag_select( string tag_name, mapping args, string contents,
			   string name, multiset (string) value )
{
  array (string) tmp;
  int c;
  
  if (name && args->name != name)
    return 0;
  tmp = contents / "<option";
  for (c=1; c < sizeof( tmp ); c++)
    if (sizeof( tmp[c] / "</option>" ) == 1)
      tmp[c] += "</option>";
  contents = tmp * "<option";
  mapping m = ([ "option" : tag_option ]);
  contents = parse_html( contents, ([ ]), m, value );
  return ({ make_container( tag_name, args, contents ) });
}

// The default tag is used to give default values to forms elements,
// without any fuss.
string tag_default( string tag_name, mapping args, string contents,
		    object id, object f, mapping defines, object fd )
{
  string multi_separator = args->multi_separator || "\000";

  contents = parse_rxml( contents, id );
  if (args->value)
    return parse_html( contents, ([ "input" : tag_input ]),
		       ([ "select" : tag_select ]),
		       args->name, mkmultiset( args->value
					       / multi_separator ) );
  else if (args->variable && id->variables[ args->variable ])
    return parse_html( contents, ([ "input" : tag_input ]),
		       ([ "select" : tag_select ]),
		       args->name,
		       mkmultiset( id->variables[ args->variable ]
				   / multi_separator ) );
  else    
    return contents;
}

string tag_sort(string t, mapping m, string c, object id)
{
  if(!m->separator)
    m->separator = "\n";

  string pre="", post="";
  array lines = c/m->separator;

  while(lines[0] == "")
  {
    pre += m->separator;
    lines = lines[1..];
  }

  while(lines[-1] == "")
  {
    post += m->separator;
    lines = lines[..sizeof(lines)-2];
  }

  return pre + sort(lines)*m->separator + post;
}

string tag_recursive_output (string tagname, mapping args, string contents,
			     object id, object file, mapping defines)
{
  int limit;
  array(string) inside, outside;
  if (id->misc->recout_limit) {
    limit = id->misc->recout_limit - 1;
    inside = id->misc->recout_outside, outside = id->misc->recout_inside;
  }
  else {
    limit = (int) args->limit || 100;
    inside = args->inside ? args->inside / (args->multisep || ",") : ({});
    outside = args->outside ? args->outside / (args->multisep || ",") : ({});
    if (sizeof (inside) != sizeof (outside))
      return "\n<b>'inside' and 'outside' replacement sequences "
	"aren't of same length</b>\n";
  }

  if (limit <= 0) return contents;

  int save_limit = id->misc->recout_limit;
  string save_inside = id->misc->recout_inside, save_outside = id->misc->recout_outside;

  id->misc->recout_limit = limit;
  id->misc->recout_inside = inside;
  id->misc->recout_outside = outside;

  string res = parse_rxml (
    parse_html (
      contents,
      (["recurse": lambda (string t, mapping a, string c) {return ({c});}]), ([]),
      "<" + tagname + ">" + replace (contents, inside, outside) + "</" + tagname + ">"),
    id);

  id->misc->recout_limit = save_limit;
  id->misc->recout_inside = save_inside;
  id->misc->recout_outside = save_outside;

  return res;
}

mapping query_container_callers()
{
  return ([
	   "crypt":lambda(string t, mapping m, string c){
		     if(m->compare)
		       return (string)crypt(c,m->compare);
		     else
		       return crypt(c);
		   },
	   "cset":lambda(string t, mapping m, string c, object id)
	  { return tag_set("set",m+([ "value":html_decode_string(c) ]),
			    id); },
	   "source":tag_source,
	   "catch":lambda(string t, mapping m, string c, object id) {
		     string r;
		     array e = catch(r=parse_rxml(c, id));
		     if(e) return e[0];
		     return r;
		   },
	   "throw":lambda(string t, mapping m, string c) {
		     if(c[-1] != "\n") c+="\n";
		     throw( ({ c, backtrace() }) );
		   },
	   "cache":tag_cache,
	   "sort":tag_sort,
	   "doc":tag_source2,
	   "autoformat":tag_autoformat,
	   "random":tag_random,
	   "scope":tag_scope,
	   "gauge":tag_gauge,
	   "apre":tag_aprestate,
	   "aconf":tag_aconfig,
	   "aconfig":tag_aconfig,
	   "smallcaps":tag_smallcaps,
	   "formoutput":tag_formoutput,
	   "trimlines" : tag_trimlines,
	   "default" : tag_default,
	   "recursive-output": tag_recursive_output,
	   ]);
}



mapping query_if_callers()
{
  return ([
    "expr":lambda( string q){ return (int)sexpr_eval(q); },
  ]);
}

int api_query_num(object id, string f, int|void i)
{
  NOCACHE();
  return query_num(f, i);
}

string api_parse_rxml(object id, string r)
{
  return parse_rxml( r, id );
}


string api_tagtime(object id, int ti, string t, string l)
{
  mapping m = ([ "type":t, "lang":l ]);
  NOCACHE();
  return tagtime( ti, m );
}

string api_relative(object id, string path)
{
  return fix_relative( path, id );
}

string api_set(object id, string what, string to)
{
  tag_set("set",(["variable":what, "value":to]) , id);
  return ([])[0];
}

string api_define(object id, string what, string to)
{
  id->misc->defines[what]=to;
  return ([])[0];
}


string api_query_define(object id, string what)
{
  return id->misc->defines[what];
}

string api_query_variable(object id, string what)
{
  return id->variables[what];
}

string api_read_file(object id, string f)
{
  mapping m = ([ "file":f ]);
  return tag_insert("insert", m, id, id, id->misc->defines);
}

string api_query_cookie(object id, string f)
{
  mapping m = ([ "cookie":f ]);
  return tag_insert("insert", m, id, id, id->misc->defines);
}

string api_query_modified(object id, string f, int|void by)
{
  mapping m = ([ "by":by, "file":f ]);
  return tag_modified("modified", m, id, id, id->misc->defines);
}

void api_add_header(object id, string h, string v)
{
  add_header(id->misc->defines[" _extra_heads"], h, v);
}

void api_set_cookie(object id, string c, string v)
{
  tag_add_cookie( "add_cookie", (["name":c,"persistent":1,"value":v]),
		  id, id, id->misc->defines);
}

void api_remove_cookie(object id, string c, string v)
{
  tag_remove_cookie( "remove_cookie", (["name":c,"value":v]),
		     id, id, id->misc->defines);
}

int api_prestate(object id, string p)
{
  return id->prestate[p];
}

int api_set_prestate(object id, string p)
{
  return id->prestate[p]=1;
}

int api_supports(object id, string p)
{
  NOCACHE();
  return id->supports[p];
}

int api_set_supports(object id, string p)
{
  NOCACHE();
  return id->supports[p]=1;
}


int api_set_return_code(object id, int c, string p)
{
  tag_return("return", ([ "code":c, "text":p ]), id,id,id->misc->defines);
  return ([])[0];
}

string api_get_referer(object id)
{
  NOCACHE();
  if(id->referer && sizeof(id->referer)) return id->referer*"";
  return ([])[0];
}

string api_html_quote(object id, string what)
{
  return replace(what, ({ "<", ">", "&" }),({"&lt;", "&gt;", "&amp;" }));
}

constant replace_from=indices( iso88591 )+({"&lt;","&gt;","&amp;","&#022;"});
constant replace_to =values( iso88591 )+ ({"<",">", "&","\""});

string api_html_dequote(object id, string what)
{
  return replace(what, replace_from, replace_to);
}

string api_html_quote_attr(object id, string value)
{
  return sprintf("\"%s\"", replace(value, "\"", "&quot;"));
}

void add_api_function( string name, function f, void|array(string) types)
{
  if(this_object()["_api_functions"])
    this_object()["_api_functions"][name] = ({ f, types });
}


void define_API_functions()
{
  add_api_function("accessed", api_query_num, ({ "string", 0,"int" }));
  add_api_function("parse_rxml", api_parse_rxml, ({ "string" }));
  add_api_function("tag_time", api_tagtime, ({ "int", 0,"string", "string" }));
  add_api_function("fix_relative", api_relative, ({ "string" }));
  add_api_function("set_variable", api_set, ({ "string", "string" }));
  add_api_function("define", api_define, ({ "string", "string" }));

  add_api_function("query_define", api_query_define, ({ "string", }));
  add_api_function("query_variable", api_query_variable, ({ "string", }));
  add_api_function("query_cookie", api_query_cookie, ({ "string", }));
  add_api_function("query_modified", api_query_modified, ({ "string", }));

  add_api_function("read_file", api_read_file, ({ "string", 0,"int"}));
  add_api_function("add_header", api_add_header, ({"string", "string"}));
  add_api_function("add_cookie", api_set_cookie, ({"string", "string"}));
  add_api_function("remove_cookie", api_remove_cookie, ({"string", "string"}));

  add_api_function("html_quote", api_html_quote, ({"string"}));
  add_api_function("html_dequote", api_html_dequote, ({"string"}));
  add_api_function("html_quote_attr", api_html_quote_attr, ({"string"}));

  add_api_function("prestate", api_prestate, ({"string"}));
  add_api_function("set_prestate", api_set_prestate, ({"string"}));

  add_api_function("supports", api_supports, ({"string"}));
  add_api_function("set_supports", api_set_supports, ({"string"}));

  add_api_function("set_return_code", api_set_return_code, ({ "int", 0, "string" }));
  add_api_function("query_referer", api_get_referer, ({ "int", 0, "string" }));

  add_api_function("roxen_version", tag_version, ({}));
  add_api_function("config_url", tag_configurl, ({}));
}

int may_disable()  { return 0; }
