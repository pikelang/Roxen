// This is a roxen module. Copyright © 1996 - 1999, Idonex AB.
//
// This module maintains an accessed database,
// to be used by the <accessed> tag also provided
// by this module.
//

constant cvs_version="$Id: accessed.pike,v 1.5 1999/08/13 19:11:12 nilsson Exp $";
constant thread_safe=1;

constant language = roxen->language;

#include <module.h>

inherit "module";
inherit "roxenlib";

int cnum=0;
mapping fton=([]); // Holds the access database

object database, names_file;

string status()
{
  return (sizeof(fton)+" entries in the accessed database.<br>");
}

void create(object c)
{
  defvar("Accesslog", 
	 GLOBVAR(logdirprefix)+
	 short_name(c?c->name:".")+"/Accessed", 
	 "Access log file", TYPE_FILE|VAR_MORE,
	 "In this file all accesses to files using the &lt;accessed&gt;"
	 " tag will be logged.");

  defvar("extcount", ({  }), "Extensions to access count",
          TYPE_STRING_LIST,
         "Always access count all files ending with these extensions. "
	 "Note: This module must be reloaded for a change here to take "
	 "effect.");

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

  define_API_functions();

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

  p=fton[file];
  if(!p) return 0;
  mixed key = open_db_file();
  database->seek((p*8)+4);
  return database->write(sprintf("%4c", t||time(1)));
}

int database_created(string file)
{
  int p,w;

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
  return ({ MODULE_PARSER|MODULE_LOGGER, 
	    "Accessed counter", 
	    ("This module provides an accessed counter, both through the &lt;accessed&gt; tag and "
             "filewise."), 0, 1 });
}

int log(object id, mapping file)
{
  if(id->misc->accessed || query("extcount")==({})) {
    return 0;
  }

  // Although we are not 100% sure we should make a count, nothing bad happens if we shouldn't and still do.
  foreach(query("extcount"), string tmp)
    if(search(id->realfile,tmp)!=-1)
    {
      query_num(id->not_query, 1);
      id->misc->accessed = "1";
    }

  return 0;
}

string tag_accessed(string tag, mapping m, object id)
{
  int counts, n, prec, q, timep;
  string real, res;
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
    else if(id->misc->accessed != "1") 
    {
      counts = query_num(id->not_query, (int)m->add||1);
      id->misc->accessed = "1";
    } else {
      counts = query_num(id->not_query, (int)m->add||0);
    }
      
    m->file=id->not_query;
  }
  
  if(m->reset)
  {
    // FIXME: There are a few cases where users can avoid this.
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
      return id->conf->api_functions()->tag_time_wrapper[0](id,database_created(0),m);
    return id->conf->api_functions()->tag_time_wrapper[0](id,database_created(m->file),m);
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
      return rxml_error(tag, "Access count per what?", id);
    }
  }

  if(prec=(int)m->prec)
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

mapping query_tag_callers()
{
  return (["accessed":tag_accessed]);
}

int api_query_num(object id, string f, int|void i)
{
  NOCACHE();
  return query_num(f, i);
}

void define_API_functions()
{
  add_api_function("accessed", api_query_num, ({ "string", 0,"int" }));
}
