/*
 * $Id: ProviderModule.java,v 1.3 2004/05/30 23:18:39 _cvs_dirix Exp $
 *
 */

package com.chilimoon.chilimoon;

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
