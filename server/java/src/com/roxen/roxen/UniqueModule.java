/*
 * $Id: UniqueModule.java,v 1.4 2004/05/30 23:18:39 _cvs_dirix Exp $
 *
 */

package com.chilimoon.chilimoon;

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
