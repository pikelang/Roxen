/*
 * $Id: ProviderModule.java,v 1.5 2004/05/31 23:01:48 _cvs_stephen Exp $
 *
 */

package com.core.roxen;

/**
 * The interface for modules providing services to other modules.
 *
 * @see Module
 *
 * @version	$Version$
 * @author	marcus
 */

public interface ProviderModule {

  /**
   * Returns the name of the service this module provides
   *
   * @return  a string uniquely identifying the service
   */
  String queryProvides();

}
