// This is a roxen module. Copyright © 1999 - 2000, Roxen IS.
//

#charset iso-2022-jp
inherit "module";
inherit "roxenlib";
#include <config_interface.h>
#include <roxen.h>

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
  inherit "basic_defvar";
  string name, host;

  void save()
  {
    werror("Saving settings for "+name+"\n");
    settings->set( name, variables );
  }

  void create( string _name )
  {
    name = _name;
    variables = settings->get( name ) || ([]);
    defvar( "theme", "default",
            "Theme",  TYPE_THEME, "The theme to use" );

    defvar( "docs", 1,
            ([
              "english":"Show documentation",
              "svenska":"Visa dokumentation",
            ]), TYPE_FLAG,
            ([
              "english":"Show the variable documentation.",
              "svenska":"Visa variabeldokumentationen.",
            ]), 0, 0 );

    defvar( "more_mode", 1,
            ([
              "english":"Show advanced configuration options",
              "svenska":"Visa avancerade val",
            ]), TYPE_FLAG,
            ([ "english":"Show all possible configuration options, not only "
               "the ones that are most often changed.",
               "svenska":"Visa alla konfigureringsval, inte bara de som "
               "oftast ändras."
	    ]), 0, 0 );

    defvar( "devel_mode", 1,
            ([
              "english":"Show developer options and actions",
              "svenska":"Visa utvecklingsval och funktioner",
            ]), TYPE_FLAG,
            ([
              "english":"Show settings and actions that are not normaly "
              "useful for non-developer users. If you develop your own "
              "roxen modules, this option is for you.",
              "svenska":"Visa inställningar och funktioner som normalt "
              "sett inte är intressanta för icke-utvecklare. Om du utvecklar "
              "egna moduler så är det här valet för dig."
            ]), 0, 0 );

    defvar( "bgcolor", "white",
	    ([
	      "english":"Background color",
	      "svenska":"Bakgrundsfärg",
	    ]),TYPE_STRING,
	    ([
	      "english":"Configuration interface background color.",
	      "svenska":"Bakgrundsfärg till konfigurationsgränssnittet."
	    ]), 0, 0 );

    defvar( "fgcolor", "black",
	    ([
	      "english":"Text color",
	      "svenska":"Textfärg",
	    ]),TYPE_STRING,
	    ([
	      "english":"Configuration interface text color.",
	      "svenska":"Textfärg till konfigurationsgränssnittet."
	    ]), 0, 0 );

    defvar( "linkcolor", "darkblue",
	    ([
	      "english":"Link color",
	      "svenska":"Länkfärg",
	    ]),TYPE_STRING,
	    ([
	      "english":"Configuration interface text color.",
	      "svenska":"Textfärg till konfigurationsgränssnittet."
	    ]), 0, 0 );

    defvar( "font", "bastard",
	    ([
	      "english":"Font",
	      "svenska":"Typsnitt",
	    ]),TYPE_FONT,
	    ([
	      "english":"Configuration interface font.",
	      "svenska":"Typsnitt som konfigurationsgränssnittetet ska använda."
	    ]), 0, 0 );

    defvar( "addmodulemethod", "normal",
            ([
              "english":"Add/Delete module page type",
              "svenska":"Typ som addera/ta bort modulsidorna har",
            ]),TYPE_STRING_LIST,
            ([
              "english":
#"<pre>
  normal  - Show module name and documentation with images
  fast    - Like verbose, but no type images
  compact - Only show the names of modules, and allow addition/deletion
            of multiple modules at once
</pre>
",
              "svenska":
#"<pre>
   normal  - Visa modulnamnet, dokumentationen och typbilder
   snabb   - Som den normal, men inga typbilder
   kompakt - Visa bara namnet, och tillåt adderande av flera moduler
             på samma gång
" ]),
({ "normal","fast","compact"}),
(["svenska":([ "normal":"normal","fast":"snabb","compact":"kompakt"]),
 ])
            );
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
  possible_permissions -= ({ perm });
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
                     "nihongo":"$(BK|>l0t5v(B",
                     "standard":"All permissions", ]) );
  add_permission( "View Settings",
                  ([
                    "nihongo":"$(B%j!<%I%*%s%j!<(B",
                    "svenska":"Läsa inställingar",
                  ]));
  add_permission( "Edit Users",
                  ([
                    "nihongo":"$(B%(%G%#%H%f!<%6!<%:(B",
                    "svenska":"Editera användare",
                  ]) );
  add_permission( "Edit Global Variables",
                  ([
                    "nihongo":"$(B%(%G%#%H%0%m!<%P%k(B",
                    "svenska":"Editera globala inställningar"
                  ]));
  add_permission( "Edit Module Variables",
                  ([
                    "nihongo":"$(B%(%G%#%H%"%I%*%s%b%8%e!<%k(B",
                    "svenska":"Editera modulinställingar"
                  ]));
  add_permission( "Tasks",
                  ([
                    "nihongo":"$(BMQ;v(B",
                    "svenska":"Funktioner"
                  ]));
  add_permission( "Restart",
                  ([
                    "nihongo":"$(B%j%9%?!<%H(B",
                    "svenska":"Starta om"
                  ]));
  add_permission( "Shutdown",
                  ([
                    "nihongo":"$(B%7%c%C%H%@%&%s(B",
                    "svenska":"Stäng av"
                  ]));
  add_permission( "Create Site",
                  ([
                    "nihongo":"$(B<yN)%5%$%H(B",
                    "svenska":"Skapa ny site"
                  ]));
  add_permission( "Add Module",
                  ([
                    "nihongo":"$(BIU$1$k%"%I%*%s%b%8%e!<%k(B",
                    "svenska":"Addera moduler"
                  ]));
  if(sizeof(roxen->configuration_perm))
    foreach(indices(roxen->configuration_perm), string perm)
      add_permission(perm, roxen->configuration_perm[perm]);
  roxen->add_configuration_auth(this_object());

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
    string set_src =  parse_rxml( "<gbutton-url font=&usr.font; width=180 preparse> &locale.save; </gbutton-url>", id );
    string form = error+
#"
<table>
<tr valign=top><td><pre>
   Real name:   <input name=PPPreal_name value='"+real_name+#"'>
    Password:   <input type=password name=PPPpassword value=''>
       Again:   <input type=password name=PPPpassword2 value=''>
     Crypted:   <input name=PPPc_password value='"+password+"'>  </pre></td>"
      "<td><img src=\"/internal-roxen-unit\" height=5><br>\n\n";

    foreach( possible_permissions, string perm )
    {
      int dim;
      if( perm != "Everything" && permissions->Everything )
        dim = 1;
      if( permissions[ perm ] )
      {
        string s = parse_rxml( "<gbutton-url "+(dim?"dim":"")+
                               "    icon_src=/standard/img/selected.gif "
                               "    font=&usr.font; "
                               "    width=180>"+translate_perm(perm,id)+
                               "</gbutton-url>", id );

        form += sprintf( "<input border=0 type=image name='PPPremove_%s'"
                         " src='%s'>\n", perm, s );
      }
      else
      {
        string s = parse_rxml( "<gbutton-url "+(dim?"dim":"")+
                               "    icon_src=/standard/img/unselected.gif "
                               "    font=&usr.font; "
                               "    width=180>"+translate_perm(perm,id)+
                               "</gbutton-url>", id );
        form += sprintf( "<input border=0 type=image name='PPPadd_%s'"
                         " src='%s'>\n", perm, s );
      }
    }
    return replace(form,"PPP",varpath)+
      "<br><input type=image border=0 alt=' Set ' value=' Set ' src='"+set_src+"'>"
      "</td></tr></table>";
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

void start()
{
  roxen->add_configuration_auth( this_object() );
}

void stop()
{
  roxen->remove_configuration_auth( this_object() );
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
