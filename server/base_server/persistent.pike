// static private inherit "db";

/* $Id: persistent.pike,v 1.17 1997/04/01 16:00:59 per Exp $ */
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
  open_db(__id[..0])->set(__id[1..], encode_value(res) );
}


/* Public methods! */
static int ___destructed = 0;

public void begone()
{
  remove_call_out(really_save);
  ___destructed=1;
  if(__id)
    open_db(__id[..0])->delete(__id[1..]);
  __id=0;
  call_out(destruct,2,this_object());
}

void destroy()
{
  remove_call_out(really_save);
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
    var=decode_value(open_db(id[..0])->get(id[1..]));
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

