/*
 * $Id: RoxenStringResponse.java,v 1.2 1999/12/19 21:00:51 marcus Exp $
 *
 */

package se.idonex.roxen;

public class RoxenStringResponse extends RoxenResponse {

  String data;

  RoxenStringResponse(int _errno, String _type, int _len, String _data)
  {
    super(_errno, _type, _len);
    data = _data;
  }

}

