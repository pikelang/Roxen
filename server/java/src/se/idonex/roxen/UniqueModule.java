/*
 * $Id: UniqueModule.java,v 1.2 2000/02/06 21:30:59 marcus Exp $
 *
 */

package se.idonex.roxen;

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
