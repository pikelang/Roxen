/*
 * $Id: RoxenRXMLResponse.java,v 1.1 2000/01/05 18:10:55 marcus Exp $
 *
 */

package se.idonex.roxen;

public class RoxenRXMLResponse extends RoxenStringResponse {

  RoxenRXMLResponse(int _errno, String _type, String _data)
  {
    super(_errno, _type, 0, _data);
  }

}

