/*
 * $Id: ProviderModule.java,v 1.2 2000/02/21 18:30:46 marcus Exp $
 *
 */

package com.roxen.roxen;

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
