#include <module.h>
#include <roxen.h>
//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)

constant modules = ({});

constant silent_modules = ({}); 
//! Silent modules does not get their initial variables shown.

string initial_form( RequestID id )
{
  Configuration conf = id->misc->new_configuration;
  id->variables->initial = 1;
  string res = "";
  foreach( modules, string mod )
  {
    ModuleInfo mi = roxen.find_module( mod );
    if(mi)
    {
      RoxenModule moo = conf->find_module( mod );
      foreach( indices(moo->query()), string v )
      {
	if( moo->getvar( v )->get_flags() & VAR_INITIAL )
	{
	  res += 
	    "<tr><td colspan='3'><h2>"
	    +LOCALE("","Initial variables for ")+
	    mi->get_name()+"</h2></td></tr>"
	    "<emit source=module-variables configuration=\""+conf->name+"\""
	    " module=\""+mod+#"\">
 <tr><td width='50'></td><td width=20%><b>&_.name;</b></td><td><eval>&_.form:none;</eval></td></tr>
 <tr><td></td><td colspan=2>&_.doc:none;<p>&_.type_hint;</td></tr>
</emit>";
	  break;
	}
      }
    }
  }
  return res;
}

int form_is_ok( RequestID id )
{
  Configuration conf = id->misc->new_configuration;
  foreach( modules, string mod )
  {
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

  foreach( modules, string mod ) 
  {
    RoxenModule module;
    
    if( !conf->find_module( mod ) && (module = conf->enable_module( mod, 0, 0, 1 )))
    {
      conf->call_low_start_callbacks( module, 
				      roxen.find_module( mod ), 
				      conf->modules[ mod ] );
    }
    remove_call_out( roxen.really_save_it );
  }

  string cf_form = 
    "<emit source=config-variables configuration='"+conf->name+"'>"
    "  <tr><td width='50'></td><td width=20%><b>&_.name;</b></td>"
    "      <td><eval>&_.form:none;</eval></td></tr>"
    "  <tr><td></td><td colspan=2>&_.doc:none;<p>&_.type_hint;</td></tr>"
    "</emit>";
  
  // set initial variables from form variables...
  Roxen.parse_rxml( cf_form, id );
  Roxen.parse_rxml( initial_form( id ), id );
  
  if( id->variables["ok.x"] && form_is_ok( id ) )
  {
    conf->set( "MyWorldLocation", Roxen.get_world(conf->query("URLs"))||"");
    foreach( modules, string mod )
    {
      RoxenModule module = conf->find_module( mod );
      if(module)
	conf->call_start_callbacks( module,
				    roxen.find_module( mod ),
				    conf->modules[ mod ] );
    }
    
    foreach( silent_modules, string mod )
      conf->enable_module( mod );
    
    conf->add_parse_module( conf );
    foreach( conf->after_init_hooks, function q )
      catch(q( conf ));
    conf->after_init_hooks = ({});
    conf->inited = 1;
    conf->start( 0 );
    conf->save( ); // save it all in one go
    return "<done/>";
  }
  return "<h2>"+
         LOCALE("","Initial variables for the site")+
         "</h2><table>" + cf_form + initial_form( id ) + 
         "</table><p>"+
         ((opt||([]))->no_ok?"":"<cf-ok />");
}
