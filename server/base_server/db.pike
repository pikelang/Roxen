//#define USE_GDBM

/* $Id: db.pike,v 1.5 1997/02/13 13:00:54 per Exp $ */

private static inherit files.file;
private static mapping db;
private static string last;

#define DIR "dbm_dir.perdbm/"


private static void sync()
{
  if(last)
  {
    perror("save ("+ last +")\n");
    if(!file::open(DIR+last,"wca"))
    {
      perror("FAILED TO OPEN FILE\n");
      error("Save of object not possible.\n");
    }
    file::write(encode_value(db));
    file::close();
  }
}

/* Public methods */



public int db_open(string f)
{
  int res;
  if(last != f)
  {
    perror("restore ("+ f +")\n");
    last = f;
    res = file::open(DIR+f, "rc");
    if(!res)
    {
      mkdirhier(DIR+f);
      res = file::open(DIR+f, "rc");
      if(!res) return 0;
    }
    string s;
    if((s = file::read(0x7ffffff)) && strlen(s))
      db = decode_value(s);
    else
      db = ([ ]);
    file::close();
  }
  return 1;
}


public void db_destroy()
{
  rm(DIR+last);
  last=0;
}

public void db_delete(string varname)
{
  m_delete(db, varname);
  sync();
}

public void db_set(string varname, mixed value)
{
  db[varname] = value;
  sync();
}

public mixed db_get(string varname)
{
  return db[varname];
}
