/* $Id: module.pike,v 1.36 1998/11/18 04:53:48 per Exp $ */

#include <module.h>

#define TRACE_ENTER(A,B) do{if(id->misc->trace_enter)id->misc->trace_enter((A),(B));}while(0)
#define TRACE_LEAVE(A) do{if(id->misc->trace_leave)id->misc->trace_leave((A));}while(0)

mapping (string:mixed *) variables=([]);

object this = this_object();
int module_type;
string fix_cvs(string from)
{
  from = replace(from, ({ "$", "Id: "," Exp $" }), ({"","",""}));
  sscanf(from, "%*s,v %s", from);
  return from;
}

int module_dependencies(object configuration, array (string) modules)
{
  if(configuration)
  {
    foreach (modules, string module)
    {
      if(!configuration->modules[module] ||
	 (!configuration->modules[module]->copies &&
	  !configuration->modules[module]->master))
	configuration->enable_module(module+"#0");
    }
    if(roxen->root)
      roxen->configuration_interface()->build_root(roxen->root);
  }
  _do_call_outs();
  return 1;
}

string file_name_and_stuff()
{
  return ("<b>Loaded from:</b> "+(roxen->filename(this))+"<br>"+
	  (this->cvs_version?"<b>CVS Version: </b>"+fix_cvs(this->cvs_version)+"<nr>\n":""));
}

object my_configuration()
{
  object conf;
  foreach(roxen->configurations, conf)
    if(conf->otomod[this])
      return conf;
  return 0;
}

string module_creator;
string module_url;

void set_module_creator(string c)
{
  module_creator = c;
}

void set_module_url(string to)
{
  module_url = to;
}

int killvar(string var)
{
  if(!variables[var]) error("Killing undefined variable.\n");
  m_delete(variables, var);
  return 1;
}

void free_some_sockets_please(){}

void start(void|int num, void|object conf) {}
string status() {}

string info(object conf)
{ 
  return (this->register_module(conf)[2]);
}

static class ConfigurableWrapper
{
  int mode;
  function f;
  int check()
  {
    if ((mode & VAR_EXPERT) &&
	(!roxen->configuration_interface()->expert_mode)) {
      return 1;
    }
    if ((mode & VAR_MORE) &&
	(!roxen->configuration_interface()->more_mode)) {
      return 1;
    }
    return(f());
  }
  void create(int mode_, function f_)
  {
    mode = mode_;
    f = f_;
  }
};

// Define a variable, with more than a little error checking...
void defvar(string|void var, mixed|void value, string|void name,
	    int|void type, string|void doc_str, mixed|void misc,
	    int|function|void not_in_config)
{
  if(!strlen(var))
    error("No name for variable!\n");

//  if(var[0]=='_' && previous_object() != roxen)
//    error("Variable names beginning with '_' are reserved for"
//	    " internal usage.\n");

  if (!stringp(name))
    name = var;

  if((search(name, "\"") != -1))
    error("Please do not use \" in variable names");
  
  if (!stringp(doc_str))
    doc_str = "No documentation";

  switch (type & VAR_TYPE_MASK)
  {
  case TYPE_NODE:
    if(!arrayp(value))
      error("TYPE_NODE variables should contain a list of variables "
	    "to use as subnodes.\n");
    break;
  case TYPE_CUSTOM:
    if(!misc
       && arrayp(misc)
       && (sizeof(misc)>=3)
       && functionp(misc[0])
       && functionp(misc[1])
       && functionp(misc[2]))
       error("When defining a TYPE_CUSTOM variable, the MISC "
	     "field must be an array of functionpointers: \n"
	     "({describe,describe_form,set_from_form})\n");
    break;

  case TYPE_TEXT_FIELD:
  case TYPE_FILE:
  case TYPE_STRING:
  case TYPE_LOCATION:
  case TYPE_PASSWORD:
    if(value && !stringp(value)) {
      report_error(sprintf("%s:\nPassing illegal value (%t:%O) "
			   "to string type variable.\n",
			   roxen->filename(this), value, value));
    }
    break;
    
  case TYPE_FLOAT:
    if(!floatp(value))
      report_error(sprintf("%s:\nPassing illegal value (%t:%O) "
			   "(not float) to floating point "
			   "decimal number variable.\n",
			   roxen->filename(this), value, value));
    break;
  case TYPE_INT:
    if(!intp(value))
      report_error(sprintf("%s:\nPassing illegal value (%t:%O) "
			   "(not int) to integer number variable.\n",
			   roxen->filename(this), value, value));
    break;
     
  case TYPE_MODULE_LIST:
    value = ({});
    break;
    
  case TYPE_MODULE:
    /* No default possible */
    value = 0;
    break;

  case TYPE_DIR_LIST:
    int i;
    if(!arrayp(value)) {
      report_error(sprintf("%s:\nIllegal type %t to TYPE_DIR_LIST, "
			   "must be array.\n",
			   roxen->filename(this), value));
      value = ({ "./" });
    } else {
      for(i=0; i<sizeof(value); i++) {
	if(strlen(value[i])) {
	  if(value[i][-1] != '/')
	    value[i] += "/";
	 } else {
	   value[i]="./";
	 }
      }
    }
    break;

  case TYPE_DIR:
    if(value && !stringp(value))
      report_error(sprintf("%s:\nPassing illegal value (%t:%O) (not string) "
			   "to directory variable.\n",
			   roxen->filename(this), value, value));
    
    if(value && strlen(value) && ((string)value)[-1] != '/')
      value+="/";
    break;
    
  case TYPE_INT_LIST:
  case TYPE_STRING_LIST:
    if(!misc && value && !arrayp(value)) {
      report_error(sprintf("%s:\nPassing illegal misc (%t:%O) (not array) "
			   "to multiple choice variable.\n",
			   roxen->filename(this), value, value));
    } else {
      if(misc && !arrayp(misc)) {
	report_error(sprintf("%s:\nPassing illegal misc (%t:%O) (not array) "
			     "to multiple choice variable.\n",
			     roxen->filename(this), misc, misc));
      }
      if(misc && value && search(misc, value)==-1) {
	roxen_perror(sprintf("%s:\nPassing value (%t:%O) not present "
			     "in the misc array.\n",
			     roxen->filename(this), value, value));
      }
    }
    break;
    
  case TYPE_FLAG:
    value=!!value;
    break;
    
  case TYPE_ERROR:
    break;

  case TYPE_COLOR:
    if (!intp(value))
      report_error(sprintf("%s:\nPassing illegal value (%t:%O) (not int) "
			   "to color variable.\n",
			   roxen->filename(this), value, value));
    break;
    
  case TYPE_FILE_LIST:
  case TYPE_PORTS:
  case TYPE_FONT:
    // FIXME: Add checks for these.
    break;

  default:
    report_error(sprintf("%s:\nIllegal type (%s) in defvar.\n",
			 roxen->filename(this), type));
    break;
  }


  // Locale stuff!
  // Här blir vi farliga...
  Locale.Roxen.standard
    ->register_module_doc( this_object(), var, name, doc_str );


  variables[var]=allocate( VAR_SIZE );
  if(!variables[var])
    error("Out of memory in defvar.\n");
  variables[var][ VAR_VALUE ]=value;
  variables[var][ VAR_TYPE ]=type&VAR_TYPE_MASK;
  variables[var][ VAR_DOC_STR ]=doc_str;
  variables[var][ VAR_NAME ]=name;

  type &= ~VAR_TYPE_MASK;		// Probably not needed, but...
  type &= (VAR_EXPERT | VAR_MORE);
  if (functionp(not_in_config)) {
    if (type) {
      variables[var][ VAR_CONFIGURABLE ] = ConfigurableWrapper(type, not_in_config)->check;
    } else {
      variables[var][ VAR_CONFIGURABLE ] = not_in_config;
    }
  } else if (type) {
    variables[var][ VAR_CONFIGURABLE ] = type;
  } else if(intp(not_in_config)) {
    variables[var][ VAR_CONFIGURABLE ] = !not_in_config;
  }

  variables[var][ VAR_MISC ]=misc;
  variables[var][ VAR_SHORTNAME ]= var;
}

void deflocaledoc( string locale, string variable, 
		   string name, string doc, mapping|void translate )
{
  if(!Locale.Roxen[locale])
    report_debug("Invalid locale: "+locale+". Ignoring.\n");
  else
    Locale.Roxen[locale]
      ->register_module_doc( this_object(), variable, name, doc, translate );
}

// Convenience function, define an invissible variable, this variable
// will be saved, but it won't be vissible in the configuration interface.
void definvisvar(string name, int value, int type, array|void misc)
{
  defvar(name, value, "", type, "", misc, 1);
}

string check_variable( string s, mixed value )
{
  // Check if `value' is O.K. to store in the variable `s'.  If so,
  // return 0, otherwise return a string, describing the error.

  return 0;
}

mixed query(string|void var, int|void ok)
{
  if(var) {
    if(variables[var])
      return variables[var][VAR_VALUE];
    else if(!ok)
      error("Querying undefined variable.\n");
  }

  return variables;
}

void set_module_list(string var, string what, object to)
{
  int p;
  p = search(variables[var][VAR_VALUE], what);
  if(p == -1)
  {
#ifdef MODULE_DEBUG
    perror("The variable '"+var+"': '"+what+"' found by hook.\n");
    perror("Not found in variable!\n");
#endif
  } else 
    variables[var][VAR_VALUE][p]=to;
}

void set(string var, mixed value)
{
  if(!variables[var])
    error( "Setting undefined variable.\n" );
  else
    if(variables[var][VAR_TYPE] == TYPE_MODULE && stringp(value))
      roxenp()->register_module_load_hook( value, set, var );
    else if(variables[var][VAR_TYPE] == TYPE_MODULE_LIST)
    {
      variables[var][VAR_VALUE]=value;
      if(arrayp(value))
	foreach(value, value)
	  if(stringp(value))
	    roxenp()->register_module_load_hook(value,set_module_list,var,value);
    }
    else
      variables[var][VAR_VALUE]=value;
}

int setvars( mapping (string:mixed) vars )
{
  string v;
  int err;

  foreach( indices( vars ), v )
    if(variables[v])
      set( v, vars[v] );
  return !err;
}


string comment()
{
  return "";
}

/* Per default, return the value of the module variable 'location' */
string query_location()
{
  string s;
  catch{s = query("location");};
  return s;
}

/* By default, provide nothing. */
string query_provides() { return 0; } 

/*
 * Parse and return a parsed version of the security levels for this module
 *
 */

class IP_with_mask {
  int net;
  int mask;
  static private int ip_to_int(string ip)
  {
    int res;
    foreach(((ip/".") + ({ "0", "0", "0" }))[..3], string num) {
      res = res*256 + (int)num;
    }
    return(res);
  }
  void create(string _ip, string|int _mask)
  {
    net = ip_to_int(_ip);
    if (intp(_mask)) {
      if (_mask > 32) {
	report_error(sprintf("Bad netmask: %s/%d\n"
			     "Using %s/32\n", _ip, _mask, _ip));
	_mask = 32;
      }
      mask = ~0<<(32-_mask);
    } else {
      mask = ip_to_int(_mask);
    }
    if (net & ~mask) {
      report_error(sprintf("Bad netmask: %s for network %s\n"
			   "Ignoring node-specific bits\n", _ip, _mask));
      net &= mask;
    }
  }
  int `()(string ip)
  {
    return((ip_to_int(ip) & mask) == net);
  }
};

array query_seclevels()
{
  array patterns=({ });

  if(catch(query("_seclevels"))) {
    return patterns;
  }
  
  foreach(replace(query("_seclevels"),
		  ({" ","\t","\\\n"}),
		  ({"","",""}))/"\n", string sl) {
    if(!strlen(sl) || sl[0]=='#')
      continue;

    string type, value;
    if(sscanf(sl, "%s=%s", type, value)==2)
    {
      switch(lower_case(type))
      {
      case "allowip":
	array(string|int) arr;
	if (sizeof(arr = (value/"/")) == 2) {
	  // IP/bits
	  arr[1] = (int)arr[1];
	  patterns += ({ ({ MOD_ALLOW, IP_with_mask(@arr) }) });
	} else if ((sizeof(arr = (value/":")) == 2) ||
		   (sizeof(arr = (value/",")) > 1)) {
	  // IP:mask or IP,mask
	  patterns += ({ ({ MOD_ALLOW, IP_with_mask(@arr) }) });
	} else {
	  // Pattern
	  value = replace(value, ({ "?", ".", "*" }), ({ ".", "\\.", ".*" }));
	  patterns += ({ ({ MOD_ALLOW, Regexp(value)->match, }) });
	}
	break;

      case "acceptip":
	// Short-circuit version of allow ip.
	array(string|int) arr;
	if (sizeof(arr = (value/"/")) == 2) {
	  // IP/bits
	  arr[1] = (int)arr[1];
	  patterns += ({ ({ MOD_ACCEPT, IP_with_mask(@arr) }) });
	} else if ((sizeof(arr = (value/":")) == 2) ||
		   (sizeof(arr = (value/",")) > 1)) {
	  // IP:mask or IP,mask
	  patterns += ({ ({ MOD_ACCEPT, IP_with_mask(@arr) }) });
	} else {
	  // Pattern
	  value = replace(value, ({ "?", ".", "*" }), ({ ".", "\\.", ".*" }));
	  patterns += ({ ({ MOD_ACCEPT, Regexp(value)->match, }) });
	}
	break;

      case "denyip":
	array(string|int) arr;
	if (sizeof(arr = (value/"/")) == 2) {
	  // IP/bits
	  arr[1] = (int)arr[1];
	  patterns += ({ ({ MOD_DENY, IP_with_mask(@arr) }) });
	} else if ((sizeof(arr = (value/":")) == 2) ||
		   (sizeof(arr = (value/",")) > 1)) {
	  // IP:mask or IP,mask
	  patterns += ({ ({ MOD_DENY, IP_with_mask(@arr) }) });
	} else {
	  // Pattern
	  value = replace(value, ({ "?", ".", "*" }), ({ ".", "\\.", ".*" }));
	  patterns += ({ ({ MOD_DENY, Regexp(value)->match, }) });
	}
	break;

      case "allowuser":
	value = replace(value, ({ "?", ".", "*" }), ({ ".", "\\.", ".*" }));
	array(string) users = (value/"," - ({""}));
	int i;
	
	for(i=0; i < sizeof(users); i++) {
	  if (lower_case(users[i]) == "any") {
	    if(this->register_module()[0] & MODULE_PROXY) 
	      patterns += ({ ({ MOD_PROXY_USER, lambda(){ return 1; } }) });
	    else
	      patterns += ({ ({ MOD_USER, lambda(){ return 1; } }) });
	    break;
	  } else {
	    users[i & 0x0f] = "(^"+users[i]+"$)";
	  }
	  if ((i & 0x0f) == 0x0f) {
	    value = users[0..0x0f]*"|";
	    if(this->register_module()[0] & MODULE_PROXY) {
	      patterns += ({ ({ MOD_PROXY_USER, Regexp(value)->match, }) });
	    } else {
	      patterns += ({ ({ MOD_USER, Regexp(value)->match, }) });
	    }
	  }
	}
	if (i & 0x0f) {
	  value = users[0..(i-1)&0x0f]*"|";
	  if(this->register_module()[0] & MODULE_PROXY) {
	    patterns += ({ ({ MOD_PROXY_USER, Regexp(value)->match, }) });
	  } else {
	    patterns += ({ ({ MOD_USER, Regexp(value)->match, }) });
	  }
	}
	break;

      case "acceptuser":
	// Short-circuit version of allow user.
	// NOTE: MOD_PROXY_USER is already short-circuit.
	value = replace(value, ({ "?", ".", "*" }), ({ ".", "\\.", ".*" }));
	array(string) users = (value/"," - ({""}));
	int i;
	
	for(i=0; i < sizeof(users); i++) {
	  if (lower_case(users[i]) == "any") {
	    if(this->register_module()[0] & MODULE_PROXY) 
	      patterns += ({ ({ MOD_PROXY_USER, lambda(){ return 1; } }) });
	    else
	      patterns += ({ ({ MOD_ACCEPT_USER, lambda(){ return 1; } }) });
	    break;
	  } else {
	    users[i & 0x0f] = "(^"+users[i]+"$)";
	  }
	  if ((i & 0x0f) == 0x0f) {
	    value = users[0..0x0f]*"|";
	    if(this->register_module()[0] & MODULE_PROXY) {
	      patterns += ({ ({ MOD_PROXY_USER, Regexp(value)->match, }) });
	    } else {
	      patterns += ({ ({ MOD_ACCEPT_USER, Regexp(value)->match, }) });
	    }
	  }
	}
	if (i & 0x0f) {
	  value = users[0..(i-1)&0x0f]*"|";
	  if(this->register_module()[0] & MODULE_PROXY) {
	    patterns += ({ ({ MOD_PROXY_USER, Regexp(value)->match, }) });
	  } else {
	    patterns += ({ ({ MOD_ACCEPT_USER, Regexp(value)->match, }) });
	  }
	}
	break;

      default:
	report_error(sprintf("Unknown Security:Patterns directive: "
			     "type=\"%s\"\n", type));
	break;
      }
    } else {
      report_error(sprintf("Syntax error in Security:Patterns directive: "
			   "line=\"%s\"\n", sl));
    }
  }
  return patterns;
}

mixed stat_file(string f, object id){}
mixed find_dir(string f, object id){}
mapping(string:array(mixed)) find_dir_stat(string f, object id)
{
  TRACE_ENTER("find_dir_stat(): \""+f+"\"", 0);

  array(string) files = find_dir(f, id);
  mapping(string:array(mixed)) res = ([]);

  foreach(files || ({}), string fname) {
    TRACE_ENTER("stat()'ing "+ f + "/" + fname, 0);
    array(mixed) st = stat_file(f + "/" + fname, id);
    if (st) {
      res[fname] = st;
      TRACE_LEAVE("OK");
    } else {
      TRACE_LEAVE("No stat info");
    }
  }

  TRACE_LEAVE("");
  return(res);
}
mixed real_file(string f, object id){}

mapping _api_functions = ([]);
void add_api_function( string name, function f, void|array(string) types)
{
  _api_functions[name] = ({ f, types });
}

mapping api_functions()
{
  return _api_functions;
}

object get_font_from_var(string base)
{
  int weight, slant;
  switch(query(base+"_weight"))
  {
   case "light": weight=-1; break;
   default: weight=0; break;
   case "bold": weight=1; break;
   case "black": weight=2; break;
  }
  switch(query(base+"_slant"))
  {
   case "obligue": slant=-1; break;
   default: slant=0; break;
   case "italic": slant=1; break;
  }
  return get_font(query(base+"_font"), 32, weight, slant, "left", 0, 0);
}
