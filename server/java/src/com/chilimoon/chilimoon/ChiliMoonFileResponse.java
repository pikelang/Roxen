/*
 * $Id: ChiliMoonFileResponse.java,v 1.1 2004/05/31 11:48:51 _cvs_dirix Exp $
 *
 */

package com.chilimoon.chilimoon;

import java.io.Reader;

/**
 * A class of responses using a file as their source.
 * Use the methods in the {@link HTTP} class to create
 * objects of this class.
 *
 * @see ChiliMoonLib
 *
 * @version	$Version$
 * @author	marcus
 */

public class ChiliMoonFileResponse extends ChiliMoonResponse {

  Reader file;

  ChiliMoonFileResponse(String _type, long _len, Reader _file)
  {
    super(0, _type, _len);
    file = _file;
  }

}

