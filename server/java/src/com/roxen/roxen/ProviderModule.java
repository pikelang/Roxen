/*
 * $Id: ProviderModule.java,v 1.6 2004/06/01 07:37:35 _cvs_stephen Exp $
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
