import com.roxen.roxen.*;

import java.util.HashMap;
import java.lang.reflect.Modifier;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.lang.reflect.Constructor;


/*
 * This is an example Roxen location module.
 * Copyright (c) 2000 - 2009, Roxen IS
 */


public class JavaReflector extends AbstractLocationModule
{

  String modifierFont, typeFont, variableFont, methodFont, keywordFont;

  public String queryName()
  {
    return "Java Class Reflector";
  }

  public String info()
  {
    return "A location module providing an HTML interface to Java Reflection.";
  }

  protected RoxenResponse response(String title, String body)
  {
    /*
     * Package the content in an HTML page and return it with
     * RXML parsing.
     */
    String page = "<html><head><title>"+title+"</title>\n"+
      "<body bgcolor=\"white\" text=\"black\" link=\"#6699cc\" "+
      "alink=\"red\" vlink=\"#6677cc\">\n"+
      body+
      "</body></html>\n";

    return RoxenLib.httpRXMLAnswer(page);
  }

  public RoxenResponse packageList(RoxenRequest id)
  {
    /*
     * Default page, lists known packages.
     */
    StringBuffer page = new StringBuffer();
    page.append("<h1>All packages</h1>\n<ul>\n");
    Package[] packages = Package.getPackages();
    for(int i=0; i<packages.length; i++) {
      Package p = packages[i];
      page.append(" <li>");
      HashMap args = new HashMap();
      args.put("href", queryLocation()+p.getName());
      page.append(RoxenLib.makeContainer("a", args, p.getName()));
      page.append("</li>\n");
    }
    page.append("</ul>\n");
    /*
     * Include a link to the reflection of this class, just
     * to get people started...
     */
    page.append("Class of module: ");
    HashMap args = new HashMap();
    Class c = getClass();
    args.put("href", queryLocation()+c.getName());
    page.append(RoxenLib.makeContainer("a", args, c.getName()));
    page.append("\n");
    return response("Packages", page.toString());
  }

  public RoxenResponse describePackage(Package p, RoxenRequest id)
  {
    /*
     * Unfortunately, there is no way to list all classes
     * in a package.  So this page only contains some manifest info.
     */
    StringBuffer page = new StringBuffer();
    page.append("<h1>Package "+p.getName()+"</h1>\n");
    page.append("<table border=1>\n<tr><td></td><th>Title</th>"+
		"<th>Vendor</th><th>Version</th></tr>\n");
    page.append("<tr><th>Specification</th><td>");
    page.append(RoxenLib.htmlEncodeString(p.getSpecificationTitle()+""));
    page.append("</td><td>");
    page.append(RoxenLib.htmlEncodeString(p.getSpecificationVendor()+""));
    page.append("</td><td>");
    page.append(RoxenLib.htmlEncodeString(p.getSpecificationVersion()+""));
    page.append("</td></tr>\n<tr><th>Implementation</th><td>");
    page.append(RoxenLib.htmlEncodeString(p.getImplementationTitle()+""));
    page.append("</td><td>");
    page.append(RoxenLib.htmlEncodeString(p.getImplementationVendor()+""));
    page.append("</td><td>");
    page.append(RoxenLib.htmlEncodeString(p.getImplementationVersion()+""));
    page.append("</td></tr></table>\n");
    return response("Package "+p.getName(), page.toString());
  }

  static protected void indentedLine(StringBuffer buf, String txt, int indent)
  {
    /* Append a line with indentation to a StringBuffer */
    while(indent-->0) buf.append("&nbsp;");
    buf.append(txt);
    buf.append("<br>\n");
  }

  protected String modifierNames(int modifiers)
  {
    /* Translate a mask of modifiers to clear text */
    if((modifiers&Modifier.INTERFACE)>0)
      modifiers &= ~(Modifier.ABSTRACT | Modifier.STATIC | Modifier.INTERFACE);
    return (modifiers==0? "" :
	    modifierFont+Modifier.toString(modifiers)+"</font> ");
  }

  protected String simpleClassName(String name)
  {
    /* Translate a qualified name to a simple name */
    int i = name.lastIndexOf('$');
    if(i<0)
      i = name.lastIndexOf('.');
    return (i<0? name : name.substring(i+1));
  }

  protected String classLink(Class c)
  {
    /* Translate a type to clear text with hyperlinks where applicable */
    if(c.isArray())
      return classLink(c.getComponentType())+"[]";
    String n = c.getName();
    String t = typeFont+n.replace('$', '.')+"</font>";
    if(c.isPrimitive())
      return t;
    int i = n.lastIndexOf('$');
    HashMap args = new HashMap();
    args.put("href", queryLocation()+(i<0? n : n.substring(0, i)));
    return RoxenLib.makeContainer("a", args, t);
  }

  protected String classLink(Class[] c)
  {
    /* Translate a list of types to clear text with hyperlinks */
    StringBuffer buf = new StringBuffer();
    for(int i=0; i<c.length; i++) {
      if(i>0)
	buf.append(", ");
      buf.append(classLink(c[i]));
    }
    return buf.toString();
  }

  protected void describe(StringBuffer page, Field f, RoxenRequest id,
			  int indent)
  {
    /* Append description of a field to a StringBuffer */
    indentedLine(page, modifierNames(f.getModifiers())+
		 classLink(f.getType())+" "+variableFont+
		 f.getName()+"</font>;", indent);
  }

  protected void describe(StringBuffer page, Method m, RoxenRequest id,
			  int indent)
  {
    /* Append description of a method to a StringBuffer */
    Class[] th = m.getExceptionTypes();
    indentedLine(page, modifierNames(m.getModifiers())+
		 classLink(m.getReturnType())+" "+methodFont+
		 m.getName()+"</font>("+classLink(m.getParameterTypes())+
		 ")"+(th.length>0? " "+keywordFont+"throws</font> "+
		      classLink(th):"")+";", indent);
  }

  protected void describe(StringBuffer page, Constructor c, RoxenRequest id,
			  int indent)
  {
    /* Append description of a constructor to a StringBuffer */
    Class[] th = c.getExceptionTypes();
    indentedLine(page, modifierNames(c.getModifiers())+
		 methodFont+simpleClassName(c.getName())+
		 "</font>("+classLink(c.getParameterTypes())+
		 ")"+(th.length>0? " "+keywordFont+"throws</font> "+
		      classLink(th):"")+";", indent);
  }

  protected void describe(StringBuffer page, Class c, RoxenRequest id,
			  int indent)
  {
    /* Append description of a class or interface to a StringBuffer */
    Class[] ifcs = c.getInterfaces();
    if(c.isInterface())
      indentedLine(page, modifierNames(c.getModifiers())+
		   keywordFont+"interface</font> "+
		   methodFont+simpleClassName(c.getName())+"</font> "+
		   (ifcs.length>0? keywordFont+"extends</font> "+
		    classLink(ifcs)+" ":"")+
		   "{", indent);
    else {
      Class s = c.getSuperclass();
      indentedLine(page, modifierNames(c.getModifiers())+
		   keywordFont+"class</font> "+
		   methodFont+simpleClassName(c.getName())+"</font> "+
		   (s!=null? keywordFont+"extends</font> "+
		    classLink(s)+" ":"")+
		   (ifcs.length>0? keywordFont+"implements</font> "+
		    classLink(ifcs)+" ":"")+
		   "{", indent);
    }
    indent += 2;
    Class[] dclasses = c.getDeclaredClasses();
    for(int i=0; i<dclasses.length; i++) {
      indentedLine(page, "", indent);
      describe(page, dclasses[i], id, indent);
    }
    Field[] fields = c.getDeclaredFields();
    if(fields.length>0)
      indentedLine(page, "", indent);
    for(int i=0; i<fields.length; i++)
      describe(page, fields[i], id, indent);
    Method[] methods = c.getDeclaredMethods();
    if(methods.length>0)
      indentedLine(page, "", indent);
    for(int i=0; i<methods.length; i++)
      describe(page, methods[i], id, indent);
    Constructor[] constructors = c.getDeclaredConstructors();
    if(constructors.length>0)
      indentedLine(page, "", indent);
    for(int i=0; i<constructors.length; i++)
      describe(page, constructors[i], id, indent);
    indentedLine(page, "", indent);
    indent -= 2;
    indentedLine(page, "}", indent);
  }

  public RoxenResponse describeClass(Class c, RoxenRequest id)
  {
    /*
     * Page describing a class or interface (including inner classes)
     */
    StringBuffer page = new StringBuffer();
    String ci = (c.isInterface()? "Interface":"Class");
    page.append("<h1>"+ci+" "+c.getName()+"</h1>\n");
    page.append("\n<tt>\n");
    Package p = c.getPackage();
    if(p != null) {
      page.append(keywordFont+"package</font> ");
      HashMap args = new HashMap();
      args.put("href", queryLocation()+p.getName());
      page.append(RoxenLib.makeContainer("a", args,
					 modifierFont+p.getName()+"</font>"));
      page.append(";<br><br>\n");
    }
    describe(page, c, id, 0);
    page.append("</tt>\n");
    return response(ci+" "+c.getName(), page.toString());
  }

  public RoxenResponse findFile(String f, RoxenRequest id)
  {
    /* If no class or package name is given, show a default page */
    if("".equals(f))
      return packageList(id);

    try {

      /* Is it a class/interface ? */

      Class c = Class.forName(f);

      if(c != null && c.getDeclaringClass() == null &&
	 !c.isArray() && !c.isPrimitive())
	return describeClass(c, id);

    } catch (ClassNotFoundException e) { }

    /* No?  Maybe a package? */

    Package p = Package.getPackage(f);

    if(p != null)
      return describePackage(p, id);

    /* Nope.  No appropriate page found. */
    return null;
  }

  protected void start()
  {
    /*
     * Prefabricate font tags using the customizable colors,
     * for speed and simplicity.
     */
    modifierFont = "<font color=\""+queryString("modifier_color")+"\">";
    typeFont = "<font color=\""+queryString("type_color")+"\">";
    variableFont = "<font color=\""+queryString("variable_color")+"\">";
    methodFont = "<font color=\""+queryString("method_color")+"\">";
    keywordFont = "<font color=\""+queryString("keyword_color")+"\">";
  }

  public JavaReflector()
  {
    defvar("location", "/reflector/", "Mount point", TYPE_LOCATION,
	   "This is where the module will be inserted in the "+
	   "namespace of your server.");

    /* To get some interresting config variables, all the
       syntactic highlight colors are customizable.  :-)  */
    defvar("modifier_color", "red", "Modifier font color", TYPE_STRING,
	   "Color to use for names of modifiers.");
    defvar("type_color", "steelblue", "Type font color", TYPE_STRING,
	   "Color to use for names of types.");
    defvar("variable_color", "purple", "Variable font color", TYPE_STRING,
	   "Color to use for names of variables and fields.");
    defvar("method_color", "brown", "Method font color", TYPE_STRING,
	   "Color to use for names of methods and constructors.");
    defvar("keyword_color", "green", "Keyword font color", TYPE_STRING,
	   "Color to use for names of keywords.");
  }

}
