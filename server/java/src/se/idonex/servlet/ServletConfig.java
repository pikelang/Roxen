package se.idonex.servlet;

import java.util.Dictionary;
import java.util.Hashtable;
import java.util.Enumeration;
import javax.servlet.ServletContext;

class ServletConfig implements javax.servlet.ServletConfig
{
  ServletContext context;
  Dictionary dic = new Hashtable();

  public ServletContext getServletContext()
  {
    return context;
  }

  public String getInitParameter(String name)
  {
    return (String)dic.get(name);
  }

  public Enumeration getInitParameterNames()
  {
    return dic.keys();
  }

  ServletConfig(ServletContext ctx)
  {
    context = ctx;
  }

  // 2.2 stuff follows

  public String getServletName()
  {
    // FIXME
    return null;
  }

}
