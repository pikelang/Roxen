package com.roxen.servlet;

import java.util.Enumeration;
import java.util.NoSuchElementException;
import java.util.Calendar;
import java.util.Locale;
import java.util.TimeZone;
import java.util.Hashtable;
import java.io.File;
import java.io.StringWriter;
import java.io.PrintWriter;
import java.io.InputStream;
import java.io.IOException;
import java.net.URL;
import java.net.MalformedURLException;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import javax.servlet.Servlet;
import javax.servlet.ServletException;
import javax.servlet.ServletContext;
import javax.servlet.RequestDispatcher;


class RoxenServletContext implements ServletContext
{
  final int id;

  static DateFormat dateformat =
    new SimpleDateFormat("EEE, d MMM yyyy HH:mm:ss z", Locale.US);
  static {
    dateformat.setCalendar(Calendar.getInstance(TimeZone.getTimeZone("GMT"),
						Locale.US));
  }

  Hashtable attributes = new Hashtable();
  Hashtable initparameters = new Hashtable();

  /**
   * @deprecated  As of Java Servlet API 2.1, with no direct replacement. 
   */
  public Servlet getServlet(String name) throws ServletException
  {
    return null;
  }

  /**
   * @deprecated  As of Java Servlet API 2.1, with no replacement. 
   */
  public Enumeration getServletNames()
  {

    return new Enumeration() {

      public boolean hasMoreElements()
      {
	return false;
      }

      public Object nextElement()
      {
	throw new NoSuchElementException();
      }

    };
    
  }

  /**
   * @deprecated  As of Java Servlet API 2.0, with no replacement. 
   */
  public Enumeration getServlets()
  {
    return new Enumeration() {

      public boolean hasMoreElements()
      {
	return false;
      }

      public Object nextElement()
      {
	throw new NoSuchElementException();
      }

    };
  }

  public native void log(String msg);

  /**
   * @deprecated  As of Java Servlet API 2.1, use
   * 		  {@link log(String message, Throwable throwable)} 
   *		  instead.
   */
  public void log(Exception exception, String msg)
  {
    log(msg, exception);
  }

  public void log(String message, Throwable throwable)
  {
    StringWriter sw = new StringWriter();
    throwable.printStackTrace(new PrintWriter(sw));
    sw.write(message);
    log(sw.toString());
  }

  public native String getRealPath(String path);
  public native String getMimeType(String file);
  public native String getServerInfo();

  public Object getAttribute(String name)
  {
    return attributes.get(name);
  }

  public void setAttribute(String name, Object object)
  {
    attributes.put(name, object);
  }

  public void removeAttribute(String name)
  {
    attributes.remove(name);
  }

  public Enumeration getAttributeNames()
  {
    return attributes.keys();
  }

  public ServletContext getContext(String uripath)
  {
    return this;
  }

  native RequestDispatcher getRequestDispatcher(String path1, String path2);

  public RequestDispatcher getRequestDispatcher(String path)
  {
    return getRequestDispatcher("", path);
  }

  private native String getResourceURL(String path);

  public URL getResource(String path) throws MalformedURLException
  {
    String url = getResourceURL(path);
    return url == null? null : new URL(url);
  }

  public InputStream getResourceAsStream(String path)
  {
    try {
      URL url = getResource(path);
      return url == null? null : url.openStream();
    } catch(MalformedURLException e) {
      return null;
    } catch(IOException e) {
      return null;
    }
  }

  public int getMajorVersion()
  {
    return 2;
  }

  public int getMinorVersion()
  {
    return 2;
  }

  RoxenServletContext(int id, String temppath)
  {
    this.id = id;
    setAttribute("javax.servlet.context.tempdir", new File(temppath));
  }

  // 2.2 stuff follows

  public RequestDispatcher getNamedDispatcher(String name)
  {
    return null;
  }

  public String getInitParameter(String name)
  {
    return (String)initparameters.get(name);
  }

  public Enumeration getInitParameterNames()
  {
    return initparameters.keys();
  }

}
