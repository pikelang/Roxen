// static private inherit "db";

/* $Id: persistent.pike,v 1.14 1997/03/01 07:35:39 per Exp $ */
/*************************************************************,
* PERSIST. An implementation of persistant objects for Pike.  *
* Variables and callouts are saved between restarts.          *
*                                                             *
* What is not saved?                                          *
* o Listening info (/precompiled/port)                        *
* o Open files (/precompiled/file)                            *
*                                                             *
* This can be solved by specifying two new objects, like      *
* persists/port and persist/file in Pike. I leave that as an  *
* exercise for the reader.. :-)                               *
*                                                             *
* (remember to save info about seek etc.. But it is possible) *
'*************************************************************/

#define PRIVATE private static inline 

private static string __id;
#define DIR "dbm_dir.perdbm/"

PRIVATE void really_save()
{
  object file = files.file();
  array res = ({ });
  mixed b;

  if(!__id)
  {
    mixed i = nameof(this_object());
    if(arrayp(i)) __id=(i[0]+".class/"+i[1]);
  }

  foreach(indices(this_object()), string a)
  {
    b=this_object()[a];
    if(!catch { this_object()[a]=b; } ) // It can be assigned. Its a variable!
      res += ({ ({ a, b }) });
  }
//  perror("save ("+ __id +")\n");
  if(!file->open(DIR+__id,"wct"))
  {
    mkdirhier(DIR+__id);
    if(!file->open(DIR+__id, "wct"))
      error("Save of object not possible.\n");
  }
  file->write(encode_value(res));
}


/* Public methods! */
static int ___destructed = 0;

public void begone()
{
  remove_call_out(really_save);
  ___destructed=1;
  rm(DIR+__id);
  __id=0;
}


nomask public void persist(mixed id)
{
  object file = files.file();

  if(arrayp(id)) id=(id[0]+".class/"+id[1]);
  /* No known id. This should not really happend. */
  if(!id)  error("No known id in persist.\n");
  
  __id = id;
// Restore

  array var;
  catch {
    if(!file->open(DIR+__id, "r")) return 0;
//    perror("restore ("+ __id +")\n");
    var=decode_value(file->read(0x7ffffff));
  };
  if(var) foreach(var, var) catch {
    this_object()[var[0]] = var[1];
  };
  
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

