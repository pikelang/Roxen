inherit "read_config";

#include <roxen.h>
#include <module.h>
#include <config.h>

#if DEBUG_LEVEL > 0
#ifndef MODULE_DEBUG
#  define MODULE_DEBUG
#endif
#endif


/* Set later on to something better in roxen.pike::main() */
array (object) configurations;
object current_configuration;
mapping (string:mixed *) variables=([]); 

/* Variable support for the main Roxen "module". Normally this is
 * inherited from module.pike, but this is not possible, or wanted, in
 * this case.  Instead we define a few support functions.
 *
 * They do have to handle booth global and virtual server local
 * variables, though.
 */


int setvars( mapping (string:mixed) vars )
{
  string v;
  foreach( indices( vars ), v )
  {
    if(!current_configuration)
    {
      if(variables[v])
	variables[v][ VAR_VALUE ] = vars[ v ];
    }
    else
      if(current_configuration->variables[v])
	current_configuration->variables[v][ VAR_VALUE ] = vars[ v ];
  }
  return 1;
}

void killvar(string name)
{
  m_delete(current_configuration->variables, name);
}

varargs int defvar(string var, mixed value, string name, int type,
		   string doc_str, mixed misc, int|function not_in_config)
{
  current_configuration->variables[var]                = allocate( VAR_SIZE );
  current_configuration->variables[var][ VAR_VALUE ]        = value;
  current_configuration->variables[var][ VAR_TYPE ]         = type;
  current_configuration->variables[var][ VAR_DOC_STR ]      = doc_str;
  current_configuration->variables[var][ VAR_NAME ]         = name;
  current_configuration->variables[var][ VAR_MISC ]         = misc;
  if(intp(not_in_config))
    current_configuration->variables[var][ VAR_CONFIGURABLE ] = !not_in_config;
  else
    current_configuration->variables[var][ VAR_CONFIGURABLE ] = not_in_config;
  current_configuration->variables[var][ VAR_SHORTNAME ] = var;
}

int definvisvar(string var, mixed value, int type)
{
  return defvar(var, value, "", type, "", 0, 1);
}

varargs int globvar(string var, mixed value, string name, int type,
		    string doc_str, mixed misc, int|function not_in_config)
{
  variables[var]                     = allocate( VAR_SIZE );
  variables[var][ VAR_VALUE ]        = value;
  variables[var][ VAR_TYPE ]         = type;
  variables[var][ VAR_DOC_STR ]      = doc_str;
  variables[var][ VAR_NAME ]         = name;
  variables[var][ VAR_MISC ]         = misc;
  
  if(intp(not_in_config))
    variables[var][ VAR_CONFIGURABLE ] = !not_in_config;
  else
    variables[var][ VAR_CONFIGURABLE ] = not_in_config;
  variables[var][ VAR_SHORTNAME ] = var;
}

public mixed query(string var)
{
  if(!current_configuration)
    if(var)
      return variables[var] && variables[var][ VAR_VALUE ];
    else
      return ([ ]); //Nono..
  else
    if(var)
      return (current_configuration->variables[var] 
	      && current_configuration->variables[var][VAR_VALUE]);
    else
      return current_configuration->variables;
  error("query("+var+"). Unknown variable.\n");
}

mixed set(string var, mixed val)
{
#if DEBUG_LEVEL > 30
  perror(sprintf("MAIN: set(\"%s\", %O)\n", var, val));
#endif
  if(variables[var] && !current_configuration)
  {
#if DEBUG_LEVEL > 28
    perror("MAIN:    Setting global variable.\n");
#endif
    return variables[var][VAR_VALUE] = val;
  } else {
#if DEBUG_LEVEL > 28
    perror("MAIN:    Setting local variable.\n");
#endif
    if(current_configuration)
      return (current_configuration->variables[var] && 
	      (current_configuration->variables[var][VAR_VALUE]=val));
  }
  error("set("+var+"). Unknown variable.\n");
}


/* =============================================== */
/* =============================================== */
/* =============================================== */
/* =============================================== */
/* =============================================== */


program last_loaded();
object load_from_dirs(array q, string);

varargs void store(string what, mapping map, int mode);

/* ================================================= */
/* ================================================= */

int unload_module( string modname );
int load_module( string modname );

int disable_module( string modname )
{
  mapping module;
  mapping enabled_modules;
  object me;
  int pri;
  int id;

  sscanf(modname, "%s#%d", modname, id );

  module = current_configuration -> modules[ modname ];

  if(!module) 
  {
    report_error("Modules: Failed to disable module\n"
		 "Modules: No module by that name: \""+modname+"\".\n");
    return 0;
  }

  if(module->copies)
  {
    me = module->copies[id];
    m_delete(module->copies, id);
    if(!sizeof(module->copies))
      unload_module(modname);
  } else {
    me = module->enabled || module->master;
    module->enabled=module->master = 0;
    unload_module(modname);
  }

  current_configuration->unvalidate_cache();

  if(!me)
  {
    report_error("Modules: Failed to Disable "+module->name+" # "+id+"\n");
    return 0;
  }

  if(me->stop) me->stop();

#ifdef MODULE_DEBUG
  perror("Modules: Disabling "+module->name+" # "+id+"\n");
#endif

  if(module["type"] & MODULE_EXTENSION 
     && arrayp( me -> query_extensions()))
  {
    string foo;
    foreach( me -> query_extensions(), foo )
      for(pri=0; pri<10; pri++)
	if( current_configuration->pri[pri]->extension_modules[ foo ] ) 
	  current_configuration->pri[pri]->extension_modules[ foo ]-= ({ me });
  }

  if(module["type"] & MODULE_FILE_EXTENSION 
     && arrayp( me -> query_file_extensions()))
  {
    string foo;
    foreach( me -> query_file_extensions(), foo )
      for(pri=0; pri<10; pri++)
	if(current_configuration->pri[pri]->file_extension_modules[ foo ] ) 
	  current_configuration->pri[pri]->file_extension_modules[foo]-=({me});
  }

  if(module["type"] & MODULE_TYPES)
  {
    current_configuration->types_module = 0;
    current_configuration->types_fun = 0;
  }

  if(module->type & MODULE_MAIN_PARSER)
    current_configuration->parse_module = 0;

  if(module->type & MODULE_PARSER)
  {
    if(current_configuration->parse_module)
      current_configuration->parse_module->remove_parse_module( me );
    current_configuration->_toparse_modules -= ({ me, 0 });
  }

  if( module->type & MODULE_AUTH )
  {
    current_configuration->auth_module = 0;
    current_configuration->auth_fun = 0;
  }

  if( module->type & MODULE_DIRECTORIES )
    current_configuration->dir_module = 0;


  if( module->type & MODULE_LOCATION )
    for(pri=0; pri<10; pri++)
     current_configuration->pri[pri]->location_modules -= ({ me });

  if( module->type & MODULE_URL )
    for(pri=0; pri<10; pri++)
      current_configuration->pri[pri]->url_modules -= ({ me });

  if( module->type & MODULE_LAST )
    for(pri=0; pri<10; pri++)
      current_configuration->pri[pri]->last_modules -= ({ me });

  if( module->type & MODULE_FILTER )
    for(pri=0; pri<10; pri++)
      current_configuration->pri[pri]->filter_modules -= ({ me });

  if( module->type & MODULE_FIRST )
    for(pri=0; pri<10; pri++)
      current_configuration->pri[pri]->first_modules -= ({ me });

  if( module->type & MODULE_LOGGER )
    for(pri=0; pri<10; pri++)
      current_configuration->pri[pri]->logger_modules -= ({ me });

  enabled_modules=retrieve("EnabledModules");

  if(enabled_modules[modname+"#"+id])
  {
    m_delete( enabled_modules, modname + "#" + id );
    store( "EnabledModules",enabled_modules, 1 );
  }
  destruct(me);
  return 1;
}

mapping _hooks=([ ]);


object|string find_module(string name)
{
  int id;
  mapping modules;
  modules = current_configuration->modules;
  sscanf(name, "%s#%d", name, id);
  if(modules[name])
  {
    if(modules[name]->copies)
      return modules[name]->copies[id];
    else 
      if(modules[name]->enabled)
	return modules[name]->enabled;
  }
  return 0;
}

void register_module_load_hook( string modname, function fun, mixed ... args )
{
  object o;
#ifdef MODULE_DEBUG
  perror("Registering a hook for the module "+modname+"\n");
#endif
  if(o=find_module(modname))
  {
#ifdef MODULE_DEBUG
    perror("Already there!\n");
#endif
    fun( @args, o );
  } else
    if(!_hooks[modname])
      _hooks[modname] = ({ ({ fun, args }) });
    else
      _hooks[modname] += ({ ({ fun, args }) });
}


void hooks_for( string modname, object mod )
{
  array hook;
  if(_hooks[modname])
  {
#ifdef MODULE_DEBUG
    perror("Module hooks...");
#endif
    foreach(_hooks[modname], hook)
      hook[0]( @hook[1], mod );
  }
}

object enable_module( string modname )
{
  string id;
  mapping module;
  mapping enabled_modules;

  modname = replace(modname, ".lpc#","#");
  
  sscanf(modname, "%s#%s", modname, id );

  module = current_configuration->modules[ modname ];
  if(!module)
  {
    load_module(modname);
    module = current_configuration->modules[ modname ];
  }

  if( module )
  {
    object me;
    mapping tmp;
    int pri;

#ifdef MODULE_DEBUG
    perror("Modules: Enabling "+module->name+" # "+id+" ... ");
#endif


    if(module->copies)
    {
      me = module["program"]();
      if(module->copies[id])
      {
	module->copies[id]->stop();
	destruct(module->copies[id]);
      }
    } else {
      if(objectp(module->master))
	me = module->master;
      else
	me = module["program"]();
    }


    if((module->type & MODULE_LOCATION)       ||
       (module->type & MODULE_EXTENSION)      ||
       (module->type & MODULE_FILE_EXTENSION) ||
       (module->type & MODULE_LOGGER)         ||
       (module->type & MODULE_URL)  	      ||
       (module->type & MODULE_LAST)           ||
       (module->type & MODULE_FILTER)         ||
       (module->type & MODULE_FIRST))
    {
      me->defvar("_priority", 5, "Priority", TYPE_INT_LIST,
		 "The priority of the module. 9 is highest and 0 is lowest."
		 " Modules with the same priority can be assumed to be "
		 "called in random order", 
		 ({0, 1, 2, 3, 4, 5, 6, 7, 8, 9}));
      
      if(module->type != MODULE_LOGGER)
      {
        if(!(module->type & MODULE_PROXY))
        {
	  me->defvar("_seclvl",  0, "Security: Trust level", TYPE_INT, 
		   "When a location module find a file, that file will get "
		   "a 'Trust level' that equals the level of the module."
		   " This file will then only be sent to modules with a lower "
		   " or equal 'Trust level'. <p>As an example: If the trust "
		   " level of a User filesystem is one, and the CGI module "
		   "have trust level 2, the file will never get passed to the "
		   " CGI module. A trust level of '0' is the same thing as "
		   " free access.\n");

	  me->defvar("_seclevels", "",
		     "Security: Patterns",
		     TYPE_TEXT_FIELD,
		     "This is the 'security level=value' list.<br>"
		     "Each security level can be any or more from this list:"
		     "<hr noshade>"
		     "allow ip=pattern<br>"
		     "allow user=username,...<br>"
		     "deny ip=pattern<br>"
		     "<hr noshade>"
		     "In patterns: * is on or more characters, ? is one "
		     " character.<p>"
		     "In username: 'any' stands for any valid account "
		     "(from .htaccess"
		     " or auth-module. The default (used when _no_ "
		     "entries are present) is 'allow ip=*', allowing"
		     " everyone to access the module");
	  
	} else {
	  me->definvisvar("_seclvl", -1, TYPE_INT); /* Lowest possible */
	  
	  me->defvar("_seclevels", "",
		     "Proxy security: Patterns",
		     TYPE_TEXT_FIELD,
		     "This is the 'security level=value' list.<br>"
		     "Each security level can be any or more from "
		     "this list:<br>"
		     "<hr noshade>"
		     "allow ip=pattern<br>"
		     "allow user=username,...<br>"
		     "deny ip=pattern<br>"
		     "<hr noshade>"
		     "In patterns: * is on or more characters, ? is one "
		     " character.<p>"
		     "In username: 'any' stands for any valid account"
		     " (from .htaccess"
		     " or auth-module. The default is 'deny ip=*'");
	}
      }
    } else
      me->defvar("_priority", 0, "", TYPE_INT, "", 0, 1);

    me->defvar("_comment", "", " Comment", TYPE_TEXT_FIELD,
	       "An optional comment. This has no effect on the module, it "
	       "is only a text field for comments that the administrator "
	       "might have (why the module are here, etc.)");

    me->defvar("_name", "", " Module name", TYPE_STRING,
	       "An optional name. Set to something to remaind you what "
	       "the module really does.");

    me->setvars(retrieve(modname + "#" + id));
      
    mixed err;
    if(err=catch{if(me->start) me->start();})
    {
      report_error("Error while initiating module copy of "+module->name+"\n"
		    + describe_backtrace(err));
      destruct(me);
      return 0;
    }
      
    pri = me->query("_priority");

    if((module->type&MODULE_EXTENSION) && arrayp(me->query_extensions()))
    {
      string foo;
      foreach( me->query_extensions(), foo )
	if(current_configuration->pri[pri]->extension_modules[ foo ])
	  current_configuration->pri[pri]->extension_modules[foo] += ({ me });
	else
	  current_configuration->pri[pri]->extension_modules[foo] = ({ me });
    }	  

    if((module->type & MODULE_FILE_EXTENSION) && 
       arrayp(me->query_file_extensions()))
    {
      string foo;
      foreach( me->query_file_extensions(), foo )
	if(current_configuration->pri[pri]->file_extension_modules[foo] ) 
	  current_configuration->pri[pri]->file_extension_modules[foo]+=({me});
	else
	  current_configuration->pri[pri]->file_extension_modules[foo]=({me});
    }

    if(module->type & MODULE_TYPES)
    {
      current_configuration->types_module = me;
      current_configuration->types_fun = me->type_from_extension;
    }


    if((module->type & MODULE_MAIN_PARSER))
    {
      current_configuration->parse_module = me;
      if(current_configuration->_toparse_modules)
	map_array(current_configuration->_toparse_modules,
		  lambda(object o, object me) 
		  { me->add_parse_module(o); }, me);
    }

    if(module->type & MODULE_PARSER)
    {
      if(current_configuration->parse_module)
	current_configuration->parse_module->add_parse_module( me );
      current_configuration->_toparse_modules += ({ me });
    }

    if(module->type & MODULE_AUTH)
    {
      current_configuration->auth_module = me;
      current_configuration->auth_fun = me->auth;
    }

    if(module->type & MODULE_DIRECTORIES)
      current_configuration->dir_module = me;

    if(module->type & MODULE_LOCATION)
      current_configuration->pri[pri]->location_modules += ({ me });

    if(module->type & MODULE_LOGGER)
      current_configuration->pri[pri]->logger_modules += ({ me });

    if(module->type & MODULE_URL)
      current_configuration->pri[pri]->url_modules += ({ me });

    if(module->type & MODULE_LAST)
      current_configuration->pri[pri]->last_modules += ({ me });

    if(module->type & MODULE_FILTER)
      current_configuration->pri[pri]->filter_modules += ({ me });

    if(module->type & MODULE_FIRST)
      current_configuration->pri[pri]->first_modules += ({ me });

    if(module->copies)
      module->copies[(int)id] = me;
    else
      module->enabled = me;

    hooks_for(module->sname+"#"+id, me);
      

    current_configuration->otomod[ me ] = modname;
    enabled_modules=retrieve("EnabledModules");

    if(!enabled_modules[modname+"#"+id])
    {
#ifdef MODULE_DEBUG
      perror("New module...");
#endif
      enabled_modules[modname+"#"+id] = 1;
      store( "EnabledModules",enabled_modules, 1);
    }
#ifdef MODULE_DEBUG
    perror(" Done.\n");
#endif 
    current_configuration->unvalidate_cache();
    return me;
  }
}

int load_module(string module_file)
{
  int foo, disablep;
  mixed err;
  mixed *module_data;
  mapping loaded_modules;
  object obj;
  program prog;

#ifdef MODULE_DEBUG
  perror("Modules: Loading "+module_file+"... ");
#endif

  if(prog=cache_lookup("modules", module_file))
    obj=prog();
  else
  {
    string dir;
    obj = load_from_dirs(QUERY(ModuleDirs), module_file);
    prog = last_loaded();
  }
  if(!obj)
  {
#ifdef MODULE_DEBUG
    perror("FAILED\n");
#endif
    report_error( "Module load failed.\n");
    return 0;
  }
  err = catch (module_data = obj->register_module());

  if (err)
  {
#ifdef MODULE_DEBUG
    perror("FAILED\n");
#endif
    report_error( "Module loaded, but register_module() failed (" 
		 + module_file + ").\n"  +
		  describe_backtrace( err ));
    return 0;
  }

  err = "";
      
  if (!arrayp( module_data ))
    err = "Register_module didn't return an array.\n";
  else
    switch (sizeof( module_data ))
    {
     case 5:
      foo=1;
      module_data=module_data[0..3];
     case 4:
      if (module_data[3] && !arrayp( module_data[3] ))
	err = "The fourth element of the array register_module returned "
	  + "(extra_buttons) wasn't an array.\n" + err;
     case 3:
      if (!stringp( module_data[2] ))
	err = "The third element of the array register_module returned "
	  + "(documentation) wasn't a string.\n" + err;
      if (!stringp( module_data[1] ))
	err = "The second element of the array register_module returned "
	  + "(name) wasn't a string.\n" + err;
      if (!intp( module_data[0] ))
	err = "The first element of the array register_module returned "
	  + "(type) wasn't an integer.\n" + err;
      break;

     default:
      err = ("The array register_module returned was too small/large. "
	     + "It should have been three or four elements (type, name, "
	     + "documentation and extra buttons (optional))\n");
    }
  if (err != "")
  {
#ifdef MODULE_DEBUG
    perror("FAILED\n");
#endif
    report_error( "Tried to load module " + module_file + ", but:\n" + err );
    if(obj)
      destruct( obj );
    return 0;
  } 
    
  if (sizeof(module_data) == 3)
    module_data += ({ 0 }); 

  if(!foo)
  {
    destruct(obj);
    obj=0;
  } else {
    current_configuration->otomod[obj] = module_file;
  }

  if(!current_configuration->modules[ module_file ])
    current_configuration->modules[ module_file ] = ([]);
  mapping tmpp = current_configuration->modules[ module_file ];

  tmpp->type=module_data[0];
  tmpp->name=module_data[1];
  tmpp->doc=module_data[2];
  tmpp->extra=module_data[3];
  tmpp["program"]=prog;
  tmpp->master=obj;
  tmpp->copies=(foo ? 0 : (tmpp->copies||([])));
  tmpp->sname=module_file;
      
#ifdef MODULE_DEBUG
  perror(" Done ("+search(_master->programs,prog)+").\n");
#endif
  cache_set("modules", module_file,
	    current_configuration->modules[module_file]["program"]);
// ??  current_configuration->unvalidate_cache();

  return 1;
}

int unload_module(string module_file)
{
  mapping module;
  int id;

  module = current_configuration->modules[ module_file ];

  if(!module) 
    return 0;

  if(objectp(module->master)) 
    destruct(module->master);

  cache_remove("modules", module_file);
  
  m_delete(current_configuration->modules, module_file);

  return 1;
}
 

