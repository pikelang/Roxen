/*
 * $Id$
 *
 */

package com.roxen.roxen;

/**
 * The interface for modules which have a specific URL path in the
 * virtual file system.
 *
 * @see Module
 *
 * @version	$Version$
 * @author	marcus
 */

public interface LocationModule {

  /**
   * Returns the URL path handled by this module.
   *
   * @return the path name
   */
  String queryLocation();

  /**
   * Request a file from this module.
   *
   * @param  f   the path of the file relative to the location of
   *             this module
   * @param  id  the request object
   * @return     a response, or <code>null</code> if no such
   *             file exists.
   */
  RoxenResponse findFile(String f, RoxenRequest id);

  /**
   * List the contents of a directory.
   *
   * @param  f   the path of the directory relative to the location of
   *             this module
   * @param  id  the request object
   * @return     a list of filenames, or <code>null</code> if no such
   *             directory exists.
   */
  String[] findDir(String f, RoxenRequest id);

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
  String realFile(String f, RoxenRequest id);

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
  int[] statFile(String f, RoxenRequest id);

}
