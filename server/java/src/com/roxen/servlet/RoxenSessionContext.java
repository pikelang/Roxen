package com.roxen.servlet;

import javax.servlet.http.HttpSession;
import java.util.Hashtable;

class RoxenSessionContext 
{

  protected Hashtable sessions = new Hashtable();

  public synchronized HttpSession getSession(String id, boolean create)
  {
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
