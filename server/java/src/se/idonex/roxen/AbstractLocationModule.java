/*
 * $Id: AbstractLocationModule.java,v 1.1 2000/01/09 23:27:56 marcus Exp $
 *
 */

package se.idonex.roxen;

public abstract class AbstractLocationModule extends Module implements LocationModule {

  public String queryLocation()
  {
    return queryString("location");
  }

  public String[] findDir(String f, RoxenRequest id)
  {
    return null;
  }

  public String realFile(String f, RoxenRequest id)
  {
    return null;
  }

  public int[] statFile(String f, RoxenRequest id)
  {
    return null;
  }

}
