/*
 * $Id: ParserModule.java,v 1.6 2004/05/31 11:45:00 _cvs_dirix Exp $
 *
 */

package com.roxen.roxen;

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
