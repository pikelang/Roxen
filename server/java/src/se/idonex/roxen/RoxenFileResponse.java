/*
 * $Id: RoxenFileResponse.java,v 1.1 1999/12/21 00:05:45 marcus Exp $
 *
 */

package se.idonex.roxen;

import java.io.Reader;

public class RoxenFileResponse extends RoxenResponse {

  Reader file;

  RoxenFileResponse(String _type, long _len, Reader _file)
  {
    super(0, _type, _len);
    file = _file;
  }

}

