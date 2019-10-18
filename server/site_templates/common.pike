#include <module.h>
#include <roxen.h>
//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)

//! @decl optional array(string) modules = ({});
//!
//! Modules to include in the configuration. Any @tt{VAR_INITIAL@}
//! variables in them get shown in the wizard to be set by the user.
//!
//! Use "!" as separator for multiple module copies in this array,
//! e.g. "filesystem!1".

//! @decl optional array(string) silent_modules = ({});
//!
//! Silent modules do not get their @tt{VAR_INITIAL@} variables shown.
//!
//! In this array the normal "#" separator is used in module copy
//! specs, e.g. "filesystem#1".

int unlocked(License.Key license)
{
  foreach(this->modules || ({}), string module)
    if(!license->is_module_unlocked((module / "!")[0]))
       return 0;
  return 1;
}

object load_modules(Configuration conf)
{
#ifdef THREADS
  Thread.MutexKey enable_modules_lock = conf->enable_modules_mutex->lock();
#else
  object enable_modules_lock;
#endif
  
  // The stuff below ought to be in configuration.pike and not here;
  // we have to meddle with locks and stuff that should be internal.

  foreach( this->modules || ({}), string mod )
  {
    mod = replace (mod, "!", "#");
    RoxenModule module;

    // Enable the module but do not call start or save in the
    // configuration. Call start manually.
    if( !conf->find_module( mod ) &&
	(module = conf->enable_module( mod, 0, 0, 1, 1 )))
    {
      conf->call_low_start_callbacks( module, 
				      roxen.find_module( mod ), 
				      conf->modules[ mod ] );
    }
  }
  return enable_modules_lock;
}

void init_module (Configuration conf, RoxenModule mod, RequestID id);
//! Called in each newly added module just before
//! @[RoxenModule.start].
//!
//! This is suitable to configure initial values for the module
//! variables. In that case you should probably use
//! @expr{mod->low_set@} to bypass the module checks, since the module
//! hasn't been properly initialized yet.

void init_modules(Configuration conf, RequestID id);
//! Called after all modules have been enabled but before their
//! variables are saved.
//!
//! This function is not the right place to initialize module
//! variables, since it is called after the first call to the
//! @[RoxenModule.start] functions. Use @[init_module] for that
//! instead.

protected class PreStartCb (RequestID id)
{
  void pre_start_cb (RoxenModule mod, int save_vars,
		     Configuration conf, int newly_added)
  {
    init_module (conf, mod, id);
  }
}

string initial_form( Configuration conf, RequestID id, int setonly )
{
  id->variables->initial = "1";
  id->real_variables->initial = ({ "1" });

  string res = "";
  int num;

  foreach( this->modules || ({}), string mod )
  {
    ModuleInfo mi = roxen.find_module( (mod/"!")[0] );
    RoxenModule moo = conf->find_module( replace(mod,"!","#") );
    foreach( indices(moo->query()), string v )
    {
      if(moo->getvar( v )->check_visibility(id, 1, 0, 0, 1, 1))
      {
        num++;
        res += "<tr><td colspan='3'><h2>"
        +LOCALE(1,"Initial variables for ")+
            Roxen.html_encode_string(mi->get_name())+"</h2></td></tr>"
        "<emit source='module-variables' "
	  " configuration=\""+conf->name+"\""
	  " module=\""+mod+#"\"/>";
	if( !setonly )
	  res += 
        "<emit noset='1' source='module-variables' "
	  " configuration=\""+conf->name+"\""
        " module=\""+mod+#"\">
 <tr>
 <td width='150' valign='top' colspan='2'><b>&_.name;</b></td>
 <td valign='top'><eval>&_.form:none;</eval></td></tr>
 <tr>
<td width='30'><img src='/internal-roxen-unit' width=50 height=1 alt='' /></td>
  <td colspan=2>&_.doc:none;</td></tr>
 <tr><td colspan='3'><img src='/internal-roxen-unit' height='18' /></td></tr>
</emit>";
        break;
      }
    }
  }
  return res;
}

int form_is_ok( RequestID id )
{
  Configuration conf = id->misc->new_configuration;
  foreach( this->modules || ({}), string mod )
  {
    mod = replace (mod, "!", "#");
    ModuleInfo mi = roxen.find_module( mod );
    if( mi )
    {
      RoxenModule moo = conf->find_module( mod );
      if( moo )
      {
        foreach( indices(moo->query()), string v )
        {
          Variable.Variable va = moo->getvar( v );
          if( va->get_warnings() )
            return 0;
        }
      }
    }
  }
  foreach( indices( conf->query() ), string v )
  {
    Variable.Variable va = conf->getvar( v );
    if( va->get_warnings() )
      return 0;
  }
  return 1;
}

mixed parse( RequestID id, mapping|void opt )
{
  Configuration conf = id->misc->new_configuration;
  id->misc->do_not_goto = 1;  

  // Load initial modules
  object enable_modules_lock = load_modules(conf);
  
  string cf_form = 
    "<emit noset='1' source=config-variables configuration='"+conf->name+"'>"
    "  <tr><td colspan=2 valign=top width=20%><b>&_.name;</b></td>"
    "      <td valign=top><eval>&_.form:none;</eval></td></tr>"
    "  <tr><td></td><td colspan=2>&_.doc:none;<p>&_.type_hint;</td></tr>"
    "  <tr><td colspan='3'><img src='/internal-roxen-unit' height='18' /></td></tr>"
    "</emit>";
  
  // set initial variables from form variables...
  Roxen.parse_rxml("<emit source=config-variables configuration='"+
		   conf->name+"'/>", id );
  Roxen.parse_rxml( initial_form( conf, id, 1 ), id );
  
  if( id->variables["ok.x"] && form_is_ok( id ) )
  {
    conf->set( "MyWorldLocation", Roxen.get_world(conf->query("URLs"))||"");

    PreStartCb psc;
    if (init_module) {
      psc = PreStartCb (id);
      conf->add_module_pre_callback (0, "start", psc->pre_start_cb);
    }

    foreach( this->modules || ({}), string mod )
    {
      mod = replace (mod, "!", "#");
      RoxenModule module = conf->find_module( mod );
      if(module) {
        // Configuration->call_low_start_callbacks() already called from
        // load_modules() (that we called above). This fix solves EP-1502.
	conf->call_high_start_callbacks( module,
				    roxen.find_module( mod ),
				    1);
      }
    }
    
    License.Key key = conf->getvar("license")->get_key();
    foreach( this->silent_modules || ({}), string mod )
    {
      // If the module list doesn't explicitly state that more than
      // one module copy is wanted then avoid it.
      if (!has_value (mod, "#")) mod += "#0";
      if (conf->enabled_modules[mod])
	continue;

      ModuleInfo module = roxen.find_module(mod);
      if(module->locked && (!key || !module->unlocked(key)) ) {
	report_debug("Ignoring module "+mod+", disabled in license.\n");
	continue;
      }
      conf->enable_module( mod );
    }

    if (psc)
      destruct (psc);

    if (init_modules)
      init_modules( conf, id );

    conf->fix_no_delayed_load_flag();
    conf->save (1); // Call start callbacks and save it all in one go.
    conf->low_init (1); // Handle the init hooks.
    conf->forcibly_added = ([]);
    return "<done/>";
  }
  return
    "<h2>"+LOCALE(190,"Initial variables for the site")+"</h2>"
    "<table>" + cf_form + initial_form( conf, id, 0 ) + 
         ((opt||([]))->no_end_table?"":"</table><p>")+
         ((opt||([]))->no_ok?"":"<p align=right><cf-ok /></p>");
}
