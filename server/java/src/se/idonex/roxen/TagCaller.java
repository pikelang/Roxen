/*
 * $Id: TagCaller.java,v 1.1 1999/12/19 00:26:01 marcus Exp $
 *
 */

package se.idonex.roxen;

import java.util.Dictionary;

public interface TagCaller {

  public String tagCalled(String tag, Dictionary args, RoxenRequest id,
			  Object file, Dictionary defines, Object client);

}
