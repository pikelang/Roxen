/*
 * $Id: RoxenResponse.java,v 1.3 2000/01/10 00:04:57 marcus Exp $
 *
 */

package se.idonex.roxen;

import java.util.Map;
import java.util.HashMap;

public abstract class RoxenResponse {

  int errno;
  String type;
  long len;
  Map extra_heads;

  public void addHTTPHeader(String name, String value)
  {
    if(name == null)
      return;
    if(extra_heads == null)
      extra_heads = new HashMap();
    Object o = extra_heads.get(name);
    if(o != null)
      if(o instanceof Object[]) {
	String[] n = new String[((Object[])o).length+1];
	System.arraycopy(o, 0, n, 0, n.length-1);
	n[n.length-1] = value;
	extra_heads.put(name, n);
      } else {
	String[] n = new String[2];
	n[0] = (String)o;
	n[1] = value;
	extra_heads.put(name, n);
      }
    else
      extra_heads.put(name, value);
  }

  RoxenResponse(int _errno, String _type, long _len)
  {
    errno = _errno;
    type = _type;
    len = _len;
  }

}

