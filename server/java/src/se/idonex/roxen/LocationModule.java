/*
 * $Id: LocationModule.java,v 1.3 2000/01/09 23:27:55 marcus Exp $
 *
 */

package se.idonex.roxen;

public interface LocationModule {

  String queryLocation();
  RoxenResponse findFile(String f, RoxenRequest id);
  String[] findDir(String f, RoxenRequest id);
  String realFile(String f, RoxenRequest id);
  int[] statFile(String f, RoxenRequest id);

}
