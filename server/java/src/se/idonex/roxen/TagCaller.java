/*
 * $Id: TagCaller.java,v 1.2 1999/12/20 18:51:34 marcus Exp $
 *
 */

package se.idonex.roxen;

import java.util.Map;

public interface TagCaller {

  public String queryName();
  public String tagCalled(String tag, Map args, RoxenRequest id);

}
