/* $Id: module.pike,v 1.82 2000/02/20 11:29:02 mast Exp $ */

#include <module_constants.h>
#include <module.h>
#include <request_trace.h>

mapping (string:array) variables=([]);
RoxenModule this = this_object();
mapping(string:array(int)) error_log=([]);

constant is_module = 1;
constant module_type   = MODULE_ZERO;
constant module_name   = "Unnamed module";
constant module_doc    = "Undocumented";
constant module_unique = 1;

/* These functions exists in here because otherwise the messages in
 * the event log does not always end up in the correct
 * module/configuration.  And the reason for that is that if the
 * messages are logged from subclasses in the module, the DWIM in
 * roxenlib.pike cannot see that they are logged from a module. This
 * solution is not really all that beatiful, but it works. :-)
 */
void report_fatal( mixed ... args )  { predef::report_fatal( @args );  }
void report_error( mixed ... args )  { predef::report_error( @args );  }
void report_notice( mixed ... args ) { predef::report_notice( @args ); }
void report_debug( mixed ... args )  { predef::report_debug( @args );  }


private string _module_identifier;
string module_identifier()
{
  if (!_module_identifier) {
    string|mapping name = register_module()[1];
    if (mappingp (name)) name = name->standard;
    _module_identifier = sprintf ("%s,%O", name || module_name, my_configuration());
  }
  return _module_identifier;
}

string _sprintf()
{
  return "RoxenModule(" + module_identifier() + ")";
}

array register_module()
{
  return ({
    module_type,
    module_name,
    module_doc,
    0,
    module_unique,
  });
}

mapping tagdocumentation() { return ([]); }

string fix_cvs(string from)
{
  from = replace(from, ({ "$", "Id: "," Exp $" }), ({"","",""}));
  sscanf(from, "%*s,v %s", from);
  return replace(from,"/","-");
}

int module_dependencies(Configuration configuration,
                        array (string) modules,
                        int|void now)
{
  if(configuration) configuration->add_modules( modules, now );
// Shouldn't do call outs here, since things assume call outs aren't
// done until all modules are loaded. /mast
//   mixed err;
//   if (err = catch (_do_call_outs()))
//     report_error ("Error doing call outs:\n" + describe_backtrace (err));
  return 1;
}

string file_name_and_stuff()
{
  return ("<b>Loaded from:</b> "+(roxen->filename(this))+"<br>"+
	  (this->cvs_version?
           "<b>CVS Version: </b>"+
           fix_cvs(this->cvs_version)+"\n":""));
}

static private Configuration _my_configuration;

Configuration my_configuration()
{
  if(_my_configuration)
    return _my_configuration;
  Configuration conf;
  foreach(roxen->configurations, conf)
    if(conf->otomod[this])
      return _my_configuration = conf;
  return 0;
}

nomask void set_configuration(Configuration c)
{
  if(_my_configuration && _my_configuration != c)
    error("set_configuration() called twice.\n");
  _my_configuration = c;
}

string|array(string) module_creator;
string module_url;

void set_module_creator(string|array(string) c)
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

void start(void|int num, void|Configuration conf) {}
string status() {}


string info(Configuration conf)
{
  return (this->register_module()[2]);
}

constant ConfigurableWrapper = roxen.ConfigurableWrapper;
constant reg_s_loc = RoxenLocale.standard.register_module_doc;

// Define a variable, with more than a little error checking...
void defvar(string var, mixed value, string name,
	    int type, string|void doc_str, mixed|void misc,
	    int|function|void not_in_config)
{
#ifdef MODULE_DEBUG
  if(!strlen(var))
    report_debug("No name for variable!\n");
//  if(var[0]=='_' && previous_object() != roxen)
//    report_debug("Variable names beginning with '_' are reserved for"
//	    " internal usage.\n");
  if (!stringp(name))
    report_error("The variable "+var+"has no name.\n");

  if((search(name, "\"") != -1))
    report_error("Please do not use \" in variable names");

  if (!stringp(doc_str))
    doc_str = "No documentation";

  switch (type & VAR_TYPE_MASK)
  {
  case TYPE_CUSTOM:
    if(!misc
       && arrayp(misc)
       && (sizeof(misc)>=3)
       && functionp(misc[0])
       && functionp(misc[1])
       && functionp(misc[2]))
       report_error("When defining a TYPE_CUSTOM variable, the MISC "
		    "field must be an array of functionpointers: \n"
		    "({describe,describe_form,set_from_form})\n");
    break;

  case TYPE_TEXT_FIELD:
  case TYPE_FILE:
  case TYPE_STRING:
  case TYPE_LOCATION:
  case TYPE_PASSWORD:
    if(value && !stringp(value)) {
      report_error("%s:\nPassing illegal value (%t:%O) "
		   "to string type variable.\n",
		   roxen->filename(this), value, value);
    }
    break;

  case TYPE_FLOAT:
    if(!floatp(value))
      report_error("%s:\nPassing illegal value (%t:%O) "
		   "(not float) to floating point "
		   "decimal number variable.\n",
		   roxen->filename(this), value, value);
    break;
  case TYPE_INT:
    if(!intp(value))
      report_error("%s:\nPassing illegal value (%t:%O) "
		   "(not int) to integer number variable.\n",
		   roxen->filename(this), value, value);
    break;

  case TYPE_MODULE:
    /* No default possible */
    value = 0;
    break;

  case TYPE_DIR_LIST:
    int i;
    if(!arrayp(value)) {
      report_error("%s:\nIllegal type %t to TYPE_DIR_LIST, "
		   "must be array.\n",
		   roxen->filename(this), value);
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
      report_error("%s:\nPassing illegal value (%t:%O) (not string) "
		   "to directory variable.\n",
		   roxen->filename(this), value, value);

    if(value && strlen(value) && ((string)value)[-1] != '/')
      value+="/";
    break;

  case TYPE_INT_LIST:
  case TYPE_STRING_LIST:
    if(!misc && value && !arrayp(value)) {
      report_error("%s:\nPassing illegal misc (%t:%O) (not array) "
		   "to multiple choice variable.\n",
		   roxen->filename(this), value, value);
    } else {
      if(misc && !arrayp(misc)) {
	report_error("%s:\nPassing illegal misc (%t:%O) (not array) "
		     "to multiple choice variable.\n",
		     roxen->filename(this), misc, misc);
      }
      if(misc && value && search(misc, value)==-1) {
	report_error("%s:\nPassing value (%t:%O) not present "
		    "in the misc array.\n",
		    roxen->filename(this), value, value);
      }
    }
    break;

  case TYPE_FLAG:
    value=!!value;
    break;

//   case TYPE_COLOR:
//     if (!intp(value))
//       report_error("%s:\nPassing illegal value (%t:%O) (not int) "
// 		   "to color variable.\n",
// 		   roxen->filename(this), value, value);
//     break;

  case TYPE_FILE_LIST:
  case TYPE_FONT:
    // FIXME: Add checks for these.
    break;

  default:
    report_error("%s:\nIllegal type (%s) in defvar.\n",
		 roxen->filename(this), type);
    break;
  }
#endif
  // Locale stuff.
  reg_s_loc( this_object(), var, name, doc_str );

  variables[var]=allocate( VAR_SIZE );
  variables[var][ VAR_VALUE ]=value;
  variables[var][ VAR_TYPE ]=type&VAR_TYPE_MASK;
  variables[var][ VAR_DOC_STR ]=doc_str;
  variables[var][ VAR_NAME ]=name;

  type &= ~VAR_TYPE_MASK;		// Probably not needed, but...
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

static mapping locs = ([]);
void deflocaledoc( string locale, string variable,
		   string name, string doc, mapping|void translate )
{
  if(!locs[locale] )
    locs[locale] = RoxenLocale[locale]->register_module_doc;
  if(!locs[locale])
    report_debug("Invalid locale: "+locale+". Ignoring.\n");
  else
    locs[locale]( this_object(), variable, name, doc, translate );
}

void save_me()
{
  my_configuration()->save_one( this_object() );
}

void save()
{
  save_me();
}

// Convenience function, define an invisible variable, this variable
// will be saved, but it won't be visible in the configuration interface.
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
    else if(!ok && var[0] != '_')
      error("Querying undefined variable.\n");
    return 0;
  }

  return variables;
}

void set(string var, mixed value)
{
  if(!variables[var])
    error( "Setting undefined variable.\n" );
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

string query_internal_location()
{
  if(!_my_configuration)
    error("Please do not call this function from create()!\n");
  return _my_configuration->query_internal_location(this_object());
}

/* Per default, return the value of the module variable 'location' */
string query_location()
{
  string s;
  catch{s = query("location");};
  return s;
}

array(string) location_urls()
// The first is the canonical one built with MyWorldLocation.
{
  string loc = query_location();
  if (!loc) return ({});
  if(!_my_configuration)
    error("Please do not call this function from create()!\n");
  string world_url = _my_configuration->query("MyWorldLocation");
  if (world_url == "") world_url = 0;
  array(string) urls = _my_configuration->query("URLs");
  string hostname = gethostname();
  for (int i = 0; i < sizeof (urls); i++) {
    if (world_url && glob (urls[i], world_url)) urls[i] = 0;
    else if (sizeof (urls[i]/"*") == 2)
      urls[i] = replace(urls[i], "*", hostname);
  }
  if (world_url) urls = ({world_url}) | (urls - ({0}));
  return map (urls, `+, loc[1..]);
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

mixed stat_file(string f, RequestID id){}
mixed find_dir(string f, RequestID id){}
mapping(string:array(mixed)) find_dir_stat(string f, RequestID id)
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
mixed real_file(string f, RequestID id){}

mapping _api_functions = ([]);
void add_api_function( string name, function f, void|array(string) types)
{
  _api_functions[name] = ({ f, types });
}

mapping api_functions()
{
  return _api_functions;
}

function _rxml_error;
string rxml_error(string tag, string error, RequestID id) {
  if(_rxml_error) return _rxml_error(tag, error, id);
  if(id->conf->get_provider("RXMLErrorAlert")) {
    _rxml_error=id->conf->get_provider("RXMLErrorAlert")->rxml_error;
    return _rxml_error(tag, error, id);
  }
  return ((id->misc->debug||id->prestate->debug)?
    sprintf("(%s: %s)", capitalize(tag), error):"")+"<false>";
}

mapping query_tag_callers()
{
  mapping m = ([]);
  foreach(glob("tag_*", indices( this_object())), string q)
    if(functionp( this_object()[q] ))
      m[replace(q[4..], "_", "-")] = this_object()[q];
  return m;
}

mapping query_container_callers()
{
  mapping m = ([]);
  foreach(glob("container_*", indices( this_object())), string q)
    if(functionp( this_object()[q] ))
      m[replace(q[10..], "_", "-")] = this_object()[q];
  return m;
}

mapping query_simple_tag_callers()
{
  mapping m = ([]);
  foreach(glob("simpletag_*", indices(this_object())), string q)
    if(functionp(this_object()[q]))
      m[replace(q[10..],"_","-")] =
	({ intp (this_object()[q + "_flags"]) && this_object()[q + "_flags"],
	   this_object()[q] });
  return m;
}

private RXML.TagSet module_tag_set;

RXML.TagSet query_tag_set()
{
  if (!module_tag_set) {
    array(function|program|object) tags =
      filter (rows (this_object(),
		    glob ("Tag*", indices (this_object()))),
	      functionp);
    for (int i = 0; i < sizeof (tags); i++)
      if (programp (tags[i]))
	if (!tags[i]->is_RXML_Tag) tags[i] = 0;
	else tags[i] = tags[i]();
      else {
	tags[i] = tags[i]();
	// Bogosity: The check is really a little too late here..
	if (!tags[i]->is_RXML_Tag) tags[i] = 0;
      }
    tags -= ({0});
    module_tag_set =
      (this_object()->ModuleTagSet || RXML.TagSet) (module_identifier(), tags);
  }
  return module_tag_set;
}

mixed get_value_from_file(string path, string index, void|string pre)
{
  Stdio.File file=Stdio.File();
  if(!file->open(path,"r")) return 0;
  if(index[sizeof(index)-2..sizeof(index)-1]=="()") {
    return compile_string((pre||"")+file->read())[index[..sizeof(index)-3]]();
  }
  return compile_string((pre||"")+file->read())[index];
}
