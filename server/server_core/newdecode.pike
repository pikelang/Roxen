// This file is part of ChiliMoon.
// Copyright © 1996 - 2001, Roxen IS.
// $Id: newdecode.pike,v 1.35 2003/01/21 23:46:26 mani Exp $

// The magic below is for the 'install' program
#ifndef roxenp
# if !efun(roxenp)
#  define roxenp this_object
# endif
#endif

#include <roxen.h>

#define ENC_ADD(X)do{if(arrayp(res->res))res->res+=({(X)});else res->res=(X); return "foo";}while(0)
#define SIMPLE_DECODE(X,Y) private string X(Parser.HTML p, mapping m, string s, mapping res) { ENC_ADD( Y );}

SIMPLE_DECODE(decode_int, (int)s );
SIMPLE_DECODE(decode_module, s );
SIMPLE_DECODE(decode_float, (float)s );
SIMPLE_DECODE(decode_string, http_decode_string(s));

private constant xml_header = "<?XML version=\"1.0\" encoding=\"UTF-8\"?>";

private string decode_list(Parser.HTML p, mapping m, string s, mapping res)
{
  mapping myres = ([ "res":({}) ]);
  parse(s, myres);
  ENC_ADD( mkmultiset(myres->res) );
}

private string decode_array(Parser.HTML p, mapping m, string s, mapping res)
{
  mapping myres = ([ "res":({}) ]);
  parse(s, myres);
  ENC_ADD( myres->res );
}

private string decode_mapping(Parser.HTML p, mapping m, string s, mapping res)
{
  mapping myres = ([ "res":({ }) ]);
  parse(s, myres);
  ENC_ADD( aggregate_mapping(@myres->res) );
}

string decode_variable(Parser.HTML p, mapping m, string s, mapping res)
{
  mapping mr;
  mr = ([ "res":0 ]);
  parse(s, mr);

  res[m->name] = mr->res;
  return "bar";
}

string name_of_module( RoxenModule m, Configuration c )
{
  return (c && c->otomod && c->otomod[m]) || "?";
}

private void parse(string s, mapping mr)
{
  Parser.HTML()
    ->add_containers (([
      "a":decode_array,  "map":decode_mapping,
      "lst":decode_list,  "mod":decode_module,
      "int":decode_int,   "str":decode_string,
      "flt":decode_float
    ]))
    ->add_quote_tag ("!--", "", "--")
    ->set_extra (mr)
    ->finish (s);
}

private string decode_config_region(Parser.HTML p, mapping mr, string s, mapping res2)
{
  mapping res = ([ ]);
  Parser.HTML()
    ->add_container ("var", decode_variable)
    ->add_quote_tag ("!--", "", "--")
    ->set_extra (res)
    ->finish (s);
  res2[mr->name] = res;
  return "";
}

string trim_comments( string from )
{
  string res = "";
  foreach( String.SplitIterator(from, '\n'); int r; string l )
  {
    if( strlen(l) && l[0] == '#' )
      // Just defeat any tags on the line. This won't clobber any
      // variable values, since '<' is always encoded in them.
      res += replace (l, "<", "") + "\n";
    else
      res += l+"\n";
  }
  return res;
}

mapping decode_config_file(string s)
{
  mapping res = ([ ]);
  if(sizeof(s) < 10) return res; // Empty file..
  if( sscanf( s, "%*s" + xml_header + "\n%*s" ) == 2 )
    s = utf8_to_string( s );
  else
    s = trim_comments( s );
  Parser.HTML()
    ->add_container ("region", decode_config_region)
    ->add_quote_tag ("!--", "", "--")
    ->set_extra (res)
    ->finish (s);
  return res;
}

string encode_mixed(mixed from, Configuration c, int|void indent)
{
  switch(sprintf("%t", from))
  {
   case "string":
    return "<str>"+replace(from, ({ ">", "<", "%" }), ({ "%3e", "%3c", "%25" })  )
           + "</str>";
   case "int":
   case "mixed":
    return "<int>"+from+"</int>";
   case "float":
     return "<flt>"+from+"</flt>";
   case "array": {
     if (!sizeof (from)) return "<a></a>";
     string res = "<a>\n";
     foreach (from, mixed i)
       res += "  "*indent + "  " + encode_mixed (i, c, indent + 1) + "\n";
     return res + "  "*indent + "</a>";
   }
   case "multiset": {
     if (!sizeof (from)) return "<lst></lst>";
     string res = "<lst>\n";
     foreach (sort (indices (from)), mixed i)
       res += "  "*indent + "  " + encode_mixed (i, c, indent + 1) + "\n";
     return res + "  "*indent + "</lst>";
   }
   case "mapping": {
     if (!sizeof (from)) return "<map></map>";
     string res="<map>\n";
     foreach(sort (indices (from)), mixed i)
       res += "  "*indent + "  " + encode_mixed(i, c, indent + 1) + " : " +
	 encode_mixed(from[i],c, indent + 1)+"\n";
     return res + "  "*indent + "</map>";
   }
   default:
     if (objectp (from))
       return "<mod>"+name_of_module(from,c)+"</mod>";
     report_debug("I do not know how to encode "+
		  sprintf("%t (%O)\n", from, from)+"\n");
     return "<int>0</int>";
  }
}

string trim_tags( string what )
{
  int i;
  int add = 1;
  string res = "";
  what = replace( what, ({ "<pre>", "</pre>" }),
                  ({"\n", "\n" }) );
  for( i=0; i<strlen(what); i++ )
  {
    switch( what[i] )
    {
     case '&': continue;
     case '<': add--; continue;
     case '>': add++; continue;
     default:
       if( add > 0 )
         res += what[i..i];
    }
  }
  return replace( res, ({"amp;", "lt;", "gt;" }),
                  ({ "&", "<", ">" }) );
}

string trim_ws( string indata )
{
  string res="";
  indata = replace( indata, ({"<br>", "<p>" }),
                    ({ "\n", "\n\n" }) );

  indata = trim_tags( indata );

  foreach(String.SplitIterator(indata, '\n'); int row; string line)
    res += String.trim_whites(line) + "\n";

  return res;
}

string encode_config_region(mapping m, string reg, Configuration c,
			    int comments)
{
  string res = "";
  string v;

  if( reg == "EnabledModules" )
  {
    foreach( sort(indices( m )), string q ) {
      string cmt;
      if (comments)
	if( catch {
	  string|mapping name=roxenp()->find_module( (q/"#")[0] )->name;
	  if(mappingp(name)) name=name->standard;
	  cmt = " <!-- " + replace(replace(name, "--", "- -" ), "--", "- -" ) + " -->";
	})
	  cmt = " <!-- Error? -->";
      res += sprintf ("  %-30s <int>1</int> </var>%s\n",
		      "<var name='"+q+"'>", cmt || "");
    }

    return res;
  }

  foreach(sort(indices(m)), v)
  {
    string doc;
    switch(v)
    {
     case "_comment":
     case "_name":
     case "_seclevels":
       if(m[v] == "")
         continue;
       break;
     case "_priority":
       if(m[v] == 5)
         continue;
       break;
     case "_sec_group":
       if(m[v] == "user")
         continue;
       break;
     case "_seclvl":
       if(m[v] == 0)
         continue;
       break;
    }

    if(comments && c && c->get_doc_for)
      doc = c->get_doc_for( reg, v );
    if(doc)
      res += ("\n  <!--\n    "+
	      replace(replace(sprintf("%*-=s",74,trim_ws(doc)),
			      ({"\n","--"}), ({"\n    ","- -"})),
		      "--", "- -")
	      +"\n   -->\n");
    string enc = encode_mixed(m[v],c,1);
    if (has_value (enc, "\n"))
      res += "  <var name='" + v + "'>" + enc + "</var>\n";
    else
      res += sprintf ("  %-30s %s </var>\n", "<var name='"+v+"'>", enc);
  }
  return res;
}

string encode_regions(mapping r, Configuration c)
{
  string v;
  string res = (xml_header + "\n\n");
  int comments = roxenp()->query ("config_file_comments");
  foreach(r->EnabledModules ?
	  ({"EnabledModules"}) + sort(indices(r) - ({"EnabledModules"})) :
	  sort(indices(r)), v)
    res += "<region name='"+v+"'>\n" +
             encode_config_region(r[v],v,c,comments)
           + "</region>\n\n";
  return string_to_utf8( res );
}
