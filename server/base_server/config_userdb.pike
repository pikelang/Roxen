// Core part of the configuration user database.  Handles creation of
// users and permissions, and verifies users against the database.
inherit "language";

#define IN_ROXEN
#include <config_interface.h>
#include <roxen.h>
#include <module.h>

//<locale-token project="roxen_config"> LOCALE </locale-token>
//<locale-token project="roxen_config"> SLOCALE </locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)
#define SLOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)
string query_configuration_dir();

// Settings used by the various administration interface modules etc.
class ConfigIFCache
{
  string dir;
  int settings;
  private static inherit "newdecode";
  void create( string name, int|void _settings )
  {
    if( settings = _settings )
      dir = query_configuration_dir() + "_configinterface/" + name + "/";
    else
      dir = "../var/"+roxen_version()+"/config_caches/" + name + "/";
    mkdirhier( dir );
  }

  mixed set( string name, mixed to )
  {
    Stdio.File f;
    int mode = 0777;
    if( settings )
      mode = 0770;
    if(!(f=open(  dir + replace( name, "/", "-" ), "wct", mode )))
    {
      mkdirhier( dir+"/foo" );
      if(!(f=open(  dir + replace( name, "/", "-" ), "wct", mode )))
      {
        report_error("Failed to create administration interface cache file ("+
                     dir + replace( name, "/", "-" )+") "+
                     strerror( errno() )+"\n");
        return to;
      }
    }
    if( settings )
      f->write(
#"<?XML version=\"1.0\" encoding=\"UTF-8\"?>
" + string_to_utf8(encode_mixed( to, this_object() ) ));
    else
      f->write( encode_value( to ) );
    return to;
  }

  mixed get( string name )
  {
    Stdio.File f;
    mapping q = ([]);
    f=open( dir + replace( name, "/", "-" ), "r" );
    if(!f) return 0;
    if( settings )
      decode_variable( 0, ([ "name":"res" ]), utf8_to_string(f->read()), q );
    else
    {
      catch{ return decode_value( f->read() ); };
      return 0;
    }
    return q->res;
  }

  array list()
  {
    return r_get_dir( dir );
  }

  void delete( string name )
  {
    r_rm( dir + replace( name, "/", "-" ) );
  }
}


static mapping settings_cache = ([ ]);
static object settings;

class ConfigurationSettings
{
  inherit "basic_defvar";
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
  string name, host;

  mapping trim_variables( mapping m )
  {
    mapping q = ([]);
    foreach( indices( m ), string v )  q[v] = m[v]->query( );
    return q;
  }

  void save()
  {
    settings->set( name, trim_variables(variables) );
  }

  void create( string _name )
  {
    name = _name;
    variables = ([]);
    mapping vv = settings->get( name );

    int theme_can_change_colors( RequestID i, Variable v )
    {
      if( !RXML.get_context() ) return 0;
      if( config_setting2( "can-change-colors" ) ) return 0;
      return 1;
    };

    defvar( "theme", ThemeVariable( "default", 0,
                                    "Theme",
                                    "The theme to use" ) );
    defvar( "configlistmode", 0,
            LOCALE(278, "Compact site list" ),
            TYPE_FLAG,
            LOCALE(279, "If true, the list list will be presented in a "
                    "compact format suitable for servers with many sites." ));

    defvar( "docs", 1, LOCALE(174, "Show documentation"),
            TYPE_FLAG, LOCALE(175, "Show the variable documentation."));

    defvar( "more_mode", 1, LOCALE(176, "Show advanced configuration options"),
	    TYPE_FLAG, 
	    LOCALE(177, "Show all possible configuration options, not only "
		   "the ones that are most often changed."));

    defvar( "translations", 0, LOCALE(178, "Show all translations"),
            TYPE_FLAG, 
	    LOCALE(179, "Show the language selection flags. All translations "
		   "will be listed, more or less completed."));

    defvar( "devel_mode", 1, LOCALE(180, "Show developer options and actions"),
	    TYPE_FLAG, 
	    LOCALE(181, "Show settings and actions that are not normaly "
		   "useful for non-developer users. If you develop your own "
		   "Roxen modules, this option is for you."));

    defvar( "bgcolor", "white", LOCALE(182, "Background color"),
	    TYPE_STRING, 
	    LOCALE(183, "Administration interface background color."))
            ->set_invisibility_check_callback( theme_can_change_colors );

    defvar( "fgcolor", "black", LOCALE(184, "Text color"),
	    TYPE_STRING, LOCALE(185, "Administration interface text color."))
            ->set_invisibility_check_callback( theme_can_change_colors );

    defvar( "linkcolor", "darkblue", LOCALE(186, "Link color"),
	    TYPE_STRING, LOCALE(185, "Administration interface text color."))
            ->set_invisibility_check_callback( theme_can_change_colors );

    defvar( "font", "franklin gothic demi", LOCALE(187, "Font"),
	    TYPE_FONT, LOCALE(188, "Administration interface font."));

    defvar( "addmodulemethod", "normal", 
	    LOCALE(189, "Add/Delete module page type"),
            TYPE_STRING_LIST, 
	    ("<dl>\n<dt>"+LOCALE(280, "normal")+"</dt><dd>"+
	     LOCALE(281,"Show module name and documentation with images.")+
	     "</dd>\n<dt>"+LOCALE(282, "fast")+"</dt><dd>"+
	     LOCALE(283,"Like normal, but no type images.")+
	     "</dd>\n<dt>"+LOCALE(284,"faster")+"</dt><dd>"+
	     LOCALE(285, "Like normal, but allows selecting multiple modules "
		    "at once.")+
	     "</dd>\n<dt>"+LOCALE(286,"compact")+"</dt><dd>"+
	     LOCALE(287,"Only show the names of modules, and allow "
		    "addition/deletion of multiple modules at once.")+
	     "</dd>\n<dt>"+LOCALE(288,"really compact")+"</dt><dd>"+
	     LOCALE(289,"Like compact, but no module classes.")+"</dd>\n</dl>"),
	    ([ "normal":LOCALE(280, "normal"), "fast":LOCALE(282, "fast"),
	       "faster":LOCALE(284, "faster"), "compact":LOCALE(286, "compact"),
	       "really compact":LOCALE(288, "really compact")  ]));

    if( vv )
      foreach( indices( vv ), string i )
        if( variables[i] )
          variables[i]->low_set( vv[i] );
  }
}

void adminrequest_get_context( string ident, string host, object id )
{
  if( settings_cache[ ident ] )
    id->misc->config_settings = settings_cache[ ident ];
  else
    id->misc->config_settings = settings_cache[ ident ]
                              = ConfigurationSettings( ident );
  id->misc->config_settings->host = host;
}


class AdminUser
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
    string set_src =  Roxen.parse_rxml( "<gbutton-url width=120 talign=center font=&usr.font; preparse> "+SLOCALE("bA", "Save")+
					" </gbutton-url>", id );
    string form = error+
#"
<table>
<tr valign=\"top\"><td><pre>
   Real name:   <input name='PPPreal_name' value='"+real_name+#"'>
    Password:   <input type='password' name='PPPpassword' value=''>
       Again:   <input type='password' name='PPPpassword2' value=''>
     Crypted:   <input name='PPPc_password' value='"+password+#"'>  
                <input type='image' border='0' alt=' Set ' value=' Set ' src='"+
       set_src+"' />"
      +"</pre></td>"
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
      "</td></tr></table>";
  }

  void restore()
  {
    mapping q = settings->get( name+"_uid" ) || ([]);
    real_name = q->real_name||"";
    password = q->password||crypt("www");
    permissions = mkmultiset( q->permissions||({}) );
  }

  AdminUser save()
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

  int valid_id( RequestID id )
  {
    if(!id->realauth)
      return 0;
    array auth = id->realauth/":";
    if( sizeof(auth) < 2 )            return 0;
    if( auth[0] != name )             return 0;
    if( crypt( auth[1], password ) )  return 1;
  }

  void create( string n )
  {
    name = n;
    restore( );
  }
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

void init_configuserdb()
{
  settings = ConfigIFCache( "settings",1 );
  add_constant( "AdminUser", AdminUser );
  add_permission( "Everything", LOCALE(191, "All Permissions"));
}

// cache
static mapping(string:AdminUser) admin_users = ([]);

AdminUser find_admin_user( string s )
{
  if( admin_users[ s ] )
    return admin_users[ s ];
  if( settings->get( s+"_uid" ) )
    return admin_users[ s ] = AdminUser( s );
}

AdminUser create_admin_user( string s )
{
  return AdminUser( s )->save( );
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


/* compatibility and convenience functions */
string configuration_authenticate(RequestID id, string what, void|int silent)
{
  array a = map( list_admin_users(), find_admin_user ) - ({ 0 });
  foreach( a, AdminUser u )
    if( u->valid_id( id ) && u->auth( what ) )
      return u->name;
  return 0;
}

array(AdminUser) get_config_users( string uname )
{
  return ({ find_admin_user( uname ) })-({ 0 });
}

array(string|object) list_config_users(string uname, string|void required_auth)
{
  array users = list_admin_users( );
  if( !required_auth )
    return users;

  array res = ({ });
  foreach( users, string q )
    if( AdminUser u = find_admin_user( q ))
      if( u->auth( required_auth ) )
        res += ({ u });
  return res;
}
