/*
 * $Id: Roxen.pmod,v 1.30 2000/08/23 03:14:20 nilsson Exp $
 *
 * Various helper functions.
 *
 * Henrik Grubbström 1999-05-03
 */

#include <config.h>
inherit "roxenlib";

// Low-level C-roxen optimization functions.
#if constant( _Roxen )
inherit _Roxen;
#endif

/*
 * TODO:
 *
 * o Quota: Fix support for the index file.
 *
 */

#ifdef QUOTA_DEBUG
#define QD_WRITE(X)	werror(X)
#else /* !QUOTA_DEBUG */
#define QD_WRITE(X)
#endif /* QUOTA_DEBUG */

class QuotaDB
{
#if constant(create_thread)
  object(Thread.Mutex) lock = Thread.Mutex();
#define LOCK()		mixed key__; catch { key__ = lock->lock(); }
#define UNLOCK()	do { if (key__) destruct(key__); } while(0)
#else /* !constant(create_thread) */
#define LOCK()
#define UNLOCK()
#endif /* constant(create_thread) */

  constant READ_BUF_SIZE = 256;
  constant CACHE_SIZE_LIMIT = 512;

  string base;

  object catalog_file;
  object data_file;

  mapping(string:int) new_entries_cache = ([]);
  mapping(string:object) active_objects = ([]);

  array(int) index;
  array(string) index_acc;
  int acc_scale;

  int next_offset;

  static class QuotaEntry
  {
    string name;
    int data_offset;

    static int usage;
    static int quota;

    static void store()
    {
      LOCK();

      QD_WRITE(sprintf("QuotaEntry::store(): Usage for %O is now %O(%O)\n",
		       name, usage, quota));

      data_file->seek(data_offset);
      data_file->write(sprintf("%4c", usage));

      UNLOCK();
    }

    static void read()
    {
      LOCK();

      data_file->seek(data_offset);
      string s = data_file->read(4);

      usage = 0;
      sscanf(s, "%4c", usage);

      if (usage < 0) {
	// No negative usage.
	usage = 0;
      }

      QD_WRITE(sprintf("QuotaEntry::read(): Usage for %O is %O(%O)\n",
		       name, usage, quota));

      UNLOCK();
    }

    void create(string n, int d_o, int q)
    {
      QD_WRITE(sprintf("QuotaEntry(%O, %O, %O)\n", n, d_o, q));

      name = n;
      data_offset = d_o;
      quota = q;

      read();
    }

    int check_quota(string uri, int amount)
    {
      QD_WRITE(sprintf("QuotaEntry::check_quota(%O, %O): usage:%d(%d)\n",
		       uri, amount, usage, quota));

      if (!quota) {
	// No quota at all.
	return 0;
      }

      if (amount == 0x7fffffff) {
	// Workaround for FTP.
	return 1;
      }

      return(usage + amount <= quota);
    }

    int allocate(string uri, int amount)
    {
      QD_WRITE(sprintf("QuotaEntry::allocate(%O, %O): usage:%d => %d(%d)\n",
		       uri, amount, usage, usage + amount, quota));

      usage += amount;

      if (usage < 0) {
	// No negative usage...
	usage = 0;
      }

      store();

      return(usage <= quota);
    }

    int deallocate(string uri, int amount)
    {
      return(allocate(uri, -amount));
    }

    int get_usage(string uri)
    {
      return usage;
    }

    void set_usage(string uri, int amount)
    {
      usage = amount;

      store();
    }

#if !constant(set_weak_flag)
    static int refs;

    void add_ref()
    {
      refs++;
    }

    void free_ref()
    {
      if (!(--refs)) {
	destruct();
      }
    }
  }

  static class QuotaProxy
  {
    static object(QuotaEntry) master;

    function(string, int:int) check_quota;
    function(string, int:int) allocate;
    function(string, int:int) deallocate;
    function(string, int:void) set_usage;
    function(string:int) get_usage;

    void create(object(QuotaEntry) m)
    {
      master = m;
      master->add_ref();
      check_quota = master->check_quota;
      allocate = master->allocate;
      deallocate = master->deallocate;
      set_usage = master->set_usage;
      get_usage = master->get_usage;
    }

    void destroy()
    {
      master->free_ref();
    }
#endif /* !constant(set_weak_flag) */
  }

  static object read_entry(int offset, int|void quota)
  {
    QD_WRITE(sprintf("QuotaDB::read_entry(%O, %O)\n", offset, quota));

    catalog_file->seek(offset);

    string data = catalog_file->read(READ_BUF_SIZE);

    if (data == "") {
      QD_WRITE(sprintf("QuotaDB::read_entry(%O, %O): At EOF\n",
		       offset, quota));

      return 0;
    }

    int len;
    int data_offset;
    string key;

    sscanf(data[..7], "%4c%4c", len, data_offset);
    if (len > sizeof(data)) {
      key = data[8..] + catalog_file->read(len - sizeof(data));

      len -= 8;

      if (sizeof(key) != len) {
	error(sprintf("Failed to read catalog entry at offset %d.\n"
		      "len: %d, sizeof(key):%d\n",
		      offset, len, sizeof(key)));
      }
    } else {
      key = data[8..len-1];
      catalog_file->seek(offset + 8 + sizeof(key));
    }

    return QuotaEntry(key, data_offset, quota);
  }

  static object open(string fname, int|void create_new)
  {
    object f = Stdio.File();
    string mode = create_new?"rwc":"rw";

    if (!f->open(fname, mode)) {
      error(sprintf("Failed to open quota file %O.\n", fname));
    }
    if (f->try_lock && !f->try_lock()) {
      error(sprintf("Failed to lock quota file %O.\n", fname));
    }
    return(f);
  }

  static void init_index_acc()
  {
    /* Set up the index accellerator.
     * sizeof(index_acc) ~ sqrt(sizeof(index))
     */
    acc_scale = 1;
    if (sizeof(index)) {
      int i = sizeof(index)/2;

      while (i) {
	i /= 4;
	acc_scale *= 2;
      }
    }
    index_acc = allocate((sizeof(index) + acc_scale -1)/acc_scale);

    QD_WRITE(sprintf("QuotaDB()::init_index_acc(): "
		     "sizeof(index):%d, sizeof(index_acc):%d acc_scale:%d\n",
		     sizeof(index), sizeof(index_acc), acc_scale));
  }

  void rebuild_index()
  {
    array(string) new_keys = sort(indices(new_entries_cache));

    int prev;
    array(int) new_index = ({});

    foreach(new_keys, string key) {
      QD_WRITE(sprintf("QuotaDB::rebuild_index(): key:%O lo:0 hi:%d\n",
		       key, sizeof(index_acc)));

      int lo;
      int hi = sizeof(index_acc);
      if (hi) {
	do {
	  // Loop invariants:
	  //   hi is an element > key.
	  //   lo-1 is an element < key.

	  int probe = (lo + hi)/2;

	  QD_WRITE(sprintf("QuotaDB::rebuild_index(): acc: "
			   "key:%O lo:%d probe:%d hi:%d\n",
			   key, lo, probe, hi));

	  if (!index_acc[probe]) {
	    object e = read_entry(index[probe * acc_scale]);

	    index_acc[probe] = e->name;
	  }
	  if (index_acc[probe] < key) {
	    lo = probe + 1;
	  } else if (index_acc[probe] > key) {
	    hi = probe;
	  } else {
	    /* Found */
	    // Shouldn't happen...
	    break;
	  }
	} while(lo < hi);

	if (lo < hi) {
	  // Found...
	  // Shouldn't happen, but...
	  // Skip to the next key...
	  continue;
	}
	if (hi) {
	  hi *= acc_scale;
	  lo = hi - acc_scale;

	  if (hi > sizeof(index)) {
	    hi = sizeof(index);
	  }

	  do {
	    // Same loop invariants as above.

	    int probe = (lo + hi)/2;

	    QD_WRITE(sprintf("QuotaDB::rebuild_index(): "
			     "key:%O lo:%d probe:%d hi:%d\n",
			     key, lo, probe, hi));
	    
	    object e = read_entry(index[probe]);
	    if (e->name < key) {
	      lo = probe + 1;
	    } else if (e->name > key) {
	      hi = probe;
	    } else {
	      /* Found */
	      // Shouldn't happen...
	      break;
	    }
	  } while (lo < hi);
	  if (lo < hi) {
	    // Found...
	    // Shouldn't happen, but...
	    // Skip to the next key...
	    continue;
	  }
	}
	new_index += index[prev..hi-1] + ({ new_entries_cache[key] });
	prev = hi;
      } else {
	new_index += ({ new_entries_cache[key] });
      }
    }

    // Add the trailing elements...
    new_index += index[prev..];

    QD_WRITE("Index rebuilt.\n");

    LOCK();

    object index_file = open(base + ".index.new", 1);
    string to_write = sprintf("%@4c", new_index);
    if (index_file->write(to_write) != sizeof(to_write)) {
      index_file->close();
      rm(base + ".index.new");
    } else {
      mv(base + ".index.new", base + ".index");
    }

    index = new_index;
    init_index_acc();

    UNLOCK();

    foreach(new_keys, string key) {
      m_delete(new_entries_cache, key);
    }
  }

  static object low_lookup(string key, int quota)
  {
    QD_WRITE(sprintf("QuotaDB::low_lookup(%O, %O)\n", key, quota));

    int cat_offset;

    if (!zero_type(cat_offset = new_entries_cache[key])) {
      QD_WRITE(sprintf("QuotaDB::low_lookup(%O, %O): "
		       "Found in new entries cache.\n", key, quota));
      return read_entry(cat_offset, quota);
    }

    /* Try the index file. */

    /* First use the accellerated index. */
    int lo;
    int hi = sizeof(index_acc);
    if (hi) {
      do {
	// Loop invariants:
	//   hi is an element that is > key.
	//   lo-1 is an element that is < key.
	int probe = (lo + hi)/2;

	QD_WRITE(sprintf("QuotaDB:low_lookup(%O): "
			 "In acc: lo:%d, probe:%d, hi:%d\n",
			 key, lo, probe, hi));

	if (!index_acc[probe]) {
	  object e = read_entry(index[probe * acc_scale], quota);

	  index_acc[probe] = e->name;

	  if (key == e->name) {
	    /* Found in e */
	    QD_WRITE(sprintf("QuotaDB:low_lookup(%O): In acc: Found at %d\n",
			     key, probe * acc_scale));
	    return e;
	  }
	}
	if (index_acc[probe] < key) {
	  lo = probe + 1;
	} else if (index_acc[probe] > key) {
	  hi = probe;
	} else {
	  /* Found */
	  QD_WRITE(sprintf("QuotaDB:low_lookup(%O): In acc: Found at %d\n",
			   key, probe * acc_scale));
	  return read_entry(index[probe * acc_scale], quota);
	}
      } while(lo < hi);
      // At this point hi is the first element that is > key.
      // Not in the accellerated index.

      if (hi) {
	// Go to disk

	hi *= acc_scale;
	lo = hi - acc_scale;

	if (hi > sizeof(index)) {
	  hi = sizeof(index);
	}

	do {
	  // Same loop invariant as above.

	  int probe = (lo + hi)/2;

	  QD_WRITE(sprintf("QuotaDB:low_lookup(%O): lo:%d, probe:%d, hi:%d\n",
			   key, lo, probe, hi));

	  object e = read_entry(index[probe], quota);
	
	  if (e->name < key) {
	    lo = probe + 1;
	  } else if (e->name > key) {
	    hi = probe;
	  } else {
	    /* Found */
	    QD_WRITE(sprintf("QuotaDB:low_lookup(%O): Found at %d\n",
			     key, probe));
	    return e;
	  }
	} while (lo < hi);
      }
    }

    QD_WRITE(sprintf("QuotaDB::low_lookup(%O): Not found\n", key));

    return 0;
  }

  object lookup(string key, int quota)
  {
    QD_WRITE(sprintf("QuotaDB::lookup(%O, %O)\n", key, quota));

    LOCK();

    object res;

    if (res = active_objects[key]) {
      QD_WRITE(sprintf("QuotaDB::lookup(%O, %O): User in active objects.\n",
		       key, quota));

#if constant(set_weak_flag)
      return res;
#else /* !constant(set_weak_flag) */
      return QuotaProxy(res);
#endif /* constant(set_weak_flag) */
    }
    if (res = low_lookup(key, quota)) {
      active_objects[key] = res;

#if constant(set_weak_flag)
      return res;
#else /* !constant(set_weak_flag) */
      return QuotaProxy(res);
#endif /* constant(set_weak_flag) */
    }

    QD_WRITE(sprintf("QuotaDB::lookup(%O, %O): New user.\n", key, quota));

    // Search to EOF.
    data_file->seek(-1);
    data_file->read(1);

    catalog_file->seek(next_offset);

    // We should now be at EOF.

    int data_offset = data_file->tell();

    // Initialize.
    if (data_file->write(sprintf("%4c", 0)) != 4) {
      error(sprintf("write() failed for quota data file!\n"));
    }
    string entry = sprintf("%4c%4c%s", sizeof(key)+8, data_offset, key);

    if (catalog_file->write(entry) != sizeof(entry)) {
      error(sprintf("write() failed for quota catalog file!\n"));
    }

    new_entries_cache[key] = next_offset;
    next_offset = catalog_file->tell();

    if (sizeof(new_entries_cache) > CACHE_SIZE_LIMIT) {
      rebuild_index();
    }

    // low_lookup will always succeed at this point.
    return low_lookup(key, quota);
  }

  void create(string base_name, int|void create_new)
  {
    base = base_name;

    catalog_file = open(base_name + ".cat", create_new);
    data_file = open(base_name + ".data", create_new);
    object index_file = open(base_name + ".index", 1);

#if constant(set_weak_flag)
    set_weak_flag(active_objects, 1);
#endif /* constant(set_weak_flag) */

    /* Initialize the new_entries table. */
    array index_st = index_file->stat();
    if (!index_st || !sizeof(index_st)) {
      error(sprintf("stat() failed for quota index file!\n"));
    }
    array data_st = data_file->stat();
    if (!data_st || !sizeof(data_st)) {
      error(sprintf("stat() failed for quota data file!\n"));
    }
    if (index_st[1] < 0) {
      error("quota index file isn't a regular file!\n");
    }
    if (data_st[1] < 0) {
      error("quota data file isn't a regular file!\n");
    }
    if (data_st[1] < index_st[1]) {
      error("quota data file is shorter than the index file!\n");
    }
    if (index_st[1] & 3) {
      error("quota index file has odd length!\n");
    }
    if (data_st[1] & 3) {
      error("quota data file has odd length!\n");
    }

    /* Read the index, and find the last entry in the catalog file.
     */
    int i;
    array(string) index_str = index_file->read()/4;
    index = allocate(sizeof(index_str));

    if (sizeof(index_str) && (sizeof(index_str[-1]) != 4)) {
      error("Truncated read of the index file!\n");
    }

    foreach(index_str, string offset_str) {
      int offset;
      sscanf(offset_str, "%4c", offset);
      index[i++] = offset;
      if (offset > next_offset) {
	next_offset = offset;
      }
    }

    init_index_acc();

    if (sizeof(index)) {
      /* Skip past the last entry in the catalog file */
      mixed entry = read_entry(next_offset);
      next_offset = catalog_file->tell();
    }

    if (index_st[1] < data_st[1]) {
      /* Put everything else in the new_entries_cache */
      while (mixed entry = read_entry(next_offset)) {
	new_entries_cache[entry->name] = next_offset;
	next_offset = catalog_file->tell();
      }

      /* Clean up the index. */
      rebuild_index();
    }
  }
}


#define CTX()   
class EScope
{
  string scope;
  
  void delete( string var )
  {
    RXML.Context ctx = RXML.get_context( );  
    ctx->delete_var( var, scope );
  }

  string name()
  {
    RXML.Context ctx = RXML.get_context( );  
    return scope == "_" ? ctx->current_scope() : scope;
  }

  /*static*/ mixed `[]( string what )
  {
    RXML.Context ctx = RXML.get_context( );  
    return ctx->get_var( what, scope );
  }

  /*static*/ mixed `->( string what )
  {
    return `[]( what );
  }

  /*static*/ mixed `[]=( string what, mixed nval )
  {
    RXML.Context ctx = RXML.get_context( );  
    ctx->set_var( what, nval, scope );
    return nval;
  }

  /*static*/ mixed `->=( string what, mixed nval )
  {
    return `[]=( what, nval );
  }

  /*static*/ array(string) _indices( )
  {
    RXML.Context ctx = RXML.get_context( );  
    return ctx->list_var( scope );
  } 

  /*static*/ array(string) _values( )
  {
    RXML.Context ctx = RXML.get_context( );  
    return map( ctx->list_var( scope ), `[] );
  } 

  /*static*/ void create( string _scope )
  {
    scope = _scope;
  }
}

class SRestore
{
  mapping osc = ([]);
  void destroy()
  {
    foreach( indices( osc ), string o ) 
      add_constant( o, osc[o] );
    add_constant( "roxen", roxenp() );
  }
}

SRestore add_scope_constants( string|void name )
{
  SRestore res = SRestore();
  mapping ac = all_constants();
  if(!name) name = "";
  if( RXML.get_context() )
  {
    foreach( RXML.get_context()->list_scopes()|({"_"}), string scope )
    {
      res->osc[ name+scope ] = ac[ name+scope ];
      add_constant( name+scope, EScope( scope ) );
    }
  }
  return res;
}

//! A mapping suitable for Parser.HTML.add_entities to initialize it
//! to transform the standard character reference entities.
mapping(string:string) parser_charref_table =
  lambda () {
    mapping(string:string) table = ([]);
    for (int i = 0; i < sizeof (replace_entities); i++) {
      string chref = replace_entities[i];
      table[chref[1..sizeof (chref) - 2]] = replace_values[i];
    }
    return table;
  }();



// RXML complementary stuff shared between configurations.

class ScopeRoxen {
  inherit RXML.Scope;

  string pike_version=predef::version();
  int ssl_strength=0;

#if constant(SSL)
  void create() {
    ssl_strength=40;
#if constant(SSL.constants.CIPHER_des)
    if(SSL.constants.CIPHER_algorithms[SSL.constants.CIPHER_des])
      ssl_strength=128;
    if(SSL.constants.CIPHER_algorithms[SSL.constants.CIPHER_3des])
      ssl_strength=168;
#endif /* !constant(SSL.constants.CIPHER_des) */
  }
#endif

  mixed `[] (string var, void|RXML.Context c, void|string scope) {
    switch(var)
    {
     case "uptime":
       c->id->misc->cacheable=1;
       return (time(1)-roxenp()->start_time);
     case "uptime-days":
       c->id->misc->cacheable=3600*2;
       return (time(1)-roxenp()->start_time)/3600/24;
     case "uptime-hours":
       c->id->misc->cacheable=1800;
       return (time(1)-roxenp()->start_time)/3600;
     case "uptime-minutes":
       c->id->misc->cacheable=60;
       return (time(1)-roxenp()->start_time)/60;
     case "hits-per-minute":
       c->id->misc->cacheable=60;
       return c->id->conf->requests / ((time(1)-roxenp()->start_time)/60 + 1);
     case "hits":
       c->id->misc->cacheable=0;
       return c->id->conf->requests;
     case "sent-mb":
       c->id->misc->cacheacle=10;
       return sprintf("%1.2f",c->id->conf->sent / (1024.0*1024.0));
     case "sent":
       c->id->misc->cacheable=0;
       return c->id->conf->sent;
     case "sent-per-minute":
       c->id->misc->cacheable=60;
       return c->id->conf->sent / ((time(1)-roxenp()->start_time)/60 || 1);
     case "sent-kbit-per-second":
       c->id->misc->cacheable=1;
       return sprintf("%1.2f",((c->id->conf->sent*8)/1024.0/
                               (time(1)-roxenp()->start_time || 1)));
     case "ssl-strength":
       return ssl_strength;
     case "pike-version":
       return pike_version;
     case "version":
       return roxenp()->version();
     case "time":
       c->id->misc->cacheable=1;
       return time(1);
     case "server":
       return c->id->conf->query("MyWorldLocation");
     case "domain":
       string tmp=c->id->conf->query("MyWorldLocation");
       sscanf(tmp, "%*s//%s", tmp);
       sscanf(tmp, "%s:", tmp);
       sscanf(tmp, "%s/", tmp);
       return tmp;
     case "locale":
       c->id->misc->cachealbe=0;
       return roxenp()->locale->get();
     default:
       return RXML.nil;
    }
    :: `[] (var, c, scope);
  }

  array(string) _indices() {
    return ({"uptime", "uptime-days", "uptime-hours", "uptime-minutes",
	     "hits-per-minute", "hits", "sent-mb", "sent",
             "sent-per-minute", "sent-kbit-per-second", "ssl-strength",
              "pike-version", "version", "time", "server", "domain",
	     "locale"});
  }

  string _sprintf() { return "RXML.Scope(roxen)"; }
}

class ScopePage {
  inherit RXML.Scope;
  constant converter=(["fgcolor":"fgcolor", "bgcolor":"bgcolor",
		       "theme-bgcolor":"theme_bgcolor", "theme-fgcolor":"theme_fgcolor",
		       "theme-language":"theme_language"]);
  constant in_defines=aggregate_multiset(@indices(converter));

  mixed `[] (string var, void|RXML.Context c, void|string scope) {
    c->id->misc->cacheable=0;
    switch (var) {
      case "pathinfo": return c->id->misc->path_info;
    }
    if(in_defines[var])
      return c->id->misc->defines[converter[var]];
    if(objectp(c->id->misc->scope_page[var])) return c->id->misc->scope_page[var]->rxml_var_eval(c, var, "page");
    return c->id->misc->scope_page[var];
  }

  mixed `[]= (string var, mixed val, void|RXML.Context c, void|string scope_name) {
    switch (var) {
      case "pathinfo": return c->id->misc->path_info = val;
    }
    if(in_defines[var])
      return c->id->misc->defines[converter[var]]=val;
    return c->id->misc->scope_page[var]=val;
  }

  array(string) _indices(void|RXML.Context c) {
    if(!c) return ({});
    c->id->misc->cacheable=0;
    array ind=indices(c->id->misc->scope_page);
    foreach(indices(in_defines), string def)
      if(c->id->misc->defines[converter[def]]) ind+=({def});
    return ind + ({"pathinfo"});
  }

  void m_delete (string var, void|RXML.Context c, void|string scope_name) {
    if(!c) return;
    switch (var) {
      case "pathinfo":
	predef::m_delete (c->id->misc, "pathinfo");
	return;
    }
    if(in_defines[var]) {
      if(var[0..4]=="theme")
	predef::m_delete(c->id->misc->defines, converter[var]);
      else
	::m_delete(var, c, scope_name);
      return;
    }
    predef::m_delete(c->id->misc->scope_page, var);
  }

  string _sprintf() { return "RXML.Scope(page)"; }
}

class ScopeCookie {
  inherit RXML.Scope;

  mixed `[] (string var, void|RXML.Context c, void|string scope) {
    if(!c) return RXML.nil;
    c->id->misc->cacheable=0;
    return c->id->cookies[var];
  }

  mixed `[]= (string var, mixed val, void|RXML.Context c, void|string scope_name) {
    if(c && c->id->cookies[var]!=val) {
      c->id->cookies[var]=val;
      add_http_header(c->id->misc->defines[" _extra_heads"], "Set-Cookie", http_encode_cookie(var)+
		      "="+http_encode_cookie( (string)(val||"") )+
		      "; expires="+http_date(time(1)+(3600*24*365*2))+"; path=/");
    }
    return RXML.nil;
  }

  array(string) _indices(void|RXML.Context c) {
    if(!c) return ({});
    c->id->misc->cacheable=0;
    return indices(c->id->cookies);
  }

  void m_delete (string var, void|RXML.Context c, void|string scope_name) {
    if(!c || !c->id->cookies[var]) return;
    predef::m_delete(c->id->cookies, var);
    add_http_header(c->id->misc->defines[" _extra_heads"], "Set-Cookie",
		    http_encode_cookie(var)+"=; expires=Thu, 01-Jan-70 00:00:01 GMT; path=/");
  }

  string _sprintf() { return "RXML.Scope(Cookie)"; }
}

RXML.Scope scope_roxen=ScopeRoxen();
RXML.Scope scope_page=ScopePage();
RXML.Scope scope_cookie=ScopeCookie();

RXML.TagSet entities_tag_set = class
// This tag set always has the lowest priority.
{
  inherit RXML.TagSet;

  void prepare_context (RXML.Context c) {
    c->add_scope("roxen",scope_roxen);
    c->id->misc->scope_page=([]);
    c->add_scope("page",scope_page);
    c->add_scope("cookie", scope_cookie);
    c->add_scope("form", c->id->variables);
    c->add_scope("client", c->id->client_var);
    c->add_scope("var", ([]) );
  }


  void create (string name)
  {
    ::create (name);
    // Note: No string entities are replaced when the result type for
    // the parser is t_xml or t_html.
    add_string_entities (parser_charref_table);
  }
} ("entities_tag_set");


constant monthnum=(["Jan":0, "Feb":1, "Mar":2, "Apr":3, "May":4, "Jun":5,
		    "Jul":6, "Aug":7, "Sep":8, "Oct":9, "Nov":10, "Dec":11,
		    "jan":0, "feb":1, "mar":2, "apr":3, "may":4, "jun":5,
		    "jul":6, "aug":7, "sep":8, "oct":9, "nov":10, "dec":11,]);

#define MAX_SINCE_CACHE 16384
static mapping(string:int) since_cache=([ ]);
array(int) parse_since(string date)
{
  if(!date || sizeof(date)<14) return({0,-1});
  int t=0, length = -1;

#if constant(mktime)
  string dat=lower_case(date);
  sscanf(dat+"; length=", "%*s, %s; length=%d", dat, length);

  if(!(t=since_cache[dat])) {
    int day, year = -1, month, hour, minute, second;
    string m;
    if(sscanf(dat, "%d-%s-%d %d:%d:%d", day, m, year, hour, minute, second)>2)
    {
      month=monthnum[m];
    } else if(dat[2]==',') { // I bet a buck that this never happens
      sscanf(dat, "%*s, %d %s %d %d:%d:%d", day, m, year, hour, minute, second);
      month=monthnum[m];
    } else if(!(int)dat) {
      sscanf(dat, "%*[^ ] %s %d %d:%d:%d %d", m, day, hour, minute, second, year);
      month=monthnum[m];
    } else {
      sscanf(dat, "%d %s %d %d:%d:%d", day, m, year, hour, minute, second);
      month=monthnum[m];
    }

    if(year >= 0) {
      // Fudge year to be localtime et al compatible.
      if (year < 60) {
	// Assume year 0 - 59 is really year 2000 - 2059.
	// Can't people stop using two digit years?
	year += 100;
      } else if (year >= 1900) {
	year -= 1900;
      }
      catch {
	t = mktime(second, minute, hour, day, month, year, 0, 0);
      };
    } else {
      report_debug("Could not parse \""+date+"\" to a time int.");
    }

    if (sizeof(since_cache) > MAX_SINCE_CACHE)
      since_cache = ([]);
    since_cache[dat]=t;
  }
#endif /* constant(mktime) */
  return ({ t, length });
}

// OBSOLETED by parse_since()
int is_modified(string a, int t, void|int len)
{
  array vals=parse_since(a);
  if(len && len!=vals[1]) return 0;
  if(vals[0]<t) return 0;
  return 1;
}

int httpdate_to_time(string date)
{
  return parse_since(date)[0]||-1;
}

string get_server_url(object c) {
  string url=c->query("MyWorldLocation");
  if(stringp(url) && sizeof(url)) return url;
  array(string) urls=c->query("URLs");
  return get_world(urls);
}

string get_world(array(string) urls) {
  if(!sizeof(urls)) return 0;

  string url=urls[0];
  foreach( ({"http:","fhttp:","https:","ftp:"}), string p)
    foreach(urls, string u)
      if(u[0..sizeof(p)-1]==p) {
	url=u;
	break;
      }

  string protocol, server, path="";
  int port;
  if(sscanf(url, "%s://%s:%d/%s", protocol, server, port, path)!=4 &&
     sscanf(url, "%s://%s:%d", protocol, server, port)!=3 &&
     sscanf(url, "%s://%s/%s", protocol, server, path)!=3 &&
     sscanf(url, "%s://%s", protocol, server)!=2 )
    return 0;

  if(protocol=="fhttp") protocol="http";

  array hosts=({ gethostname() }), dns;
  catch(dns=Protocols.DNS.client()->gethostbyname(hosts[0]));
  if(dns && sizeof(dns))
    hosts+=dns[2]+dns[1];

  foreach(hosts, string host)
    if(glob(server, host)) {
      server=host;
      break;
    }

  if(port) return sprintf("%s://%s:%d/%s", protocol, server, port, path);
  return sprintf("%s://%s/%s", protocol, server, path);
}

RoxenModule get_owning_module (object|function thing)
//! Tries to find out which module the thing belongs to, if any. The
//! thing can be e.g. a module object, a Tag object or a simple_tag
//! callback.
{
  if (functionp (thing)) thing = function_object (thing);
  if (objectp (thing)) {
    if (thing->is_module) return thing;
    if (object parent =
	functionp (object_program (thing)) &&
	function_object (object_program (thing))) {
      // FIXME: This way of finding the module for a tag is ugly.
      if (parent->is_module) return parent;
    }
  }
  return 0;
}

Configuration get_owning_config (object|function thing)
//! Tries to find out which configuration the thing belongs to, if
//! any. The thing can be e.g. a config or module object, a Tag object
//! or a simple_tag callback.
{
  if (RoxenModule mod = get_owning_module (thing))
    return mod->my_configuration();
  if (functionp (thing)) thing = function_object (thing);
  if (objectp (thing)) {
    if (thing->is_configuration) return thing;
    if (object parent =
	functionp (object_program (thing)) &&
	function_object (object_program (thing))) {
      // This is mainly for finding tags defined in rxml.pike.
      if (parent->is_configuration) return parent;
    }
  }
  return 0;
}

#ifdef REQUEST_TRACE

static string trace_msg (RequestID id, string msg, string name)
{
  msg = html_decode_string (
    Parser.HTML()->_set_tag_callback (lambda (object p, string s) {return "";})->
    finish (msg)->read());

  array(string) lines = msg / "\n";
  if (lines[-1] == "") lines = lines[..sizeof (lines) - 2];

  if (sizeof (lines))
    report_debug ("%s%s%-40s %s\n",
		  map (lines[..sizeof (lines) - 2],
		       lambda (string s) {
			 return sprintf ("%s%*s%s\n", id->misc->trace_id_prefix,
					 id->misc->trace_level + 1, "", s);
		       }) * "",
		  id->misc->trace_id_prefix,
		  sprintf ("%*s%s", id->misc->trace_level + 1, "", lines[-1]),
		  name);
}

void trace_enter (RequestID id, string msg, object|function thing)
{
  if (!id->misc->trace_level) {
    id->misc->trace_id_prefix = ({"%%", "##", "$$", "¤¤", "**", "@@", "§§"})[
      all_constants()->id_trace_level_rotate_counter++ % 7];
    report_debug ("%s%s Request handled by: %O\n",
		  id->misc->trace_id_prefix, id->misc->trace_id_prefix[..0],
		  id->conf);
  }

  string name;
  if (thing) {
    name = get_modfullname (get_owning_module (thing));
    if (name)
      name = "mod: " + html_decode_string (
	Parser.HTML()->_set_tag_callback (lambda (object p, string s) {return "";})->
	finish (name)->read());
    else if (Configuration conf = get_owning_config (thing))
      name = "conf: " + conf->query_name();
    else if (thing)
      name = sprintf ("obj: %O", thing);
  }
  else name = "";

  trace_msg (id, msg, name);
  id->misc->trace_level++;

  if(function(string,mixed ...:void) _trace_enter =
     [function(string,mixed ...:void)]([mapping(string:mixed)]id->misc)->trace_enter)
    _trace_enter (msg, thing);
}

void trace_leave (RequestID id, string desc)
{
  if (id->misc->trace_level) id->misc->trace_level--;

  if (sizeof (desc)) trace_msg (id, desc, "");

  if(function(string:void) _trace_leave =
     [function(string:void)]([mapping(string:mixed)]id->misc)->trace_leave)
    _trace_leave (desc);
}

#endif

#if !constant(Parser.C)
object _Parser =
  class 
  {
    object C =
    class 
    {
      mapping(string:string) global_groupings=(["{":"}","(":")","[":"]"]);

      array(string) split(string data)
      {
        int start;
        int line=1;
        array(string) ret=({});
        int pos;
        data += "\n\0";	/* End sentinel. */

        while(1)
        {
          int start=pos;

          //    werror("::::%c\n",data[pos]);

          switch(data[pos])
          {
           case '\0':
             return ret;

           case '#':
             {
             pos=search(data,"\n",pos);
             if(pos==-1)
               error("Failed to find end of preprocessor statement.\n");

             while(data[pos-1]=='\\') pos=search(data,"\n",pos+1);
             break;

              case 'a'..'z':
              case 'A'..'Z':
              case 128..65536: // Lets simplify things for now...
              case '_':
                while(1)
                {
                  switch(data[pos])
                  {
                   case '$': // allowed in some C (notably digital)
                   case 'a'..'z':
                   case 'A'..'Z':
                   case '0'..'9':
                   case 128..65536: // Lets simplify things for now...
                   case '_':
                     pos++;
                     continue;
                  }
                  break;
                }
                break;

              case '.':
                if(data[start..start+2]=="...")
                {
                  pos+=3;
                  break;
                }
                if(data[start..start+1]=="..")
                {
                  pos+=3;
                  break;
                }

              case '0'..'9':
                if(data[pos]=='0' && (data[pos+1]=='x' || data[pos+1]=='X'))
                {
                  pos+=2;
                  while(1)
                  {
                    switch(data[pos])
                    {
                     case '0'..'9':
                     case 'a'..'f':
                     case 'A'..'F':
                       pos++;
                       continue;
                    }
                    break;
                  }
                  break;
                }
                while(data[pos]>='0' && data[pos]<='9') pos++;
                if(data[pos]=='.')
                {
                  pos++;
                  while(data[pos]>='0' && data[pos]<='9') pos++;
                  if(data[pos]=='e' || data[pos]=='E')
                  {
                    pos++;
                    while(data[pos]>='0' && data[pos]<='9') pos++;
                  }
                }
                break;

              default:
                werror("%O\n",ret);
                werror("Unknown token %O\n",data[pos..pos+20]);
                exit(1);

              case  '`':
                while(data[pos]=='`') data[pos]++;

              case '\\': pos++; continue; /* IGNORED */

              case '/':
              case '{': case '}':
              case '[': case ']':
              case '(': case ')':
              case ';':
              case ',':
              case '*': case '%':
              case '?': case ':':
              case '&': case '|': case '^':
              case '!': case '~':
              case '=':
              case '@':
              case '+':
              case '-':
              case '<': case '>':
                switch(data[pos..pos+1])
                {
                 case "//":
                   pos=search(data,"\n",pos);
                   break;

                 case "/*":
                   pos=search(data,"*/",pos);
                   pos+=2;
                   break;

                 case "<<": case ">>":
                   if(data[pos+2]=='=') pos++;
                 case "==": case "<=": case ">=":
                 case "*=": case "/=": case "%=":
                 case "&=": case "|=": case "^=":
                 case "+=": case "-=":
                 case "++": case "--":
                 case "&&": case "||":
                 case "->":
                   pos++;
                 default:
                   pos++;
                }
                break;


              case ' ':
              case '\n':
              case '\r':
              case '\t':
              case '\14':
                while(1)
                {
                  switch(data[pos])
                  {
                   case ' ':
                   case '\n':
                   case '\r':
                   case '\t':
                   case '\14':
                     pos++;
                     continue;
                  }
                  break;
                }
                break;

              case '\'':
                pos++;
                if(data[pos]=='\\') pos++;
                pos=search(data, "'", pos+1)+1;
                break;

              case '"':
                {
                int q,s;
                while(1)
                {
                  q=search(data,"\"",pos+1);
                  s=search(data,"\\",pos+1);
                  if(q==-1) q=strlen(data)-1;
                  if(s==-1) s=strlen(data)-1;

                  if(q<s)
                  {
                    pos=q+1;
                    break;
                  }else{
                    pos=s+1;
                  }
                }
                break;
                }
             }
          }

          ret+=({ data[start..pos-1] });
        }
      }


      class Token
      {
        int line;
        string text;
        string file;
        string trailing_whitespaces="";

        void create(string t, int l, void|string f, void|string space)
        {
          text=t;
          line=l;
          file=f;
          if(space) trailing_whitespaces=space;
        }

        string _sprintf(int how)
        {
          switch(how)
          {
           case 's':
             return text;
           case 'O':
             return sprintf("Token(%O,%O,%d)",text,file,line);
          }
        }

        int `==(mixed foo)
        {
          return (objectp(foo) ? foo->text : foo) == text;
        }

        string `+(string ... s)
        {
          return predef::`+(text,@s);
        }

        string ``+(string ... s)
        {
          return predef::`+(@s,text);
        }

        mixed cast(string to)
        {
          if(to=="string") return text;
        }
      }

      array(Token) tokenize(array(string) s, void|string file)
      {
        array(Token) ret=allocate(sizeof(s));
        int line=1;
        for(int e=0;e<sizeof(s);e++)
        {
          ret[e]=Token(s[e],line,file);
          if(s[e][0]=='#')
          {
            sscanf(s[e],"#%*[ \t\14]%d%*[ \t\14]\"%s\"", line,file);
            sscanf(s[e],"#%*[ \t\14]line%*[ \t\14]%d%*[ \t\14]\"%s\"", 
                   line,file);
            line--;
          }
          line+=sizeof(s[e]/"\n")-1;
        }
        return ret;
      }

      array group(array(string|Token) tokens, void|mapping groupings)
      {
        Stack.stack stack=Stack.stack();
        array(Token) ret=({});
        mapping actions=([]);

        if(!groupings) groupings=global_groupings;

        foreach((array)groupings,[string x, string y])
        {
          actions[x]=1;
          actions[y]=2;
        }

        foreach(tokens, Token token)
        {
          switch(actions[(string)token])
          {
           case 0: ret+=({token}); break;
           case 1: stack->push(ret); ret=({token}); break;
           case 2:
             if (!sizeof(ret) || !stack->ptr ||
                 (groupings[(string)ret[0]] != (string)token)) {
               // Mismatch
               werror(sprintf("**** Grouping mismatch token=%O\n"
                              "**** tokens: ({ %{%O, %}})\n"
                              "**** ret: ({ %{%O, %}})\n"
                              "**** stackdepth: %d\n",
                              token->text, tokens->text,
                              ret->text, stack->ptr));
               return ret;
             }
             ret=stack->pop()+({ ret + ({token}) });
          }
        }
        return ret;
      }

      /* FIXME:
       * This actually strips all preprocessing tokens
       */
      array strip_line_statements(array tokens)
      {
        array(Token) ret=({});
        foreach(tokens, array|object(Token) t)
        {
          if(arrayp(t))
          {
            ret+=({ strip_line_statements(t) });
          }else{
            if( ((string)t) [0] != '#')
              ret+=({t});
          }
        }
        return ret;
  
      }

      array hide_whitespaces(array tokens)
      {
        array(Token) ret=({tokens[0]});
        foreach(tokens[1..], array|object(Token) t)
        {
          if(arrayp(t))
          {
            ret+=({ hide_whitespaces(t) });
          }else{
            switch( ((string)t) [0])
            {
             case ' ':
             case '\t':
             case '\14':
             case '\n':
               mixed tmp=ret[-1];
               while(arrayp(tmp)) tmp=tmp[-1];
               tmp->trailing_whitespaces+=(string)t;
               break;

             default:
               ret+=({t});
            }
          }
        }
        return ret;
      }

      array flatten(array a)
      {
        array ret=({});
        foreach(a, a) ret+=arrayp(a)?flatten(a):({a});
        return ret;
      }

      string simple_reconstitute(array(string|object(Token)|array) tokens)
      {
        string ret="";
        foreach(flatten(tokens), mixed tok)
        {
          if(objectp(tok))
            tok=tok->text + tok->trailing_whitespaces;
          ret+=tok;
        }

        return ret;
      }

      string reconstitute_with_line_numbers(array(string|object(Token)|array)
                                            tokens)
      {
        int line=1;
        string file;
        string ret="";
        foreach(flatten(tokens), mixed tok)
        {
          if(objectp(tok))
          {
            if((tok->line && tok->line != line) ||
               (tok->file && tok->file != file))
            {
              if(strlen(ret) && ret[-1]!='\n') ret+="\n";
              line=tok->line;
              if(tok->file) file=tok->file;
              ret+=sprintf("#line %d %O\n",line,file);
            }
            tok=tok->text + tok->trailing_whitespaces;
          }
          ret+=tok;
          line+=sizeof(tok/"\n")-1;
        }

        return ret;
      }
    }();
  }();
#endif
