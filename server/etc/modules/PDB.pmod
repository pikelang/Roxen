class FileIO {
  object open(string f, string m)
  {
    object o = files.file();
    if(!o->open(f,m)) return 0;
    return o;
  }
  
  void write_file(string f, mixed d)
  {
    d = encode_value(d);
    catch {
      string q;
      if(strlen(q=Gz->deflate()->deflate(d)) < strlen(d))
	d=q;
    };
    object o = open(f+".tmp","wct");
    int n = o->write(d);
    o->close();
    if(n == sizeof(d))
      mv(f+".tmp", f);
    else
      rm(f+".tmp");
  }
  
  mixed read_file(string f)
  {
    object o = open(f,"r");
    string d = o->read();
    catch { d=Gz->inflate()->inflate(d); };
    return decode_value(d);
  }
}


class Bucket
{
  inherit FileIO;
  object file=files.file();
  array free_blocks = ({});
  string rf;
  int size,  last_block;
  void write_at(int offset, string to)
  {
    file->seek(offset*size);
    file->write(to);
  }
  
  string read_at(int offset)
  {
    file->seek(offset*size);
    return file->read(size);
  }
  
  mixed get_entry(int offset)
  {
    return read_at(offset);
  }
  
  static void save_free_blocks()
  {
    write_file(rf+".free", ({last_block, free_blocks}));
  }
  
  void free_entry(int offset)
  {
    free_blocks += ({ offset });
    if(size<4)   write_at(offset,"F");
    else         write_at(offset,"FREE");
    save_free_blocks();
  }

  int allocate_entry()
  {
    if(sizeof(free_blocks))
    {
      int b = free_blocks[0];
      free_blocks = free_blocks[1..];
      return b;
    }
    last_block++;
    save_free_blocks();
    return last_block-1;
  }

  void sync()
  {
    save_free_blocks();
  }

  int set_entry(int offset, string to)
  {
    if(strlen(to) > size) return 0;
    write_at(offset, to);
    return 1;
  }
  
  void create(string d, int ms, int write)
  {
    string mode="r";
    size=ms;
    rf = d+ms;
    if(write) { mode="rwc"; }
    catch {
      array t = read_file(rf+".free");
      last_block = t[0];
      free_blocks = t[1];
    };
    if(!file->open(rf,mode)) destruct();
  }
};


class Table
{
  inherit FileIO;
  mapping index = ([ ]);
  int compress, write;
  string dir;
  function get_bucket;

  void sync()
  {
    write_file(dir+".INDEX", index);
  }

  int find_nearest_2x(int num)
  {
    for(int b=4;b<32;b++) if((1<<b) >= num) return (1<<b);
  }

  function scheme = find_nearest_2x;


  void delete(string in)
  {
    array i;
    if(!(i=index[in])) return 0;
    m_delete(index,in);
    object bucket = get_bucket(i[0]);
    bucket->free_entry(i[1]);
    sync();
  }

  mixed set(string in, mixed to)
  {
    if(!write) return 0;
    string ts = encode_value(to);
    catch {
      string q;
      if(strlen(q=Gz->deflate()->deflate(ts)) < strlen(ts)) ts=q;
    };
    object bucket = get_bucket(scheme(strlen(ts)));
    delete(in);
    int of = bucket->allocate_entry();
    bucket->set_entry(of, ts);
    index[in]=({ bucket->size, of });
    sync();
    return to;
  }
  mixed `[]=(string in,mixed to) {
    return set(in,to);
  }
  
  mixed get(string in)
  {
    array i;
    if(!(i=index[in])) return 0;
    object bucket = get_bucket(i[0]);
    mixed d = bucket->get_entry(i[1]);
    if(compress) catch { d=Gz->inflate()->inflate(d); };
    return decode_value( d );
  }

  mixed `[](string in) {
    return get(in);
  }
  
  array _indices() {
    return indices(index);
  }

  array match(string match)
  {
    return glob(match, _indices());
  }

  void purge()
  {
    // remove table...
    foreach(values(index), string d)
      get_bucket(d[0])->free_block(d[1]);
    rm(dir+".INDEX");
    index=([]);
  }

  void rehash()
  {
    // TBD ...
  }
  
  void create(string d, int wp, int cp, object fn)
  {
    get_bucket = fn;
    dir = d;
    if(sizeof(predef::indices(Gz)) && cp) compress=1;
    if(wp) write=1;
    catch { index = read_file(dir+".INDEX"); };
    sync();
  }
};


class db
{
  int write, compress;
  string dir;
  mapping (int:object(Bucket)) buckets = ([]);
  static object(Bucket) get_bucket(int s)
  {
    object bucket;
    if(!(bucket = buckets[s]))
      buckets[s] = bucket = Bucket( dir+"Buckets/", s, write );
    return bucket;
  }
  
  void mkdirhier(string from)
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
    return Table(combine_path(dir, (tname-"/")), write, compress, get_bucket);
  }

  object(Table) `[](string t)
  {
    return table(t);
  }
  
  array(string) list_tables()
  {
    return Array.map(glob("*.INDEX", get_dir(dir) || ({})),
		     lambda(string s)
		     { return s[..(sizeof(s)-1-sizeof(".INDEX"))]; });
  }

  array(string) _indices()
  {
    return list_tables();
  }

  void sync()
  {
    foreach(values(buckets), object b)
      b->sync();
    call_out(sync, 200);
    remove_call_out(sync);
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
    call_out(sync, 10);
  }
};
