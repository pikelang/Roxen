/* $Id: savers.pike,v 1.4 1997/05/31 22:01:21 grubba Exp $ */
#include <confignode.h>
#include <module.h>

string module_short_name(object m, object cf)
{
  string sn;
  mapping mod;
  int i;
  if(!objectp(m))
    error("module_short_name on non object.\n");

  sn=cf->otomod[ m ];
  mod=cf->modules[ sn ];

  if(!mod) error("No such module!\n");

  if(!mod->copies) return sn+"#0";

  if((i=search(mod->copies, m)) >= 0)
    return sn+"#"+i;

  error("Module not found.\n");
}

inline int is_module(object node)
{
  if(!node) return 1;
  switch(node->type)
  {
   case NODE_MODULE_COPY:
   case NODE_MODULE_MASTER_COPY:
    return 1;
  }
}

void save_module_variable(object o)
{
  object module;
  
  module = o;

  while(!is_module(module))
    module = module->up;

  if(!module)
    module = this_object()->root;

  if(objectp(module->data))
    module->data->set(o->data[VAR_SHORTNAME], o->data[VAR_VALUE]);
  else if(mappingp(module->data) && module->data->master)
    module->data->master->set(o->data[VAR_SHORTNAME], o->data[VAR_VALUE]);
  else if(o->config())
    o->config()->set(o->data[VAR_SHORTNAME], o->data[VAR_VALUE]);
  else
    roxen->set(o->data[VAR_SHORTNAME], o->data[VAR_VALUE]);
      
  if(o->changed) o->change(-o->changed);
}


void save_global_variables(object o)
{
  roxen->store("Variables", roxen->variables, 0, 0);
  roxen->initiate_configuration_port();
  roxen->set_u_and_gid();
  init_logger();
  roxen->initiate_supports();
  roxen->reinit_garber();
  if(o->changed) o->change(-o->changed);
}

void save_module_master_copy(object o)
{
  string s;
  object n;
  
  roxen->store(s=o->data->sname+"#0", o->data->master->query(), 0, o->config());
  o->data->master->start(2);
  o->config()->unvalidate_cache();
  if(o->changed) o->change(-o->changed);
}

void save_configuration_global_variables(object o)
{
  roxen->store("spider#0", o->config()->variables, 0, o->config());
  if(o->changed) o->change(-o->changed);
  o->config()->start(2);
}

void save_configuration(object o)
{
  if(o->changed) o->change(-o->changed);
//o->config()->start(2);
}

void save_module_copy(object o)
{
  string s;
  object cf;
  s=module_short_name(o->data, cf=o->config());

  if(!s) error("Fop fip.\n");

  cf->unvalidate_cache();
  
  roxen->store(s, o->data->query(), 0, cf);
  if(o->data->start) o->data->start(2);
  if(o->changed) o->change(-o->changed);
}
