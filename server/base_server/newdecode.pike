// import Array;

// The magic below is for the 'install' program
#ifndef roxenp
#if !efun(roxenp)
#define roxenp this_object()
#endif
#endif
#ifndef IN_INSTALL
// string cvs_version = "$Id: newdecode.pike,v 1.10 1999/03/13 20:54:36 marcus Exp $";
#endif

#include <roxen.h>


void parse(string s, mapping mr);
void new_parse(string s, mapping mr);

private string decode_int(string foo, mapping m, string s, mapping res)
{
  if(arrayp(res->res)) res->res += ({ (int)s });  else  res->res = (int)s;
  return "";
}

private string decode_module(string foo, mapping m, string s, mapping res)
{
  if(arrayp(res->res)) 
    res->res += ({ s }); 
  else 
    res->res = s;
  return "";
}


private string decode_float(string foo, mapping m, string s, mapping res)
{
  if(arrayp(res->res)) res->res += ({ (float)s }); else  res->res = (float)s;
  return "";
}

private string decode_string(string foo, mapping m, string s, mapping res)
{
  s = replace(s, ({ "%3e", "%3c" }), ({ ">", "<" }) );
  if(arrayp(res->res)) res->res += ({ s  });  else   res->res = s;
  return "";
}

private string decode_list(string foo, mapping m, string s, mapping res)
{
  mapping myres = ([ "res":({}) ]);

  parse(s, myres);

  if(arrayp(res->res)) 
    res->res += ({ aggregate_multiset(@myres->res) }); 
  else
    res->res = aggregate_multiset(@myres->res);
  return "";
}


private string new_decode_list(string foo, mapping m, string s, mapping res)
{
  mapping myres = ([ "res":({}) ]);

  new_parse(s, myres);

  if(arrayp(res->res)) 
    res->res += ({ aggregate_multiset(@myres->res) }); 
  else
    res->res = aggregate_multiset(@myres->res);
  return "";
}


private string decode_array(string foo, mapping m, string s, mapping res)
{
  mapping myres = ([ "res":({}) ]);

  parse(s, myres); 

  if(arrayp(res->res)) 
    res->res += ({ myres->res }); 
  else
    res->res = myres->res;
  return "";
}

private string new_decode_array(string foo, mapping m, string s, mapping res)
{
  mapping myres = ([ "res":({}) ]);

  new_parse(s, myres); 

  if(arrayp(res->res)) 
    res->res += ({ myres->res }); 
  else
    res->res = myres->res;
  return "";
}


private string new_decode_mapping(string foo, mapping m, string s, mapping res)
{
  mapping myres = ([ "res":({ }) ]);
  
  new_parse(s, myres);

  if(arrayp(res->res)) 
    res->res += ({ aggregate_mapping(@myres->res) }); 
  else
    res->res = aggregate_mapping(@myres->res);

  return "";
}

private string decode_mapping(string foo, mapping m, string s, mapping res)
{
  mapping myres = ([ "res":({ }) ]);

  parse(s, myres);

  if(arrayp(res->res)) 
    res->res += ({ aggregate_mapping(@myres->res) }); 
  else
    res->res = aggregate_mapping(@myres->res);

  return "";
}

private string decode_variable(string foo, mapping m, string s, mapping res)
{
  mapping mr;

  mr = ([ "res":0 ]);
  
  parse(s, mr);
  res[m->name] = mr->res;

  return "";
}

static private string strip_doc(string s)
{
  if(s[..2]!=" \n#")
    // No doc
    return s;

  int p=-1;
  while((p=search(s, "\n", p+1))>=0)
    if(p+1<sizeof(s) && s[p+1]!='#')
      return s[p..];

  // Hum.  Everything was one huge comment...
  return "";
}

private string new_decode_variable(string foo, mapping m, string s,
				   mapping res)
{
  mapping mr;

  mr = ([ "res":0 ]);
  
  new_parse(strip_doc(s), mr);
  res[m->name] = mr->res;

  return "";
}


string name_of_module( object m )
{
#ifndef IN_INSTALL
  string name;
  mapping mod;
  foreach(values(roxenp()->current_configuration->modules), mod)
  {
    if(mod->copies)
    {
      int i;
      if(!zero_type(i=search(mod->copies, m)))
	return mod->sname+"#"+i;
    } else 
      if(mod->enabled==m)
	return mod->sname+"#0"; 
  }
  return name;
#endif
}



void parse(string s, mapping mr)
{
  parse_html(s, ([ ]),  
	     (["array":decode_array, 
	      "mapping":decode_mapping,
	      "comment":"",
	      "list":decode_list,
	      "module":decode_module,
	      "int":decode_int, 
	      "string":decode_string, 
	      "float":decode_float ]), mr);
}


void new_parse(string s, mapping mr)
{
  parse_html(s, ([ ]),  
	     (["a":new_decode_array, 
	      "map":new_decode_mapping,
	      "comment":"",
	      "lst":new_decode_list,
	      "mod":decode_module,
	      "int":decode_int, 
	      "str":decode_string, 
	      "flt":decode_float ]), mr);
}

string decode_config_region(string foo, mapping mr, string s, mapping res2)
{
  mapping res = ([ ]);
  parse_html(s, ([]), ([ "variable":decode_variable ]), res);
  res2[mr->name] = res;
  return "";
}

string new_decode_config_region(string foo, mapping mr, string s, mapping res2)
{
  mapping res = ([ ]);
  parse_html(s, ([]), ([ "var":new_decode_variable ]), res);
  res2[mr->name] = res;
  return "";
}

mixed compat_decode_value( string val )
{
  if(!val || !strlen(val))  return 0;

  switch(val[0])
  {
  case '"':
    return replace(val[1 .. strlen(val)-2], "%0A", "\n");
      
  case '{':
   return Array.map(val[1 .. strlen(val)-2]/"},{", compat_decode_value);
      
  case '<':
   return aggregate_multiset(Array.map(val[1 .. strlen(val)-2]/"},{", compat_decode_value));

  default:
    if(search(val,".") != -1)
      return (float)val;
    return (int)val;
  }
}


private mapping compat_parse(string s)
{
  mapping res = ([ ]);
  string current;
  foreach(s/"\n", s) 
  {
    if(strlen(s))
    {
      switch(s[0])
      {
      case ';':
	continue;
      case '[':
	sscanf(s, "[%s]", current);
	res[ current ] = ([ ]);
	break;
      default:
	string a, b;
	sscanf(s, "%s=%s", a, b);
	res[current][ a ] = compat_decode_value(b);
      }
    }
  }
  return res;
}


mapping decode_config_file(string s)
{
//  werror(sprintf("Decoding \n%s\n",s));
  mapping res = ([ ]);
  if(!sizeof(s)) return res; // Empty file..
  switch(s[0])
  {
  case ';':
    // Old (and stupid...) configuration file format 
    perror("Reading very old (pre b11) configuration file format.\n");
    return compat_parse(s);
    break;
   case '4': // Pre b15 configuration format. Could encode most stuff, but not
	     // everything.
    perror("Reading old (pre b15) configuration file format.\n");
    parse_html(s, ([]), ([ "region":decode_config_region ]), res);
    return res;
   case '5': // New (binary) format. Fast and lean, but not very readable
	     // for a human.. :-)
    return decode_value(s[1..]); // C-function.
   case '6': // Newer ((somewhat)readable) format. Can encode everything, _and_
             // a mere human can edit it.
    
//    trace(1);
    parse_html(s, ([]), ([ "region":new_decode_config_region ]), res);
//    trace(0);
//    werror(sprintf("Decoded value is: %O\n", res));
    return res;
   }
}

private string encode_mixed(mixed from)
{
  if(stringp(from))
    return "<str>"+replace(from, ({ ">", "<" }), ({ "%3e", "%3c" })  )
           + "</str>";
  else if(intp(from))
    return "<int>"+from+"</int>";
  else if(floatp(from))
    return "<flt>"+from+"</flt>";
  else if(arrayp(from))
    return "\n  <a>\n    "+Array.map(from, encode_mixed)*"\n    "
          +"\n  </a>\n";
  else if(multisetp(from))
    return "\n  <lst>\n    "
      +Array.map(indices(from),encode_mixed)*"\n    "+"\n  </lst>\n";
  else if(objectp(from)) // Only modules.
    return "<mod>"+name_of_module(from)+"</mod>";
  else if(mappingp(from))
  {
    string res="<map>";
    mixed i;
    foreach(indices(from), i)
      res += "    " + encode_mixed(i) + " : " + encode_mixed(from[i])+"\n";
    return res + "  </map>\n";
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

    if(v[0] == '_')
    {
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
    }

    if(c && c->get_doc_for)
      doc = c->get_doc_for( reg, v );
    if(doc)
      doc=("\n#   "+trim_ws(replace(sprintf("%*-=s", 74,trim_ws(doc)), "\n", "\n#    ")));
    else
      doc = "";
    res += " <var name='"+v+"'> "+doc+"  "+encode_mixed(m[v])+"</var>\n\n";
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

