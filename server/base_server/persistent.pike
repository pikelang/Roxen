static private inherit "db";

/* $Id: persistent.pike,v 1.10 1997/02/22 00:01:23 per Exp $ */
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

/* Search for 'persist' to find the (two) public methods */

#define PRIVATE private static inline 

static object this = this_object();

PRIVATE multiset __vars = (<>);
PRIVATE string __id;

/*** Private code ***/


PRIVATE void save_variables()
{
  mixed b, a;
  array res = ({ }), variable;
  if(!sizeof(__vars)) // First time, not initialized.
    foreach(indices(this), a)
    {
      b=this[a];
      if(!catch { this[a]=b; } ) // It can be assigned. Its a variable!
      {
	__vars[a] = 1;
	res += ({ ({ a, b }) });
      }
    }
  else
    foreach(indices(__vars), a)
      res += ({ ({ a, this[a] }) });
  db_set("v", res);
}

PRIVATE void restore_variables()
{
  array var;
  if(var = db_get("v"))
    foreach(var, var) catch {
      this[var[0]] = var[1];
    };
}

static void really_save()
{
  if(!__id)
  {
    mixed i = nameof(this_object());
    if(arrayp(i)) __id=(i[0]+".class/"+i[1]);
    db_open( __id, 1 );
  }

  save_variables();
}


/* Public methods! */
public void begone()
{
  remove_call_out(really_save);
  db_destroy();
  destruct();
}


public void persist(mixed id)
{
  if(arrayp(id)) id=(id[0]+".class/"+id[1]);
  /* No known id. This should not really happend. */
  if(!id)  error("No known id in persist.\n");

  __id = id;
  db_open( id, 0 );
  restore_variables();

  if(functionp(this->persisted))
    this->persisted();
}
  
public void save()
{
  remove_call_out(really_save);
  call_out(really_save,2);
}

