package com.roxen.servlet;

import java.util.Enumeration;
import java.util.Set;
import java.util.Hashtable;
import java.net.InetAddress;
import java.net.UnknownHostException;
import javax.servlet.http.HttpSessionContext;
import javax.servlet.http.HttpSessionBindingEvent;
import javax.servlet.http.HttpSessionBindingListener;

class RoxenSession implements javax.servlet.http.HttpSession
{

  final long creationTime = System.currentTimeMillis();
  long lastAccessedTime = creationTime;
  long previousAccessedTime = lastAccessedTime;
  boolean isNew = true, invalidated = false;
  int maxInactiveInterval = 3600;
  Hashtable attributes = new Hashtable();

  static class IDGenerator {

    String base;
    int seq = 0;

    synchronized String generate()
    {
      return base+(seq++);
    }

    IDGenerator()
    {
      base = "";
      try {
	base += InetAddress.getLocalHost().getHostAddress()+":";
      } catch(UnknownHostException e) {
      }
      base += System.currentTimeMillis()+":";
    }
  }

  static private final IDGenerator generator = new IDGenerator();

  final String id = generator.generate();

  public long getCreationTime()
  {
    if(invalidated)
      throw new IllegalStateException();
    return creationTime;
  }

  public String getId()
  {
    return id;
  }

  public long getLastAccessedTime()
  {
    return previousAccessedTime;
  }
  
  public boolean isInvalidOrExpired(long now)
  {
    //  Used by RoxenSessionContext which manually garbage collects all
    //  sessions which are either invalid or timed out. The parameter now
    //  shoud be the current time in milliseconds which the caller can
    //  supply in order to save a large number of the System calls.
    if (now == 0)
      now = System.currentTimeMillis();
    return
      invalidated ||
      (maxInactiveInterval >= 0 &&
       (now - lastAccessedTime) / 1000 >= maxInactiveInterval);
  }
  
  boolean access()
  {
    if (invalidated)
      return false;
    previousAccessedTime = lastAccessedTime;
    lastAccessedTime = System.currentTimeMillis();
    if(maxInactiveInterval>=0 &&
       (lastAccessedTime-previousAccessedTime)/1000 >= maxInactiveInterval)
      return false;
    isNew = false;
    return true;
  }

  public boolean isNew()
  {
    if(invalidated)
      throw new IllegalStateException();
    return isNew;
  }

  public int getMaxInactiveInterval()
  {
    return maxInactiveInterval;
  }

  public void setMaxInactiveInterval(int interval)
  {
    maxInactiveInterval = interval;
  }

  public synchronized void invalidate()
  {
    if(invalidated)
      throw new IllegalStateException();
    invalidated = true;
    for(Enumeration atts = attributes.keys(); atts.hasMoreElements();) {
      String name = (String)atts.nextElement();
      Object v = attributes.get(name);
      if(v != null && v instanceof HttpSessionBindingListener)
	((HttpSessionBindingListener)v).valueUnbound(new HttpSessionBindingEvent(this, name));
    }
    attributes.clear();
  }

  /**
   * @deprecated  As of Version 2.2, this method is replaced by
   *              {@link getAttribute(java.lang.String)}.
   */
  public Object getValue(String name)
  {
    return getAttribute(name);
  }

  /**
   * @deprecated  As of Version 2.2, this method is replaced by
   *              {@link getAttributeNames()}.
   */
  public String[] getValueNames()
  {
    if(invalidated)
      throw new IllegalStateException();
    Set s = attributes.keySet();
    return (String[])s.toArray(new String[s.size()]);
  }

  /**
   * @deprecated  As of Version 2.2, this method is replaced by
   *              {@link setAttribute(java.lang.String,java.lang.Object)}.
   */
  public void putValue(String name, Object value)
  {
    setAttribute(name, value);
  }

  /**
   * @deprecated  As of Version 2.2, this method is replaced by
   *              {@link removeAttribute(java.lang.String)}.
   */
  public void removeValue(String name)
  {
    removeAttribute(name);
  }

  /**
   * @deprecated  As of Version 2.1, this method is deprecated
   *		  and has no replacement.
   */
  public HttpSessionContext getSessionContext()
  {
    return null;
  }

  // 2.2 stuff follows

  public synchronized Object getAttribute(String name)
  {
    if(invalidated)
      throw new IllegalStateException();
    return attributes.get(name);
  }

  public Enumeration getAttributeNames()
  {
    if(invalidated)
      throw new IllegalStateException();
    return attributes.keys();
  }

  public void setAttribute(String name, Object value)
  {
    if(value == null)
      throw new NullPointerException();
    if(invalidated)
      throw new IllegalStateException();
    Object old = attributes.get(name);
    if(value instanceof HttpSessionBindingListener)
      ((HttpSessionBindingListener)old).valueBound(new HttpSessionBindingEvent(this, name));
    attributes.put(name, value);
    if(old != null && old instanceof HttpSessionBindingListener)
      ((HttpSessionBindingListener)old).valueUnbound(new HttpSessionBindingEvent(this, name));
  }

  public void removeAttribute(String name)
  {
    if(invalidated)
      throw new IllegalStateException();
    Object old = attributes.get(name);
    attributes.remove(name);
    if(old != null && old instanceof HttpSessionBindingListener)
      ((HttpSessionBindingListener)old).valueUnbound(new HttpSessionBindingEvent(this, name));
  }
}

