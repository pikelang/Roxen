// This is a roxen module. Copyright © 1999 - 2000, Roxen IS.
//
// $Id: config_userdb.pike,v 1.51 2000/08/28 12:22:01 mast Exp $

inherit "module";
#include <config_interface.h>
#include <roxen.h>
#include <module.h>

//<locale-token project="roxen_config"> LOCALE </locale-token>
//<locale-token project="roxen_config"> SLOCALE </locale-token>
USE_DEFERRED_LOCALE;
#define LOCALE(X,Y)	_DEF_LOCALE("roxen_config",X,Y)
#define SLOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)

constant module_type   = MODULE_AUTH | MODULE_FIRST;
constant module_name   = "Configuration UserDB";
constant module_doc    = "This user database keeps the configuration users "
                         "passwords and other settings";
constant module_unique = 1;
constant thread_safe   = 1;

mapping settings_cache = ([ ]);

object settings = roxen.ConfigIFCache( "settings",1 );

class ThemeVariable
{
  inherit Variable.StringChoice;

  string theme_name( string theme )
  {
    catch {
      return String.trim_all_whites(lopen("config_interface/standard/themes/"+
                                          theme+"/name","r")->read());
    };
    return "Unknown theme ("+theme+")";
  }

  static array(string) all_themes( )
  {
    return (get_dir( "config_interface/standard/themes/" ) + 
            (get_dir( "../local/config_interface/standard/themes/" )||({}))-
            ({"CVS","README"}));
  }

  void set_choice_list()
  {
  }

  array get_choice_list()
  {
    return all_themes();
  }

  static string _title( string what )
  {
    return theme_name( what );
  }

  static void create(mixed default_value,int flags,
                     string std_name,string std_doc)
  {
    ::create( default_value,0, flags,std_name, std_doc );
  }
}


class ConfigurationSettings
{
  inherit "basic_defvar";
  string name, host;

  mapping trim_variables( mapping m )
  {
    mapping q = ([]);
    foreach( indices( m ), string v )  q[v] = m[v]->query( );
    return q;
  }

  void save()
  {
#if 0
    werror("Saving settings for "+name+"\n");
#endif
    settings->set( name, trim_variables(variables) );
  }

  void create( string _name )
  {
    name = _name;
    variables = ([]);
    mapping vv = settings->get( name );
    defvar( "theme", ThemeVariable( "default", 0,
                                    "Theme",
                                    "The theme to use" ) );
    defvar( "configlistmode", 0,
            LOCALE( "", "Compact site list" ),
            TYPE_FLAG,
            LOCALE( "", "If true, the list list will be presented in a "
                    "compact format suitable for servers with many sites" ));



    defvar( "docs", 1, LOCALE(174, "Show documentation"),
            TYPE_FLAG, LOCALE(175, "Show the variable documentation."),
            0, 0 );

    defvar( "more_mode", 1, LOCALE(176, "Show advanced configuration options"),
	    TYPE_FLAG, LOCALE(177, "Show all possible configuration options, not only "
			      "the ones that are most often changed."),
	    0, 0 );

    defvar( "translations", 0, LOCALE(178, "Show the incomplete translations"),
            TYPE_FLAG, LOCALE(179, "Show the language selection flags. The translation "
			      "of the configuration interface is not done yet, so this is "
			      "mostly useful for the curious or the translator."),
	    0, 0 );

    defvar( "devel_mode", 1, LOCALE(180, "Show developer options and actions"),
	    TYPE_FLAG, LOCALE(181, "Show settings and actions that are not normaly "
			      "useful for non-developer users. If you develop your own "
			      "roxen modules, this option is for you."),
	    0, 0 );

    defvar( "bgcolor", "white", LOCALE(182, "Background color"),
	    TYPE_STRING, LOCALE(183, "Administration interface background color."),
	    0, 0 );

    defvar( "fgcolor", "black", LOCALE(184, "Text color"),
	    TYPE_STRING, LOCALE(185, "Administration interface text color."),
	    0, 0 );

    defvar( "linkcolor", "darkblue", LOCALE(186, "Link color"),
	    TYPE_STRING, LOCALE(185, "Administration interface text color."),
	    0, 0 );

    defvar( "font", "franklin gothic demi", LOCALE(187, "Font"),
	    TYPE_FONT, LOCALE(188, "Administration interface font."),
	    0, 0 );

    defvar( "addmodulemethod", "normal", LOCALE(189, "Add/Delete module page type"),
            TYPE_STRING_LIST, LOCALE(190, "<dl>\n"
	     "<dt>normal</dt><dd>Show module name and documentation with images.</dd>\n"
	     "<dt>fast</dt><dd>Like normal, but no type images.</dd>\n"
	     "<dt>faster</dt><dd>Like normal, but allows to select multiple modules at once.</dd>\n"
	     "<dt>compact</dt><dd>Only show the names of modules, and allow "
	     "addition/deletion of multiple modules at once.</dd>\n"
	     "<dt>really compact</dt><dd>Like compact, but no module classes.</dd>\n"
	     "</dl>"),
({ "normal","fast","faster","compact","really compact"}),
 0, 
(["svenska":([ "normal":"normal","fast":"snabb","faster":"snabbare","compact":"kompakt","really compact":"kompaktare"]),
 ])
            );

    if( vv )
      foreach( indices( vv ), string i )
        if( variables[i] )
          variables[i]->low_set( vv[i] );
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

void add_permission( string perm, string|mapping text )
{
  if( mappingp( text ) )
  {
    report_warning("Unsupported to call add_permission with a mapping.\n"
                   "Use a LOCALE() string instead\n%s\n", 
                   describe_backtrace( backtrace( ) ) );
    text = [string](text->standard || (values( text )[ 0 ]));
  }
  possible_permissions -= ({ perm });
  possible_permissions += ({ perm });
  permission_translations[ perm ] = [string]text;
}

void create()
{
  add_permission( "Everything", LOCALE(191, "All Permissions"));
  add_permission( "View Settings", LOCALE(192, "View Settings"));
  add_permission( "Edit Users", LOCALE(193, "Edit Users"));
  add_permission( "Edit Global Variables", LOCALE(194, "Edit Global Variables"));
  add_permission( "Edit Module Variables", LOCALE(195, "Edit Module Variables"));
  add_permission( "Tasks", LOCALE(196, "Tasks"));
  add_permission( "Restart", LOCALE(197, "Restart"));
  add_permission( "Shutdown", LOCALE(198, "Shutdown"));
  add_permission( "Create Site", LOCALE(199, "Create Sites"));
  add_permission( "Add Module", LOCALE(200, "Add Modules"));

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
       case "name":
         break;
       case "real_name":
         real_name = id->variables[rp];
         save();
         break;
       case "c_password":
         if( id->variables[rp] != password )
           password = id->variables[rp];
         save();
         break;

       case "password":
         if( strlen( id->variables[rp] ) &&
             (id->variables[rp+"2"] == id->variables[rp]) )
         {
           password = crypt( id->variables[rp] );
           save();
         }
         else if( strlen( id->variables[rp]  ) )
           error = "Passwords does not match";
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
           save();
         }
         else if( sscanf( v, "remove_%s.x", v ) )
         {
           report_notice( "Permission "+v+" removed from "+real_name+
                          " ("+name+") by "+
                          id->misc->config_user->real_name+
                          " ("+id->misc->config_user->name+") from "+
                          id->misc->remote_config_host+"\n");
           permissions[v] = 0;
           save();
         }
         break;
      }
      m_delete( id->variables, rp );
    }
    string set_src =  Roxen.parse_rxml( "<gbutton-url font=&usr.font; width=180 preparse> "+SLOCALE("bA", "Save")+
					" </gbutton-url>", id );
    string form = error+
#"
<table>
<tr valign=\"top\"><td><pre>
   Real name:   <input name='PPPreal_name' value='"+real_name+#"'>
    Password:   <input type='password' name='PPPpassword' value=''>
       Again:   <input type='password' name='PPPpassword2' value=''>
     Crypted:   <input name='PPPc_password' value='"+password+"'>  </pre></td>"
      "<td><img src=\"/internal-roxen-unit\" height=\"5\" /><br />\n\n";

    foreach( possible_permissions, string perm )
    {
      int dim;
      if( perm != "Everything" && permissions->Everything )
        dim = 1;
      if( permissions[ perm ] )
      {
        string s = Roxen.parse_rxml( "<gbutton-url "+(dim?"dim":"")+
				     "    icon_src=/standard/img/selected.gif "
				     "    font=&usr.font; "
				     "    width=180>"+permission_translations[ perm ]+
				     "</gbutton-url>", id );

        form += sprintf( "<input border=0 type=image name='PPPremove_%s'"
                         " src='%s'>\n", perm, s );
      }
      else
      {
        string s = Roxen.parse_rxml( "<gbutton-url "+(dim?"dim":"")+
				     "    icon_src=/standard/img/unselected.gif "
				     "    font=&usr.font; "
				     "    width=180>"+
                                     permission_translations[ perm ]+
				     "</gbutton-url>", id );
        form += sprintf( "<input border=0 type=image name='PPPadd_%s'"
                         " src='%s'>\n", perm, s );
      }
    }
    return replace(form,"PPP",varpath)+
      "<br /><input type='image' border='0' alt=' Set ' value=' Set ' src='"+set_src+"' />"
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
  return map( glob( "*_uid", settings->list()||({}) ),
              lambda( string q ) {
                sscanf( q, "%s_uid", q );
                return q;
              } );
}

array auth( array auth_, RequestID id )
{
  array auth = auth_;
  auth_ = ({ auth[0], "CENSORED:PASSWORD" });

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
  if( (time(1) - logged_in[ u+host ]) > 1800 )
    report_notice(SLOCALE("dt", "Administrator logged on as %s from %s.\n"),
		  u, host+" ("+id->remoteaddr+")" );

  logged_in[ u+host ] = time(1);
  get_context( u, host, id );
}
