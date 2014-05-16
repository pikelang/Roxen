/*
 * $Id$
 *
 */

package com.roxen.roxen;

import java.io.Reader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.File;
import java.io.FileReader;
import java.io.FileNotFoundException;
import java.util.StringTokenizer;
import java.net.URL;

/**
 * A support class providing HTTP related functionality.
 * Rather than using this class directly, all these functions can
 * be accessed through the {@link RoxenLib} class.
 *
 * @version	$Version$
 * @author	marcus
 */

public class HTTP {

  /**
   * Quotes "dangerous" characters in an URL for sending it with
   * HTTP.
   * <p>
   * The following characters are replaced with <tt>%</tt> escapes:
   * <tt>SP, TAB, LF, CR, %, ', ", NUL</tt>.
   *
   * @param  f  the string to quote
   * @return    the quoted result
   */
  public static String httpEncodeString(String f)
  {
    StringTokenizer tok = new StringTokenizer(f, " \t\n\r%'\"\0", true);
    StringBuffer sb = new StringBuffer();
    while (tok.hasMoreTokens()) {
      String t = tok.nextToken();
      if(t.length()==1)
	switch(t.charAt(0)) {
	 case ' ': sb.append("%20"); break;
	 case '\t': sb.append("%09"); break;
	 case '\n': sb.append("%0a"); break;
	 case '\r': sb.append("%0d"); break;
	 case '%': sb.append("%25"); break;
	 case '\'': sb.append("%27"); break;
	 case '"': sb.append("%22"); break;
	 case '\0': sb.append("%00"); break;
	 default:
	   sb.append(t);
	}
      else
	sb.append(t);
    }
    return sb.toString();
  }

  /**
   * Create a response object with a specific error code and HTML
   * message.
   *
   * @param  error  the HTTP error code
   * @param  data   the HTML text message
   * @return        a response object
   */
  public static RoxenResponse httpLowAnswer(int error, String data)
  {
    return new RoxenStringResponse(error, "text/html", data.length(), data);
  }

  /**
   * Create a response object with a specific error code and
   * no body text.
   *
   * @param  error  the HTTP error code
   * @return        a response object
   */
  public static RoxenResponse httpLowAnswer(int error)
  {
    return httpLowAnswer(error, "");
  }

  /**
   * Create a response with a specific media type
   * from a string value.
   *
   * @param  text   the content of the response
   * @param  type   the media type of the response
   * @return        a response object
   */
  public static RoxenResponse httpStringAnswer(String text, String type)
  {
    return new RoxenStringResponse(0, type, text.length(), text);
  }

  /**
   * Create an HTML response from a string value.
   *
   * @param  text   the content of the response
   * @return        a response object
   */
  public static RoxenResponse httpStringAnswer(String text)
  {
    return httpStringAnswer(text, "text/html");
  }

  /**
   * Create a response with a specific media type
   * from an RXML parsed string value.
   *
   * @param  text   the content of the response
   * @param  type   the media type of the response
   * @return        a response object
   */
  public static RoxenResponse httpRXMLAnswer(String text, String type)
  {
    return new RoxenRXMLResponse(0, type, text);
  }

  /**
   * Create an HTML response from an RXML parsed string value.
   *
   * @param  text   the content of the response
   * @return        a response object
   */
  public static RoxenResponse httpRXMLAnswer(String text)
  {
    return httpRXMLAnswer(text, "text/html");
  }

  /**
   * Create a response of known length with a specific media type
   * from a Reader.
   *
   * @param  text   the Reader which should produce the content of the response
   * @param  type   the media type of the response
   * @param  len    the number of bytes in the content
   * @return        a response object
   */
  public static RoxenResponse httpFileAnswer(Reader text, String type, long len)
  {
    return new RoxenFileResponse(type, len, text);
  }

  /**
   * Create a response with a specific media type
   * from a Reader.
   *
   * @param  text   the Reader which should produce the content of the response
   * @param  type   the media type of the response
   * @return        a response object
   */
  public static RoxenResponse httpFileAnswer(Reader text, String type)
  {
    return httpFileAnswer(text, type, -1);
  }

  /**
   * Create an HTML response from a Reader.
   *
   * @param  text   the Reader which should produce the content of the response
   * @return        a response object
   */
  public static RoxenResponse httpFileAnswer(Reader text)
  {
    return httpFileAnswer(text, "text/html");
  }  

  /**
   * Create a response of known length with a specific media type
   * from an InputStream.
   *
   * @param  text   the InputStream which should produce the content of the response
   * @param  type   the media type of the response
   * @param  len    the number of bytes in the content
   * @return        a response object
   */
  public static RoxenResponse httpFileAnswer(InputStream text, String type,
					     long len)
  {
    return httpFileAnswer(new InputStreamReader(text), type, len);
  }

  /**
   * Create a response with a specific media type
   * from an InputStream.
   *
   * @param  text   the InputStream which should produce the content of the response
   * @param  type   the media type of the response
   * @return        a response object
   */
  public static RoxenResponse httpFileAnswer(InputStream text, String type)
  {
    return httpFileAnswer(text, type, -1);
  }

  /**
   * Create an HTTP response from an InputStream.
   *
   * @param  text   the InputStream which should produce the content of the response
   * @return        a response object
   */
  public static RoxenResponse httpFileAnswer(InputStream text)
  {
    return httpFileAnswer(text, "text/html");
  }  

  /**
   * Create a response of known length with a specific media type
   * from a File
   *
   * @param  text   the File from which the content should be read
   * @param  type   the media type of the response
   * @param  len    the number of bytes in the content
   * @return        a response object
   * @exception  FileNotFoundException  if the file doesn't exist
   */
  public static RoxenResponse httpFileAnswer(File text, String type, long len)
    throws FileNotFoundException
  {
    return httpFileAnswer(new FileReader(text), type, len);
  }

  /**
   * Create a response with a specific media type
   * from a File
   *
   * @param  text   the File from which the content should be read
   * @param  type   the media type of the response
   * @return        a response object
   * @exception  FileNotFoundException  if the file doesn't exist
   */
  public static RoxenResponse httpFileAnswer(File text, String type)
    throws FileNotFoundException
  {
    return httpFileAnswer(text, type, text.length());
  }

  /**
   * Create an HTTP response from a File
   *
   * @param  text   the File from which the content should be read
   * @param  type   the media type of the response
   * @return        a response object
   * @exception  FileNotFoundException  if the file doesn't exist
   */
  public static RoxenResponse httpFileAnswer(File text)
    throws FileNotFoundException
  {
    return httpFileAnswer(text, "text/html");
  }  

  /**
   * Create a redirect response to a specified URL
   *
   * @param  url  the URL to which the client should be redirected
   * @return      a response object
   */
  public static RoxenResponse httpRedirect(URL url)
  {
    RoxenResponse r = httpLowAnswer(302);
    r.addHTTPHeader("Location", httpEncodeString(url.toExternalForm()));
    return r;    
  }

  /**
   * Create a response requesting authentication information
   *
   * @param  realm   the security realm for which authentication is required
   * @param  message an HTTP string to be displayed if no authentication is provided
   * @return         a response object
   */
  public static RoxenResponse httpAuthRequired(String realm, String message)
  {
    RoxenResponse r = httpLowAnswer(401, message);
    r.addHTTPHeader("WWW-Authenticate", "basic realm=\""+realm+"\"");
    return r;
  }

  /**
   * Create a response requesting authentication information.
   * A default message is provided if authentication fails.
   *
   * @param  realm   the security realm for which authentication is required
   * @return         a response object
   */
  public static RoxenResponse httpAuthRequired(String realm)
  {
    return httpAuthRequired(realm, "<h1>Authentication failed.\n</h1>");
  }

  /**
   * Create a response requesting proxy authentication information
   *
   * @param  realm   the security realm for which authentication is required
   * @param  message an HTTP string to be displayed if no authentication is provided
   * @return         a response object
   */
  public static RoxenResponse httpProxyAuthRequired(String realm, String message)
  {
    RoxenResponse r = httpLowAnswer(407, message);
    r.addHTTPHeader("Proxy-Authenticate", "basic realm=\""+realm+"\"");
    return r;
  }

  /**
   * Create a response requesting proxy authentication information.
   * A default message is provided if authentication fails.
   *
   * @param  realm   the security realm for which authentication is required
   * @return         a response object
   */
  public static RoxenResponse httpProxyAuthRequired(String realm)
  {
    return httpProxyAuthRequired(realm, "<h1>Proxy authentication failed.\n</h1>");
  }

  HTTP() { }

}
