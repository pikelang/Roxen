/*
 * $Id$
 *
 */

package com.roxen.roxen;

/**
 * An abstract adaptor class that provides default implementations for
 * most methods in the <code>LocationModule</code> interface.
 * <P>
 * A module inheriting this class must either create a module variable
 * <code>location</code> using <code>defvar</code>, or provide a different
 * implementation of the <code>queryLocation</code> method.
 *
 * @see LocationModule
 * @see Module
 *
 * @version	$Version$
 * @author	marcus
 */

public abstract class AbstractLocationModule extends Module implements LocationModule {
  /**
   * Returns the URL path handled by this module.
   * Per default, this is the contents of the module variable <code>location</code>.
   *
   * @return the path name
   */
  public String queryLocation()
  {
    return queryString("location");
  }

  /**
   * List the contents of a directory.
   *
   * @param  f   the path of the directory relative to the location of
   *             this module
   * @param  id  the request object
   * @return     a list of filenames, or <code>null</code> if no such
   *             directory exists.
   */
  public String[] findDir(String f, RoxenRequest id)
  {
    return null;
  }

  /**
   * Get the real filename of a file.
   *
   * @param  f   the path of the file relative to the location of
   *             this module
   * @param  id  the request object
   * @return     the path of the file in the host filesystem, or
   *             <code>null</code> if this resource is not a real
   *             file.
   */
  public String realFile(String f, RoxenRequest id)
  {
    return null;
  }

  /**
   * Get the attributes of a file or directory.
   * The attributes are a set of 7 integers.  These are: <code>mode</code>,
   * <code>size</code>, <code>atime</code>, <code>mtime</code>,
   * <code>ctime</code>, <code>uid</code>, <code>gid</code>.
   * 
   * @param  f   the path of the file or directory relative to the
   *             location of this module
   * @param  id  the request object
   * @return     the attributes of this file or directory, or
   *             <code>null</code> if this information is not available.
   */
  public int[] statFile(String f, RoxenRequest id)
  {
    return null;
  }

}
