/*
 * $Id: ContainerCaller.java,v 1.3 2000/01/12 04:47:40 marcus Exp $
 *
 */

package se.idonex.roxen;

import java.util.Map;

public interface ContainerCaller {

  public String queryContainerName();
  public String containerCalled(String tag, Map args, String contents,
				RoxenRequest id);

}

