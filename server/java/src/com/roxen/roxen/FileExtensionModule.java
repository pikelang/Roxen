/*
 * $Id$
 *
 */

package com.roxen.roxen;

import java.io.File;

/**
 * The interface for modules which handle a specific file extension.
 *
 * @see Module
 *
 * @version	$Version$
 * @author	marcus
 */

public interface FileExtensionModule {

  /**
   * Returns a list of of file extensions that should be handled
   * by this module.  The extensions should be returned in lower case,
   * and without the period (.).
   *
   * @return an array of strings with file extension names
   */
  String[] queryFileExtensions();

  /**
   * Request that the module processes a file with a certain
   * extension.
   *
   * @param  file  the file to be processed
   * @param  ext   the file extension
   * @param  id    the request object
   * @return       a response, or <code>null</code> if the module
   *               will not process this file.
   */
  RoxenResponse handleFileExtension(File file, String ext, RoxenRequest id);

}
