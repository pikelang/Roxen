static private inherit "db";

/* $Id: persistent.pike,v 1.8 1997/02/14 04:37:22 per Exp $ */
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


PRIVATE int save_call_out_list()
{
  array ci;
  array res = ({});
  array old = db_get("c") || ({});
  foreach(call_out_info(), ci)
  {
    if(ci[1] == this)
    switch(function_name(ci[2]))
    {
     case "sync":          /* Internal functions used in persist and db. */
     case "doclose":	   /* Cannot be redefined currently */
     case "do_auto_save":  /* do_auto_save is used below */
      break;
     default:
      res += ({ ({ ci[2], ci[0], time(1), ci[3..] }) });
    }
  }
  if((old && sizeof(old)) || sizeof(res))
    db_set( "c", res);
  return (old && sizeof(old)) || sizeof(res);
}

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


PRIVATE int max(int a,int b) /* Not macro becasue this is faster.. */
{
  return a<b?b:a;
}

PRIVATE void restore_call_out_list()
{
  array ci, var;

  /* Clear call_outs iff any are restored.  This is quite important,
   * since quite a lot of people start a call_out in create(). That
   * could kill a server very quickly, since there will be a new callout
   * each time the object is restored.
   */

  if(var = db_get("c"))
  {
    foreach(call_out_info(), ci)
      if(ci[1] == this)
	switch(function_name(ci[2]))
	{
	 case "sync":         /* Internal functions used in persist and db. */
	 case "doclose":      /* Cannot be redefined currently */
	 case "do_auto_save": /* do_auto_save is used below */
	  break;
	 default:
	  remove_call_out( ci[2] );
	}
    
    foreach(var, var)
      catch {
	call_out(var[0], max(var[1]-(time(1)-var[2]),0), @var[3]); 
      };
  }
}


/* Public methods! */
static private int _____destroyed = 0; 
public void begone()
{
  _____destroyed = 1;
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
  restore_call_out_list();

  if(functionp(this->persisted))
    this->persisted();
}

public void save()
{
  if(!__id)
  {
    mixed i = nameof(this_object());
    if(arrayp(i)) __id=(i[0]+".class/"+i[1]);
    db_open( __id, 1 );
  }

//perror("\n\n\npersist->save ("+__id+")\n"+describe_backtrace(backtrace()));

  /* "Simply" save all global (non-static) variables and callouts. */
  save_variables();
  save_call_out_list();
}




/* Driver callbacks. Called when this object is destroyed. 
 * Should we _really_ destroy our self now, that is, remove the db as
 * well?
 *
 * I think not.
 */  
void destroy()  
{
  perror("\n\n\npersist->destroy ("+__id+")\n"+describe_backtrace(backtrace()));
//  if(!_____destroyed)
//    save();
}
    

