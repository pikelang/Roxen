//#define USE_GDBM

/* $Id: db.pike,v 1.4 1997/02/11 13:53:58 per Exp $ */

private static inherit "/precompiled/file";
private static mapping db;

#define DIR "dbm_dir.perdbm"


private static string last;

private static int glunk;

private static void sync()
{
  if(last && glunk) 
  {
    file::seek(0);
    file::write(encode_value(db));
    glunk = 0;
    remove_call_out(sync);
  }
}

static private void reorganize()
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

static void close()
{
  sync();
  file::close();
  last = 0;
}

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
  perror("open db "+ f+ "\n");
  if(last != f)
  {
    if(last) close();
    last = f;
    res = file::open(DIR+"/"+f, "rwc");
    if(!res)
    {
      mkdirhier(DIR+"/"+f);
      res = file::open(DIR+"/"+f, "rwc");
      if(!res) return 0;
    }
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
  close();
  rm(DIR+"/"+cl);
}

public void db_delete(string cl, string varname)
{
  if(open_db(cl))
  {
    m_delete(db, varname);
    m_delete(db,"____");
  } else
    perror("Failed to open database for "+cl+"\n");
}

public void db_set(string cl, string varname, mixed value)
{
  if(open_db(cl))
  {
    m_delete(db,"____");
    db[varname] = value;
    if(glunk++ > 2)
      sync();
    else if(glunk==1)
      if(zero_type(find_call_out(sync)))
	call_out(sync, 2);
  } else
    perror("Failed to open database for "+cl+"\n");
}

public mixed db_get(string cl, string varname)
{
  string s;
  if(open_db(cl))
    return db[varname];
  else
    perror("Failed to open database for "+cl+"\n");
}
