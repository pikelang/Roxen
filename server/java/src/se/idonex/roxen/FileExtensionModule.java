/*
 * $Id: FileExtensionModule.java,v 1.1 2000/01/10 20:32:09 marcus Exp $
 *
 */

package se.idonex.roxen;

import java.io.File;

public interface FileExtensionModule {

  String[] queryFileExtensions();
  RoxenResponse handleFileExtension(File file, String ext, RoxenRequest id);

}
