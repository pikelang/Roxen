/*
 * $Id: UniqueModule.java,v 1.6 2004/05/31 23:01:48 _cvs_stephen Exp $
 *
 */

package com.core.roxen;

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
