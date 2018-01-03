/*
 * $Id$
 *
 */

package com.roxen.roxen;

import java.util.Map;
import java.util.TreeMap;
import java.util.HashMap;
import java.util.Iterator;
import java.util.StringTokenizer;

/**
 * A support class containing useful methods for interpreting
 * requests and synthesizing responses.
 *
 * @version	$Version$
 * @author	marcus
 */

public class RoxenLib extends HTTP {

  private static HashMap entities = new HashMap();

  static {

    /* markup-significant characters */

    entities.put("quot", new Character('"'));
    entities.put("amp", new Character('&'));
    entities.put("lt", new Character('<'));
    entities.put("gt", new Character('>'));

    /* internationalization characters */

    entities.put("OElig", new Character('\u0152'));
    entities.put("oelig", new Character('\u0153'));
    entities.put("Scaron", new Character('\u0160'));
    entities.put("scaron", new Character('\u0161'));
    entities.put("Yuml", new Character('\u0178'));
    entities.put("circ", new Character('\u02C6'));
    entities.put("tilde", new Character('\u02DC'));
    entities.put("ensp", new Character('\u2002'));
    entities.put("emsp", new Character('\u2003'));
    entities.put("thinsp", new Character('\u2009'));
    entities.put("zwnj", new Character('\u200C'));
    entities.put("zwj", new Character('\u200D'));
    entities.put("lrm", new Character('\u200E'));
    entities.put("rlm", new Character('\u200F'));
    entities.put("ndash", new Character('\u2013'));
    entities.put("mdash", new Character('\u2014'));
    entities.put("lsquo", new Character('\u2018'));
    entities.put("rsquo", new Character('\u2019'));
    entities.put("sbquo", new Character('\u201A'));
    entities.put("ldquo", new Character('\u201C'));
    entities.put("rdquo", new Character('\u201D'));
    entities.put("bdquo", new Character('\u201E'));
    entities.put("dagger", new Character('\u2020'));
    entities.put("Dagger", new Character('\u2021'));
    entities.put("permil", new Character('\u2030'));
    entities.put("lsaquo", new Character('\u2039'));
    entities.put("rsaquo", new Character('\u203A'));
    entities.put("euro", new Character('\u20AC'));

    /* symbols and mathematical symbols */

    entities.put("fnof", new Character('\u0192'));
    entities.put("thetasym", new Character('\u03D1'));
    entities.put("upsih", new Character('\u03D2'));
    entities.put("piv", new Character('\u03D6'));
    entities.put("bull", new Character('\u2022'));
    entities.put("hellip", new Character('\u2026'));
    entities.put("prime", new Character('\u2032'));
    entities.put("Prime", new Character('\u2033'));
    entities.put("oline", new Character('\u203E'));
    entities.put("frasl", new Character('\u2044'));
    entities.put("weierp", new Character('\u2118'));
    entities.put("image", new Character('\u2111'));
    entities.put("real", new Character('\u211C'));
    entities.put("trade", new Character('\u2122'));
    entities.put("alefsym", new Character('\u2135'));
    entities.put("larr", new Character('\u2190'));
    entities.put("uarr", new Character('\u2191'));
    entities.put("rarr", new Character('\u2192'));
    entities.put("darr", new Character('\u2193'));
    entities.put("harr", new Character('\u2194'));
    entities.put("crarr", new Character('\u21B5'));
    entities.put("lArr", new Character('\u21D0'));
    entities.put("uArr", new Character('\u21D1'));
    entities.put("rArr", new Character('\u21D2'));
    entities.put("dArr", new Character('\u21D3'));
    entities.put("hArr", new Character('\u21D4'));
    entities.put("forall", new Character('\u2200'));
    entities.put("part", new Character('\u2202'));
    entities.put("exist", new Character('\u2203'));
    entities.put("empty", new Character('\u2205'));
    entities.put("nabla", new Character('\u2207'));
    entities.put("isin", new Character('\u2208'));
    entities.put("notin", new Character('\u2209'));
    entities.put("ni", new Character('\u220B'));
    entities.put("prod", new Character('\u220F'));
    entities.put("sum", new Character('\u2211'));
    entities.put("minus", new Character('\u2212'));
    entities.put("lowast", new Character('\u2217'));
    entities.put("radic", new Character('\u221A'));
    entities.put("prop", new Character('\u221D'));
    entities.put("infin", new Character('\u221E'));
    entities.put("ang", new Character('\u2220'));
    entities.put("and", new Character('\u2227'));
    entities.put("or", new Character('\u2228'));
    entities.put("cap", new Character('\u2229'));
    entities.put("cup", new Character('\u222A'));
    entities.put("int", new Character('\u222B'));
    entities.put("there4", new Character('\u2234'));
    entities.put("sim", new Character('\u223C'));
    entities.put("cong", new Character('\u2245'));
    entities.put("asymp", new Character('\u2248'));
    entities.put("ne", new Character('\u2260'));
    entities.put("equiv", new Character('\u2261'));
    entities.put("le", new Character('\u2264'));
    entities.put("ge", new Character('\u2265'));
    entities.put("sub", new Character('\u2282'));
    entities.put("sup", new Character('\u2283'));
    entities.put("nsub", new Character('\u2284'));
    entities.put("sube", new Character('\u2286'));
    entities.put("supe", new Character('\u2287'));
    entities.put("oplus", new Character('\u2295'));
    entities.put("otimes", new Character('\u2297'));
    entities.put("perp", new Character('\u22A5'));
    entities.put("sdot", new Character('\u22C5'));
    entities.put("lceil", new Character('\u2308'));
    entities.put("rceil", new Character('\u2309'));
    entities.put("lfloor", new Character('\u230A'));
    entities.put("rfloor", new Character('\u230B'));
    entities.put("lang", new Character('\u2329'));
    entities.put("rang", new Character('\u232A'));
    entities.put("loz", new Character('\u25CA'));
    entities.put("spades", new Character('\u2660'));
    entities.put("clubs", new Character('\u2663'));
    entities.put("hearts", new Character('\u2665'));
    entities.put("diams", new Character('\u2666'));

    /* ISO 8859-1 characters */

    String[] latin1 = {
      "nbsp", "iexcl", "cent", "pound", "curren", "yen", "brvbar", "sect",
      "uml", "copy", "ordf", "laquo", "not", "shy", "reg", "macr", "deg",
      "plusmn", "sup2", "sup3", "acute", "micro", "para", "middot", "cedil",
      "sup1", "ordm", "raquo", "frac14", "frac12", "frac34", "iquest",
      "Agrave", "Aacute", "Acirc", "Atilde", "Auml", "Aring", "AElig",
      "Ccedil", "Egrave", "Eacute", "Ecirc", "Euml", "Igrave", "Iacute",
      "Icirc", "Iuml", "ETH", "Ntilde", "Ograve", "Oacute", "Ocirc", "Otilde",
      "Ouml", "times", "Oslash", "Ugrave", "Uacute", "Ucirc", "Uuml", "Yacute",
      "THORN", "szlig", "agrave", "aacute", "acirc", "atilde", "auml", "aring",
      "aelig", "ccedil", "egrave", "eacute", "ecirc", "euml", "igrave",
      "iacute", "icirc", "iuml", "eth", "ntilde", "ograve", "oacute", "ocirc",
      "otilde", "ouml", "divide", "oslash", "ugrave", "uacute", "ucirc",
      "uuml", "yacute", "thorn", "yuml"
    };

    for(int i=0; i<96; i++)
      entities.put(latin1[i], new Character((char)(i+160)));

    /* Greek letters */

    String[] greek = {
      "Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta",
      "Theta", "Iota", "Kappa", "Lambda", "Mu", "Nu", "Xi", "Omicron",
      "Pi", "Rho", "sigmaf", "Sigma", "Tau", "Upsilon", "Phi", "Chi",
      "Psi", "Omega"
    };

    for(int i=0; i<25; i++) {
      entities.put(greek[i], new Character((char)(i+913)));
      entities.put(greek[i].toLowerCase(), new Character((char)(i+945)));
    }

  }

  /**
   * Quotes characters that are unallowed in HTML text or attributes.
   * <p>
   * The following characters are replaced with HTML entities:
   * <tt>&amp;, &lt;, &gt;, ", ', NUL</tt>.
   *
   * @param  str  the string to quote
   * @return      the quoted result
   */
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

  /**
   * Decoded HTML entities.
   * <p>
   * All HTML 4.0 entities are replaced with their literal equivalent.
   *
   * @param  str  the string to unquote
   * @return      the unquoted result
   */
  public static String htmlDecodeString(String str)
  {
    StringTokenizer tok = new StringTokenizer(str, "&;", true);
    StringBuffer sb = new StringBuffer();
    String ent = null;
    Object entcode;
    int mode = 0;
    while (tok.hasMoreTokens()) {
      String t = tok.nextToken();
      switch(mode) {
       case 0:
	 if("&".equals(t))
	   mode = 1;
	 else
	   sb.append(t);
	 break;
       case 1:
	 if("&".equals(t))
	   sb.append('&');
	 else if(";".equals(t)) {
	   sb.append('&');
	   sb.append(';');
	   mode = 0;
	 } else {
	   ent = t;
	   mode = 2;
	 }
	 break;
       case 2:
	 if(";".equals(t)) {
	   if(ent.startsWith("#") && ent.length()>1 && ent.charAt(1) != '-')
	     try {
	       sb.append((char)Integer.parseInt(ent.substring(1)));
	     } catch(NumberFormatException e) {
	       sb.append('&');
	       sb.append(ent);
	       sb.append(';');
	     }
	   else if((entcode = entities.get(ent.toLowerCase())) != null)
	     sb.append(((Character)entcode).charValue());
	   else {
	     sb.append('&');
	     sb.append(ent);
	     sb.append(';');
	   }
	   mode = 0;
	 } else {
	   sb.append('&');
	   sb.append(ent);
	   if("&".equals(t))
	     mode = 1;
	   else {
	     sb.append(t);
	     mode = 0;
	   }
	 }
      }
    }
    switch(mode) {
     case 1:
       sb.append('&');
       break;
     case 2:
       sb.append('&');
       sb.append(ent);
       break;
    }
    return sb.toString();
  }

  /**
   * Produce repeated output with variable subsitutions.
   * <p>
   * This method is used to create tags such as database
   * query tags, where zero or more results in the form of
   * variable bindings are applied to a fixed template, and
   * the results of the subsitutions are concatenated to form
   * the total result.
   *
   * @param args     attributes for the output tag itself
   * @param varArr   an array of variable subsitution mappings
   * @param contents body text in which to substitute variables
   * @param id       a request object associated with the parse
   * @return         the resulting string
   */
  public native static String doOutputTag(Map args, Map[] varArr,
					  String contents, RoxenRequest id);

  /**
   * Perform RXML parsing on a string
   *
   * @param what  the RXML code to parse
   * @param id    a request object associated with the parse
   * @return      the result of the parse
   */
  public native static String parseRXML(String what, RoxenRequest id);
  
  /**
   * Formats key and value paris for use as HTML tag attributes.
   * If the set of pairs is non-empty, the result will contain an
   * extra space at the end.
   *
   * @param in  map from attribute name to attribute value
   * @return    a string suitable for inclusion in an HTML tag
   */
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

  /**
   * Creates an HTML tag given the tag name and attributes
   *
   * @param s   name of tag element
   * @param in  map from attribute name to attribute value
   * @return    a string representation of the tag
   */
  public static String makeTag(String s, Map in)
  {
    String q = makeTagAttributes(in);
    return "<"+s+(q.length()!=0? " "+q:"")+">";
  }

  /**
   * Creates an XML empty element tag given the tag name and attributes
   *
   * @param s   name of tag element
   * @param in  map from attribute name to attribute value
   * @return    a string representation of the tag
   */
  public static String makeEmptyElemTag(String s, Map in)
  {
    // Creates an XML empty-element tag
    String q = makeTagAttributes(in);
    if(!"/".equals(in.get("/")))
      q=(q.length()!=0? q+" /":"/");
    return "<"+s+" "+q+">";
  }

  /**
   * Creates an HTML/XML tag with content given the tag name and attributes
   *
   * @param s   name of tag element
   * @param in  map from attribute name to attribute value
   * @param contents  the text contents of the tag
   * @return    a string representation of the tag, contents, and end tag
   */
  public static String makeContainer(String s, Map in, String contents)
  {
    return makeTag(s,in)+contents+"</"+s+">";
  }

  RoxenLib() { }

}
