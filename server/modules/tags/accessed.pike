// This is a roxen module. Copyright © 1996 - 2000, Roxen IS.
//
// This module maintains an accessed database,
// to be used by the <accessed> tag also provided
// by this module.
//

constant cvs_version="$Id: accessed.pike,v 1.29 2000/04/06 06:16:05 wing Exp $";
constant thread_safe=1;
constant language = roxen->language;

#include <module.h>

inherit "module";
inherit "roxenlib";

int cnum=0;
mapping fton=([]); // Holds the access database

Stdio.File database, names_file;

constant module_type = MODULE_PARSER | MODULE_LOGGER;
constant module_name = "Accessed counter";
constant module_doc  =
"This module provides accessed counters, through the "
<tt>&lt;accessed&gt;</tt> tag and the <tt>&amp;page.accessed;</tt> entity.";

string status()
{
  return sizeof(fton)+" entries in the accessed database.<br />";
}

void create(Configuration c)
{
  defvar("Accesslog","$LOGDIR/"+short_name(c?c->name:".")+"/Accessed",
	 "Access database file", TYPE_FILE|VAR_MORE,
	 "This file will be used to keep the database of file accesses.");

  defvar("extcount", ({  }), "Extensions to access count",
          TYPE_STRING_LIST,
         "Always count accesses to files ending with these extensions. "
	 "By default only accessed to files that actually contain a "
	 "<tt>&lt;accessed&gt;</tt> tag or the <tt>&amp;page.accessed;</tt> "
	 "entity will be counted. "
	 "<p>Note: This module must be reloaded before a change of this "
	 "setting takes effect.");

  defvar("close_db", 1, "Close the database if inactive",
	 TYPE_FLAG|VAR_MORE,
	 "If set, the accessed database will be closed if it is not used for "
	 "8 seconds. This saves resourses on servers with many sites.");
}

TAGDOCUMENTATION
#ifdef manual
constant tagdoc=([
  "&page.accessed;":#"<desc ent>Generates an access counter that shows how many
 times the page has been accessed.</desc>",

  "accessed":#"<desc tag><short>Generates an access counter that shows how many
 times the page has been accessed.</short> A file, AccessedDB, in the logs directory is used to
 store the number of accesses to each page. By default the access count is
 only kept for files that actually contain an accessed-tag,
 but can also be configured to count all files of a certain type.
 <ex><accessed/></ex>
 </desc>

<attr name=add value=number>
 Increments the number of accesses with this number instead of one,
 each time the page is accessed.</attr>

<attr name=addreal>
 Prints the real number of accesses as an HTML comment. Useful if you
 use the cheat attribute and still want to keep track of the
 real number of accesses.</attr>

<attr name=case value=upper|lower|capitalize>
 Sets the result to upper case, lower case or with the first letter capitalized.
</attr>

<attr name=cheat value=number>
 Adds this number of accesses to the actual number of accesses before
 printing the result. If your page has been accessed 72 times and you
 add &lt;accessed cheat=100&gt; the result will be 172.</attr>

<attr name=database>
 Works like the since attribute, but counts from the day the first entry in the entire accessed database was made.
</attr>

<attr name=factor value=percent>
 Multiplies the actual number of accesses by the factor. E.g. <accessed factor=50>
 displays half the actual value.
</attr>

<attr name=file value=filename>
 Shows the number of times the page filename has been
 accessed instead of how many times the current page has been accessed.
 If the filename does not begin with \"/\", it is assumed to be a URL
 relative to the directory containing the page with the
 accessed tag. Note, that you have to type in the full name
 of the file. If there is a file named tmp/index.html, you cannot
 shorten the name to tmp/, even if you've set Roxen up to use
 index.html as a default page. The filename refers to the
 virtual filesystem.

 One limitation is that you cannot reference a file that does not
 have its own &lt;accessed&gt; tag. You can use &lt;accessed
 silent&gt; on a page if you want it to be possible to count accesses
 to it, but don't want an access counter to show on the page itself.
</attr>

<attr name=lang value=langcodes>
 Will print the result as words in the chosen language if used together
 with type=string.

 <ex><accessed type=\"string\"/></ex>
 <ex><accessed type=\"string\" lang=\"sv\"/></ex>
</attr>

<attr name=per value=second|minute|hour|day|week|month|year>
 Shows the number of accesses per unit of time.

 <ex><accessed per=\"week\"/></ex>
</attr>

<attr name=prec value=number>
 Rounds the number of accesses to this number of significant digits. If
 prec=2 show 12000 instead of 12148.
</attr>

<attr name=reset>
 Resets the counter. This should probably only be done under very
 special conditions, maybe within an &lt;if&gt; statement.

 This can be used together with the file argument, but it is limited
 to files in the current- and sub-directories.
</attr>

<attr name=silent>
 Print nothing. The access count will be updated but not printed. This
 option is useful because the access count is normally only kept for
 pages with actual &lt;access&gt; on them. &lt;accessed
 file=filename&gt; can then be used to get the access count for the
 page with the silent counter.
</attr>

<attr name=since>
 Inserts the date that the access count started. The language will
 depend on the lang tag, default is English. All normal date
 related attributes can be used. See the &lt;date&gt; tag.

 <ex><accessed since=\"\"/></ex>
</attr>

<attr name=type value=number|string|roman|iso|discordian|stardate|mcdonalds|linus|ordered>
 Specifies how the count are to be presented. Some of these are only
 useful together with the since attribute.

 <ex><accessed type=\"roman\"/></ex>
 <ex><accessed since=\"\" type=\"iso\"/></ex>
 <ex><accessed since=\"\" type=\"discordian\"/></ex>
 <ex><accessed since=\"\" type=\"stardate\"/></ex>
 <ex><accessed type=\"mcdonalds\"/></ex>
 <ex><accessed type=\"linus\"/></ex>
 <ex><accessed type=\"ordered\"/></ex>

</attr>"]);
#endif

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

void start()
{
  define_API_functions();
  query_tag_set()->prepare_context=set_entities;

  if(olf != QUERY(Accesslog))
  {
    olf = QUERY(Accesslog);
    mkdirhier(query("Accesslog"));
    if(names_file=open(olf+".names", "wrca"))
    {
      cnum=0;
      array tmp=parse_accessed_database(names_file->read(0x7ffffff));
      fton=tmp[0];
      cnum=tmp[1];
      names_file = 0;
    }
  }
}

class Entity_page_accessed {
  int rxml_var_eval(RXML.Context c) {
    int count;
    if(c->id->misc->accessed)
      count=query_num(c->id->not_query, 0);
    else {
      count=query_num(c->id->not_query, 1);
      c->id->misc->accessed=1;
    }
    return count;
  }
}

void set_entities(RXML.Context c) {
  c->set_var("accessed", Entity_page_accessed(), "page");
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

    open_names_file();
    names_file->write(file+":"+cnum+"\n");

    database->seek(p*8);
    database->write(sprintf("%4c", 0));
    database_set_created(file);
  }
  if(database->seek(p*8) > -1)
  {
    sscanf(database->read(4), "%4c", n);
    if (count)
    {
      n+=count;
      database->seek(p*8);
      database->write(sprintf("%4c", n));
    }
    //lock->free();
    return n;
  }
  //lock->free();
  return 0;
}

int log(RequestID id, mapping file)
{
  if(id->misc->accessed || query("extcount")==({})) {
    return 0;
  }

  // Although we are not 100% sure we should make a count, nothing bad happens if we shouldn't and still do.
  foreach(query("extcount"), string tmp)
    if(sizeof(tmp) && search(id->realfile,tmp)!=-1)
    {
      query_num(id->not_query, 1);
      id->misc->accessed = "1";
    }

  return 0;
}

string tag_accessed(string tag, mapping m, RequestID id)
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
    }
    else
      // On a web hotell you don't want the guests to be alowed to reset
      // eachothers counters.
      RXML.run_error("You do not have access to reset this counter.");
  }

  if(m->silent)
    return "";

  if(m->since)
  {
    if(m->database)
      return tagtime(database_created(0),m,id,language);
    return tagtime(database_created(m->file),m,id,language);
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
      RXML.parse_error("Access count per what?");
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
    res="More than "+language("eng", "number", id)(counts*ipow(10, q))
        + " served.";
    break;

   case "linus":
    res=counts+" since "+ctime(database_created(0));
    break;

   case "ordered":
    m->type="string";
    res=number2string(counts,m,language(m->lang||id->misc->defines->theme_language, "ordered",id));
    break;

   default:
    res=number2string(counts,m,language(m->lang||id->misc->defines->theme_language, "number",id));
  }
  return res+(m->addreal?real:"");
}

int api_query_num(RequestID id, string f, int|void i)
{
  NOCACHE();
  return query_num(f, i);
}

void define_API_functions()
{
  add_api_function("accessed", api_query_num, ({ "string", 0,"int" }));
}
