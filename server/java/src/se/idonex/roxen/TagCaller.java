/*
 * $Id: TagCaller.java,v 1.4 2000/02/06 21:30:59 marcus Exp $
 *
 */

package se.idonex.roxen;

import java.util.Map;

/**
 * The interface for handling a single specific RXML empty element tag
 *
 * @see ParserModule
 *
 * @version	$Version$
 * @author	marcus
 */

public interface TagCaller {

  /**
   * Return the name of the tag handled by this caller object
   *
   * @return the name of the tag
   */
  public String queryTagName();

  /**
   * Handle a call to the tag handled by this caller object
   *
   * @param  tag  the name of the tag
   * @param  args any attributes given to the tag
   * @param  id   the request object
   * @return      the result of handling the tag
   */
  public String tagCalled(String tag, Map args, RoxenRequest id);

}
