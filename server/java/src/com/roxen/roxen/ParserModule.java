/*
 * $Id: ParserModule.java,v 1.7 2004/05/31 23:01:48 _cvs_stephen Exp $
 *
 */

package com.core.roxen;

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
