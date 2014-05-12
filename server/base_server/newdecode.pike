// This file is part of Roxen WebServer.
// Copyright © 1996 - 2009, Roxen IS.
// $Id$

// The magic below is for the 'install' program
#ifndef roxenp
# if !constant(roxenp)
#  define roxenp this_object
# endif
#endif

#include <roxen.h>

#define ENC_ADD(X)do{if(arrayp(res->res))res->res+=({(X)});else res->res=(X); return "foo";}while(0)
#define SIMPLE_DECODE(X,Y) private string X(Parser.HTML p, mapping m, string s, mapping res) { ENC_ADD( Y );}

SIMPLE_DECODE(decode_int, (int)s );
SIMPLE_DECODE(decode_module, s );
SIMPLE_DECODE(decode_float, (float)s );
SIMPLE_DECODE(decode_string,
	      ((String.width(s)>8)?
	       utf8_to_string(http_decode_string(string_to_utf8(s))):
	       http_decode_string(s)));

constant xml_header = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>";

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

void parse(string s, mapping mr)
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

string decode_config_region(Parser.HTML p, mapping mr, string s, mapping res2)
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
  foreach( from /"\n", string l )
  {
    if( strlen(l) && l[0] == '#' )
      // Just defeat any tags on the line. This won't clobber any
      // variable values, since '<' is always encoded in them.
      //
      // NB: The above is probably false - a multiline <str> value can
      // contain a "#" on the last line which then would be followed
      // by "</str>" on the same line. That can at least occur in
      // newer files with xml headers, but this function shouldn't be
      // used at all then.
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

  //  Older Roxen generated invalid XML headers so we have to perform a
  //  lower-case comparison.
  if( sscanf( lower_case(s[..100]),
	      "%*s" + lower_case(xml_header) + "\n%*s" ) == 2 )
    s = utf8_to_string( s );
  else
    s = trim_comments( s );
  Parser.HTML()
    ->add_container ("region", decode_config_region)
    ->add_tags ( ([ "roxen-config"  : 0,
		    "/roxen-config" : 0 ]) )
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

  foreach(indata/"\n", string line)
  {
    sscanf(line, "%*[ \t]%s", line);
    line = reverse(line);
    sscanf(line, "%*[ \t]%s", line);
    line = reverse(line);
    res += line+"\n";
   }
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
  string res =
    xml_header + "\n"
    "<roxen-config>\n\n";
  int comments = all_constants()->roxen->query ("config_file_comments");
  foreach(r->EnabledModules ?
	  ({"EnabledModules"}) + sort(indices(r) - ({"EnabledModules"})) :
	  sort(indices(r)), v)
    res += "<region name='"+v+"'>\n" +
             encode_config_region(r[v],v,c,comments)
           + "</region>\n\n";
  res += "</roxen-config>\n";
  return string_to_utf8( res );
}
