// import Array;

// The magic below is for the 'install' program
#ifndef roxenp
#if !efun(roxenp)
#define roxenp this_object()
#endif
#endif
#ifndef IN_INSTALL
// string cvs_version = "$Id: newdecode.pike,v 1.12 1999/04/22 09:24:11 per Exp $";
#endif

#include <roxen.h>

#define ENC_ADD(X)do{if(arrayp(res->res))res->res+=({(X)});else res->res=(X); return "";}while(0)
#define SIMPLE_DECODE(X,Y) private string X(string foo, mapping m, string s, mapping res) { ENC_ADD( Y );}

SIMPLE_DECODE(decode_int, (int)s );
SIMPLE_DECODE(decode_module, s );
SIMPLE_DECODE(decode_float, (float)s );
SIMPLE_DECODE(decode_string, http_decode_string(s));

private string decode_list(string foo, mapping m, string s, mapping res)
{
  mapping myres = ([ "res":({}) ]);
  parse(s, myres);
  ENC_ADD( mkmultiset(myres->res) );
}

private string decode_array(string foo, mapping m, string s, mapping res)
{
  mapping myres = ([ "res":({}) ]);
  parse(s, myres); 
  ENC_ADD( myres->res );
}


private string decode_mapping(string foo, mapping m, string s, mapping res)
{
  mapping myres = ([ "res":({ }) ]);
  parse(s, myres);
  ENC_ADD( aggregate_mapping(@myres->res) );
}

private string decode_variable(string foo, mapping m, string s, mapping res)
{
  mapping mr;
  sscanf(s, "%*[ \n\t\r]%s", s);
  while(s[0] == '#')
    if(sscanf(s, "%*[^\n]\n%s", s) != 2)
      break;
  mr = ([ "res":0 ]);
  parse(s, mr);
  res[m->name] = mr->res;
  return "";
}

string name_of_module( object m, object c )
{
  return (c && c->otomod && c->otomod[m]) || "?";
}

void parse(string s, mapping mr)
{
  parse_html(s, ([ ]),  
	     (["a":decode_array,  "map":decode_mapping,
	      "lst":decode_list,  "mod":decode_module,
	      "int":decode_int,   "str":decode_string, 
	      "flt":decode_float ]), mr);
}

string decode_config_region(string foo, mapping mr, string s, mapping res2)
{
  mapping res = ([ ]);
  parse_html(s, ([]), ([ "var":decode_variable ]), res);
  res2[mr->name] = res;
  return "";
}


mapping decode_config_file(string s)
{
  mapping res = ([ ]);
  if(!sizeof(s)) return res; // Empty file..
  switch(s[0])
  {
   case '6': // Newer ((somewhat)readable) format.    
     parse_html(s, ([]), ([ "region":decode_config_region ]), res);
     return res;
   default:
     werror("Unknown configuration file format '"+s[0..0]+"'\n");
     werror("Ignoring file.\n");
  }
}

private string encode_mixed(mixed from, object c)
{ 
  switch(sprintf("%t", from))
  {
   case "string":
    return "<str>"+replace(from, ({ ">", "<" }), ({ "%3e", "%3c" })  )
           + "</str>";
   case "int":
   case "mixed":
    return "<int>"+from+"</int>";
   case "float":
     return "<flt>"+from+"</flt>";
   case "array":
    return "<a>\n    "+Array.map(from, encode_mixed, c)*"\n    "
          +"\n  </a>\n";
   case "multiset":
    return "<lst>\n    "
      +Array.map(indices(from),encode_mixed, c)*"\n    "+"\n  </lst>\n";
   case "object":
    return "<mod>"+name_of_module(from,c)+"</mod>";
   case "mapping":
    string res="<map>";
    mixed i;
    foreach(indices(from), i)
      res += "    " + encode_mixed(i, c) + " : " + encode_mixed(from[i],c)+"\n";
    return res + "  </map>\n";
   default:
     werror("I do not know how to encode "+
            sprintf("%t (%O)\n", from, from)+"\n");
     return "<int>0</int>";
  }
}

string trim_ws( string indata )
{
  string res="";
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

string encode_config_region(mapping m, string reg, object c)
{
  string res = "";
  string v;
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

    if(c && c->get_doc_for)
      doc = c->get_doc_for( reg, v );
    if(doc)
      doc=("\n#   "+trim_ws(replace(sprintf("%*-=s", 74,trim_ws(doc)), "\n", "\n#    ")));
    else
      doc = "";
    res += " <var name='"+v+"'> "+doc+"  "+encode_mixed(m[v],c)+"</var>\n\n";
  }
  return res;
}

string encode_regions(mapping r, object c)
{
  string v;
  string res = "6 <- Do not remove this number!   It's the "
    "Roxen Challenger save file format identifier -->\n\n";
  foreach(sort(indices(r)), v)
    res += "<region name='"+v+"'>\n" + encode_config_region(r[v],v,c)
           + "</region>\n\n";
  return res;
}

