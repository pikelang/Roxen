/*
 * $Id: RoxenStringResponse.java,v 1.3 1999/12/21 00:06:39 marcus Exp $
 *
 */

package se.idonex.roxen;

public class RoxenStringResponse extends RoxenResponse {

  String data;

  RoxenStringResponse(int _errno, String _type, long _len, String _data)
  {
    super(_errno, _type, _len);
    data = _data;
  }

}

