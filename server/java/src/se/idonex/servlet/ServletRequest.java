package se.idonex.servlet;

import javax.servlet.ServletInputStream;
import javax.servlet.ServletContext;
import javax.servlet.RequestDispatcher;
import javax.servlet.http.HttpSession;
import javax.servlet.http.Cookie;
import java.io.IOException;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.util.Dictionary;
import java.util.Hashtable;
import java.util.Enumeration;
import java.util.Vector;
import java.util.Locale;
import java.text.ParseException;
import java.security.Principal;


class ServletRequest implements javax.servlet.http.HttpServletRequest
{
  ServletContext context;
  RoxenSessionContext sessioncontext;
  ServletResponse response = null;
  int contentLength;
  String contentType, protocol, scheme;
  String serverName;
  int serverPort;
  String remoteAddr, remoteHost;
  String data;
  String servletPath, pathInfo, method;
  String remuser;
  String requestURI, queryString, pathTranslated;
  Dictionary parameters = new Hashtable();
  Dictionary attributes = new Hashtable();
  Dictionary headers = new Hashtable();
  BufferedReader reader = null;
  ServletInputStream inputStream = null;

  public int getContentLength()
  {
    return contentLength;
  }

  public String getContentType()
  {
    return contentType;
  }

  public String getProtocol()
  {
    return protocol;
  }

  public String getScheme()
  {
    return scheme;
  }

  public String getServerName()
  {
    return serverName;
  }

  public int getServerPort()
  {
    return serverPort;
  }

  public String getRemoteAddr()
  {
    return remoteAddr;
  }

  protected static native String blockingIPToHost(String addr);

  public String getRemoteHost()
  {
    if(remoteHost == null)
      remoteHost = blockingIPToHost(remoteAddr);
    return remoteHost;
  }

  /**
   * @deprecated  As of Version 2.1 of the Java Servlet API, use
   *              {@link ServletContext.getRealPath(java.lang.String)}
   *              instead
   */
  public String getRealPath(String path)
  {
    return context.getRealPath(path);
  }

  public ServletInputStream getInputStream() throws IOException
  {
    if(inputStream == null)
      inputStream = new HTTPInputStream(data);
    return inputStream;
  }

  public String getParameter(String name)
  {
    String[] pv = getParameterValues(name);
    return (pv == null || pv.length == 0? null : pv[0]);
  }

  public String[] getParameterValues(String name)
  {
    String s = (String)parameters.get(name);
    if(s == null)
      return null;
    int a=0, p=0, i = s.length(), cnt = 1;
    while(--i>=0)
      if(s.charAt(i)=='\0')
	cnt++;
    String[] res = new String[cnt];
    --cnt;
    for(i=0; p<cnt; i++)
      if(s.charAt(i)=='\0') {
	res[p++] = s.substring(a, i);
	a = i+1;
      }
    res[cnt] = s.substring(i);
    return res;
  }

  public Enumeration getParameterNames()
  {
    return parameters.keys();
  }

  public Object getAttribute(String name)
  {
    return attributes.get(name);
  }

  public void setAttribute(String name, Object object)
  {
    attributes.put(name, object);
  }

  public Enumeration getAttributeNames()
  {
    return attributes.keys();
  }

  public BufferedReader getReader() throws IOException
  {
    if(reader == null)
      reader =
	new BufferedReader(new InputStreamReader(getInputStream(),
						 getCharacterEncoding()));
    return reader;
  }

  public Cookie[] getCookies()
  {
    Enumeration cookieh = getHeaders("Cookie");
    if(cookieh == null)
      return new Cookie[0];
    Vector cookiev = new Vector();
    while(cookieh.hasMoreElements()) {
      HeaderTokenizer cookiet =
	new HeaderTokenizer((String)cookieh.nextElement());
      Cookie lastcookie = null;
      int version=0;
      while(cookiet.more()) {
	String name = cookiet.getValue();
	String val = "";
	if(cookiet.lookingAt('=')) {
	  cookiet.discard('=');
	  val = cookiet.getValue();
	}
	if(cookiet.more())
	  cookiet.discard(cookiet.lookingAt(',')? ',':';');
	if(name.startsWith("$")) {
	  if(name.equals("$version"))
	    version = Integer.parseInt(val);
	  else
	    if(lastcookie != null)
	      if(name.equals("$domain"))
		lastcookie.setDomain(val);
	      else if(name.equals("$path"))
		lastcookie.setPath(val);
	} else {
	  cookiev.add(lastcookie = new Cookie(name, val));
	  if(version != 0)
	    lastcookie.setVersion(version);
	}
      }
    }
    return (Cookie[])cookiev.toArray(new Cookie[cookiev.size()]);
  }

  public String getMethod()
  {
    return method;
  }

  public String getRequestURI()
  {
    return requestURI;
  }

  public String getServletPath()
  {
    return servletPath;
  }

  public String getPathInfo()
  {
    return pathInfo;
  }

  public String getPathTranslated()
  {
    return pathTranslated;
  }

  public String getQueryString()
  {
    return queryString;
  }

  public String getRemoteUser()
  {
    return remuser;
  }

  public String getAuthType()
  {
    return (remuser!=null? "Basic":null);
  }

  public String getHeader(String hdr)
  {
    Enumeration h = getHeaders(hdr);
    if(h == null)
      return null;
    else
      return (String)h.nextElement();
  }

  public int getIntHeader(String hdr) throws NumberFormatException
  {
    String h = getHeader(hdr);
    return (h==null? -1 : Integer.parseInt(h));
  }

  public long getDateHeader(String hdr) throws IllegalArgumentException
  {
    String h = getHeader(hdr);
    try {
      return (h==null? -1 :
	      RoxenServletContext.dateformat.parse(h).getTime());
    } catch(ParseException e) {
      throw new IllegalArgumentException(e.getMessage());
    }
  }

  public Enumeration getHeaderNames()
  {
    return (headers == null? null : headers.keys());
  }

  public String getCharacterEncoding()
  {
    return "8859_1";
  }

  public HttpSession getSession(boolean create)
  {
    String id = getRequestedSessionId();
    HttpSession session = sessioncontext.getSession(id, create);
    if(session != null && !session.getId().equals(id) && response != null)
      response.setSessionId(session);
    return session;
  }

  public HttpSession getSession()
  {
    return getSession(true);
  }

  public String getRequestedSessionId()
  {
    Cookie[] cookies = getCookies();
    for(int i=0; i<cookies.length; i++) {
      if("JSESSIONID".equalsIgnoreCase(cookies[i].getName()))
	return cookies[i].getValue();
    }
    return null;
  }

  public boolean isRequestedSessionIdValid()
  {
    HttpSession session = getSession(false);
    return session != null;
  }

  public boolean isRequestedSessionIdFromCookie()
  {
    return getRequestedSessionId() != null;
  }
  
  /**
   * @deprecated  As of Version 2.1 of the Java Servlet API, use
   *              {@link isRequestedSessionIdFromURL()}
   *              instead.
   */
  public boolean isRequestedSessionIdFromUrl()
  {
    return isRequestedSessionIdFromURL();
  }

  public boolean isRequestedSessionIdFromURL()
  {
    return false;
  }

  void setResponse(ServletResponse rp)
  {
    response = rp;
  }

  ServletRequest(ServletContext cx, RoxenSessionContext sx,
		 int cl, String ct, String pr, String sc,
		 String sn, int sp, String ra, String rh, String d,
		 String ap, String pi, String me, String ru, String u,
		 String q, String pt)
  {
    context = cx;
    sessioncontext = sx;
    contentLength = cl;
    contentType = ct;
    protocol = pr;
    scheme = sc;
    serverName = sn;
    serverPort = sp;
    remoteAddr = ra;
    remoteHost = rh;
    data = d;
    servletPath = ap;
    pathInfo = pi;
    method = me;
    remuser = ru;
    requestURI = u;
    queryString = q;
    pathTranslated = pt;
  }

  // 2.2 stuff follows

  public void removeAttribute(String name)
  {
    attributes.remove(name);
  }

  public Locale getLocale()
  {
    // FIXME
    return null;
  }

  public Enumeration getLocales()
  {
    // FIXME
    return null;
  }
  
  public boolean isSecure()
  {
    return "https".equalsIgnoreCase(protocol);
  }

  public RequestDispatcher getRequestDispatcher(String path)
  {
    // FIXME
    return null;
  }

  public Enumeration getHeaders(String name)
  {
    if(headers == null)
      return null;
    Object hdr = headers.get(name.toLowerCase());
    if(hdr == null)
      return null;
    else if(hdr instanceof String) {
      Vector v = new Vector(1);
      v.add(hdr);
      return v.elements();
    } else
      return ((Vector)hdr).elements();
  }

  public String getContextPath()
  {
    // FIXME
    return null;
  }

  public boolean isUserInRole(String role)
  {
    // FIXME
    return false;
  }

  public Principal getUserPrincipal()
  {
    // FIXME
    return null;
  }

}
