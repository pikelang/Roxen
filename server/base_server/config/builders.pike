/* $Id: builders.pike,v 1.12 1997/08/13 03:02:45 grubba Exp $ */

#include <module.h>
#include <confignode.h>
inherit "describers";
inherit "savers";

import Array;

/*#define CONFIG_DEBUG*/

import Array;

void low_build_variables(object node, mapping from)
{
  array m;
  object o;
  int i;

#ifdef CONFIG_DEBUG
  perror("low_build_variables()\n");
#endif

  m = values(from);
  sort(column(m,VAR_NAME),m);
  
  for(i=0; i<sizeof(m); i++)
  {
    if(m[i][VAR_TYPE] == TYPE_NODE)
    {
      o=node->descend(m[i][VAR_NAME]);
      o->type = NODE_MODULE_COPY_VARIABLES;
      o->data = m[i];
      o->changed = 0;
      o->folded = 1;
      o->describer = describe_module_subnode;
      low_build_variables(o,o->data[VAR_VALUE]->query());
    } else
      if(m[i][VAR_NAME] && m[i][VAR_CONFIGURABLE])
      {  
	string base, name;
	if(m[i][VAR_SHORTNAME][0] == '_')
	{
	  o=node->descend("Builtins")->descend(m[i][VAR_NAME]);
	  o->changed = 0;
	  o->folded = 1;
	}
	else if(sscanf(m[i][VAR_NAME], "%s:%s", base, name) == 2)
	{
	  sscanf(name, "%*[\t ]%s", name);
	  m[i][VAR_NAME] = name;
	  o=node->descend(base);
	  o->describer = describe_holder;
	  o->data = base;
	  o->changed = 0;
	  o->folded = 1;
	  o=o->descend(name);
	  o->changed = 0;
	  o->folded = 1;
	} else {
	  o=node->descend(m[i][VAR_NAME]);
	  o->changed = 0;
	  o->folded = 1;
	}
	o->type = NODE_MODULE_COPY_VARIABLE;
	o->saver = save_module_variable;
	o->changed = 0;
	o->folded = 1;
	o->data = m[i];
	o->describer = describe_module_variable;
      }
  }
  if(o=node->descend("Builtins", 1))
  {
    o->describer = describe_builtin_variables;
    o->changed = 0;
    o->folded = 1;
    o->data = 0;
    o->type = NODE_MODULE_COPY_BUILTIN_VARIABLES;
  }
}

void build_module_copy_variables(object node)
{
#ifdef CONFIG_DEBUG
  perror("build_module_copy_variables()\n");
#endif
  node->changed = 0;
  node->folded = 1;
  low_build_variables(node, node->data->query());
}

void build_module_master_copy_variables(object node)
{
#ifdef CONFIG_DEBUG
  perror("build_module_master_copy_variables("+node->data->name+")\n");
#endif
  low_build_variables(node, node->data->master->query());
}

void build_module_copy_status(object node)
{
#ifdef CONFIG_DEBUG
  perror("build_module_copy_status()\n");
#endif
}

void build_module_copy(object node)
{
  string res;
  object o;

#ifdef CONFIG_DEBUG
  perror("build_module_copy()\n");
#endif
  o=node->descend("Status");
  o->type = NODE_MODULE_COPY_STATUS;
  o->data = node->data->status;
  o->changed = 0;
  o->folded = 1;

  o->describer = describe_module_copy_status;
  build_module_copy_status(o);
  build_module_copy_variables(node);
}

void build_module(object node)
{
  string res;
  int t;
  mixed copies, mod;
  object o, c;

  if(!node->data->master && !node->data->copies) return;
  
  mod = node->data;
  copies = node->data->copies;

#ifdef CONFIG_DEBUG
  perror("build_module ("+mod->name+")\n");
#endif

  if(copies)
  {
    foreach(indices(copies), t)
    {
      o=node->descend((string)t);
      o->describer = describe_module_copy;
      o->saver = save_module_copy;
      o->changed = 0;
      o->folded = 1;
      o->type = NODE_MODULE_COPY;
      o->data = copies[t];
      build_module_copy(o);
    }
  } else {
    o=node->descend("Status");
    o->type = NODE_MODULE_COPY_STATUS;
    o->data = node->data->master->status;
    o->describer = describe_module_copy_status;
    o->changed = 0;
    o->folded = 1;
    build_module_copy_status(o);

    node->type = NODE_MODULE_MASTER_COPY; 
    node->saver = save_module_master_copy;
    node->changed = 0;
    node->folded = 1;
    build_module_master_copy_variables(node);
  }
}

void build_global_variables(object node)
{
  node->saver = save_global_variables;
  low_build_variables(node, node->data);
}

void build_configuration(object node)
{
  object cf;
  string res;
  array (mapping) modules;
  int i;
  cf = node->data;
#ifdef CONFIG_DEBUG
  perror("build_configuration("+node->data->name+")\n");
#endif
  
  object o;
  
  modules = sort_array(values(node->data->modules),
		       lambda(mapping a, mapping b) {
    return a->name > b->name;
  });

  // Configuration global variables recide in the roxen "module"... :)

  o=node->descend("Status");
  o->type = NODE_MODULE_COPY_STATUS;
  o->data = cf->status;
  o->describer = describe_module_copy_status;
  build_module_copy_status( o );

  o=node->descend("Global");
/*  roxen->current_configuration = o->config();*/
  o->data = cf->query();
  o->describer = describe_configuration_global_variables;
  o->type = NODE_CONFIG_GLOBAL_VARIABLES;
  o->saver = save_configuration_global_variables;
  low_build_variables(o, o->data);

  o->folded = 1;
  o->changed = 0;

  for(i=0; i<sizeof(modules); i++)
  {
    o=node->descend((string)modules[i]->name);
    o->data = modules[i];
    o->describer = describe_module;
    o->type = NODE_MODULE;
    o->folded = 1;
    o->changed = 0;
    build_module(o);
  }
}

void build_configurations(object node)
{
  int i;
  object o;
  array configurations;

#ifdef CONFIG_DEBUG
  perror("build_configurations()\n");
#endif

  if(node->data)
    configurations=sort_array(node->data, lambda(object a, object b) {
      return a->name > b->name;
    });
  node->changed = 0;

  if(configurations)
    for(i=0; i<sizeof(configurations); i++)
    {
      if(objectp(configurations[i]))
      {
	o=node->descend(configurations[i]->name);
	o->data = configurations[i];
	o->describer = describe_configuration;
	o->type = NODE_CONFIGURATION;
	o->saver = save_configuration;
	o->changed = 0;
	o->folded = 1;
	build_configuration( o );
      }
    }
}

void build_root(object root, void|int nodes)
{
  object o;

#ifdef CONFIG_DEBUG
  perror("build_root()\n");
#endif

  root->describer = describe_root;
/*root->data = roxen->configurations;*/
  
  o=root->descend("Errors");
  if(!o->data)
  {
    o->describer = describe_errors;
    o->data = roxen->error_log;
    o->type = NODE_ERRORS;
  }

  if(!nodes)
  {
    o=root->descend("Globals");
    o->describer = describe_global_variables;
    o->data=roxen->variables;
    o->type = NODE_GLOBAL_VARIABLES;
    build_global_variables( o );

    o=root->descend("Actions");
    o->describer = describe_actions;
    o->data = 0;
    o->type = NODE_WIZARDS;
   
    o=root->descend("Configurations");
    o->describer = describe_configurations;
    o->data = roxen->configurations;
    o->type = NODE_CONFIGURATIONS;
    build_configurations( o );

    o=root->descend("Status");

    object sn;
    o->describer = describe_global_status;
    o->data = 1;

    sn=o->descend("Request");
    sn->describer = describe_request_status;

    sn=o->descend("Process");
    sn->describer = describe_process_status;

    sn=o->descend("Pipe");
    sn->describer = describe_pipe_status;

    sn=o->descend("Strings");
    sn->describer = describe_string_status;

    sn=o->descend("Hosts");
    sn->describer = describe_hostnames_status;

    sn=o->descend("Cache");
    sn->describer = describe_cache_system_status;

    sn=o->descend("Disk");
    sn->describer = describe_disk_cache_system_status;

    sn=o->descend("Files");
    sn->describer = describe_open_files;

    sn=o->descend("Debug");
    sn->describer = describe_global_debug;
  }
}


