/*
 * $Id: ContainerCaller.java,v 1.1 1999/12/19 00:26:00 marcus Exp $
 *
 */

package se.idonex.roxen;

import java.util.Dictionary;

public interface ContainerCaller {

  public String containerCalled(String tag, Dictionary args, String contents,
				RoxenRequest id, Object file,
				Dictionary defines, Object client);

}

