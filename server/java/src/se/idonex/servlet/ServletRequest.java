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

  protected static class HeaderTokenizer
  {
    String header;
    int pos, len;

    protected final void skipWS()
    {
      while(pos<len && header.charAt(pos)<=' ')
	pos++;
    }

    public boolean lookingAt(char c)
    {
      skipWS();
      return pos<len && header.charAt(pos)==c;
    }
    
    public void discard(char c)
    {
      if(!lookingAt(c))
	throw new IllegalArgumentException ("header: "+header);
      pos++;
    }

    public String getToken()
    {
      skipWS();
      int p0=pos;
      while(pos<len && Character.isJavaIdentifierPart(header.charAt(pos)))
	pos++;
      if(pos==p0)
	throw new IllegalArgumentException ("header: "+header);
      return header.substring(p0, pos).toLowerCase();
    }

    public String getValue()
    {
      if(!lookingAt('"'))
	return getToken();
      int p0=pos++;
      while(pos<len && header.charAt(pos)!='"')
	if(header.charAt(pos)=='\\')
	  pos+=2;
	else
	  pos++;
      if(pos>=len)
	throw new IllegalArgumentException ("header: "+header);
      String v = header.substring(p0, pos++);
      for(p0=0; (p0=v.indexOf('\\', p0))>=0; p0++)
	v = v.substring(0, p0)+v.substring(p0+1);
      return v;
    }

    public boolean more()
    {
      skipWS();
      return pos<len;
    }

    public HeaderTokenizer(String h)
    {
      header = h;
      pos = 0;
      len = h.length();
    }
  }

  public Cookie[] getCookies()
  {
    String cookieh = getHeader("Cookie");
    if(cookieh == null)
      return new Cookie[0];
    HeaderTokenizer cookiet = new HeaderTokenizer(cookieh);
    Vector cookiev = new Vector();
    Cookie lastcookie = null;
    int version=0;
    while(cookiet.more()) {
      String name = cookiet.getToken();
      cookiet.discard('=');
      String val = cookiet.getValue();
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
    if(headers == null)
      return null;
    else
      return (String)headers.get(hdr.toLowerCase());
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
    // FIXME
    return null;
  }

  public HttpSession getSession()
  {
    return getSession(true);
  }

  public String getRequestedSessionId()
  {
    // FIXME
    return null;
  }

  public boolean isRequestedSessionIdValid()
  {
    // FIXME
    return false;
  }

  public boolean isRequestedSessionIdFromCookie()
  {
    // FIXME
    return false;
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
    // FIXME
    return false;
  }

  ServletRequest(ServletContext cx, int cl, String ct, String pr, String sc,
		 String sn, int sp, String ra, String rh, String d,
		 String ap, String pi, String me, String ru, String u,
		 String q, String pt)
  {
    context = cx;
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
    // FIXME
    if(headers == null)
      return null;
    String hdr = (String)headers.get(name.toLowerCase());
    if(hdr == null)
      return null;
    else
      return new java.util.StringTokenizer(hdr, "\0");
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
