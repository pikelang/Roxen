/*
 * $Id: LocationModule.java,v 1.1 1999/12/19 00:26:00 marcus Exp $
 *
 */

package se.idonex.roxen;

public interface LocationModule {

  RoxenResponse findFile(String f, RoxenRequest id);

}
