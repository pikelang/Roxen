/*
 * $Id: ProviderModule.java,v 1.1 2000/02/03 22:51:44 marcus Exp $
 *
 */

package se.idonex.roxen;

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
