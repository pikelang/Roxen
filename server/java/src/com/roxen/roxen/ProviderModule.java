/*
 * $Id: ProviderModule.java,v 1.4 2004/05/31 11:45:00 _cvs_dirix Exp $
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
