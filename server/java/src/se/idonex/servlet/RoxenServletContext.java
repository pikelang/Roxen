package se.idonex.servlet;

import java.util.Enumeration;
import java.util.NoSuchElementException;
import java.util.Calendar;
import java.util.Locale;
import java.util.TimeZone;
import java.io.StringWriter;
import java.io.PrintWriter;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import javax.servlet.Servlet;
import javax.servlet.ServletException;


class RoxenServletContext implements javax.servlet.ServletContext
{
  final int id;

  static DateFormat dateformat =
    new SimpleDateFormat("EEE, d MMM yyyy HH:mm:ss z", Locale.US);
  static {
    dateformat.setCalendar(Calendar.getInstance(TimeZone.getTimeZone("GMT"),
						Locale.US));
  }

  public native Servlet getServlet(String name) throws ServletException;
  private native String[] getServletList();

  public Enumeration getServletNames()
  {

    return new Enumeration() {

      String[] servlets = getServletList();
      int pos = 0;

      public boolean hasMoreElements()
      {
	return pos<servlets.length;
      }

      public Object nextElement()
      {
	if(pos>=servlets.length)
	  throw new NoSuchElementException();
	return servlets[pos++];
      }

    };
    
  }

  /**
   * @deprecated  Please use getServletNames in conjunction with getServlet
   */
  public Enumeration getServlets()
  {
    return new Enumeration() {

      Enumeration parent = getServletNames();

      public boolean hasMoreElements()
      {
	return parent.hasMoreElements();
      }

      public Object nextElement()
      {
	try {
	  return getServlet((String)parent.nextElement());
	} catch(ServletException se) {
	  return null;
	}
      }

    };
  }

  public native void log(String msg);

  public void log(Exception exception, String msg)
  {
    StringWriter sw = new StringWriter();
    exception.printStackTrace(new PrintWriter(sw));
    sw.write(msg);
    log(sw.toString());
  }

  public native String getRealPath(String path);
  public native String getMimeType(String file);
  public native String getServerInfo();
  public native Object getAttribute(String name);

  RoxenServletContext(int id)
  {
    this.id = id;
  }

}
