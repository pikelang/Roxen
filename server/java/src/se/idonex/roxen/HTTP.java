/*
 * $Id: HTTP.java,v 1.1 1999/12/19 00:26:00 marcus Exp $
 *
 */

package se.idonex.roxen;

public class HTTP {

  public static RoxenResponse httpLowAnswer(int error, String data)
  {
    return new RoxenStringResponse(error, "text/html", data.length(), data);
  }

  public static RoxenResponse httpLowAnswer(int error)
  {
    return httpLowAnswer(error, "");
  }

  public static RoxenResponse httpStringAnswer(String text, String type)
  {
    return new RoxenStringResponse(0, type, text.length(), text);
  }

  public static RoxenResponse httpStringAnswer(String text)
  {
    return httpStringAnswer(text, "text/html");
  }

  HTTP() { }

}
