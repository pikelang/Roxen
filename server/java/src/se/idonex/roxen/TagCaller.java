/*
 * $Id: TagCaller.java,v 1.3 2000/01/12 04:47:40 marcus Exp $
 *
 */

package se.idonex.roxen;

import java.util.Map;

public interface TagCaller {

  public String queryTagName();
  public String tagCalled(String tag, Map args, RoxenRequest id);

}
