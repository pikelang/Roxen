/*
 * $Id: RoxenFileResponse.java,v 1.3 2000/02/21 18:30:46 marcus Exp $
 *
 */

package com.roxen.roxen;

import java.io.Reader;

/**
 * A class of responses using a file as their source.
 * Use the methods in the {@link HTTP} class to create
 * objects of this class.
 *
 * @see RoxenLib
 *
 * @version	$Version$
 * @author	marcus
 */

public class RoxenFileResponse extends RoxenResponse {

  Reader file;

  RoxenFileResponse(String _type, long _len, Reader _file)
  {
    super(0, _type, _len);
    file = _file;
  }

}

