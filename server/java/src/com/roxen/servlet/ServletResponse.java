package com.roxen.servlet;

import javax.servlet.ServletOutputStream;
import javax.servlet.http.Cookie;
import javax.servlet.http.HttpSession;
import java.io.PrintWriter;
import java.io.OutputStreamWriter;
import java.io.IOException;
import java.util.Date;
import java.util.Dictionary;
import java.util.Hashtable;
import java.util.Enumeration;
import java.util.Locale;
import java.util.List;
import java.util.Iterator;
import java.util.Vector;


class ServletResponse implements javax.servlet.http.HttpServletResponse
{
  int contentLength = -1;
  String contentType = null;
  String encoding = null;
  HTTPOutputStream pikeStream;
  ServletOutputStream outputStream = null;
  PrintWriter writer = null;
  Dictionary headers = null;
  int status = 200;
  String statusmsg = null;
  Locale locale = Locale.getDefault();

  static Dictionary statusTexts = new Hashtable();

  static {
    statusTexts.put(new Integer(200), "OK");
    statusTexts.put(new Integer(201), "Created");
    statusTexts.put(new Integer(202), "Accepted");
    statusTexts.put(new Integer(203), "Provisional Information");
    statusTexts.put(new Integer(204), "No Content");
    statusTexts.put(new Integer(300), "Moved");
    statusTexts.put(new Integer(301), "Permanent Relocation");
    statusTexts.put(new Integer(302), "Temporary Relocation");
    statusTexts.put(new Integer(303), "See Other");
    statusTexts.put(new Integer(304), "Not Modified");
    statusTexts.put(new Integer(400), "Bad Request");
    statusTexts.put(new Integer(401), "Access denied");
    statusTexts.put(new Integer(402), "Payment Required");
    statusTexts.put(new Integer(403), "Forbidden");
    statusTexts.put(new Integer(404), "No such file or directory");
    statusTexts.put(new Integer(405), "Method not allowed");
    statusTexts.put(new Integer(407), "Proxy authorization needed");
    statusTexts.put(new Integer(408), "Request timeout");
    statusTexts.put(new Integer(409), "Conflict");
    statusTexts.put(new Integer(410), "Gone");
    statusTexts.put(new Integer(500), "Internal Server Error");
    statusTexts.put(new Integer(501), "Not Implemented");
    statusTexts.put(new Integer(502), "Gateway Timeout");
    statusTexts.put(new Integer(503), "Service unavailable");
  }

  public void setContentLength(int len)
  {
    contentLength = len;
  }

  public void setContentType(String type)
  {
    if(contentType == null) {
      contentType = type;
      HeaderTokenizer ct = new HeaderTokenizer(type);
      try {
	ct.getValue();
	ct.discard('/');
	ct.getValue();
	if(ct.more())
	  for(;;) {
	    while(!ct.lookingAt(';'))
	      if(ct.more())
		ct.getValue();
	      else
		break;
	    ct.discard(';');
	    if(!ct.more())
	      break;
	    if("charset".equalsIgnoreCase(ct.getValue())) {
	      ct.discard('=');
	      encoding = ct.getValue();
	      break;
	    }
	  }
      } catch(IllegalArgumentException e) {
      }
    }
  }

  public ServletOutputStream getOutputStream() throws IOException
  {
    if(outputStream == null) {
      if(writer != null)
	throw new IllegalStateException();
      outputStream = pikeStream;
    }
    return outputStream;
  }

  void commitRequest(ServletOutputStream out) throws IOException
  {
    Object statustext;
    out.println("HTTP/1.0 "+status+" "+
		  ((statustext=statusTexts.get(new Integer(status)))==null?
		   "Foo":(String)statustext));
    if(!containsHeader("Content-Type"))
      out.println("Content-Type: "+contentType);
    if(contentLength != -1 && !containsHeader("Content-Length"))
      out.println("Content-Length: "+contentLength);
    if(headers != null)
      for(Enumeration e = headers.elements(); e.hasMoreElements() ;) {
	Object v = e.nextElement();
	if(v instanceof String)
	  out.println((String)v);
	else for(Iterator i = ((List)v).iterator(); i.hasNext(); )
	  out.println((String)i.next());
      }
    out.println();
    if(statusmsg != null)
      out.print(statusmsg);
  }

  public PrintWriter getWriter() throws IOException
  {
    if(writer == null) {
      if(outputStream != null)
	throw new IllegalStateException();
      writer = new PrintWriter(new OutputStreamWriter(pikeStream,
						      getCharacterEncoding()));
    }
    return writer;
  }

  public String getCharacterEncoding()
  {
    if(encoding == null) {
      if(contentType == null)
	contentType = "text/plain";
      encoding = System.getProperty("file.encoding", "iso-8859-1");
      contentType += "; charset="+encodeValue(encoding);
    }
    return encoding;
  }

  public void addCookie(Cookie cookie)
  {
    String val, cookiehead;
    int nval;
    Object v = null;

    if(headers != null)
      v = headers.get("set-cookie");
    if(v != null && v instanceof String) {
      cookiehead = ((String)v) + ",\r\n\t";
      v = null;
    } else
      cookiehead = "Set-Cookie: ";      

    cookiehead += encodeValue(cookie.getName())+"="+
      encodeValue(cookie.getValue());
    if((val = cookie.getComment()) != null)
      cookiehead += "; Comment="+encodeValue(val);
    if((val = cookie.getDomain()) != null)
      cookiehead += "; Domain="+encodeValue(val);
    if((nval = cookie.getMaxAge()) != -1)
      cookiehead += "; Max-Age="+nval;
    if((val = cookie.getPath()) != null)
      cookiehead += "; Path="+encodeValue(val);
    if(cookie.getSecure())
      cookiehead += "; Secure";
    if((nval = cookie.getVersion()) != 0)
      cookiehead += "; Version="+nval;

    if(v == null)
      v = cookiehead;
    else
      ((List)v).add(cookiehead);
    setHeader("set-cookie", v);
  }

  void setSessionId(HttpSession session)
  {
    Cookie id = new Cookie("JSESSIONID", session.getId());
    int mtim = session.getMaxInactiveInterval();
    if(mtim>=0)
      id.setMaxAge(mtim);
    id.setComment("servlet session tracking");
    addCookie(id);
  }

  protected static final boolean badAtomChar(char c)
  {
    return c<=32 || c>=127 || c=='(' || c==')' || c=='[' || c==']' ||
      c=='"' || c==',' || c=='\\' || c=='/' || c=='{' || c=='}' ||
      (c>=':' && c<='@');
  }

  protected static final String encodeValue(String val)
  {
    if(val.length()==0)
      return "\"\"";
    for(int i=0; i<val.length(); i++)
      if(badAtomChar(val.charAt(i))) {
	for(int p=0; (p=val.indexOf('\\', p))>=0; p+=2)
	  val = val.substring(0, p)+'\\'+val.substring(p);
	for(int p=0; (p=val.indexOf('"', p))>=0; p+=2)
	  val = val.substring(0, p)+'\\'+val.substring(p);
	return '"'+val+'"';
      }
    return val;
  }

  public boolean containsHeader(String name)
  {
    return headers != null && headers.get(name.toLowerCase()) != null;
  }

  /**
   * @deprecated  As of version 2.1, due to ambiguous meaning of the
   *              message parameter. To set a status code use
   *              setStatus(int), to send an error with a description
   *              use sendError(int, String).  Sets the status code
   *              and message for this response.
   */
  public void setStatus(int sc, String sm)
  {
    statusmsg = "<body>"+sm+"</body>\r\n";
    setContentType("text/html");
    setContentLength(statusmsg.length());
    setStatus(sc);
  }

  public void setStatus(int sc)
  {
    status = sc;
  }

  private void setHeader(String name, Object value)
  {
    if(headers == null)
      headers = new Hashtable();
    headers.put(name, value);
  }

  public void setHeader(String name, String value)
  {
    setHeader(name.toLowerCase(), (Object)(name+": "+value));
  }

  public void setIntHeader(String name, int value)
  {
    setHeader(name, Integer.toString(value));
  }

  public void setDateHeader(String name, long date)
  {
    setHeader(name, RoxenServletContext.dateformat.format(new Date(date)));
  }

  public void sendError(int sc, String msg) throws IOException
  {
    statusmsg = "<body>"+msg+"</body>\r\n";
    sendError(sc);
  }

  public void sendError(int sc) throws IOException
  {
    reset(); // Throws IllegalStateException if committed
    outputStream = null;
    setContentType("text/html");
    setContentLength((statusmsg==null? 0:statusmsg.length()));
    setStatus(sc);
    getWriter().close();
  }

  public void sendRedirect(String location) throws IOException
  {
    setHeader("Location", location);
    sendError(302);
  }

  /**
   * @deprecated  As of version 2.1, use encodeURL(String url) instead
   */
  public String encodeUrl(String url)
  {
    return encodeURL(url);
  }

  /**
   * @deprecated  As of version 2.1, use encodeRedirectURL(String url) instead
   */
  public String encodeRedirectUrl(String url)
  {
    return encodeRedirectURL(url);
  }

  public String encodeURL(String url)
  {
    return url;
  }

  public String encodeRedirectURL(String url)
  {
    return url;
  }

  void wrapUp() throws IOException
  {
    if(writer!=null)
      writer.flush();
    pikeStream.close();
  }

  ServletResponse(HTTPOutputStream sos)
  {
    pikeStream = sos;
    pikeStream.setResponse(this);
  }

  // 2.2 stuff follows

  public void setBufferSize(int size)
  {
    pikeStream.setBufferSize(size);
  }

  public int getBufferSize()
  {
    return pikeStream.getBufferSize();
  }

  public void reset()
  {
    pikeStream.reset();
  }
  
  public boolean isCommitted()
  {
    return pikeStream.isCommitted();
  }

  public void flushBuffer() throws IOException
  {
    pikeStream.flush();
  }

  public void setLocale(Locale loc)
  {
    locale = loc;
    setHeader("Content-Language", locale.getLanguage());
  }

  public Locale getLocale()
  {
    return locale;
  }

  public void addHeader(String name, String value)
  {
    Object v = (headers != null? headers.get(name.toLowerCase()) : null);
    if(v == null)
      v = name+": "+value;
    else if(v instanceof String) {
      Vector vv = new Vector(2);
      vv.add(v);
      vv.add(name+": "+value);
      v = vv;
    } else
      ((List)v).add(name+": "+value);
    setHeader(name.toLowerCase(), v);
  }

  public void addDateHeader(String name, long date)
  {
    addHeader(name, RoxenServletContext.dateformat.format(new Date(date)));
  }

  public void addIntHeader(String name, int value)
  {
    addHeader(name, Integer.toString(value));
  }

}
