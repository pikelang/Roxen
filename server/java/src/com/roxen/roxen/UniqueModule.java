/*
 * $Id: UniqueModule.java,v 1.3 2000/02/21 18:30:46 marcus Exp $
 *
 */

package com.roxen.roxen;

/**
 * The interface for modules that may only have one copy in any
 * given virtual server. It contains no methods, implementing it
 * just prevents multiple copies of the module from being added
 * to a virtual server.
 *
 * @see Module
 *
 * @version	$Version$
 * @author	marcus
 */

public interface UniqueModule {
}
