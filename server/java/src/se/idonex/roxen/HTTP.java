/*
 * $Id: HTTP.java,v 1.3 2000/01/05 18:14:46 marcus Exp $
 *
 */

package se.idonex.roxen;

import java.io.Reader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.File;
import java.io.FileReader;
import java.io.FileNotFoundException;

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

  public static RoxenResponse httpRXMLAnswer(String text, String type)
  {
    return new RoxenRXMLResponse(0, type, text);
  }

  public static RoxenResponse httpRXMLAnswer(String text)
  {
    return httpRXMLAnswer(text, "text/html");
  }

  public static RoxenResponse httpFileAnswer(Reader text, String type, long len)
  {
    return new RoxenFileResponse(type, len, text);
  }

  public static RoxenResponse httpFileAnswer(Reader text, String type)
  {
    return httpFileAnswer(text, type, -1);
  }

  public static RoxenResponse httpFileAnswer(Reader text)
  {
    return httpFileAnswer(text, "text/html");
  }  

  public static RoxenResponse httpFileAnswer(InputStream text, String type,
					     long len)
  {
    return httpFileAnswer(new InputStreamReader(text), type, len);
  }

  public static RoxenResponse httpFileAnswer(InputStream text, String type)
  {
    return httpFileAnswer(text, type, -1);
  }

  public static RoxenResponse httpFileAnswer(InputStream text)
  {
    return httpFileAnswer(text, "text/html");
  }  

  public static RoxenResponse httpFileAnswer(File text, String type, long len)
    throws FileNotFoundException
  {
    return httpFileAnswer(new FileReader(text), type, len);
  }

  public static RoxenResponse httpFileAnswer(File text, String type)
    throws FileNotFoundException
  {
    return httpFileAnswer(text, type, text.length());
  }

  public static RoxenResponse httpFileAnswer(File text)
    throws FileNotFoundException
  {
    return httpFileAnswer(text, "text/html");
  }  


  HTTP() { }

}
