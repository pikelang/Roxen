/*
 * $Id: ProviderModule.java,v 1.1 2004/05/31 11:48:52 _cvs_dirix Exp $
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
