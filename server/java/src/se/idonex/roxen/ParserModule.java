/*
 * $Id: ParserModule.java,v 1.3 2000/02/07 17:00:56 marcus Exp $
 *
 */

package se.idonex.roxen;

/**
 * The interface for modules which define RXML tags.
 *
 * @see Module
 *
 * @version	$Version$
 * @author	marcus
 */

public interface ParserModule {

  /**
   * Returns the set of tags handled by this module.
   *
   * @return tag handler objects for the desried tags
   */
  SimpleTagCaller[] querySimpleTagCallers();

}
