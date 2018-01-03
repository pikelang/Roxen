/*
 * $Id$
 *
 */

package com.roxen.roxen;

import java.util.Map;
import java.util.HashMap;

/**
 * The base class for response objects.
 * Use the methods in the {@link HTTP} class to create
 * response objects.
 *
 * @see RoxenLib
 *
 * @version	$Version$
 * @author	marcus
 */

public abstract class RoxenResponse {

  int errno;
  String type;
  long len;
  Map extraHeads;

  /**
   * Add a specific HTTP header to the response
   *
   * @param name  the name of the header
   * @param value the value of the header
   */
  public void addHTTPHeader(String name, String value)
  {
    if(name == null)
      return;
    if(extraHeads == null)
      extraHeads = new HashMap();
    Object o = extraHeads.get(name);
    if(o != null)
      if(o instanceof Object[]) {
	String[] n = new String[((Object[])o).length+1];
	System.arraycopy(o, 0, n, 0, n.length-1);
	n[n.length-1] = value;
	extraHeads.put(name, n);
      } else {
	String[] n = new String[2];
	n[0] = (String)o;
	n[1] = value;
	extraHeads.put(name, n);
      }
    else
      extraHeads.put(name, value);
  }

  RoxenResponse(int _errno, String _type, long _len)
  {
    errno = _errno;
    type = _type;
    len = _len;
  }

}

