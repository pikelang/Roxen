/*
 * $Id: RoxenResponse.java,v 1.1 1999/12/19 00:26:01 marcus Exp $
 *
 */

package se.idonex.roxen;

public abstract class RoxenResponse {

  int errno;
  String type;
  int len;

  RoxenResponse(int _errno, String _type, int _len)
  {
    errno = _errno;
    type = _type;
    len = _len;
  }

}

