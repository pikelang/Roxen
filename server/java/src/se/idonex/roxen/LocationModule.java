/*
 * $Id: LocationModule.java,v 1.2 1999/12/19 21:00:26 marcus Exp $
 *
 */

package se.idonex.roxen;

public interface LocationModule {

  String queryLocation();
  RoxenResponse findFile(String f, RoxenRequest id);

}
