/*
 * $Id: ContainerCaller.java,v 1.4 2000/02/06 21:30:59 marcus Exp $
 *
 */

package se.idonex.roxen;

import java.util.Map;

/**
 * The interface for handling a single specific RXML container tag
 *
 * @see ParserModule
 *
 * @version	$Version$
 * @author	marcus
 */

public interface ContainerCaller {

  /**
   * Return the name of the container tag handled by this caller object
   *
   * @return the name of the container tag
   */
  public String queryContainerName();

  /**
   * Handle a call to the container tag handled by this caller object
   *
   * @param  tag       the name of the tag
   * @param  args      any attributes given to the 
   * @param  contents  the contents of the container tag
   * @param  id        the request object
   * @return           the result of handling the tag
   */
  public String containerCalled(String tag, Map args, String contents,
				RoxenRequest id);

}

