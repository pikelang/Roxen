/*
 * $Id: RoxenLib.java,v 1.2 1999/12/20 18:51:33 marcus Exp $
 *
 */

package se.idonex.roxen;

import java.util.Map;
import java.util.TreeMap;
import java.util.Iterator;
import java.util.StringTokenizer;

public class RoxenLib extends HTTP {

  public static String htmlEncodeString(String str)
  {
    // Encodes str for use as a literal in html text.
    StringTokenizer tok = new StringTokenizer(str, "&<>\"'\0", true);
    StringBuffer sb = new StringBuffer();
    while (tok.hasMoreTokens()) {
      String t = tok.nextToken();
      if(t.length()==1)
	switch(t.charAt(0)) {
	 case '&': sb.append("&amp;"); break;
	 case '<': sb.append("&lt;"); break;
	 case '>': sb.append("&gt;"); break;
	 case '"': sb.append("&#34;"); break;
	 case '\'': sb.append("&#39;"); break;
	 case '\0': sb.append("&#0;"); break;
	 default:
	   sb.append(t);
	}
      else
	sb.append(t);
    }
    return sb.toString();
  }
  
  public static String makeTagAttributes(Map in)
  {
    TreeMap tm = new TreeMap(in);
    StringBuffer sb = new StringBuffer();
    Iterator k = tm.entrySet().iterator();
    boolean sl = false;
    
    while(k.hasNext()) {
      Map.Entry e = (Map.Entry)k.next();
      String key = e.getKey().toString();
      String value = e.getValue().toString();
      if(key.equals("/") && value.equals("/"))
	sl = true;
      else {
	sb.append(key);
	sb.append("=\"");
	sb.append(htmlEncodeString(value));
	sb.append("\" ");
      }
    }
    if(sl)
      sb.append("/ ");
    if(sb.length()==0)
      return "";
    else {
      sb.setLength(sb.length()-1);
      return sb.toString();
    }
  }

  public static String makeTag(String s, Map in)
  {
    String q = makeTagAttributes(in);
    return "<"+s+(q.length()!=0? " "+q:"")+">";
  }

  public static String makeEmptyElemTag(String s, Map in)
  {
    // Creates an XML empty-element tag
    String q = makeTagAttributes(in);
    if(!"/".equals(in.get("/")))
      q=(q.length()!=0? q+" /":"/");
    return "<"+s+" "+q+">";
  }

  public static String makeContainer(String s, Map in, String contents)
  {
    return makeTag(s,in)+contents+"</"+s+">";
  }

  RoxenLib() { }

}
