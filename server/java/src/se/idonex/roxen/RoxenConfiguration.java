/*
 * $Id: RoxenConfiguration.java,v 1.1 1999/12/19 00:26:00 marcus Exp $
 *
 */

package se.idonex.roxen;

public class RoxenConfiguration {

  public native Object query(String name);

  public String queryString(String name)
  {
    return (String)query(name);
  }

  public String queryInternalLocation()
  {
    return queryString("InternalLoc");
  }

  public String queryInternalLocation(Module m)
  {
    return queryInternalLocation()+"blah!0"+"/";
  }

}
