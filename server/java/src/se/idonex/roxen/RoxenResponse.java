/*
 * $Id: RoxenResponse.java,v 1.2 1999/12/21 00:06:39 marcus Exp $
 *
 */

package se.idonex.roxen;

public abstract class RoxenResponse {

  int errno;
  String type;
  long len;

  RoxenResponse(int _errno, String _type, long _len)
  {
    errno = _errno;
    type = _type;
    len = _len;
  }

}

