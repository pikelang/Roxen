/*
 * $Id: RoxenResponse.java,v 1.4 2000/01/10 00:14:59 marcus Exp $
 *
 */

package se.idonex.roxen;

import java.util.Map;
import java.util.HashMap;

public abstract class RoxenResponse {

  int errno;
  String type;
  long len;
  Map extraHeads;

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

