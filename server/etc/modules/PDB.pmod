/*
 * $Id: PDB.pmod,v 1.11 1997/09/14 17:31:31 grubba Exp $
 */

#if constant(thread_create)
#define THREAD_SAFE
#define LOCK() do { object key; catch(key=lock())
#define UNLOCK() key=0; } while(0)
#else
#undef THREAD_SAFE
#define LOCK() do {
#define UNLOCK() } while(0)
#endif

class FileIO {

#ifdef THREAD_SAFE
  static inherit Thread.Mutex;
#endif

  static private object open(string f, string m)
  {
    object o = files.file();
    if(!o->open(f,m)) return 0;
    return o;
  }
  
  static void write_file(string f, mixed d)
  {
    d = encode_value(d);
    catch {
      string q;
      object g;
      if (sizeof(indices(g=Gz))) {
	if(strlen(q=g->deflate()->deflate(d)) < strlen(d))
	  d=q;
      }
    };
    object o = open(f+".tmp","wct");
    int n = o->write(d);
    o->close();
    if(n == sizeof(d))
      mv(f+".tmp", f);
    else
      rm(f+".tmp");
  }
  
  static mixed read_file(string f)
  {
    object o = open(f,"r");
    string d = o->read();
    catch {
      object g;
      if (sizeof(indices(g=Gz))) {
	d=g->inflate()->inflate(d);
      }
    };
    return decode_value(d);
  }
}


class Bucket
{
  inherit FileIO;
  static object file=files.file();
  static array free_blocks = ({});
  static string rf;
  static int last_block, dirty;
  static function db_log;
  int size;

  static void log(int subtype, mixed arg)
  {
    db_log('B', subtype, size, arg);
  }

  static void write_at(int offset, string to)
  {
    file->seek(offset*size);
    file->write(to);
  }
  
  static string read_at(int offset)
  {
    file->seek(offset*size);
    return file->read(size);
  }
  
  mixed get_entry(int offset)
  {
    LOCK();
    return read_at(offset);
    UNLOCK();
  }
  
  static void save_free_blocks()
  {
    write_file(rf+".free", ({last_block, free_blocks}));
    dirty = 0;
  }
  
  void free_entry(int offset)
  {
    LOCK();
    free_blocks += ({ offset });
    dirty = 1;
    log('F', offset);
    if(size<4)   write_at(offset,"F");
    else         write_at(offset,"FREE");
    UNLOCK();
  }

  int allocate_entry()
  {
    int b;
    LOCK();
    if(sizeof(free_blocks)) {
      b = free_blocks[0];
      free_blocks -= ({ b });
    } else
      b = last_block++;
    dirty = 1;
    log('A', b);
    UNLOCK();
    return b;
  }

  void sync()
  {
    LOCK();
    if(dirty)
      save_free_blocks();
    UNLOCK();
  }

  int set_entry(int offset, string to)
  {
    if(strlen(to) > size) return 0;
    LOCK();
    write_at(offset, to);
    UNLOCK();
    return 1;
  }

  void restore_from_log(array log)
  {
    multiset alloced = (< >);
    multiset freed = (< >);
    foreach(log, array entry)
      switch(entry[0]) {
      case 'A':
	alloced[entry[1]] = 1;
	freed[entry[1]] = 0;
	break;
      case 'F':
	freed[entry[1]] = 1;
	alloced[entry[1]] = 0;
	break;
      }
    foreach(sort(indices(alloced)), int a)
      if(a>=last_block) {
	int i;
	for(i=last_block; i<a; i++)
	  free_blocks += ({ i });
	last_block = a+1;
	dirty = 1;
      } else if(search(free_blocks, a)>=0) {
	free_blocks -= ({ a });
	dirty = 1;
      }
    array(int) fr = indices(freed) - free_blocks;
    if(sizeof(fr)) {
      free_blocks += fr;
      foreach(fr, int f)
	if(size<4)   write_at(f,"F");
	else         write_at(f,"FREE");
      dirty = 1;
    }
  }
  
  void create(string d, int ms, int write, function logfun)
  {
    string mode="r";
    size=ms;
    rf = d+ms;
    db_log = logfun;
    if(write) { mode="rwc"; }
    catch {
      array t = read_file(rf+".free");
      last_block = t[0];
      free_blocks = t[1];
    };
    if(!file->open(rf,mode)) destruct();
  }

  void destroy()
  {
    sync();
  }
};


class Table
{
  inherit FileIO;
  static mapping index = ([ ]);
  static int compress, write;
  static string dir, name;
  static function get_bucket;
  static int dirty;
  static function db_log;

  static void log(int subtype, mixed ... arg)
  {
    db_log('T', subtype, name, @arg);
  }

  void sync()
  {
    LOCK();
    if(dirty) {
      write_file(dir+".INDEX", index);
      dirty = 0;
    }
    UNLOCK();
  }

  int find_nearest_2x(int num)
  {
    for(int b=4;b<32;b++) if((1<<b) >= num) return (1<<b);
  }

  function scheme = find_nearest_2x;


  void delete(string in)
  {
    LOCK();
    array i;
    if(i=index[in]) {
      m_delete(index,in);
      dirty = 1;
      log('D', in);
      object bucket = get_bucket(i[0]);
      bucket->free_entry(i[1]);
    }
    UNLOCK();
  }

  mixed set(string in, mixed to)
  {
    if(!write) return 0;
    string ts = encode_value(to);
    if(compress)
      catch {
	string q;
	object g;
	if (sizeof(indices(g=Gz))) {
	  if(strlen(q=g->deflate()->deflate(ts)) < strlen(ts))
	    ts=q;
	}
      };
    LOCK();
    object bucket = get_bucket(scheme(strlen(ts)));
    if(index[in] && index[in][0] == bucket->size) {
      bucket->set_entry(index[in][1], ts);
      return to;
    }
    delete(in);
    int of = bucket->allocate_entry();
    bucket->set_entry(of, ts);
    index[in]=({ bucket->size, of });
    dirty = 1;
    log('C', in, index[in]);
    UNLOCK();
    return to;
  }

  mixed `[]=(string in,mixed to) {
    return set(in,to);
  }
  
  mixed get(string in)
  {
    array i;
    mixed d;
    LOCK();
    if(!(i=index[in])) return 0;
    object bucket = get_bucket(i[0]);
    d = bucket->get_entry(i[1]);
    UNLOCK();
    if(compress) {
      catch {
	object g;
	if (sizeof(indices(g=Gz))) {
	  d=g->inflate()->inflate(d);
	}
      };
    }
    return decode_value( d );
  }

  mixed `[](string in) {
    return get(in);
  }
  
  array _indices() {
    LOCK();
    return indices(index);
    UNLOCK();
  }

  array match(string match)
  {
    return glob(match, _indices());
  }

  void purge()
  {
    // remove table...
    LOCK();
    foreach(values(index), string d)
      get_bucket(d[0])->free_block(d[1]);
    rm(dir+".INDEX");
    index=([]);
    dirty = 0;
    log('P');
    UNLOCK();
  }

  void rehash()
  {
    // TBD ...
  }
  
  void restore_from_log(array log)
  {
    int purge = 0;
    foreach(log, array entry)
      switch(entry[0]) {
      case 'D':
	m_delete(index, entry[1]);
	break;
      case 'C':
	index[entry[1]] = entry[2];
	break;
      case 'P':
	index = ([]);
	purge = 1;
	break;
      }
    if(purge) {
      rm(dir+".INDEX");
      dirty = sizeof(index)>0;
    } else
      dirty = sizeof(log)>0;
  }

  void create(string n, string d, int wp, int cp, function fn, function logfun)
  {
    name = n;
    get_bucket = fn;
    db_log = logfun;
    dir = d;
    if(sizeof(predef::indices(Gz)) && cp) compress=1;
    if(wp) write=1;
    catch { index = read_file(dir+".INDEX"); };
  }

  void destroy()
  {
    sync();
  }
};


class db
{
#ifdef THREAD_SAFE
  static inherit Thread.Mutex;
#endif

  static int write, compress;
  static string dir;
  static mapping (int:object(Bucket)) buckets = ([]);
  static mapping (string:object(Table)) tables = ([]);
  static object(files.file) logfile;

  static void log(int major, int minor, mixed ... args)
  {
    LOCK();
    if(logfile)
      logfile->write(sprintf("%c%c%s\n", major, minor,
			     replace(encode_value(args),
				     ({ "\203", "\n" }),
				     ({ "\203\203", "\203n" }))));;
    UNLOCK();
  }

  static object(Bucket) get_bucket(int s)
  {
    object bucket;
    LOCK();
    if(!(bucket = buckets[s]))
      buckets[s] = bucket = Bucket( dir+"Buckets/", s, write, log );
    UNLOCK();
    return bucket;
  }
  
  static void mkdirhier(string from)
  {
    string a, b;
    array f;

    f=(from/"/");
    b="";

    foreach(f[0..sizeof(f)-2], a)
    {
      mkdir(b+a);
      b+=a+"/";
    }
  }

  object(Table) table(string tname)
  {
    tname -= "/";
    LOCK();
    if(tables[tname])
      return tables[tname];
    return tables[tname] =
      Table(tname, combine_path(dir, tname), write, compress, get_bucket, log);
    UNLOCK();
  }

  object(Table) `[](string t)
  {
    return table(t);
  }
  
  array(string) list_tables()
  {
    LOCK();
    return Array.map(glob("*.INDEX", get_dir(dir) || ({})),
		     lambda(string s)
		     { return s[..(sizeof(s)-1-sizeof(".INDEX"))]; });
    UNLOCK();
  }

  array(string) _indices()
  {
    return list_tables();
  }

  static void rotate_logs()
  {
    mv(dir+"log.1", dir+"log.2");
    logfile->open(dir+"log.1", "cwta");
  }

  void sync()
  {
    array b, t;
    LOCK();
    log('D', '1');
    b = values(buckets);
    t = values(tables);
    UNLOCK();
    foreach(b+t, object o)
      catch{o->sync();};
    LOCK();
    log('D', '2');
    rotate_logs();
    UNLOCK();
    remove_call_out(sync);
    call_out(sync, 200);
  }

  static void restore_logs()
  {
    string log = "\n"+(Stdio.read_file(dir+"log.2")||"")+
      (Stdio.read_file(dir+"log.1")||"")+"\n";
    int p=-1, d1_pos=-1, d2_pos=-1;
    while((p=search(log, "\nD", p+1))>=0)
      if(log[p+2]=='1')
	d1_pos = p;
      else if(log[p+2]=='2')
	d2_pos = d1_pos;
    if(d2_pos >= 0)
      log = log[d2_pos..];

    mapping(int:array(array)) bucket_log = ([]);
    mapping(string:array(array)) table_log = ([]);

    foreach(log/"\n", string entry) {
      int main, sub;
      array a;
      if(sscanf(entry, "%c%c%s", main, sub, entry)==3 &&
	 !catch(a = decode_value(replace(entry, ({ "\203\203", "\203n" }),
					 ({ "\203", "\n" })))))
	switch(main) {
	case 'D':
	  break;
	case 'T':
	  if(table_log[a[0]])
	    table_log[a[0]] += ({ ({ sub }) + a[1..] });
	  else
	    table_log[a[0]] = ({ ({ sub }) + a[1..] });
	  break;
	case 'B':
	  if(bucket_log[a[0]])
	    bucket_log[a[0]] += ({ ({ sub }) + a[1..] });
	  else
	    bucket_log[a[0]] = ({ ({ sub }) + a[1..] });
	  break;
	  break;
	}
    }
    log = 0;

    foreach(indices(bucket_log), int bucket)
      get_bucket(bucket)->restore_from_log(bucket_log[bucket]);
    foreach(indices(table_log), string t)
      table(t)->restore_from_log(table_log[t]);
  }
  
  void create(string d, string mode)
  {
    if(search(mode,"w")+1) write=1;
    if(search(mode,"C")+1) compress=1;
    if(search(mode,"c")+1) if(!file_stat(d))
    {
      mkdirhier(d+"/foo");
      mkdirhier(d+"/Buckets/foo");
    }
    dir = replace(d+"/","//","/");
    logfile = 0;
    restore_logs();
    if (write) {
      logfile = files.file();
      logfile->open(dir+"log.1", "cwa");
      logfile->write("\n");
      sync();
    }
  }
};
