// static private inherit "db";

/* $Id: persistent.pike,v 1.22 1997/04/13 00:42:00 per Exp $ */

/*************************************************************,
* PERSIST. An implementation of persistant objects for Pike.  *
* Variables and callouts are saved between restarts.          *
*                                                             *
* What is not saved?                                          *
* o Listening info (files.port)                               *
* o Open files (files.file)                                   *
*                                                             *
* This can be solved by specifying two new objects, like      *
* persists/port and persist/file in Pike. I leave that as an  *
* exercise for the reader.. :-)                               *
*                                                             *
* (remember to save info about seek etc.. But it is possible) *
'*************************************************************/

#define PRIVATE private static inline 

private static array __id;

void really_save()
{
  object file = files.file();
  array res = ({ });
  mixed b;

  if(!__id)
  {
    mixed i = nameof(this_object());
    if(!arrayp(i)) __id=({i});
    else __id = i;
  }

  foreach(indices(this_object()), string a)
  {
    b=this_object()[a];
    if(!catch { this_object()[a]=b; } ) // It can be assigned. Its a variable!
      res += ({ ({ a, b }) });
  }
  open_db(__id[0])->set(__id[1], encode_value(res) );
}


/* Public methods! */
static int ___destructed = 0;

public void begone()
{
  remove_call_out(really_save);
  ___destructed=1;
  if(__id) open_db(__id[0])->delete(__id[1]);
  __id=0;
// A nicer destruct. Won't error() if no object.
  call_out(do_destruct,8,this_object());
}

void destroy()
{
  remove_call_out(really_save);
}

static void compat_persist()
{
  string _id;
  _id=(__id[0]+".class/"+__id[1]);

#define COMPAT_DIR "dbm_dir.perdbm/"
 object file = files.file();
  array var;
  catch {
    if(!file->open(COMPAT_DIR+_id, "r")) return 0;
    perror("compat restore ("+ _id +")\n");
    var=decode_value(file->read(0x7ffffff));
  };
  if(var)
  {
    foreach(var, var) catch {
      this_object()[var[0]] = var[1];
    };
    remove_call_out(really_save);
    call_out(really_save,0);
    rm(COMPAT_DIR+_id);
  }

}

nomask public void persist(mixed id)
{
  object file = files.file();
  /* No known id. This should not really happend. */
  if(!id)  error("No known id in persist.\n");
  __id = id;

// Restore
  array var;
  catch {
    var=decode_value(open_db(__id[0])->get(__id[1]));
//  perror("decode_value ok\n");
  };
  

  if(var && sizeof(var)) foreach(var, var) catch {
    this_object()[var[0]] = var[1];
  };
  else
    compat_persist();

  if(functionp(this_object()->persisted))
    this_object()->persisted();
}
  

public void save()
{
  if(!___destructed)
  {
    remove_call_out(really_save);
    call_out(really_save,2);
  }
}
