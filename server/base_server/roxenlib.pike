inherit "http";

// static string _cvs_version = "$Id: roxenlib.pike,v 1.91 1999/02/18 13:13:18 wing Exp $";
// This code has to work both in the roxen object, and in modules
#if !efun(roxen)
#define roxen roxenp()
#endif

#include <stat.h>

#define ipaddr(x,y) (((x)/" ")[y])

string gif_size(object gif)
{
  int x,y;
  string d;
  gif->seek(6);
  d = gif->read(4);
  x = (d[1]<<8) + d[0]; y = (d[3]<<8) + d[2];
  return "width="+x+" height="+y;
}

static string extract_query(string from)
{
  if(!from) return "";
  if(sscanf(from, "%*s?%s%*[ \t\n]", from))
    return (from/"\r")[0];
  return "";
}

static mapping build_env_vars(string f, object id, string path_info)
{
  string addr=id->remoteaddr || "Internal";
  mixed tmp;
  object tmpid;
  mapping new = ([]);
  
  
  if(id->query && strlen(id->query))
    new->INDEX=id->query;
    
  if(path_info && strlen(path_info))
  {
    string t, t2;
    if(path_info[0] != '/')
      path_info = "/" + path_info;
    
    t = t2 = "";
    
    // Kludge
    if (id->misc->path_info == path_info) {
      // Already extracted
      new["SCRIPT_NAME"]=id->not_query;
    } else {
      new["SCRIPT_NAME"]=
	id->not_query[0..strlen(id->not_query)-strlen(path_info)-1];
    }
    new["PATH_INFO"]=path_info;


    while(1)
    {
      // Fix PATH_TRANSLATED correctly.
      t2 = roxen->real_file(path_info, id);
      if(t2)
      {
	new["PATH_TRANSLATED"] = t2 + t;
	break;
      }
      tmp = path_info/"/" - ({""});
      if(!sizeof(tmp))
	break;
      path_info = "/" + (tmp[0..sizeof(tmp)-2]) * "/";
      t = tmp[-1] +"/" + t;
    }
  } else
    new["SCRIPT_NAME"]=id->not_query;

  tmpid = id;
  while(tmpid->misc->orig)
    // internal get
    tmpid = tmpid->misc->orig;
  
  // Begin "SSI" vars.
  if(sizeof(tmp = tmpid->not_query/"/" - ({""})))
    new["DOCUMENT_NAME"]=tmp[-1];
  
  new["DOCUMENT_URI"]= tmpid->not_query;
  
  if((tmp = file_stat(tmpid->conf->real_file(tmpid->not_query||"", tmpid)))
     && sizeof(tmp))
    new["LAST_MODIFIED"]=http_date(tmp[3]);

  // End SSI vars.
    
  if(tmp = roxen->real_file(new["SCRIPT_NAME"], id))
    new["SCRIPT_FILENAME"] = tmp;
    
  if(tmp = roxen->real_file("/", id))
    new["DOCUMENT_ROOT"] = tmp;

  if(!new["PATH_TRANSLATED"])
    m_delete(new, "PATH_TRANSLATED");
  else if(new["PATH_INFO"][-1] != '/' && new["PATH_TRANSLATED"][-1] == '/')
    new["PATH_TRANSLATED"] = 
      new["PATH_TRANSLATED"][0..strlen(new["PATH_TRANSLATED"])-2];

  // HTTP_ style variables:

  mapping hdrs;

  if ((hdrs = id->request_headers)) {
    foreach(indices(hdrs) - ({ "authorization", "proxy-authorization",
			       "security-scheme", }), string h) {
      string hh = "HTTP_" + replace(upper_case(h),
				    ({ " ", "-", "\0", "=" }),
				    ({ "_", "_", "", "_" }));

      new[hh] = replace(hdrs[h], ({ "\0" }), ({ "" }));
    }
    if (!new["HTTP_HOST"]) {
      if(objectp(id->my_fd) && id->my_fd->query_address(1))
	new["HTTP_HOST"] = replace(id->my_fd->query_address(1)," ",":");
    }
  } else {
    if(id->misc->host)
      new["HTTP_HOST"]=id->misc->host;
    else if(objectp(id->my_fd) && id->my_fd->query_address(1))
      new["HTTP_HOST"]=replace(id->my_fd->query_address(1)," ",":");
    if(id->misc["proxy-connection"])
      new["HTTP_PROXY_CONNECTION"]=id->misc["proxy-connection"];
    if(id->misc->accept) {
      if (arrayp(id->misc->accept)) {
	new["HTTP_ACCEPT"]=id->misc->accept*", ";
      } else {
	new["HTTP_ACCEPT"]=(string)id->misc->accept;
      }
    }

    if(id->misc->cookies)
      new["HTTP_COOKIE"] = id->misc->cookies;
  
    if(sizeof(id->pragma))
      new["HTTP_PRAGMA"]=indices(id->pragma)*", ";

    if(stringp(id->misc->connection))
      new["HTTP_CONNECTION"]=id->misc->connection;
    
    new["HTTP_USER_AGENT"] = id->client*" "; 
    
    if(id->referer && sizeof(id->referer))
      new["HTTP_REFERER"] = id->referer*""; 
  }

  new["REMOTE_ADDR"]=addr;
    
  if(roxen->quick_ip_to_host(addr) != addr)
    new["REMOTE_HOST"]=roxen->quick_ip_to_host(addr);

  catch {
    if(id->my_fd) {
      new["REMOTE_PORT"] = ipaddr(id->my_fd->query_address(), 1);
    }
  };
    
  if(id->misc->_temporary_query_string)
    new["QUERY_STRING"] = id->misc->_temporary_query_string;
  else
    new["QUERY_STRING"] = extract_query(id->raw);
   
  if(!strlen(new["QUERY_STRING"]))
    m_delete(new, "QUERY_STRING");
    
  if(id->auth && id->auth[0] && stringp(id->auth[1]))
    new["REMOTE_USER"] = (id->auth[1]/":")[0];
    
  if(id->data && strlen(id->data))
  {
    if(id->misc["content-type"])
      new["CONTENT_TYPE"]=id->misc["content-type"];
    else
      new["CONTENT_TYPE"]="application/x-www-form-urlencoded";
    new["CONTENT_LENGTH"]=(string)strlen(id->data);
  }
    
  if(id->query && strlen(id->query))
    new["INDEX"]=id->query;
    
  new["REQUEST_METHOD"]=id->method||"GET";
  new["SERVER_PORT"] = id->my_fd?
    ((id->my_fd->query_address(1)||"foo unknown")/" ")[1]: "Internal";
    
  return new;
}

static mapping build_roxen_env_vars(object id)
{
  mapping new = ([]);
  mixed tmp;

  if(id->cookies->RoxenUserID)
    new["ROXEN_USER_ID"]=id->cookies->RoxenUserID;

  new["COOKIES"] = "";
  foreach(indices(id->cookies), tmp)
    {
      new["COOKIE_"+tmp] = id->cookies[tmp];
      new["COOKIES"]+= tmp+" ";
    }
	
  foreach(indices(id->config), tmp)
    {
      new["WANTS_"+replace(tmp, " ", "_")]="true";
      if(new["CONFIGS"])
	new["CONFIGS"] += " " + replace(tmp, " ", "_");
      else
	new["CONFIGS"] = replace(tmp, " ", "_");
    }

  foreach(indices(id->variables), tmp)
  {
    string name = replace(tmp," ","_");
    if (id->variables[tmp] && (sizeof(id->variables[tmp]) < 8192)) {
      /* Some shells/OS's don't like LARGE environment variables */
      new["QUERY_"+name] = replace(id->variables[tmp],"\000"," ");
      new["VAR_"+name] = replace(id->variables[tmp],"\000","#");
    }
    if(new["VARIABLES"])
      new["VARIABLES"]+= " " + name;
    else
      new["VARIABLES"]= name;
  }
      
  foreach(indices(id->prestate), tmp)
  {
    new["PRESTATE_"+replace(tmp, " ", "_")]="true";
    if(new["PRESTATES"])
      new["PRESTATES"] += " " + replace(tmp, " ", "_");
    else
      new["PRESTATES"] = replace(tmp, " ", "_");
  }
	
  foreach(indices(id->supports), tmp)
  {
    new["SUPPORTS_"+replace(tmp-",", " ", "_")]="true";
    if (new["SUPPORTS"])
      new["SUPPORTS"] += " " + replace(tmp, " ", "_");
    else
      new["SUPPORTS"] = replace(tmp, " ", "_");
  }
  return new;
}


static string decode_mode(int m)
{
  string s;
  s="";
  
  if(S_ISLNK(m))  s += "Symbolic link";
  else if(S_ISREG(m))  s += "File";
  else if(S_ISDIR(m))  s += "Dir";
  else if(S_ISCHR(m))  s += "Special";
  else if(S_ISBLK(m))  s += "Device";
  else if(S_ISFIFO(m)) s += "FIFO";
  else if(S_ISSOCK(m)) s += "Socket";
  else if((m&0xf000)==0xd000) s+="Door";
  else s+= "Unknown";
  
  s+=", ";
  
  if(S_ISREG(m) || S_ISDIR(m))
  {
    s+="<tt>";
    if(m&S_IRUSR) s+="r"; else s+="-";
    if(m&S_IWUSR) s+="w"; else s+="-";
    if(m&S_IXUSR) s+="x"; else s+="-";
    
    if(m&S_IRGRP) s+="r"; else s+="-";
    if(m&S_IWGRP) s+="w"; else s+="-";
    if(m&S_IXGRP) s+="x"; else s+="-";
    
    if(m&S_IROTH) s+="r"; else s+="-";
    if(m&S_IWOTH) s+="w"; else s+="-";
    if(m&S_IXOTH) s+="x"; else s+="-";
    s+="</tt>";
  } else {
    s+="--";
  }
  return s;
}

constant MONTHS=(["Jan":0, "Feb":1, "Mar":2, "Apr":3, "May":4, "Jun":5,
	         "Jul":6, "Aug":7, "Sep":8, "Oct":9, "Nov":10, "Dec":11,
		 "jan":0, "feb":1, "mar":2, "apr":3, "may":4, "jun":5,
	         "jul":6, "aug":7, "sep":8, "oct":9, "nov":10, "dec":11,]);

static int _match(string w, array (string) a)
{
  string q;
  if(!stringp(w)) // Internal request..
    return -1;
  foreach(a, q) 
    if(stringp(q) && strlen(q) && glob(q, w)) 
      return 1; 
}

static int is_modified(string a, int t, void|int len)
{
  mapping t1;
  int day, year, month, hour, minute, second, length;
  string m, extra;
  if(!a)
    return 1;
  t1=localtime(t + timezone() - localtime(t)->isdst*3600);
   // Expects 't' as returned from time(), not UTC.
  sscanf(lower_case(a), "%*s, %s; %s", a, extra);
  if(extra && sscanf(extra, "length=%d", length) && len && length != len)
    return 0;

  if(search(a, "-") != -1)
  {
    sscanf(a, "%d-%s-%d %d:%d:%d", day, m, year, hour, minute, second);
    year += 1900;
    month=MONTHS[m];
  } else   if(search(a, ",") == 3) {
    sscanf(a, "%*s, %d %s %d %d:%d:%d", day, m, year, hour, minute, second);
    if(year < 1900) year += 1900;
    month=MONTHS[m];
  } else if(!(int)a) {
    sscanf(a, "%*[^ ] %s %d %d:%d:%d %d", m, day, hour, minute, second, year);
    month=MONTHS[m];
  } else {
    sscanf(a, "%d %s %d %d:%d:%d", day, m, year, hour, minute, second);
    month=MONTHS[m];
    if(year < 1900) year += 1900;
  }

  if(year < (t1["year"]+1900))                                
    return 0;
  else if(year == (t1["year"]+1900)) 
    if(month < (t1["mon"]))  
      return 0;
    else if(month == (t1["mon"]))      
      if(day < (t1["mday"]))   
	return 0;
      else if(day == (t1["mday"]))	     
	if(hour < (t1["hour"]))  
	  return 0;
	else if(hour == (t1["hour"]))      
	  if(minute < (t1["min"])) 
	    return 0;
	  else if(minute == (t1["min"]))     
	    if(second < (t1["sec"])) 
	      return 0;
  return 1;
}

string short_name(string long_name)
{
  long_name = replace(long_name, " ", "_");
  return lower_case(long_name);
}

string strip_config(string from)
{
  sscanf(from, "/<%*s>%s", from);
  return from;
}

string strip_prestate(string from)
{
  sscanf(from, "/(%*s)%s", from);
  return from;
}

#define _error defines[" _error"]
#define _extra_heads defines[" _extra_heads"]
#define _rettext defines[" _rettext"]

static string parse_rxml(string what, object id,
			 void|object file, void|mapping defines)
{
  if(!defines) {
    defines = id->misc->defines||([]);
    if(!_error)
      _error=200;
    if(!_extra_heads)
      _extra_heads=([ ]);
  }

  if(!id) error("No id passed to parse_rxml\n");

  if(!id->conf || !id->conf->parse_module)
    return what;
  
  what = id->conf->parse_module->
    do_parse(what, id, file||this_object(), defines, id->my_fd);

  if(!id->misc->moreheads)
    id->misc->moreheads= ([]);
  id->misc->moreheads |= _extra_heads;
  return what;
}

constant iso88591
=([ "&nbsp;":   " ",
    "&iexcl;":  "¡",
    "&cent;":   "¢",
    "&pound;":  "£",
    "&curren;": "¤",
    "&yen;":    "¥",
    "&brvbar;": "¦",
    "&sect;":   "§",
    "&uml;":    "¨",
    "&copy;":   "©",
    "&ordf;":   "ª",
    "&laquo;":  "«",
    "&not;":    "¬",
    "&shy;":    "­",
    "&reg;":    "®",
    "&macr;":   "¯",
    "&deg;":    "°",
    "&plusmn;": "±",
    "&sup2;":   "²",
    "&sup3;":   "³",
    "&acute;":  "´",
    "&micro;":  "µ",
    "&para;":   "¶",
    "&middot;": "·",
    "&cedil;":  "¸",
    "&sup1;":   "¹",
    "&ordm;":   "º",
    "&raquo;":  "»",
    "&frac14;": "¼",
    "&frac12;": "½",
    "&frac34;": "¾",
    "&iquest;": "¿",
    "&Agrave;": "À",
    "&Aacute;": "Á",
    "&Acirc;":  "Â",
    "&Atilde;": "Ã",
    "&Auml;":   "Ä",
    "&Aring;":  "Å",
    "&AElig;":  "Æ",
    "&Ccedil;": "Ç",
    "&Egrave;": "È",
    "&Eacute;": "É",
    "&Ecirc;":  "Ê",
    "&Euml;":   "Ë",
    "&Igrave;": "Ì",
    "&Iacute;": "Í",
    "&Icirc;":  "Î",
    "&Iuml;":   "Ï",
    "&ETH;":    "Ð",
    "&Ntilde;": "Ñ",
    "&Ograve;": "Ò",
    "&Oacute;": "Ó",
    "&Ocirc;":  "Ô",
    "&Otilde;": "Õ",
    "&Ouml;":   "Ö",
    "&times;":  "×",
    "&Oslash;": "Ø",
    "&Ugrave;": "Ù",
    "&Uacute;": "Ú",
    "&Ucirc;":  "Û",
    "&Uuml;":   "Ü",
    "&Yacute;": "Ý",
    "&THORN;":  "Þ",
    "&szlig;":  "ß",
    "&agrave;": "à",
    "&aacute;": "á",
    "&acirc;":  "â",
    "&atilde;": "ã",
    "&auml;":   "ä",
    "&aring;":  "å",
    "&aelig;":  "æ",
    "&ccedil;": "ç",
    "&egrave;": "è",
    "&eacute;": "é",
    "&ecirc;":  "ê",
    "&euml;":   "ë",
    "&igrave;": "ì",
    "&iacute;": "í",
    "&icirc;":  "î",
    "&iuml;":   "ï",
    "&eth;":    "ð",
    "&ntilde;": "ñ",
    "&ograve;": "ò",
    "&oacute;": "ó",
    "&ocirc;":  "ô",
    "&otilde;": "õ",
    "&ouml;":   "ö",
    "&divide;": "÷",
    "&oslash;": "ø",
    "&ugrave;": "ù",
    "&uacute;": "ú",
    "&ucirc;":  "û",
    "&uuml;":   "ü",
    "&yacute;": "ý",
    "&thorn;":  "þ",
    "&yuml;":   "ÿ",]);

constant safe_characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"/"";
constant empty_strings = ({
  "","","","","","","","","","","","","","","","","","","","","","","","","",
  "","","","","","","","","","","","","","","","","","","","","","","","","",
  "","","","","","","","","","","","",
});

static int is_safe_string(string in)
{
  return strlen(in) && !strlen(replace(in, safe_characters, empty_strings));
}

static string make_tag_attributes(mapping in)
{
  array a=indices(in), b=values(in);
  for(int i=0; i<sizeof(a); i++)
    if(lower_case(b[i]) != a[i])
      if(is_safe_string(b[i]))
	a[i]+="="+b[i];
      else
	// Bug inserted again. Grmbl.
	a[i]+="=\""+replace(b[i], ({ "\"", "<", ">" //, "&"
	}) ,
			    ({ "&quot;", "&lt;", "&gt;" //, "&amp;"
			    }))+"\"";
  return a*" ";
}

static string make_tag(string s,mapping in)
{
  string q = make_tag_attributes(in);
  return "<"+s+(strlen(q)?" "+q:"")+">";
}

static string make_container(string s,mapping in, string contents)
{
  return make_tag(s,in)+contents+"</"+s+">";
}

static string dirname( string file )
{
  if(!file) 
    return "/";
  mixed tmp;
  if(file[-1] == '/')
    if(strlen(file) > 1)
      return file[0..strlen(file)-2];
    else
      return file;
  tmp=file/"/";
  if(sizeof(tmp)==2 && tmp[0]=="")
    return "/";
  return tmp[0..sizeof(tmp)-2]*"/";
}

static string conv_hex( int color )
{
  int c;
  string result;

  result = "";
  for (c=0; c < 6; c++, color>>=4)
    switch (color & 15)
    {
     case 0: case 1: case 2: case 3: case 4:
     case 5: case 6: case 7: case 8: case 9:
      result = (color & 15) + result;
      break;
     case 10: 
      result = "A" + result;
      break;
     case 11: 
      result = "B" + result;
      break;
     case 12: 
      result = "C" + result;
      break;
     case 13: 
      result = "D" + result;
      break;
     case 14: 
      result = "E" + result;
      break;
     case 15: 
      result = "F" + result;
      break;
    }
  return "#" + result;
  
}

static string add_config( string url, array config, multiset prestate )
{
  if(!sizeof(config)) 
    return url;
  if(strlen(url)>5 && (url[1] == "(" || url[1] == "<"))
    return url;
  return "/<" + config * "," + ">" + add_pre_state(url, prestate);
}

string msectos(int t)
{
  if(t<1000) /* One sec. */
  {
    return sprintf("0.%02d sec", t/10);
  } else if(t<6000) {  /* One minute */
    return sprintf("%d.%02d sec", t/1000, (t%1000 + 5) / 10);
  } else if(t<3600000) { /* One hour */
    return sprintf("%d:%02d m:s", t/60000,  (t%60000)/1000);
  } 
  return sprintf("%d:%02d h:m", t/3600000, (t%3600000)/60000);
}

static string extension( string f )
{
  string q;
  sscanf(f, "%s?%*s", f); // Forms.

  f=lower_case( f );
  if(strlen(f)) switch(f[-1])
  {
   case '#': sscanf(f, "%s#", f);    break;
   case '~': sscanf(f, "%s~%*s", f); break;
   case 'd': sscanf(f, "%s.old", f); break;
   case 'k': sscanf(f, "%s.bak", f); break;
  }
  q=f;
  sscanf(reverse(f), "%s.%*s", f);
  f = reverse(f);
  if(q==f) return "";
  return f;
}

static int backup_extension( string f )
{
  if(!strlen(f)) 
    return 1;
  return (f[-1] == '#' || f[-1] == '~' 
	  || (f[-1] == 'd' && sscanf(f, "%*s.old")) 
	  || (f[-1] == 'k' && sscanf(f, "%*s.bak")));
}

/* ================================================= */
/* Arguments: Anything Returns: Memory usage of the argument.  */
int get_size(mixed x)
{
  if(mappingp(x))
    return 8 + 8 + get_size(indices(x)) + get_size(values(x));
  else if(stringp(x))
    return strlen(x)+8;
  else if(arrayp(x))
  {
    mixed f;
    int i;
    foreach(x, f)
      i += get_size(f);
    return 8 + i;    // (refcount + pointer) + arraysize..
  } else if(multisetp(x)) {
    mixed f;
    int i;
    foreach(indices(x), f)
      i += get_size(f);
    return 8 + i;    // (refcount + pointer) + arraysize..
  } else if(objectp(x) || functionp(x)) {
    return 8 + 16; // (refcount + pointer) + object struct.
    // Should consider size of global variables / refcount 
  }
  return 20; // Ints and floats are 8 bytes, refcount and float/int.
}


static int ipow(int what, int how)
{
  int r=what;
  if(!how) return 1;
  while (how-=1) r *= what; 
  return r;
}

/* This one will remove .././ etc. in the path. Might be useful :) */
/* ================================================= */

static string simplify_path(string file)
{
  string tmp;
  int t2,t1;
  if(!strlen(file))
    return "";

  if(file[0] != '/')
      t2 = 1;

  if(strlen(file) > 1 
     && ((file[-1] == '/') || (file[-1]=='.')) 
     && file[-2]=='/')
    t1=1;

  tmp=combine_path("/", file);

  if(t1) tmp += "/.";

// perror(file+"->"+tmp+"\n");

  if(t2) return tmp[1..];
    
  return tmp;
}

/* Returns a short date string from a time-int 
   ===========================================
   Arguments: int (time)
   Returns:   string ("short_date")
   */

static string short_date(int timestamp)
{
  int date = time(1);
  
  if(ctime(date)[19..22] < ctime(timestamp)[19..22])
    return ctime(timestamp)[4..9] +" "+ ctime(timestamp)[19..22];
  
  return ctime(timestamp)[4..9] +" "+ ctime(timestamp)[11..15];
}


int httpdate_to_time(string date)
{     
   if (intp(date)) return -1;
   // Tue, 28 Apr 1998 13:31:29 GMT
   // 0    1  2    3    4  5  6
   int mday,hour,min,sec,year;
   string month;
   if(sscanf(date,"%*s, %d %s %d %d:%d:%d GMT",mday,month,year,hour,min,sec)==6)
     return mktime((["year":year-1900,
		     "mon":MONTHS[lower_case(month)],
		     "mday":mday,
		     "hour":hour,
		     "min":min,
		     "sec":sec,
		     "timezone":0]));
   
   
   return -1; 
}

static string int2roman(int m)
{
  string res="";
  if (m>10000000||m<0) return "que";
  while (m>999) { res+="M"; m-=1000; }
  if (m>899) { res+="CM"; m-=900; }
  else if (m>499) { res+="D"; m-=500; }
  else if (m>399) { res+="CD"; m-=400; }
  while (m>99) { res+="C"; m-=100; }
  if (m>89) { res+="XC"; m-=90; }
  else if (m>49) { res+="L"; m-=50; }
  else if (m>39) { res+="XL"; m-=40; }
  while (m>9) { res+="X"; m-=10; }
  if (m>8) return res+"IX";
  else if (m>4) { res+="V"; m-=5; }
  else if (m>3) return res+"IV";
  while (m) { res+="I"; m--; }
  return res;
}

static string number2string(int n,mapping m,mixed names)
{
  string s;
  switch (m->type)
  {
   case "string":
    if (functionp(names)) 
    { s=names(n); break; }
    if (!arrayp(names)||n<0||n>=sizeof(names)) s="";
    else s=names[n];
    break;
   case "roman":
    s=int2roman(n);
    break;
   default:
    return (string)n;
  }
  if (m->lower) s=lower_case(s);
  if (m->upper) s=upper_case(s);
  if (m->cap||m->capitalize) s=String.capitalize(s);
  return s;
}


static string image_from_type( string t )
{
  if(t)
  {
    sscanf(t, "%s/%*s", t);
    switch(t)
    {
     case "audio":
     case "sound":
      return "internal-gopher-sound";
     case "image":
      return "internal-gopher-image";
     case "application":
      return "internal-gopher-binary";
     case "text":
      return "internal-gopher-text";
    }
  }
  return "internal-gopher-unknown";
}

#define  PREFIX ({ "bytes", "kB", "MB", "GB", "TB", "HB" })
static string sizetostring( int size )
{
  float s = (float)size;
  if(size<0) 
    return "--------";
  size=0;

  while( s > 1024.0 )
  {
    s /= 1024.0;
    size ++;
  }
  return sprintf("%.1f %s", s, PREFIX[ size ]);
}

mapping proxy_auth_needed(object id)
{
  mixed res = id->conf->check_security(proxy_auth_needed, id);
  if(res)
  {
    if(res==1) // Nope...
      return http_low_answer(403, "You are not allowed to access this proxy");
    if(!mappingp(res))
      return 0; // Error, really.
    res->error = 407;
    return res;
  }
  return 0;
}

string program_filename()
{
  return roxen->filename(this_object()) ||
    search(master()->programs, object_program(this_object()));
}

string program_directory()
{
  array(string) p = program_filename()/"/";
  return (sizeof(p)>1? p[..sizeof(p)-2]*"/" : getcwd());
}

string html_encode_string(string str)
// Encodes str for use as a literal in html text.
{
  return replace(str, ({"&", "<", ">", "\"", "\'", "\000" }),
		 ({"&amp;", "&lt;", "&gt;", "&#34;", "&#39;", "&#0;"}));
}

string html_decode_string(string str)
// Decodes str, opposite to html_encode_string()
{
  return replace(str, ({"&amp;", "&lt;", "&gt;", "&#34;", "&#39;", "&#0;"}),
		 ({"&", "<", ">", "\"", "\'", "\000" }) );
}

string html_encode_tag_value(string str)
// Encodes str for use as a value in an html tag.
{
  return "\"" + replace(str, ({"&", "\""}), ({"&amp;", "&quot;"})) + "\"";
}

object get_module (string modname)
// Resolves a string as returned by get_modname to a module object if
// one exists.
{
  string cname, mname;
  int mid = 0;

  if (sscanf (modname, "%s/%s", cname, mname) != 2 ||
      !sizeof (cname) || !sizeof(mname)) return 0;
  sscanf (mname, "%s#%d", mname, mid);

  foreach (roxen->configurations, object conf) {
    mapping moddata;
    if (conf->name == cname && (moddata = conf->modules[mname])) {
      if (mid >= 0) {
	if (moddata->copies) return moddata->copies[mid];
      }
      else if (moddata->enabled) return moddata->enabled;
      if (moddata->master) return moddata->master;
      return 0;
    }
  }

  return 0;
}

string get_modname (object module)
// Returns a string uniquely identifying the given module on the form
// `<config name>/<module short name>#<copy>', where `<copy>' is 0 for
// modules with no copies.
{
  if (!module) return 0;

  foreach (roxen->configurations, object conf) {
    string mname = conf->otomod[module];
    if (mname) {
      mapping moddata = conf->modules[mname];
      if (moddata->copies)
	foreach (indices (moddata->copies), int i) {
	  if (moddata->copies[i] == module)
	    return conf->name + "/" + mname + "#" + i;
	}
      else if (moddata->master == module || moddata->enabled == module)
	return conf->name + "/" + mname + "#0";
    }
  }

  return 0;
}

// This determines the full module name in approximately the same way
// as the config UI.
string get_modfullname (object module)
{
  if (module) {
    string name = 0;
    if (module->query_name) name = module->query_name();
    if (!name || !sizeof (name)) name = module->register_module()[1];
    return name;
  }
  else return 0;
}

// internal method for do_output_tag
private string remove_leading_trailing_ws( string str )
{
  sscanf( str, "%*[\t\n\r ]%s", str ); str = reverse( str ); 
  sscanf( str, "%*[\t\n\r ]%s", str ); str = reverse( str );
  return str;
}

// method for use by tags that replace variables in their content, like
// formoutput, sqloutput and others
string do_output_tag( mapping args, array (mapping) var_arr, string contents,
		      object id )
{
  string quote = args->quote || "#";
  mapping other_vars;
  string new_contents = "", unparsed_contents = "";

  // multi_separator must default to \000 since one sometimes need to
  // pass multivalues through several output tags, and it's a bit
  // tricky to set it to \000 in a tag..
  string multi_separator = args->multi_separator || args->multisep || "\000";

  if (args->preprocess)
    contents = parse_rxml( contents, id );

  switch (args["debug-input"]) {
    case 0: break;
    case "log":
      report_debug ("tag input: " + contents + "\n");
      break;
    case "comment":
      new_contents = "<!--\n" + html_encode_string (contents) + "\n-->";
      break;
    default:
      new_contents = "\n<br><b>[</b><pre>" +
	html_encode_string (contents) + "</pre><b>]</b>\n";
  }

  foreach (var_arr, mapping vars)
  {
    if (args->set)
      foreach (indices (vars), string var) {
	mixed val = vars[var];
	if (!val) val = args->zero || "";
	else {
	  if (arrayp( val ))
	    val = Array.map (val, lambda (mixed v) {return (string) v;}) *
	      multi_separator;
	  else
	    val = replace ((string) val, "\000", multi_separator);
	  if (!sizeof (val)) val = args->empty || "";
	}
	id->variables[var] = val;
      }

    other_vars = id->misc->variables;
    id->misc->variables = vars;

    if (!args->replace || lower_case( args->replace ) != "no")
    {
      array exploded = contents / quote;
      if (!(sizeof (exploded) & 1))
	return "<b>Contents ends inside a replace field</b>";

      for (int c=1; c < sizeof( exploded ); c+=2)
	if (exploded[c] == "")
	  exploded[c] = quote;
	else
	{
	  array(string) options =  exploded[c] / ":";
	  string var = remove_leading_trailing_ws (options[0]);
	  mixed val = vars[var];
	  array(string) encodings = ({});
	  string multisep = multi_separator;
	  string zero = args->zero || "";
	  string empty = args->empty || "";

	  foreach(options[1..], string option) {
	    array (string) foo = option / "=";
	    string optval = remove_leading_trailing_ws (foo[1..] * "=");

	    switch (lower_case (remove_leading_trailing_ws( foo[0] ))) {
	      case "empty":
		empty = optval;
		break;
	      case "zero":
		zero = optval;
		break;
	      case "multisep":
	      case "multi_separator":
		multisep = optval;
		break;
	      case "quote":	// For backward compatibility.
		optval = lower_case (optval);
		switch (optval) {
		  case "mysql": case "sql": case "oracle":
		    encodings += ({optval + "-dtag"});
		    break;
		  default:
		    encodings += ({optval});
		}
		break;
	      case "encode":
		encodings += Array.map (lower_case (optval) / ",",
					remove_leading_trailing_ws);
		break;
	      default:
		return "<b>Unknown option " + remove_leading_trailing_ws (foo[0]) +
		  " in replace field " + ((c >> 1) + 1) + "</b>";
	    }
	  }

	  if (!val)
	    if (zero_type (vars[var]) && (args->debug || id->misc->debug))
	      val = "<b>No variable " + options[0] + "</b>";
	    else
	      val = zero;
	  else {
	    if (arrayp( val ))
	      val = Array.map (val, lambda (mixed v) {return (string) v;}) *
		multisep;
	    else
	      val = replace ((string) val, "\000", multisep);
	    if (!sizeof (val)) val = empty;
	  }

	  if (!sizeof (encodings))
	    encodings = args->encode ?
	      Array.map (lower_case (args->encode) / ",",
			 remove_leading_trailing_ws) : ({"html"});
	  foreach (encodings, string encoding)
	    switch (encoding) {
	      case "none":
	      case "":
		break;

	      case "http":
		// HTTP encoding.
		val = http_encode_string (val);
		break;

	      case "cookie":
		// HTTP cookie encoding.
		val = http_encode_cookie (val);
		break;

	      case "url":
		// HTTP encoding, including special characters in URL:s.
		val = http_encode_url (val);
		break;

	      case "html":
		// For generic html text and in tag arguments. Does
		// not work in RXML tags (use dtag or stag instead).
		val = html_encode_string (val);
		break;

	      case "dtag":
		// Quote quotes for a double quoted tag argument. Only
		// for internal use, i.e. in arguments to other RXML tags.
		val = replace (val, "\"", "\"'\"'\"");
		break;

	      case "stag":
		// Quote quotes for a single quoted tag argument. Only
		// for internal use, i.e. in arguments to other RXML tags.
		val = replace(val, "'", "'\"'\"'");
		break;

	      case "pike":
		// Pike string quoting (e.g. for use in a <pike> tag).
		val = replace (val,
			       ({ "\"", "\\", "\n" }),
			       ({ "\\\"", "\\\\", "\\n" }));
		break;

	      case "js":
	      case "javascript":
		// Javascript string quoting.
		val = replace (val,
			       ({ "\b", "\f", "\n", "\r", "\t", "\\", "'", "\"" }),
			       ({ "\\b", "\\f", "\\n", "\\r", "\\t", "\\\\",
				  "\\'", "\\\"" }));
		break;

	      case "mysql":
		// MySQL quoting.
		val = replace (val,
			       ({ "\"", "'", "\\" }),
			       ({ "\\\"" , "\\'", "\\\\" }) );
		break;

	      case "sql":
	      case "oracle":
		// SQL/Oracle quoting.
		val = replace (val, "'", "''");
		break;

	      case "mysql-dtag":
		// MySQL quoting followed by dtag quoting.
		val = replace (val,
			       ({ "\"", "'", "\\" }),
			       ({ "\\\"'\"'\"", "\\'", "\\\\" }));
		break;

	      case "mysql-pike":
		// MySQL quoting followed by Pike string quoting.
		val = replace (val,
			       ({ "\"", "'", "\\", "\n" }),
			       ({ "\\\\\\\"", "\\\\'",
				  "\\\\\\\\", "\\n" }) );
		break;

	      case "sql-dtag":
	      case "oracle-dtag":
		// SQL/Oracle quoting followed by dtag quoting.
		val = replace (val,
			       ({ "'", "\"" }),
			       ({ "''", "\"'\"'\"" }) );
		break;

	      default:
		return "<b>Unknown encoding " + encoding +
		  " in replace field " + ((c >> 1) + 1) + "</b>";
	    }

	  exploded[c] = val;
	}

      new_contents += args->preprocess ? exploded * "" :
	parse_rxml (exploded * "", id);
      if (args["debug-output"]) unparsed_contents += exploded * "";
    }
    else {
      new_contents += args->preprocess ? contents : parse_rxml (contents, my_id);
      if (args["debug-output"]) unparsed_contents += contents;
    }
  }

  switch (args["debug-output"]) {
    case 0: break;
    case "log":
      report_debug ("tag output: " + unparsed_contents + "\n");
      break;
    case "comment":
      new_contents += "<!--\n" + html_encode_string (unparsed_contents) + "\n-->";
      break;
    default:
      new_contents = "\n<br><b>[</b><pre>" + html_encode_string (unparsed_contents) +
	"</pre><b>]</b>\n";
  }

  id->misc->variables = other_vars;
  return new_contents;
}

string fix_relative(string file, object id)
{
  if(file != "" && file[0] == '/') 
    ;
  else if(file != "" && file[0] == '#') 
    file = id->not_query + file;
  else
    file = dirname(id->not_query) + "/" +  file;
  return simplify_path(file);
}
