/*
 * $Id: HTTP.java,v 1.4 2000/01/10 00:04:57 marcus Exp $
 *
 */

package se.idonex.roxen;

import java.io.Reader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.File;
import java.io.FileReader;
import java.io.FileNotFoundException;
import java.util.StringTokenizer;
import java.net.URL;

public class HTTP {

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

  public static RoxenResponse httpRedirect(URL url)
  {
    RoxenResponse r = httpLowAnswer(302);
    r.addHTTPHeader("Location", httpEncodeString(url.toExternalForm()));
    return r;    
  }

  public static RoxenResponse httpAuthRequired(String realm, String message)
  {
    RoxenResponse r = httpLowAnswer(401, message);
    r.addHTTPHeader("WWW-Authenticate", "basic realm=\""+realm+"\"");
    return r;
  }

  public static RoxenResponse httpAuthRequired(String realm)
  {
    return httpAuthRequired(realm, "<h1>Authentication failed.\n</h1>");
  }

  public static RoxenResponse httpProxyAuthRequired(String realm, String message)
  {
    RoxenResponse r = httpLowAnswer(407, message);
    r.addHTTPHeader("Proxy-Authenticate", "basic realm=\""+realm+"\"");
    return r;
  }

  public static RoxenResponse httpProxyAuthRequired(String realm)
  {
    return httpProxyAuthRequired(realm, "<h1>Proxy authentication failed.\n</h1>");
  }

  HTTP() { }

}
