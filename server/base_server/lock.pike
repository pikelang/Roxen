/* Handle a lock in a somewhat more abstract way than (roxen) uLPC does. */
string cvs_version = "$Id: lock.pike,v 1.2 1996/12/01 19:18:31 per Exp $";
private static  int lockid;
private static  int aquired = 0;

/* Public functions to be called. */
public void aquire()
{
#if efun(_lock)
  if(!aquired++)
    _lock(lockid);
#endif
}

public void free()
{
#if efun(_unlock)
  if(!--aquired)
    _unlock(lockid);
  if(aquired < 0)
    error("Freeing lock to many times.\n");
#endif
}


/* Create is called when the object is created, and destroy when it is
 * freed.  Create _might_ be called multiple times by the user, same
 * goes for destroy, since they _have_ to be public.
 */

void create(int | void id)
{
#if efun(_lock)
  if(!id)
    id = getpid()<<2+time()<<4+random(100000);
  if(lockid)
    _free_lock(lockid);
  lockid = _new_lock(id);
#else
#ifdef DEBUG
 perror("No locking available.\n");
#endif
#endif
}

void destroy()
{
#if efun(_free_lock)
  if(lockid)
    _free_lock(lockid);
  lockid=0;
#endif
}



