/*
 * $Id: ParserModule.java,v 1.1 2004/05/31 11:48:52 _cvs_dirix Exp $
 *
 */

package com.chilimoon.chilimoon;

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
