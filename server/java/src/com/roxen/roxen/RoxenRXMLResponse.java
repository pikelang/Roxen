/*
 * $Id: RoxenRXMLResponse.java,v 1.5 2004/06/01 07:37:35 _cvs_stephen Exp $
 *
 */

package com.roxen.roxen;

/**
 * A class of responses using an RXML parsed string as
 * their source.
 * Use the methods in the {@link HTTP} class to create
 * objects of this class.
 *
 * @see RoxenLib
 *
 * @version	$Version$
 * @author	marcus
 */

public class RoxenRXMLResponse extends RoxenStringResponse {

  RoxenRXMLResponse(int _errno, String _type, String _data)
  {
    super(_errno, _type, 0, _data);
  }

}

