#include <confignode.h>
#include <module.h>

object find_module(string s)
{
  int i;
  mixed tmp;
  sscanf(s, "%s#%d", s, i);
  if(tmp=roxen->current_configuration->modules[s])
    if(tmp->copies)
      return tmp->copies[i];
    else
      return tmp->enabled;
}

string module_short_name(object m)
{
  string sn;
  mapping mod;
  int i;
  if(!objectp(m))
    error("module_short_name on non object.\n");

  sn=roxen->current_configuration->otomod[ m ];
  mod=roxen->current_configuration->modules[ sn ];

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

  roxen->current_configuration = o->config(); 

  while(!is_module(module))
    module = module->up;

  if(!module)
    module = this_object()->root;

  if(objectp(module->data))
    module->data->set(o->data[VAR_SHORTNAME], o->data[VAR_VALUE]);
  else if(mappingp(module->data) && module->data->master)
    module->data->master->set(o->data[VAR_SHORTNAME], o->data[VAR_VALUE]);
  else
    roxen->set(o->data[VAR_SHORTNAME], o->data[VAR_VALUE]);
  if(o->changed) o->change(-o->changed);
}


void save_global_variables(object o)
{
  roxen->current_configuration=0;
  roxen->store("Variables", roxen->variables, 0);

  /*  destruct(roxen->main_configuration_port);*/
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
  
  roxen->current_configuration=o->config(); // Needed in store later on. 
  
  roxen->store(s=o->data->sname+"#0", o->data->master->query(), 0);
  o->data->master->start(2);

  roxen->misc_cache = ([]);
  o->config()->unvalidate_cache();

  if(o->changed) o->change(-o->changed);
}

void save_configuration_global_variables(object o)
{
  roxen->current_configuration=o->config();
  roxen->store("spider#0", 
	       roxen->current_configuration->variables, 0);
  if(o->changed) o->change(-o->changed);
  roxen->start(2);
}

void save_configuration(object o)
{
  roxen->current_configuration=o->config();
  if(o->changed) o->change(-o->changed);
  roxen->start(2);
}

void save_module_copy(object o)
{
  string s;
  roxen->current_configuration=o->config();
  s=module_short_name(o->data);

  if(!s) error("Fop fip.\n");

  roxen->misc_cache = ([]);
  roxen->current_configuration->unvalidate_cache();
  
  roxen->store(s, o->data->query(), 0);
  if(o->data->start) o->data->start(2);
  if(o->changed) o->change(-o->changed);
}
