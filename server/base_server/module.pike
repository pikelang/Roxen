#include <module.h>

mapping (string:mixed *) variables=([]);

object this = this_object();
int module_type;
string fix_cvs(string from)
{
  from = replace(from, ({ "$", "Id: "," Exp $" }), ({"","",""}));
  sscanf(from, "%*s,v %s", from);
  return from;
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

void start(void|int num) {}
string status() {}

string info()
{ 
  return (this->register_module()[2]);
}

// Define a variable, with more than a little error checking...
varargs int defvar(string var, mixed value, string name, int type,
		   string doc_str, mixed misc, int|function not_in_config)
{
  if(!strlen(var))
    error("No name for variable!\n");

//  if(var[0]=='_' && previous_object() != roxen)
//    error("Variable names beginning with '_' are reserved for"
//	    " internal usage.\n");

  if (!stringp(name))
    name = var;
  
  if (!stringp(doc_str))
    doc_str = "No documentation";
  
  switch (type & VAR_TYPE_MASK)
  {
   case TYPE_TEXT_FIELD:
   case TYPE_FILE:
   case TYPE_STRING:
   case TYPE_LOCATION:
    if(value && !stringp(value))
      report_error("Passing illegal value to string type variable.\n");
    break;
    
   case TYPE_FLOAT:
    if(!floatp(value))
      report_error("Passing illegal value (not float) to floating point "
		   "decimal number variable.\n");
    break;
   case TYPE_INT:
    if(!intp(value))
      report_error("Passing illegal value (not int) to integer number variable.\n");
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
     if(!arrayp(value))
       report_error("Illegal type to TYPE_DIR_LIST, must be array.\n");
     for(i=0; i<sizeof(value); i++)
       if(strlen(value[i]))
       {
	 if(value[i][-1] != '/')
	   value[i] += "/";
       } else {
	 value[i]="./";
       }
     break;

   case TYPE_DIR:
    if(value && !stringp(value))
      report_error("Passing illegal value (not string) to directory variable.\n");

    if(value && strlen(value) && ((string)value)[-1] != '/')
      value+="/";
    break;
    
   case TYPE_INT_LIST:
   case TYPE_STRING_LIST:
    if(!misc && value && !arrayp(value))
      report_error("Passing illegal misc (not array) to multiple choice variable.\n");
    if(misc && !arrayp(misc))
      report_error("Passing illegal misc (not array) to multiple choice variable.\n");
    if(misc && search(misc, value)==-1)
      report_error("Passing value passed not present in the misc array.\n");
    break;
    
   case TYPE_FLAG:
    value=!!value;
    break;
    
   case TYPE_ERROR:
    break;

   case TYPE_COLOR:
    if (!intp(value))
      report_error("Passing illegal value (not int) to color variable.\n");
    break;
    
   default:
    report_error("Illegal type ("+type+") in defvar.\n");
  }

  variables[var]=allocate( VAR_SIZE );
  if(!variables[var])
    error("Out of memory in defvar.\n");
  variables[var][ VAR_VALUE ]=value;
  variables[var][ VAR_TYPE ]=type&VAR_TYPE_MASK;
  variables[var][ VAR_DOC_STR ]=doc_str;
  variables[var][ VAR_NAME ]=name;
  if((type&~VAR_TYPE_MASK) & VAR_EXPERT)
    variables[var][ VAR_CONFIGURABLE ] = VAR_EXPERT;
  else
    if(intp(not_in_config))
      variables[var][ VAR_CONFIGURABLE ]= !not_in_config;
    else if(functionp(not_in_config))
      variables[var][ VAR_CONFIGURABLE ]= not_in_config;
  variables[var][ VAR_MISC ]=misc;
  variables[var][ VAR_SHORTNAME ]= var;
}


// Convenience function, define an invissible variable, this variable
// will be saved, but it won't be vissible in the configuration interface.
int definvisvar(string name, int value, int type, array|void misc)
{
  return defvar(name, value, "", type, "", misc, 1);
}

string check_variable( string s, mixed value )
{
  // Check if `value' is O.K. to store in the variable `s'.  If so,
  // return 0, otherwise return a string, describing the error.

  return 0;
}

varargs mixed query(string var, int ok)
{
  if(var)
    if(variables[var])
      return variables[var][VAR_VALUE];
    else if(!ok)
      error("Querying undefined variable.\n");

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
      roxen->register_module_load_hook( value, set, var );
    else if(variables[var][VAR_TYPE] == TYPE_MODULE_LIST)
    {
      variables[var][VAR_VALUE]=value;
      if(arrayp(value))
	foreach(value, value)
	  if(stringp(value))
	    roxen->register_module_load_hook(value,set_module_list,var,value);
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

/*
 * Parse and return a parsed version of the security levels for this module
 *
 */

array query_seclevels()
{
  string sl, sec;
  array patterns=({ });

  if(catch(query("_seclevels")))
    return patterns;
  
  foreach(replace(query("_seclevels"),({" ","\t","\\\n"}),({"","",""}))/"\n",sl)
  {
    if(!strlen(sl) || sl[0]=='#')
      continue;
    string type, value;
    if(sscanf(sl, "%s=%s", type, value)==2)
    {
      value = replace(value, ({ "?", ".", "*" }), ({ ".", "\.", ".*" }));
      switch(type)
      {
      case "allowip":
	patterns += ({ ({ MOD_ALLOW, Regexp(value)->match, }) });
	break;

      case "denyip":
	patterns += ({ ({ MOD_DENY, Regexp(value)->match, }) });
	break;

      case "allowuser":
	value = replace("("+(value/",")*")|("+")","(any)","(.*)");
	if(this->proxy_auth_needed) {
	  patterns += ({ ({ MOD_PROXY_USER, Regexp(value)->match, }) });
	} else {
	  patterns += ({ ({ MOD_USER, Regexp(value)->match, }) });
	}
	break;
      }
    }
  }
  return patterns;
}


mixed stat_file(string f, object id){}
mixed find_dir(string f, object id){}
mixed real_file(string f, object id){}


