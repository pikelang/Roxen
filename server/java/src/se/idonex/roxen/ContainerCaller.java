/*
 * $Id: ContainerCaller.java,v 1.2 1999/12/20 18:51:33 marcus Exp $
 *
 */

package se.idonex.roxen;

import java.util.Map;

public interface ContainerCaller {

  public String queryName();
  public String containerCalled(String tag, Map args, String contents,
				RoxenRequest id);

}

