//#define USE_GDBM

#ifdef USE_GDBM
inherit "/precompiled/gdbm";
#else
inherit "/precompiled/file";
private static mapping db;
#endif

#ifdef USE_GDBM
#define DIR "dbm_dir.gdbm"
#else
#define DIR "dbm_dir.perdbm"
#endif

private static string last;

private static int glunk;

private static void sync()
{
  if(last && glunk) 
  {
    efun::write("Saved.\n");
#ifdef USE_GDBM
    gdbm::sync();
#else
    seek(0);
    file::write(encode_value(db));
#endif
    glunk = 0;
    remove_call_out(sync);
  }
}

#ifndef USE_GDBM
void reorganize()
{
  string s;
  seek(0);
  if((s = read(0x7ffffff)) && strlen(s))
  {
    db = decode_value(s);
    if(!db->____)
    {
      file::close();
      rm(DIR+"/"+last);
      file::open(DIR+"/"+last, "rwc");
      db->____ = 1;
      file::write(encode_value(db));
      seek(0);
    }
  } else
    db = ([ ]);
}

void close()
{
  sync();
  file::close();
  last = 0;
}
#endif



private static void doclose()
{
  if(last) 
  {
    close();
    last = 0;
  }
}

private static int open_db(string f)
{
  int res;
  if(last != f)
  {
    if(last) close();
    last = f;
#ifdef USE_GDBM
    gdbm::create(DIR+"/"+f, "rwc");
#else
    res = file::open(DIR+"/"+f, "rwc");
    if(!res)
    {
      mkdir(DIR);
      res = file::open(DIR+"/"+f, "rwc");
      if(!res)
	return 0;
    }
#endif
    reorganize();
    remove_call_out(doclose);
    call_out(doclose, 20);
    glunk = 0;
  } 
  return 1;
}

/* Driver callbacks */



/* Public methods */

public void db_close(string cl)
{
  if(last == cl)
    doclose();
}


public void db_destroy(string cl)
{
  rm(DIR+"/"+cl);
}

public void db_delete(string cl, string varname)
{
  if(open_db(cl))
  {
#ifdef USE_GDBM
    delete(varname);
#else
    m_delete(db, varname);
    m_delete(db,"____");
#endif
  }
}

public void db_set(string cl, string varname, mixed value)
{
  if(open_db(cl))
  {
#ifdef USE_GDBM
    delete(varname);
    store(varname, encode_value(value));
#else
    m_delete(db,"____");
    db[varname] = value;
    if(glunk++ > 2)
      sync();
    else if(glunk==1)
      if(zero_type(find_call_out(sync)))
	call_out(sync, 2);
#endif
  }
}

public mixed db_get(string cl, string varname)
{
  string s;
  if(open_db(cl))
  {
#ifdef USE_GDBM
    if(!(s = fetch(varname)))
      return 0;
#else
    return db[varname];
#endif
  }
#ifdef USE_GDBM
  else
    return 0;

  return decode_value(s);
#endif
}
