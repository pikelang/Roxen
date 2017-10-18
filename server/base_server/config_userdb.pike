// This file is part of Roxen WebServer.
// Copyright © 2000 - 2009, Roxen IS.
//
// Core part of the configuration user database.  Handles creation of
// users and permissions, and verifies users against the database.
inherit "language";

#define IN_ROXEN
#include <config_interface.h>
#include <roxen.h>
#include <module.h>

//<locale-token project="roxen_config"> LOCALE </locale-token>
//<locale-token project="roxen_config"> SLOCALE </locale-token>
#define LOCALE(X,Y)	_DEF_LOCALE("roxen_config",X,Y)
#define SLOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)
string query_configuration_dir();

// Settings used by the various administration interface modules etc.
class ConfigIFCache
{
  string dir;
  function db;
  private inherit "newdecode";

  mixed query( string what, mixed ... args )
  {
    return db("local")->query( what, @args );
  }
  
  void create( string name, int|void _settings )
  {
    if( _settings )
    {
      dir = query_configuration_dir() + "_configinterface/" + name + "/";
      mkdirhier( dir );
    }
    else
    {
      dir = name;
      db = master()->resolv("DBManager.cached_get");
      query( "create table if not exists "+name+" ("
	     "  id varchar(80) not null primary key,"
	     "  data blob not null default ''"
	     ")" );
      switch( name )
      {
	case "settings":
	  master()->resolv("DBManager.is_module_table")
	    (0, "local", name, "Settings for configuration user interface");
	  break;
	case "modules":
	  master()->resolv("DBManager.is_module_table")
	    (0, "local", name, "Module information cache");
	  master()->resolv("DBManager.inhibit_backups")("local", name);
	  break;
	default:
	  master()->resolv("DBManager.is_module_table")
	    (0, "local", name, "Settings");
	  break;
      }
    }
  }

  mixed set( string name, mixed to )
  {
    if( db )
    {
      query("REPLACE INTO "+dir+" VALUES (%s,%s)", name, encode_value(to));
      return to;
    }

    Stdio.File f;
    int mode = 0770;
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
    f->write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
	     "<roxen-config>\n" +
             string_to_utf8(encode_mixed( to, this_object() ) ) +
	     "</roxen-config>\n");
    return to;
  }

  mixed get( string name )
  {
    if( db )
      if( catch {
        return decode_value( query( "SELECT data  FROM "+dir+
                                        " where id=%s",name)[0]->data );
      })
        return 0;

    Stdio.File f;
    mapping q = ([]);
    f=open( dir + replace( name, "/", "-" ), "r" );
    if(!f) return 0;
    decode_variable( 0, ([ "name":"res" ]), utf8_to_string(f->read()), q );
    return q->res;
  }

  array list()
  {
    if( db )
      return query( "SELECT id from "+dir )->id;
    return r_get_dir( dir );
  }

  void delete( string name )
  {
    if( db )
      query("DELETE FROM "+dir+" WHERE id=%s",name);
    else
      r_rm( dir + replace( name, "/", "-" ) );
  }
}


protected mapping settings_cache = ([ ]);
ConfigIFCache config_settings;
ConfigIFCache config_settings2;

class ConfigurationSettings
{
  inherit "basic_defvar";
  class ThemeVariable
  {
    inherit Variable.StringChoice;

    string theme_name( string theme )
    {
      catch {
        return String.trim_all_whites(lopen("config_interface/themes/"+
                                            theme+"/name","r")->read());
      };
      return "Unknown theme ("+theme+")";
    }

    protected array(string) all_themes( )
    {
      return filter((get_dir( "config_interface/themes/" ) + 
		     (get_dir( "../local/config_interface/themes/" )||({}))-
		     ({"CVS","README",".distignore",".cvsignore"})),
		    lambda(string theme) {
		      catch {
			return lopen("config_interface/themes/"+theme+"/name",
				     "r")->read() != "";
		      };
		      return 0;
		    });
    }

    mixed set( string nv )
    {
      // Support disappearing themes.
      if( has_value( all_themes(), nv ) )
	return ::set( nv );
      report_warning((string)LOCALE(384, "Warning: The theme %s "
			    " no longer exists, using default.\n"),nv);
      return ::set( "default" );
    }
    
    void set_choice_list()
    {
    }

    array get_choice_list()
    {
      return all_themes();
    }

    protected string _title( string what )
    {
      return theme_name( what );
    }

    protected void create(mixed default_value,int flags,
			  string std_name,string std_doc)
    {
      ::create( default_value,0, flags,std_name, std_doc );
    }
  }
  string name, host;

  mapping trim_variables( mapping m )
  {
    mapping q = (config_settings2->get( name ) || ([]));
    foreach( indices( m ), string v )  q[v] = m[v]->query( );
    return q;
  }

  void save()
  {
    config_settings2->set( name, trim_variables(variables) );
  }

  protected string _sprintf()
  {
    return sprintf("ConfigSettings( %O )", name );
  }

  void restore()
  {
    mapping vv = config_settings2->get( name );
    if( vv ) 
      foreach( indices( vv ), string i )
        if( variables[ i ] )
          variables[ i ]->set( vv[i] );
  }

  class BoxVariable
  {
    inherit Variable.Variable;
    constant type = "ContentBoxes";
    protected string box_type;

#define BDIR "config_interface/boxes/"
    protected mapping bdata = ([]);
    array possible( )
    {
      class Box
      {
	constant box = "box";
	LocaleString box_name;
	LocaleString box_doc;
	int box_initial;
      };
      foreach( glob("*.pike", get_dir( BDIR ) ), string f )
      {
        catch
        {
          Box box = (object)(BDIR+f);
	  roxenloader->dump( BDIR+f, object_program(box) );
          if( box->box && box->box == box_type )
            bdata[ (f/".")[0] ] = ([ "name":box->box_name,
                                     "doc":box->box_doc,
                                     "initial":box->box_initial ]);
        };
      }
      foreach( glob("*.xml", get_dir( BDIR ) ), string f )
      {
	foreach( Roxen.parse_box_xml( BDIR+f ), Box box )
	{
          if( box->box && box->box == box_type )
            bdata[ (f/".")[0]+":"+box->ident ] =
	      ([
		"name":box->box_name,
		"doc":box->box_doc,
		"initial":box->box_initial
	      ]);
        }
      }
      array i = indices( bdata );
      array b = map( i, lambda( string q ){ return (string)bdata[q]->name; } );
      sort( b, i );
      return i;
    }

    protected void create( LocaleString name, LocaleString doc,
			   string _type, int|void flags  )
    {
      box_type = _type;
      _initial = ({});
      foreach( sort( possible() ), string q )
        if( bdata[q]->initial  )
          _initial += ({ q });
      __name = name;
      __doc = doc;
      set_flags( flags );
    }

    protected string short_describe_box( string box )
    {
      if( !bdata[box] )  possible();
      if( !bdata[box] )
        return sprintf((string)LOCALE(283,"Unknown box %s"),box);
      return (string)bdata[box]->name;
    }

    string render_view( RequestID id )
    {
      return map(map( query(), short_describe_box ),Roxen.html_encode_string)
             *" <br />";
    }

    void set_from_form( RequestID id )
    {
      mapping vl = get_form_vars( id );
      if( vl[""] )
      {
        array ok = ({});
        foreach( indices( vl ), string v )
          if( bdata[v[1..]] )
            ok+= ({v[1..]});
        set( sort( ok ) );
      }
    }

    protected string describe_box( string b, string ea )
    {
      mapping bd = bdata[b];
      if( bd )
        return "<dt><input type='checkbox'"+ea+" name='"+path()+"."+b+"'> <b>"+
               bd->name+"</b></dt><dd>"+bd->doc+"</dd>";
      return "";
    }
    
    string render_form( RequestID id, void|mapping additional_args )
    {
      multiset has = (multiset)query();
      string res = ("<input type=hidden name='"+
                    path()+"' value='Go, Gadget, go!' />");
      foreach( possible(), string b )
        if( has[b] )
          res += describe_box( b, " checked=''" )+"\n";
        else
          res += describe_box( b, "" )+"\n";
      return "<dl>"+res+"</dl>";
    }
  }

  protected void create( string _name )
  {
    name = _name;
    variables = ([]);

    int theme_can_change_colors( RequestID i, Variable.Variable v )
    {
      if( !RXML.get_context() ) return 0;
      if( config_setting2( "can-change-colors" ) ) return 0;
      return 1;
    };

    defvar( "left_boxes",
            BoxVariable( LOCALE(285,"Large Content Boxes"),
                         LOCALE(287,"Content boxes on the Startpage"),
                         "large" ) );

    defvar( "right_boxes",
            BoxVariable( LOCALE(289,"Small Content Boxes"),
                         LOCALE(287,"Content boxes on the Startpage"),
                         "small" ) );

    defvar( "theme", ThemeVariable( "default", 0,
                                    LOCALE(327,"Theme"),
                                    LOCALE(343,"The theme to use") ) );

    defvar( "form-font-size", -1, LOCALE(167,"Form font size"),
	    TYPE_INT_LIST,
	    LOCALE(178,"The fontsize of the variables in the "
		   "configuration interface"),
	    ({ -2, -1, 0, 1, 2, }) );

    defvar( "docs-font-size", -1, LOCALE(179,"Documentation font size"),
	    TYPE_INT_LIST,
	    LOCALE(193,"The fontsize of the documentation in the "
		   "configuration interface"),
	    ({ -2, -1, 0, 1, 2, }) );

    mixed listmode_var =
    defvar( "modulelistmode", "uf",
	    LOCALE(14,"Module list mode"),
	    TYPE_STRING_LIST,
	    LOCALE(15,"The module list mode. One of "
		   "<dl>"
		   "<dt>Folded</dt><dd>Modules in the same group are folded</dd>"
		   "<dt>Folded with JavaScript Popup</dt><dd>Like Folded, but when you "
		   "move the mouse over a folded group, a menu with the folded "
		   "modules will popup</dd>"
		   "<dt>Unfolded</dt><dd>Like the 'old' Roxen 2.1 list</dd>"
		   "</dl>"),
	    ([
	      "js": LOCALE(17,"Folded with JavaScript popup"),
	      "fl": LOCALE(122,"Folded"),
	      "uf": LOCALE(123,"Unfolded (Old style)"),
	    ]) );
    listmode_var->set_choice_list( ({ "fl", "js", "uf" }) );

    defvar( "moduletab", "Status",
	    LOCALE(85,"Default module tab"),
	    TYPE_STRING_LIST,
	    LOCALE(162,"The tab that will be selected by default when you "
		   "select a module."),
	    ([
	      "Status":LOCALE(228,"Status"),
	      "Settings":LOCALE(256,"Settings"),
	    ]) );

    defvar( "configlistmode", 0,
            LOCALE(278, "Compact site list" ),
            TYPE_FLAG,
            LOCALE(279, "If true, the list of sites will be presented in a "
                    "compact format suitable for servers with many sites." ));

    defvar( "charset", "utf-8", 
            LOCALE(229,"Page charset"),
            TYPE_STRING_LIST,
            LOCALE(230,"The charset to use when rendering configuration "
                   "interface pages."),
            ({
              "utf-8",
              "iso-2022-jp",
              "iso-2022",
              "iso-8859-1",
              "iso-8859-2",
	      "iso-8859-3",
	      "iso-8859-4",
	      "iso-8859-5",
	      "iso-8859-6",
	      "iso-8859-7",
	      "iso-8859-8",
// 	      "iso646-se",
            }));

    mixed sort_var =
    defvar( "sortorder", "as defined",
	    LOCALE(236, "Default variable sort order"), TYPE_STRING_LIST,
	    LOCALE(237, "The default order variables are sorted in" ),
	    ([
	      "alphabetical" : LOCALE(238,"Alphabetical"),
	      "as defined"   : LOCALE(239,"As defined"),
	      "changed/alphabetical" : LOCALE(240,"Alphabetical, changed first"),
	      "changed/as defined"   : LOCALE(241,"As defined, changed first"),
	    ]) );
    sort_var->set_choice_list( ({ "as defined",
				  "changed/as defined",
				  "alphabetical",
				  "changed/alphabetical" }) );

    defvar( "changemark", "color",
	    LOCALE(242, "Changed variables are highlighted"),
	    TYPE_STRING_LIST,
	    LOCALE(243, "How to highlight variables that does not have "
		   "their default value" ),
	    ([
	      "not"   :LOCALE(244, "Not at all"),
	      "color" :LOCALE(268, "Different background color"),
	      "header":LOCALE(302, "Add a header")
	    ]) );

    defvar( "docs", 1, LOCALE(174, "Show documentation"),
            TYPE_FLAG, LOCALE(175, "Show the variable documentation."));

    defvar( "more_mode", 1, LOCALE(176, "Show advanced configuration options"),
	    TYPE_FLAG, 
	    LOCALE(177, "Show all possible configuration options, not only "
		   "the ones that are most often changed."));

//     defvar( "translations", 0, LOCALE(178, "Show all translations"),
//             TYPE_FLAG, 
// 	    LOCALE(179, "Show the language selection flags. All translations "
// 		   "will be listed, more or less completed."));

  defvar("locale",
	 Variable.Language("Standard", ({ "Standard" }) +
			   Locale.list_languages("roxen_config"),
			   0, LOCALE(5, "Interface language"), 
			   LOCALE(19, "Select the Administration interface "
				  "language.")))
    ->set_changed_callback( lambda(Variable.Variable s) {
			      roxenp()->set_locale();
			    } );


    defvar( "devel_mode", 0, LOCALE(180, "Show developer options and actions"),
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

    defvar( "font", "roxen builtin", LOCALE(187, "Font"),
	    TYPE_FONT, LOCALE(188, "Administration interface font."));

    defvar( "group_tasks", 1, LOCALE(303,"Group Tasks"),
	    TYPE_FLAG, LOCALE( 304, "If true, tasks are grouped acording to "
			       "type, otherwise all tasks will be listed on "
			       "one page") );

    mixed method_var =
    defvar( "addmodulemethod", "normal", 
	    LOCALE(189, "Add/Delete module page type"),
            TYPE_STRING_LIST, 
	    LOCALE(153, "<dl>\n<dt>Normal</dt><dd>"
		   "Show module name and documentation with images."
		   "</dd>\n<dt>Fast</dt><dd>"
		   "Like Normal, but no type images."
		   "</dd>\n<dt>Faster</dt><dd>"
		   "Like Normal, but allows selecting multiple modules "
		    "at once."
		   "</dd>\n<dt>Compact</dt><dd>"
		   "Only show the names of modules, and allow "
		   "addition/deletion of multiple modules at once."
		   "</dd>\n<dt>Really compact</dt><dd>"
		   "Like Compact, but no module classes.</dd>\n</dl>"),
	    ([ "normal"         : LOCALE(280, "Normal"),
	       "fast"           : LOCALE(282, "Fast"),
	       "faster"         : LOCALE(284, "Faster"),
	       "compact"        : LOCALE(286, "Compact"),
	       "really compact" : LOCALE(288, "Really compact")  ]));
    method_var->set_choice_list( ({ "normal", "fast", "faster",
				    "compact", "really compact" }) );

    restore( );
  }
}

void adminrequest_get_context( string ident, string host, RequestID id )
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
  ConfigurationSettings settings;

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
           password = crypt_password( id->variables[rp] );
           save();
         }
         else if( strlen( id->variables[rp]  ) )
           error = "Passwords do not match";
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
    string set_src =  Roxen.parse_rxml( "<gbutton-url width=120 talign=center "
					"preparse> "+
					SLOCALE("bA", "Save")+
					" </gbutton-url>", id );
    string form = error+
#"
<table>
<tr valign=\"top\"><td>
  <table>
   <tr><td align='right'><nobr>Real name:</nobr></td><td><input name='PPPreal_name' value='"+real_name+#"'></td></tr>
   <tr><td align='right'>Password:</td><td><input type='password' name='PPPpassword' value=''></td></tr>
   <tr><td align='right'>Again:</td><td><input type='password' name='PPPpassword2' value=''></td></tr>
   <tr><td align='right'>Crypted:</td><td><input name='PPPc_password' value='"+password+#"'></td></tr>
   <tr><td></td><td><input type='image' border='0' alt=' Set ' value=' Set ' src='"+
       set_src+#"' /></td></tr>
  </table>
</td>"
      "<td><img src=\"/internal-roxen-unit\" height=\"5\" /><br />\n\n";

    int is_me = this_object() == id->misc->config_user;

    foreach( possible_permissions, string perm )
    {
      int dim, noclick;
      if( perm != "Everything" && permissions->Everything )
        dim = 1;

      if( is_me && (perm == "Everything") )
	dim = noclick = 1;

      if( permissions[ perm ] )
      {
        string s = Roxen.parse_rxml(
	  "<gbutton-url "+
	  ( dim ? "state='disabled' "
	    "frame-image='&usr.gbutton-disabled-frame-image;'" :
	    "" )+
	  "    icon_src=/img/selected.gif "
	  "    width=180>"+
	  permission_translations[ perm ]+
	  "</gbutton-url>", id );
	if( noclick )
	  form += sprintf("<img src='%s' />\n", s);
	else
	  form += sprintf( "<input border=0 type=image name='PPPremove_%s'"
			   " src='%s'>\n", perm, s );
      }
      else
      {
        string s = Roxen.parse_rxml(
	  "<gbutton-url "+
	  ( dim ?
	    "state='disabled' "
	    "frame-image='&usr.gbutton-disabled-frame-image;'" :
	    "" )+
	  "    icon_src=/img/unselected.gif "
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
    mapping q = config_settings->get( name+"_uid" ) || ([]);
    real_name = q->real_name||"";
    password = q->password||crypt_password("www");
    permissions = mkmultiset( q->permissions||({}) );
    if( settings_cache[ name ] )
      settings = settings_cache[ name ];
    else
      settings = settings_cache[ name ] = ConfigurationSettings( name );
  }

  AdminUser save()
  {
    config_settings->set( name+"_uid", ([
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
    if( verify_password( auth[1], password ) )  return 1;
  }

  protected void create( string n )
  {
    name = n;
    restore( );
  }

  protected string _sprintf()
  {
    return sprintf("AdminUser( %O, %O, %{%s %} )", 
                   name, real_name, (array)permissions);
  }
}

array possible_permissions = ({ });
mapping permission_translations = ([ ]);

void add_permission( string perm, LocaleString text )
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
  config_settings = ConfigIFCache( "settings",1 );
  config_settings2 =ConfigIFCache( "settings",0 );
  add_constant( "AdminUser", AdminUser );
  add_permission( "Everything", LOCALE(191, "All Permissions"));
}

// cache
protected mapping(string:AdminUser) admin_users = ([]);

AdminUser find_admin_user( string s )
{
  if( admin_users[ s ] )
    return admin_users[ s ];
  if( config_settings->get( s+"_uid" ) )
    return admin_users[ s ] = AdminUser( s );
}

AdminUser create_admin_user( string s )
{
  return AdminUser( s )->save( );
}

void delete_admin_user( string s )
{
  m_delete( admin_users,  s );
  config_settings2->delete( s );
  config_settings->delete( s+"_uid" );
}

array(string) list_admin_users()
{
  return map( glob( "*_uid", config_settings->list()||({}) ),
              lambda( string q ) {
                sscanf( q, "%s_uid", q );
                return q;
              } );
}


/* compatibility and convenience functions */
string configuration_authenticate(RequestID id, string what, void|int silent)
{
  //  Search is not ordered so we can just as well try cached users before
  //  listing all identities.
  array known = values(admin_users);
  foreach(known, AdminUser u)
    if (u->valid_id(id) && u->auth(what))
      return u->name;
  
  array a = map(list_admin_users(), find_admin_user) - ({ 0 }) - known;
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


class UserDBModule
{
  inherit UserDB;

  string module_identifier(){ return 0; }
  
  protected class CFUser
  {
    inherit User;
    AdminUser ruser;

    // Wrappers 
    string name()              { return ruser->name;      }
    string real_name()         { return ruser->real_name; }
    int uid()                  { return -1;               }
    int gid()                  { return -1;               }
    string shell()             { return "";               }
    string homedir()   	       { return "/";              }
    string crypted_password()  {  return ruser->password; }


    protected void create( UserDB p, AdminUser u )
    {
      ::create( p );
      ruser = u;
    }	
  }


  array(string) list_users()  { return list_admin_users();  }

  CFUser find_user( string uid )
  {
    AdminUser u = find_admin_user( uid );
    if( u ) return CFUser( this_object(), u );
  }

  CFUser find_user_from_uid( int id )
  {
    return 0; // optimize
  }
}

UserDBModule config_userdb_module = UserDBModule();
