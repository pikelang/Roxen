package com.roxen.servlet;

import javax.servlet.http.HttpSession;
import java.util.Hashtable;
import java.util.Enumeration;

class RoxenSessionContext 
{

  protected Hashtable sessions = new Hashtable();

  //  Sessions which aren't reused will eventually time-out, but we need
  //  to manually gc them. We check the hash table entries every ten
  //  minutes.
  protected long lastGarbTime = System.currentTimeMillis();
  protected long kGarbInterval = 600;
  
  public synchronized HttpSession getSession(String id, boolean create)
  {
    //  Perform manual gc on session objects. Sessions which are never
    //  reused will stay in the hash table until we remove them since
    //  the built-in invalidation only tracks sessions requested repeatedly.
    long currentTime = System.currentTimeMillis();
    if (currentTime - lastGarbTime > (kGarbInterval * 1000)) {
      lastGarbTime = currentTime;
      for (Enumeration peek = sessions.keys(); peek.hasMoreElements();) {
	String garbID = (String) peek.nextElement();
	RoxenSession session = (RoxenSession) sessions.get(garbID);

	//  Session may be marked as invalid already or simply expired. In
	//  the second case we need to invalidate it as well in order to
	//  notify HttpSession attribute listeners.
	if (session != null && session.isInvalidOrExpired(currentTime)) {
	  sessions.remove(garbID);
	  if (!session.invalidated)
	    session.invalidate();
	}
      }
    }

    if(id != null) {
      Object s = sessions.get(id);
      if(s != null) {
	RoxenSession session = (RoxenSession)s;
	if(session.access())
	  return session;
	else {
	  sessions.remove(id);
          if (!session.invalidated)
            session.invalidate();
	}
      }
    }
    if(!create)
      return null;
    RoxenSession session = new RoxenSession();
    sessions.put(session.getId(), session);
    return session;
  }


}
