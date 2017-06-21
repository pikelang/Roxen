/*
 * $Id$
 *
 */

package com.roxen.roxen;

/**
 * A class representing the configuration of a virtual server in
 * the Roxen server.
 *
 * @version	$Version$
 * @author	marcus
 */

public class RoxenConfiguration {
  /**
   * Get the real path of a virtual file
   *
   * @param name The virtual file name
   */
  public native String getRealPath(String filename, RoxenRequest id);

  /**
   * Gets the contents of a file
   *
   * @param name The name of the file
   * @return File contents, or null if the file could not be read
   */
  public native String getFileContents(String filename, RoxenRequest id);

  /**
   * Gets the mime type of a file
   *
   * @param name The name of the file
   * @return The mime type of the file
   */
  public native String getMimeType(String filename);

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

  /**
   * Returns a list of modules providing a particular service
   *
   * @return    the modules that provide this service
   */
  public native Module[] getProviders(String provides);

  /**
   * Returns any module providing a particular service
   *
   * @return    the module that provide this service, or null
   */
  public Module getProvider(String provides)
  {
    Module[] modules = getProviders(provides);
    return (modules.length>0? modules[0] : null);
  }

}
