/*
 * $Id: ParserModule.java,v 1.2 2000/02/06 21:30:59 marcus Exp $
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
   * Returns the set of empty element tags handled by this module.
   *
   * @return tag handler objects for the desried tags
   */
  TagCaller[] queryTagCallers();

  /**
   * Returns the set of container tags handled by this module.
   *
   * @return container handler objects for the desried tags
   */
  ContainerCaller[] queryContainerCallers();

}
