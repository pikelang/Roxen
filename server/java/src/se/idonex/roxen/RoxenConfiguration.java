/*
 * $Id: RoxenConfiguration.java,v 1.3 2000/02/06 02:10:12 marcus Exp $
 *
 */

package se.idonex.roxen;

/**
 * A class representing the configuration of a virtual server in
 * the Roxen server.
 *
 * @version	$Version$
 * @author	marcus
 */

public class RoxenConfiguration {

  /**
   * Get the current value of a global configuration variable
   *
   * @param  name  the internal name of the variable
   * @return       the value of the variable
   */
  public native Object query(String name);

  /**
   * Returns the URL path of the internal mount point
   * for a specified module
   *
   * @param  m  the module
   * @return    the URL path for the module's internal mount point
   */
  public native String queryInternalLocation(Module m);

  /**
   * Get the current value of a string typed
   * global configuration variable
   *
   * @param  name  the internal name of the variable
   * @return       the value of the variable
   */
  public String queryString(String name)
  {
    return (String)query(name);
  }

  /**
   * Returns the URL path of the base for all
   * internal mount points
   *
   * @return    the URL path for the base internal mount point
   */
  public String queryInternalLocation()
  {
    return queryInternalLocation(null);
  }

}
