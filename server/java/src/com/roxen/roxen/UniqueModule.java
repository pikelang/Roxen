/*
 * $Id: UniqueModule.java,v 1.5 2004/05/31 11:45:00 _cvs_dirix Exp $
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
