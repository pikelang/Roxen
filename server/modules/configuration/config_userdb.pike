inherit "module";
inherit "roxenlib";
#include <module.h>
#include <roxen.h>
#include <stat.h>

#define LOCALE	LOW_LOCALE->config_interface

constant module_type   = MODULE_AUTH | MODULE_FIRST;
constant module_name   = "Configuration UserDB";
constant module_doc    = "This userdatabase keeps the configuration users"
                         "passwords and other settings";
constant module_unique = 1;
constant thread_safe   = 1;


mapping settings_cache = ([ ]);

object settings = roxen.ConfigIFCache( "settings" );

class ConfigurationSettings
{
  mapping variables = ([ ]);
  string name, host;

  mapping locs = ([]);
  void deflocaledoc( string locale, string variable, 
                     string name, string doc, mapping|void translate)
  {
    if(!locs[locale] )
      locs[locale] = master()->resolv("Locale")["Roxen"][locale]
                   ->register_module_doc;
    if(!locs[locale])
      report_debug("Invalid locale: "+locale+". Ignoring.\n");
    else
      locs[locale]( this_object(), variable, name, doc, translate );
  }

  void set( string what, mixed to  )
  {
    variables[ what ][ VAR_VALUE ] = to;
    remove_call_out( save );
    call_out( save, 0.1 );
  }

  void defvar( string v, mixed val, int type, mapping q, mapping d,
               array misc, mapping translate )
  {
    if( !variables[v] )
    {
      variables[v]                     = allocate( VAR_SIZE );
      variables[v][ VAR_VALUE ]        = val;
    }
    variables[v][ VAR_TYPE ]         = type & VAR_TYPE_MASK;
    variables[v][ VAR_DOC_STR ]      = d->english;
    variables[v][ VAR_NAME ]         = q->english;
    variables[v][ VAR_MISC ]         = misc;
    type &= (VAR_EXPERT | VAR_MORE);
    variables[v][ VAR_CONFIGURABLE ] = type?type:1;
    foreach( indices( q ), string l )
      deflocaledoc( l, v, q[l], d[l], (translate?translate[l]:0));
  }

  mixed query( string what )
  {
    if( variables[ what ] )
      return variables[what][VAR_VALUE];
  }
  
  void save()
  {
    werror("Saving settings for "+name+"\n");
    settings->set( name, variables );
  }

  void create( string _name )
  {
    name = _name;
    variables = settings->get( name ) || ([]);
    defvar( "docs", 1, TYPE_FLAG,
            ([
              "english":"Show documentation",
              "svenska":"Visa dokumentation",
            ]),
            ([
              "english":"Show the variable documentation.",
              "svenska":"Visa variabeldokumentationen.",
            ]),
            0,0 );

    defvar( "more_mode", 0, TYPE_FLAG,
            ([
              "english":"Show advanced configuration options",
              "svenska":"Visa avancerade val",
            ]), 
            ([ "english":"Show all possible configuration options, not only "
               "the ones that are most often changed.",
               "svenska":"Visa alla konfigureringsval, inte bara de som "
               "oftast ändras" ]),
            0, 0 );

    defvar( "devel_mode", 0, TYPE_FLAG,
            ([
              "english":"Show developer options and actions",
              "svenska":"Visa utvecklingsval och funktioner",
            ]),
            ([ 
              "english":"Show settings and actions that are not normaly "
              "useful for non-developer users. If you develop your own "
              "roxen modules, this option is for you",
              "svenska":"Visa inställningar och funktioner som normaly "
              "sätt inte är intressanta för icke-utvecklare. Om du utvecklar "
              "egna moduler så är det här valet för dig"
            ]), 0,0 );
  }
}

void get_context( string ident, string host, object id )
{
  if( settings_cache[ ident ] )
    id->misc->config_settings = settings_cache[ ident ];
  else
    id->misc->config_settings = settings_cache[ ident ] 
                              = ConfigurationSettings( ident );
  id->misc->config_settings->host = host;
}

array possible_permissions = ({ });

mapping permission_translations = ([ ]);

void add_permission( string perm, mapping translations )
{
  possible_permissions += ({ perm });
  if( !translations )
    translations = ([]);
  if( !translations->standard )
    translations->standard = perm;
  permission_translations[ perm ] = translations;
}

string translate_perm( string perm, object id )
{
  return (permission_translations[ perm ][ id->misc->cf_locale ] ||
          permission_translations[ perm ]->standard );
}

void create()
{
  add_permission( "Everything",
                  ([ "svenska":"Alla rättingheter",
                     "standard":"All permissions", ]) );
  add_permission( "View Settings",
                  ([
                    "svenska":"Läsa inställingar",
                  ]));
  add_permission( "Edit Users", 
                  ([
                    "svenska":"Editera användare",
                  ]) );
  add_permission( "Edit Global Variables",
                  ([
                    "svenska":"Editera globala inställningar"
                  ]));
  add_permission( "Edit Module Variables",
                  ([
                    "svenska":"Editera modulinställingar"
                  ]));
  add_permission( "Actions",
                  ([
                    "svenska":"Funktioner"
                  ]));
  add_permission( "Restart",
                  ([
                    "svenska":"Starta om"
                  ]));
  add_permission( "Shutdown",
                  ([
                    "svenska":"Stäng av"
                  ]));
  add_permission( "Create Site",  ([
                    "svenska":"Skapa ny site"
                  ]));
  add_permission( "Add Module",  ([
                    "svenska":"Addera moduler"
                  ]));
}


class User
{
  string name;
  string real_name;
  string password;
  multiset permissions = (<>);
  
  string form( RequestID id )
  {
    string varpath = "config_user_"+name+"_";
    string error = "";
    // Sort is needed (see c_password and password interdepencencies)
    foreach( sort(glob( varpath+"*", indices(id->variables) )), 
             string v )
    {
      string rp = v;
      sscanf( v, varpath+"%s", v );
      switch( v ) 
      {
       case "name": break;
       case "real_name": 
         real_name = id->variables[rp]; 
         save();
         break;
       case "c_password":
         if( id->variables[rp] != password )
           password = id->variables[rp];
         break;

       case "password":  
         if( strlen( id->variables[rp] ) && 
             (id->variables[rp+"2"] == id->variables[rp]) )
           password = crypt( id->variables[rp] );
         else
           error = "Passwords does not match";
         save();
         break;

       default:
         if( sscanf( v, "add_%s.x", v ) )
         {
           report_notice( "Permission "+v+" added to "+real_name+
                          " ("+name+") by "+
                          id->misc->config_user->real_name+
                          " ("+id->misc->config_user->name+") from "+
                          id->misc->remote_config_host+"\n");
           permissions[v] = 1;
         }
         else if( sscanf( v, "remove_%s.x", v ) )
         {
           report_notice( "Permission "+v+" removed from "+real_name+
                          " ("+name+") by "+
                          id->misc->config_user->real_name+
                          " ("+id->misc->config_user->name+") from "+
                          id->misc->remote_config_host+"\n");
           permissions[v] = 0;
         }
         save();
         break;
      }
      m_delete( id->variables, rp );
    }
    string set_src =  parse_rxml( "<gbutton-url> Set </gbutton-url>", id );
    string form = error+
#"
<table>
<tr>
<tr><td><pre>
   Real name:   <input name=PPPreal_name value='"+real_name+#"'>
    Password:   <input type=password name=PPPpassword value=''>
       Again:   <input type=password name=PPPpassword2 value=''>
     Crypted:   <input name=PPPc_password value='"+password+"'> "
           "<input type=image border=0 alt=' Set ' value=' Set ' src='"+set_src+"'></pre></td><td>\n\n";

    foreach( possible_permissions, string perm )
    {
      int dim;
      if( perm != "Everything" && permissions->Everything )
        dim = 1;
      if( permissions[ perm ] )
      {
        string s = parse_rxml( "<gbutton-url "+(dim?"dim":"")+
                               "    icon_src=/standard/img/selected.gif "
                               "    width=180>"+translate_perm(perm,id)+
                               "</gbutton-url>", id );

        form += sprintf( "<input border=0 type=image name='PPPremove_%s'"
                         " src='%s'>\n", perm, s );
      }
      else
      {
        string s = parse_rxml( "<gbutton-url "+(dim?"dim":"")+
                               "    icon_src=/standard/img/unselected.gif "
                               "    width=180>"+translate_perm(perm,id)+
                               "</gbutton-url>", id );
        form += sprintf( "<input border=0 type=image name='PPPadd_%s'"
                         " src='%s'>\n", perm, s );
      }
    }
    return replace(form,"PPP",varpath)+"</tr></tr></table>";
  }

  void restore()
  {
    mapping q = settings->get( name+"_uid" ) || ([]);
    real_name = q->real_name||"";
    password = q->password||crypt("www");
    permissions = mkmultiset( q->permissions||({}) );
  }

  User save()
  {
    settings->set( name+"_uid", ([
      "name":name,
      "real_name":real_name,
      "password":password,
      "permissions":indices(permissions),
    ]));
    return this_object();
  }

  int auth( string operation )
  {
    return permissions[ operation ] || permissions->Everything;
  }

  void create( string n )
  {
    name = n;
    restore( );
  }
}

mapping logged_in = ([]);
mapping admin_users = ([]);

User find_admin_user( string s )
{
  if( admin_users[ s ] )
    return admin_users[ s ];
  if( settings->get( s+"_uid" ) )
    return admin_users[ s ] = User( s );
}

User create_admin_user( string s )
{
  return User( s )->save();
}

void delete_admin_user( string s )
{
  m_delete( admin_users,  s );
  settings->delete( s );
  settings->delete( s+"_uid" );
}

array(string) list_admin_users()
{
  return map( glob( "*_uid", settings->list() ), 
              lambda( string q ) {
                sscanf( q, "%s_uid", q );
                return q;
              } );
}

array auth( array auth, RequestID id )
{
  array arr = auth[1]/":";
  if( sizeof(arr) < 2 )
    return ({ 0, auth[1], -1 });

  string host;

  if( array h = gethostbyaddr( id->remoteaddr ) )
    host = h[0];
  else
    host = id->remoteaddr;

  string u = arr[0];
  string p = arr[1..]*":";

  if( !sizeof( admin_users ) && !sizeof( list_admin_users() ) )
  {
    User q =  create_admin_user( u );
    admin_users[ u ] = q;
    q->permissions["Everything"] = 1;
    q->password = crypt( p );
    q->real_name = "Default User";
    q->save();
  }

  if( find_admin_user( u ) )
  {
    if( !crypt( p, admin_users[ u ]->password ) )
    {
      report_notice( "Failed login attempt %s from %s\n", u, host);
      return ({ 0, u, p });
    }
    id->variables->config_user_uid = u;
    id->variables->config_user_name = admin_users[u]->real_name;
    id->misc->remote_config_host = host;
    id->misc->create_new_config_user = create_admin_user;
    id->misc->delete_old_config_user = delete_admin_user;
    id->misc->list_config_users = list_admin_users;
    id->misc->get_config_user = find_admin_user;
    id->misc->config_user = admin_users[ u ];
    return ({ 1, u, 0 });
  }
  report_notice( "Failed login attempt %s from %s\n", u, host);
  return ({ 0, u, p });
}

void first_try( RequestID id )
{
  string u;
  if( id->misc->config_user )
    u = id->misc->config_user->name;
  else
    return;

  string host;

  if( array h = gethostbyaddr( id->remoteaddr ) )
    host = h[0];
  else
    host = id->remoteaddr;
  if( (time() - logged_in[ u+host ]) > 1800 )
    report_notice(LOW_LOCALE->config_interface->
                  admin_logged_on( u, host+" ("+id->remoteaddr+")" ));

  logged_in[ u+host ] = time();
  get_context( u, host, id );
}
