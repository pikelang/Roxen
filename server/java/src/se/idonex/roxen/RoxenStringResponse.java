/*
 * $Id: RoxenStringResponse.java,v 1.1 1999/12/19 00:26:01 marcus Exp $
 *
 */

package se.idonex.roxen;

public class RoxenStringResponse extends RoxenResponse {

  String data;

  RoxenStringResponse(int _errno, String _type, int _len, String _data)
  {
    super(_errno, _type, _len);
    data = data;
  }

}

