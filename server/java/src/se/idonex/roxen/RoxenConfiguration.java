/*
 * $Id: RoxenConfiguration.java,v 1.2 1999/12/21 00:06:25 marcus Exp $
 *
 */

package se.idonex.roxen;

public class RoxenConfiguration {

  public native Object query(String name);
  public native String queryInternalLocation(Module m);

  public String queryString(String name)
  {
    return (String)query(name);
  }

  public String queryInternalLocation()
  {
    return queryInternalLocation(null);
  }

}
