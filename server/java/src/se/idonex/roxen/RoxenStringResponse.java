/*
 * $Id: RoxenStringResponse.java,v 1.4 2000/02/06 18:44:35 marcus Exp $
 *
 */

package se.idonex.roxen;

/**
 * A class of responses using a string as their source.
 * Use the methods in the {@link HTTP} class to create
 * objects of this class.
 *
 * @see RoxenLib
 *
 * @version	$Version$
 * @author	marcus
 */

public class RoxenStringResponse extends RoxenResponse {

  String data;

  RoxenStringResponse(int _errno, String _type, long _len, String _data)
  {
    super(_errno, _type, _len);
    data = _data;
  }

}

