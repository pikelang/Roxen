#include <config_interface.h>
#include <config.h>
#include <roxen.h>
//<locale-token project="roxen_config">_</locale-token>
#define _(X,Y)	_STR_LOCALE("roxen_config",X,Y)

mapping actions = ([
  // name         title                      function   must be internal
  "move":   ({  _(401,"Copy or rename database"),move_db,   0 }),
  "delete": ({  _(402,"Delete this database"), delete_db, 0 }),
  "group":  ({  _(324,"Change group for this database"), change_group, 0 }),
  "clear":  ({  _(403,"Delete all tables"),    clear_db,  0 }),
  "backup": ({  _(404,"Make a backup"),        backup_db, 1 }),
  "charset":({  _(536, "Change default character set"), change_charset, 0 }),
  "repair": ({  _(537, "Repair all tables"),     repair_db, 0 }),
  "optimize":({  _(538, "Optimize all tables"),   optimize_db, 0 }),
]);


#define CU_AUTH id->misc->config_user->auth

#define VERIFY(X) do {						\
  if( !id->variables["yes.x"] )					\
  {								\
    return							\
      ("<table><tr><td colspan='2'>\n"+				\
       sprintf((string)(X), db)+				\
       "</td><tr><td><input type=hidden name=action value='&form.action;' />"\
       "<submit-gbutton2 name='yes' align='center' "		\
       " width='&usr.gbutton-width;'>"+_(0,"Yes")+		\
       "</submit-gbutton2></td>\n"				\
       "<td align=right><cf-no href="+Roxen.html_encode_string(id->not_query)+\
      "?db="+Roxen.html_encode_string(id->variables->db)+"/>"+	\
       "</td>\n</table>\n");					\
  }								\
} while(0)


mixed change_group( string db, RequestID id )
{
  if( !id->variables->group )
  {
    string res ="<br /><blockquote>"
    "<input type=hidden name=action value='&form.action;' />"
      "<h2>"+sprintf(_(423,"Changing group for %s"), db )+"</h2>"
      "<b>"+_(445,"Old group")+":</b> " +
      DBManager.get_group(DBManager.db_group(db))->lname+"<br />"
      "<b>"+_(504,"New group")+":</b> <select name='group'>";
    foreach( DBManager.list_groups(), string g )
      if( g == DBManager.db_group( db ) )
	res += "<option selected value='"+g+"'>"+DBManager.get_group( g )->lname;
      else
	res += "<option value='"+g+"'>"+DBManager.get_group( g )->lname;
    return res + "</select><submit-gbutton2 name='ok'>"+(201,"OK")+
      "</submit-gbutton2>";
  }
  DBManager.set_db_group( db, id->variables->group );
  return 0;
}

mixed change_charset( string db, RequestID id )
{
  if( !id->variables->default_charset )
  {
    string old_charset = DBManager.get_db_default_charset(db);
    string res ="<br /><blockquote>"
    "<input type=hidden name=action value='&form.action;' />"
      "<h2>"+sprintf(_(539,"Changing default character set for %s"), db )+
      "</h2>"+
      (old_charset?("<b>"+_(540, "Old default character set")+":</b> " +
		    old_charset+"<br />"):"")+
      "<b>"+_(541,"New default character set")+":</b> "
      "<input type='string' name='default_charset' value='" +
      Roxen.html_encode_string(old_charset||"") +"' />";
    return res + "</select><submit-gbutton2 name='ok'>"+(201,"OK")+
      "</submit-gbutton2>";
  }
  DBManager.set_db_default_charset( db, id->variables->default_charset );
  return 0;
}

mixed repair_db( string db, RequestID id )
{
  // CSS stylesheet
  string res = "<style type='text/css'>"
    "#tbl {"
    " font-size: smaller;"
    " text-align: left;"
    "}\n"
    "#tbl tr > td {"
    " padding-left: 1em;"
    " border-bottom: 1px solid &usr.matrix22;;"
    "}\n"
    "#tbl tr > th {"
    " font-weight: bold;"
    " background-color: &usr.matrix12;;"
    " padding-left: 1em;"
    "}\n"
    "#tbl tr > *:first-child {"
    " padding-left: 0;"
    "}\n"
    "</style>"

    "<a href='browser.pike?db=" + db + "'><gbutton>Back</gbutton></a><br/><br/>"

    "<table id='tbl' cellspacing='0' cellpadding='1'>"
    "<thead>"
    "<tr>"
    "<th>Target</th>"
    "<th>Result</th>"
    "<th>Time</th>"
    "</tr>"
    "</thead>"
    "<tbody>";

  mixed m = query("SHOW TABLE STATUS IN " + db);
  float t3 = 0;

  if (sizeof(m)) {
    foreach (m,m) {
      string result = "";
      mixed q;
      int t = time();
      float t1 = time(t);
      float t2;

      if ( mixed e = catch { q = query( "REPAIR TABLE `" + db + "`.`" + m->Name + "`" ); } ) {
	result = "<font color='red'>Error: " + describe_error(e) + "</font>";
      } else {
	t2 = (time(t)-t1);
	t3 += t2;

	if (q->Msg_text = "OK")
	  result = "<font color='green'>OK</font>";
	else
	  result = "<font color='red'>Failed: " + q->Msg_text + "</font>";
      }

      res += "<tr>" +
	"<td><a href='browser.pike?db=" + db + "'>" + db + "</a>.<a href='browser.pike?db=" + db + "&amp;table=" + m->Name + "'>" + m->Name + "</a></td>" +
	"<td><b>" + result + "</b></td>" +
	"<td>" + t2 + " sec</td>" +
	"</tr>";
    }
  }
  res += "<tr><td colspan='2'>Total:</td><td>" + t3 + " sec</td></tr></tbody></table><br/>";

  return res;
}

mixed optimize_db( string db, RequestID id )
{
  // CSS stylesheet
  string res = "<style type='text/css'>"
    "#tbl {"
    " font-size: smaller;"
    " text-align: left;"
    "}\n"
    "#tbl tr > td {"
    " padding-left: 1em;"
    " border-bottom: 1px solid &usr.matrix22;;"
    "}\n"
    "#tbl tr > th {"
    " font-weight: bold;"
    " background-color: &usr.matrix12;;"
    " padding-left: 1em;"
    "}\n"
    "#tbl tr > *:first-child {"
    " padding-left: 0;"
    "}\n"
    "</style>"

    "<a href='browser.pike?db=" + db + "'><gbutton>Back</gbutton></a><br/><br/>"

    "<table id='tbl' cellspacing='0' cellpadding='1'>"
    "<thead>"
    "<tr>"
    "<th>Target</th>"
    "<th>Result</th>"
    "<th>Time</th>"
    "</tr>"
    "</thead>"
    "<tbody>";

  mixed m = query("SHOW TABLE STATUS IN " + db);
  float t3 = 0;

  if (sizeof(m)) {
    foreach (m,m) {
      string result = "";
      mixed q;
      int t = time();
      float t1 = time(t);
      float t2;

      if ( mixed e = catch { q = query( "OPTIMIZE TABLE `" + db + "`.`" + m->Name + "`" ); } ) {
	result = "<font color='red'>Error: " + describe_error(e) + "</font>";
      } else {
	t2 = (time(t)-t1);
	t3 += t2;

	if (q->Msg_text = "OK")
	  result = "<font color='green'>OK</font>";
	else
	  result = "<font color='red'>Failed: " + q->Msg_text + "</font>";
      }

      res += "<tr>" +
	"<td><a href='browser.pike?db=" + db + "'>" + db + "</a>.<a href='browser.pike?db=" + db + "&amp;table=" + m->Name + "'>" + m->Name + "</a></td>" +
	"<td><b>" + result + "</b></td>" +
	"<td>" + t2 + " sec</td>" +
	"</tr>";
    }
  }
  res += "<tr><td colspan='2'>Total:</td><td>" + t3 + " sec</td></tr></table><br/>";

  return res;}

mixed query( mixed ... args ) {
	return connect_to_my_mysql( 0, "roxen" )->query( @args );
}

mixed backup_db( string db, RequestID id )
{
  if( id->variables["ok.x"] )
  {
    if (roxenloader->parse_mysql_location()->mysqldump) {
      DBManager.dump
	(db, id->variables->dir == "auto" ? 0 : id->variables->dir);
    } else {
      DBManager.backup
	(db, id->variables->dir == "auto" ? 0 : id->variables->dir);
    }
    return 0;
  }
  return
    "<b>"+_(405,"Directory")+":</b> <input name='dir' size='60' value='auto' /><br />"
    "<i>" + sprintf (_(0, #"\
The directory the backup will be saved in. If you chose auto, Roxen
will generate a directory name that includes the database name and
today's date in <tt>$VARDIR/backup</tt> (%s)."),
		     combine_path (getcwd(), roxen_path ("$VARDIR/backup"))) +
    "</i>"
    "<table width='100%'><tr><td valign=top>"
    "<input type=hidden name=action value='&form.action;' />"
    "<submit-gbutton2 name='ok'>"+_(201,"OK")+"</submit-gbutton2></td>\n"
    "<td valign=top align=right><cf-cancel href='"+
      Roxen.html_encode_string(id->not_query)+
      "?db="+Roxen.html_encode_string(id->variables->db)+"'/>"
    "</td>\n</table>\n";
}

mixed move_db( string db, RequestID id )
{
  string warning="";
  int internal = DBManager.is_internal( db );
  if( id->variables["ok.x"] )
  {
    if( !internal )
    {
      if( !strlen(id->variables->url) )
        warning= "<font color='&usr.warncolor;'>"
	  +_(406,"Please specify an URL to define an external database")+
	  "</font>";
      else if( mixed err = catch( Sql.Sql( id->variables->url ) ) )
        warning = sprintf("<font color='&usr.warncolor;'>"+
			  _(407,"It is not possible to connect to %s.")+
			  "<br /> (%s)"
			  "</font>",
			  id->variables->url,
			  describe_error(err));
    }
    if( !strlen( warning ) )
      switch( id->variables->name )
      {
       case "":
	 warning =  "<font color='&usr.warncolor;'>"+
	   _(408,"Please specify a name for the database")+
	   "</font>";
         break;
       case "mysql":
       case "roxen":
         warning = sprintf("<font color='&usr.warncolor;'>"+
                         _(409,"%s is an internal database, used by Roxen. "
			   "Please select another name.")+
                         "</font>", id->variables->name );
         break;
	default:
	 if( Roxen.is_mysql_keyword( id->variables->name ) )
	   warning = sprintf("<font color='&usr.warncolor;'>"+
			     _(410,"%s is a MySQL keyword, used by MySQL. "
			       "Please select another name.")+
			     "</font>", id->variables->name );
	 catch {
	   if( DBManager.cached_get( id->variables->name ) &&
	       db != id->variables->name )
	     warning = sprintf("<font color='&usr.warncolor;'>"+
			       _(529,"the database %s does already exist")+
			       "</font>", id->variables->name );
	   // FIXME: Also check if the name is a valid db name.
	 };
	 break;
      }
    if( !strlen( warning ) )
    {
      // In all cases, create the new db.
      if(!(DBManager.get_db_url_info(id->variables->name))) {
	DBManager.create_db(id->variables->name, id->variables->url,
			    internal, id->variables->group);
      } else {
	DBManager.set_url(id->variables->name,
			  id->variables->url,
			  internal);
      }
      
      // Intern
      //   Copy if name has changed.
      // Extern
      //   Just copy the meta information.
      if(internal)
      {
	// Internal db, use the backup thingies to copy the data
	if( db != id->variables->name )
	{
	  DBManager.backup( db, "/tmp/tmpdb" );
	  DBManager.restore( db, "/tmp/tmpdb", id->variables->name );
	  DBManager.delete_backup( db, "/tmp/tmpdb" );
	}
      }
      switch( id->variables->what )
      {
	case "copy": // copy, no delete
	  if( db != id->variables->name )
	    DBManager.copy_db_md( db, id->variables->name );
	  // Done.
	  break;

	case "move": // move & delete
	  // Delete the old data.
	  if( db != id->variables->name )
	  {
	    DBManager.copy_db_md( db, id->variables->name );
	    if( !strlen(warning) )
	      DBManager.drop_db( db );
	  }
	  break;
      }
      return Roxen.http_redirect( "/dbs/", id );
    }
  }
  if(!id->variables->name)
    id->variables->name = db;

  if( !id->variables->url )
    id->variables->url  = DBManager.db_url( db ) || "";

  return
    "<gtext scale=0.6>"+_(414,"Copy or rename this database")+"</gtext><br />\n"
    +warning+
    "<table>\n"
    
    "  <tr>\n"
    "    <td><b>"+_(415,"Action")+":</b></td>\n"
    "    <td><default variable='form.what'>\n"
    "      <select name='what'>\n"
    "        <option value='copy'>"+_(416,"Copy the data to a new database")+"</option>\n"
    "        <option value='move'>"+_(417,"Rename database")+"</option>\n"
    "      </select></default>\n"
    "    </td>\n"
    "  </tr>\n"
    "  <tr>\n"
    "    <td><b>"+_(418,"New name")+":</b></td>\n"
    "    <td><input name='name' value='&form.name;'/></td>\n"
    "  </tr>\n"
    
    "  <tr>\n"
    "    <td valign=top colspan='2'>\n"
    "      <i>"+_(530,"The new name of the database. To make it easy on "
		  "your users, use all lowercaps characters, and avoid hard to type "
		  "characters.")+"</i>\n"
    "    </td>\n"
    "  </tr>\n"+
    
    (internal?"":
     " <tr>\n"
     "   <td><nbsp><b>URL:</b></nbsp></td>\n"
     "   <td colspan='3'><input name='url' size=50 value='&form.url;'/></td>\n"
     " </tr>\n"
     " <tr>"
     "   <td colspan='4'><i>\n"+
     "     "+_(422,"This URL is only used for </i>External<i> databases, it is "
	       "totally ignored for databases defined internally in Roxen. ")+"\n</i>\n"
     "   </td>"
     " </tr>\n")+
    
    "</table>\n"+
    "<table width='100%'><tr><td>"
    "<input type=hidden name=action value='&form.action;' />"
    "<submit-gbutton2 name='ok'>"+_(201,"OK")+"</submit-gbutton2></td>\n"
    "<td align=right>"
    "<cf-cancel href='"+Roxen.html_encode_string(id->not_query)+
      "?db="+
       Roxen.html_encode_string(id->variables->db)+"'/>"
    "</td>\n</table>\n";
}

mixed delete_db( string db, RequestID id )
{
  string msg;
  if( DBManager.is_internal( db ) )
    msg = (string)_(361, "Are you sure you want to delete the database %s "
		    "and the data?");
  else
    msg = (string)_(362,"Are you sure you want to delete the database %s?"
		    " No data will be deleted from the remote database.");
    
  VERIFY(msg);
  report_notice( _(424,"The database %s was deleted by %s")+"\n",
		 db, id->misc->authenticated_user->name() );
  DBManager.drop_db( db );
  return Roxen.http_redirect( "/dbs/", id );
}

mixed clear_db( string db, RequestID id )
{
  VERIFY(_(425,"Are you sure you want to delete all tables in %s?"));

  Sql.Sql sq = DBManager.get( db );

  // Note: Drop table may fail due to foreign key references
  //       in some databases. Thus the outer loop and the catch.
  int table_cnt;
  array(string) remaining_tables = DBManager.db_tables( db );
  do {
    foreach( remaining_tables, string r ) {
      catch { sq->query( "DROP TABLE "+r ); };
    }
    table_cnt = sizeof(remaining_tables);
    remaining_tables = DBManager.db_tables( db );
  } while (sizeof(remaining_tables) &&
	   (table_cnt > sizeof(remaining_tables)));
  if (sizeof(remaining_tables)) {
    // We've failed to drop some tables, try forcing an error.
    sq->query( "DROP TABLE " + remaining_tables[0]);
  }
  return 0;
}


int image_id = time() ^ gethrtime();

string is_image( string x )
{
  if( !stringp(x) )
    return 0;
  if( has_prefix( x, "GIF" ) )
    return "gif";
  if( has_value( x, "JFIF" ) )
    return "jpeg";
  if( has_prefix( x, "\x89PNG" ) )
    return "png";
}

int is_deflated (string what)
{
  // This detection is an estimate - it may give false positives.
  if (!stringp (what) || sizeof (what) < 3)
    return 0;
  return ((what[0] & 0x0f) == 8) && !(((what[0] << 8) + what[1]) % 31);
}

int is_encode_value( string what )
{
  if( !stringp(what) )
    return 0;
  return strlen(what) >= 5 && has_prefix (what, "¶ke");
}

string format_decode_value( string what )
{
#if 0
  string trim_comments( string what ) /* Needs work */
  {
    string a, b;
    while( sscanf( what, "%s/*%*s*/%s", a, b ) )
      what = a+b;
    return what;
  };
#endif

  // Type is program or object?
  if( (what[4] & 15) == 5 || (what[4] & 15) == 3 )
    return Roxen.html_encode_string(
      sprintf("<"+_(233,"bytecode data")+" ("+
	      _(505,"%d bytes")+")>", strlen(what)));
  
  catch
  {
    return
      "<pre>"+
      Roxen.html_encode_string(
	String.trim_all_whites(sprintf("%O",decode_value(what))))+
      "</pre>";
  };
  return Roxen.html_encode_string( what );
}

string store_image( string x )
{
  string id = (string)image_id++;

  .State->images[ id ] = ([
    "type":"image/"+(is_image( x )||"unknown"),
    "data":x,
    "len":strlen(x),
  ]);
  return id;
}

string db_switcher( RequestID id )
{
  mapping q = DBManager.get_permission_map( );
  if ( !sizeof( q ))
    return "";

  string res = #"
  <script type='text/javascript'>
  function switch_db( objSel ) {
    if( objSel.selectedIndex == 0) {
      return;
    }
    var selValue = objSel.options[objSel.selectedIndex].value;
    if(selValue != '&form.db:js;') {
      window.location.href = window.location.pathname + '?db=' + escape( selValue );
    }
  }
  </script>
  <select name='db' onchange='switch_db(this)'>
    <option value=''>Switch to other DB</option>\n";
  foreach( sort(indices(q)), string d ) {
    res += sprintf( "<option value='%s'%s>%s</option>\n", d,
                    (d == id->variables->db)? "selected='selected'": "", d);
  }
  return res + "</select><noscript><input type='submit' value='Switch db'/></noscript>\n";
}

string format_table_owner (mapping(string:string) mod_info, void|int skip_conf)
{
  // Note: Code duplication in db_list.pike.

  if ((<0, "">)[mod_info->conf]) return 0;

  Configuration c = roxen.find_configuration( mod_info->conf );
  RoxenModule m = c && !(<0, "">)[mod_info->module] &&
    c->find_module( mod_info->module );
  ModuleInfo i =
    !(<0, "">)[mod_info->module] &&
    roxen.find_module( (mod_info->module/"#")[0] );
  string mn;

  if (!skip_conf) {
    if (c) {
      mn = "<a href='../sites/site.html/" +
	Roxen.http_encode_url (mod_info->conf) + "/'>" +
	Roxen.html_encode_string (c->query_name()) + "</a>";
    }
    else
      mn = Roxen.html_encode_string (
	sprintf ((string) _(542, "the deleted site %O"), mod_info->conf));
  }

  if( m ) {
    string module = "<a href='../sites/site.html/"+
      Roxen.http_encode_url(mod_info->conf)+"/n!n/"+
      replace(mod_info->module,"#","!")+"/"+
      "'>"+ Roxen.html_encode_string (i->get_name())+"</a>";
    if (mn)
      mn = sprintf ((string) _(543, "%s in %s"), module, mn);
    else
      mn = module;
  }
  else if( i ) {
    if (mn)
      mn = sprintf (
	(string) _(544, "the deleted module %s in %s"),
	Roxen.html_encode_string (sprintf ("%O", (string) i->get_name())),
	mn);
    else
      mn = sprintf (
	(string) _(545, "the deleted module %s"),
	Roxen.html_encode_string (sprintf ("%O", (string) i->get_name())));
  }

  return mn;
}

mapping|string parse( RequestID id )
{
  if( id->variables->image )
    return m_delete( .State->images, id->variables->image );

  if( !id->variables->db ||
      !( CU_AUTH( "Edit Global Variables" ) ) )
    return Roxen.http_redirect( "/dbs/", id );

  string res =
    "<style type='text/css'>"
    ".num {"
    " text-align: right;"
    " white-space: nowrap;"
    "}\n"
    "#tbls a {"
    " color: #0033aa;"
    " text-decoration: none;"
    "}\n"
    "#tbls a:hover {"
    " color: #0055ff;"
    " text-decoration: underline;"
    "}\n"
    "#tbls {"
    " font-size: smaller;"
    " text-align: left;"
    " border-collapse: collapse;"
    "}\n"
    "#tbls > * > tr > td {"
    " padding-left: 1em;"
    " border-bottom: 1px solid &usr.matrix22;;"
    "}\n"
    "#tbls > * > tr > th {"
    " font-weight: bold;"
    " white-space: nowrap;"
    " background-color: &usr.matrix12;;"
    " padding-left: 1em;"
    "}\n"
    "#tbls > * > tr > *:first-child {"
    " padding-left: 0;"
    "}\n"
    "#tbls > * > tr.tbl-details > * {"
    " border-top-style: hidden;"
    "}\n"
    "#tbl-details {"
    " font-size: smaller;"
    "}\n"
    "#tbl-details > * > tr > * {"
    " padding-left: 1em;"
    "}\n"
    "#tbl-details > * > tr > *:first-child {"
    " padding-left: 0;"
    "}\n"
    "#res {"
    " font-size: smaller;"
    " text-align: left;"
    " border-collapse: collapse;"
    "}\n"
    "#res > * > tr {"
    " vertical-align: top;"
    "}\n"
    "#res > * > tr > * {"
    " border: 1px solid &usr.matrix22;;"
    "}\n"
    "#res > * > tr > th {"
    " font-weight: bold;"
    " background-color: &usr.matrix12;;"
    "}\n"
    "</style>"
    "<set variable='var.form-anchor' value='#dbquery'/>"
    "<use file='/template'/><tmpl>"
    "<topmenu base='../' selected='dbs'/>"
    "<content><cv-split><subtablist width='100%'><st-tabs>"
    "<insert file='subtabs.pike'/></st-tabs><st-page>"
    "<input type='hidden' name='sort' value='&form.sort:http;' />\n";

  if( id->variables->action && actions[ id->variables->action ])
  {
    res += "<input type='hidden' name='db' value='&form.db:http;' />\n";
    mixed tmp = actions[ id->variables->action ][1]( id->variables->db, id );
    if( stringp( tmp ) )
      return res+tmp+"\n</st-page></content></tmpl>";
    if( tmp )
      return tmp;
  }

  string url = DBManager.db_url( id->variables->db );

  string charset = "unicode";
#if !constant (Mysql.mysql.HAVE_MYSQL_FIELD_CHARSETNR)
  if (DBManager.is_mysql (url)) {
      // Ugly kludge for broken mysql client lib. Works most of the
      // time, at least..
      charset = "broken-unicode";
  }
#endif

  Sql.Sql db;
  mixed db_connect_error =
    catch (db = DBManager.get (id->variables->db, 0, 0, 0, charset));
  if (db_connect_error)
    // Try again without charset.
    db_connect_error = catch (db = DBManager.get (id->variables->db));
  if (!db && !db_connect_error) {
    db_connect_error = ({ "Failed to connect to database.\n", ({}) });
  }

  string qres="";
  
  class QueryHistory
  {
    inherit Variable.Variable;
    constant type = "QueryHistory";

    void create()
    {
      ::create( ([]), 65535 );
    }
  };

  object user = id->misc->config_user;
  QueryHistory hs;
  if( !(hs = user->settings->getvar( "db_history" ) ) )
  {
    user->settings->defvar( "db_history", (hs = QueryHistory( )) );
    user->settings->restore();
  }
  if( (!id->variables->query || id->variables["reset_q.x"]) )
  {
    array sel_t_columns = ({});
    if( !(<0, "">)[id->variables->table] ) {
      if (mixed err = catch {
	  sel_t_columns = DBManager.db_table_fields( id->variables->db,
						     id->variables->table )
	    ->name;
	}) {
	report_debug ("Error listing fields for table %s.%s: %s",
		      id->variables->db, id->variables->table,
		      describe_error (err));
      }
    }

    mapping h = hs->query();

    function(string:string) quote_name = lambda (string s) {return s;};
    if (DBManager.is_mysql (id->variables->db))
      // FIXME: Ought to be generalized and put into Sql.pmod.
      quote_name = lambda (string s) {
		     if (db && db->master_sql->is_keyword (s))
		       return "`" + s + "`";
		     return s;
		   };

    if( !id->variables["reset_q.x"] &&
	h[id->variables->db+"."+id->variables->table] )
      id->variables->query = h[id->variables->db+"."+id->variables->table];
    else if( !(<0, "">)[id->variables->table] )
      id->variables->query = "SELECT "+
	(sizeof (sel_t_columns) ?
	 map (sel_t_columns, quote_name) *", " : "*") +
	" FROM "+ quote_name (id->variables->table);
    else if( DBManager.is_mysql( id->variables->db ) )
      id->variables->query = "SHOW TABLES";
    else
      id->variables->query = "";
  }

  if (id->variables["run_q.x"] || id->variables["reset_q.x"])
    hs->query()[ id->variables->db+"."+id->variables->table ]
      = id->variables->query-"\r";

  if(db && id->variables["run_q.x"])
  {
    user->settings->save();

    string query = "";
    // Normalize.
    foreach( (id->variables->query-"\r")/"\n", string q )
    {
      //q = (q/" "-({""}))*" ";
      q = String.trim_all_whites (q);
      if (q == "--") break;
      if (q != "")
	query = (query == "" ? q : query + "\n" + q);
    }

    foreach( (query/";\n")-({""}); int i; string q )
    {
      Sql.sql_result big_q;

      int h = gethrtime();
      if (mixed err = catch (big_q = db->big_query( q ))) {
	qres += "<p><font color='&usr.warncolor;'>"+
	  sprintf((string)_(0,"Error running query %d: %s"), i + 1,
		  replace (Roxen.html_encode_string (
			     String.trim_all_whites (describe_error(err))),
			   "\n", "<br/>\n"))+
	  "</p>\n";
	continue;
      }
      float qtime = (gethrtime()-h)/1000000.0;

      if (!big_q)
	// Query had no result or was empty/commented out.
	continue;

      int qrows;
      qres += "<p>\n"
	"<table id='res'><tr>";
      multiset right_columns = (<>);
      int column;

      array(string) col_types = ({});

      foreach( big_q->fetch_fields(), mapping field )
      {
	switch( field->type  )
	{
	  case "char":	// Actually a TINYINT.
	  case "short":
	  case "int":
	  case "long":
	  case "int24":
	  case "longlong":
	    right_columns[column]=1;
	  qres += "<th class='num'>";
	  col_types += ({"int"});
	  break;
	  case "float":
	  case "double":
	    right_columns[column]=1;
	  qres += "<th class='num'>";
	  col_types += ({"float"});
	  break;
	  case "decimal":
	  case "numeric":
	    qres += "<th class='num'>";
	  col_types += ({"string"});
	  break;
	  case "bit":
	  default:
	    qres += "<th>";
	  col_types += ({"string"});
	}
	qres += Roxen.html_encode_string (field->name) + "</th>\n";
	column++;
      }
      qres += "</tr>";

      while( array q = big_q->fetch_row() )
      {
	qrows++;
	qres += "<tr>";
	for( int i = 0; i<sizeof(q); i++ ) {
	  qres += right_columns[i] ? "<td class='num'>" : "<td>";
	  if( !q[i] )
	    qres += "<i>NULL</i>";
	  else if( intp( q[i] ) || col_types[i] == "int" )
	    qres += (string) (int) q[i];
	  else if( floatp( q[i] ) || col_types[i] == "float" )
	    qres += (string) (float) q[i];
	  else if( is_image( q[i] ) )
	    qres +=
	      "<img src='browser.pike?image="+store_image( q[i] )+ "' />";
	  else {
	    mixed tmp = q[i];
	    if (is_deflated (q[i])) {
	      // is_deflated _may_ give false positives, hence the catch.
	      catch {
		tmp = Gz.inflate()->inflate (q[i]);
	      };
	    }

	    if( is_encode_value( tmp ) )
	      qres += format_decode_value(tmp);
	    else if (String.width (tmp) > 8) {
	      // Let wide chars skip past the %q quoting, because
	      // it'll quote them to \u escapes otherwise.
	      string q = "";
	      int s;
	      foreach (tmp; int i; int c)
		if (c >= 256) {
		  if (s < i) q += sprintf ("%q", tmp[s..i - 1])[1..<1];
		  q += sprintf ("%c", c);
		  s = i + 1;
		}
	      q += sprintf ("%q", tmp[s..])[1..<1];
	      qres += Roxen.html_encode_string (q);
	    }
	    else
	      qres += Roxen.html_encode_string(sprintf("%q", tmp)[1..<1]);
	  }
	  qres += "</td>";
	}
	qres += "</tr>\n";
      }

      qres += "</table>"+
	sprintf( _(426,"Query took %[0].3fs, %[1]d rows in the reply")+
		 "\n</p>\n", qtime, qrows);
    }
  }

  if( !(<0, "">)[id->variables->table] )
    res += "<input type=hidden name='table' value='&form.table:http;' />\n";

  // DB switcher and title.

  res += "<p>"
    "<table><tr valign='center'>"
    "<td><cimg border='0' format='gif' src='&usr.database-small;' alt='' "
    "max-height='20'/></td>" +
    "<td>" + db_switcher( id ) + "</td></tr></table>\n"
    "</p>\n"
    "<h3>Database " + Roxen.html_encode_string (id->variables->db) + "</h3>\n";

  if (db_connect_error)
    res += "<p><font color='red'>" +
      _(0, "Error connecting to database: ") +
      Roxen.html_encode_string (describe_error (db_connect_error)) +
      "</font></p>\n";

  // Bullet list with generic database info.

  res += "<p><ul>\n";

  if (id->variables->db == "local")
    res += "<li>" +
      _(546, "Internal data that cannot be shared between servers.") + "</li>\n";
  else if (id->variables->db == "shared")
    res += "<li>" +
      _(547, "Internal data that may be shared between servers.") + "</li>\n";
  else if( !url )
    res += "<li>Internal database.</li>\n";
  else
    res += "<li>Database URL: " + Roxen.html_encode_string(url)+"</li>\n";

  mapping(string:string) db_info =
    DBManager.module_table_info (id->variables->db, "");
  if (string owner = format_table_owner (db_info))
    res += "<li>" + sprintf((string)_(428,"Defined by %s."), owner) +
      "</li>\n";
  if (string c = db_info->comment) {
    c = String.trim_all_whites (c);
    if (c != "")
      res += "<li>" + Roxen.html_encode_string (c) + "</li>\n";
  }

  string default_charset = DBManager.get_db_default_charset(id->variables->db);
  if (default_charset) {
    res += "<li>" + _(548,"Default charset:") +
      Roxen.html_encode_string(default_charset) + "</li>";
  }

  res +="<li>" +
    sprintf( (string)
	     _(506,"Member of the %s database group."),
	     "<a href='edit_group.pike?group="+
	     Roxen.http_encode_url(DBManager.db_group( id->variables->db ))+
	     "'>" +
	     DBManager.get_group( DBManager.db_group( id->variables->db ) )
	     ->lname +
	     "</a>")
    + "</li>";

  res += "</ul></p>\n";

  if (db) {
    // The database table list.

    res += "<p><table id='tbls' border='0' cellpadding='2' cellspacing='0'>";

    array table_data = ({});
    int sort_ok, got_owner_column;

    string deep_table_info( string table )
    {
      array(mapping(string:mixed)) data =
	DBManager.db_table_fields( id->variables->db, table );
      if( !data )
	return sprintf((string)_(507,"Cannot list fields in %s databases"),
		       DBManager.db_driver(id->variables->db) );

      multiset(string) props = (<>);
      foreach (data, mapping(string:mixed) r)
	foreach (r; string prop;)
	  props[prop] = 1;
      props->name = 0;		// Always listed first.
      props->type = 0;		// Always listed second.
      props->table = 0;		// Just our own table - ignored.
      array(string) sort_props = sort (indices (props));

      string res = "<table id='tbl-details'>"
	"<tr>"
	"<th>Column</th>"
	"<th>Type</th>" +
	map (sort_props,
	     lambda (string prop) {
	       return "<th>" + Roxen.html_encode_string (
		 String.capitalize (prop)) + "</th>";
	     }) * "" +
	"</tr>\n";

      foreach( data, mapping(string:mixed) r )
      {
	res += "<tr>"
	  "<td>" + Roxen.html_encode_string (r->name) + "</td>"
	  "<td>" + Roxen.html_encode_string (r->type) + "</td>";

	foreach (sort_props, string prop) {
	  mixed val = r[prop];
	  if (zero_type (val))
	    res += "<td></td>";
	  else if (intp (val) || floatp (val))
	    res += "<td class='num'>" + val + "</td>";
	  else if (stringp (val))
	    res += "<td>" + Roxen.html_encode_string (val) + "</td>";
	  else if (arrayp (val) &&
		   !catch (val = (array(string)) val))
	    res += "<td>" + Roxen.html_encode_string (val * ", ") + "</td>";
	  else if (multisetp (val) &&
		   !catch (val = (array(string)) indices (val)))
	    res += "<td>" + Roxen.html_encode_string (val * ", ") + "</td>";
	  else if (objectp (val))
	    res += "<td>" + Roxen.html_encode_string (sprintf ("%O", val)) +
	      "</td>";
	  else
	    res += "<td>" + Roxen.html_encode_string (sprintf ("<%t>", val)) +
	      "</td>";
	}

	res += "</tr>\n";
      }

      return res+ "</table>";
    };

    void add_table_info( string table, mapping tbi )
    {
      mapping(string:string) tbl_info =
	DBManager.module_table_info (id->variables->db, table);

      int deep_info = id->variables->table == table;

      string res = "<tr>"
	"<td style='white-space: nowrap'>"
	"<a href='browser.pike?sort=&form.sort:http;&amp;"
	"db=&form.db:http;" +
	(deep_info ? "" : "&amp;table="+Roxen.http_encode_url(table)) +"'>"+
	"<cimg style='vertical-align: -2px' border='0' format='gif'"
	" src='&usr.table-small;' alt='' max-height='12'/> " +
	table+"</a></td>"
	"<td class='num'>"+
	(!tbi || zero_type (tbi->rows) ? "" : tbi->rows) + "</td>"
	"<td class='num'>" +
	(!tbi || zero_type (tbi->data_length) ? "" :
	 sprintf ("%d KiB",
		  ((int)tbi->data_length+(int)tbi->index_length) / 1024)) +
	"</td>";

      string owner;
      if ((db_info->conf || "") != (tbl_info->conf || ""))
	owner = format_table_owner (tbl_info, 0);
      else if ((db_info->module || "") != (tbl_info->module || ""))
	owner = format_table_owner (tbl_info, 1);
      if (owner) {
	res += "<td>" + String.capitalize (owner) + "</td>";
	got_owner_column = 1;
      }
      else res += "<td></td>";

      if (deep_info) {
	res += "</tr>\n<tr class='tbl-details'><td colspan='5'>";

	if (tbl_info->comment)
	  sscanf( tbl_info->comment, "%s\0%s",
		  tbl_info->tbl, tbl_info->comment );

	if( tbl_info->tbl && tbl_info->tbl != table)
	  if( tbl_info->tbl != (string)0 )
	    res +=
	      sprintf((string) _(429,"The table is known as %O "
				 "in the module."), tbl_info->tbl ) + "<br/>\n";
	  else
	    res +=
	      sprintf((string) _(430,"The table is an anonymous table defined "
				 "by the module."), tbl_info->tbl ) + "<br/>\n";

	if (string c = tbl_info->comment) {
	  c = String.trim_all_whites (c);
	  if (c != "" && c != "0")
	    res += Roxen.html_encode_string (c) + "<br/>\n";
	}

	res += deep_table_info (table) + "</td></tr>\n";
      }
      else
	res += "</tr>\n";

      if( tbi )
	sort_ok = 1;

      table_data += ({({
			table,
			(tbi ?(int)tbi->data_length+ (int)tbi->index_length:0),
			(tbi ?(int)tbi->rows:0),
			res
		      })});
    };

    foreach( DBManager.db_tables( id->variables->db )-({0}), string tb )
      add_table_info(tb,
		     DBManager.db_table_information(id->variables->db, tb));

    switch( id->variables->sort )
    {
      default:
	sort( column( table_data, 0 ), table_data );
	break;

      case "rows":
	sort( column( table_data, 2 ), table_data );
	table_data = reverse( table_data );
	break;

      case "size":
	sort( column( table_data, 1 ), table_data );
	table_data = reverse( table_data );
	break;
    }
#define SEL(X,Y)							\
    ((id->variables->sort == X || (Y && !id->variables->sort)) ?	\
     "<img style='vertical-align: -2px' src='&usr.selected-indicator;'"	\
     " border='0' alt='&gt;'/>" :					\
     "")

    if( sort_ok )
    {
      if (!got_owner_column)
	// Try to hide the owner column when it's empty. Doesn't work
	// in firefox 2.0, though.
	res += "<col span='3'/><col style='visiblity: collapse'/>\n";
      res +=
	"<thead><tr>"
	"<th><a href='browser.pike?db=&form.db:http;&amp;table=&form.table:http;&amp;sort=name'>"+
	SEL("name", 1) + _(376,"Name")+
	"</a></th>\n"
	"<th class='num'><a href='browser.pike?db=&form.db:http;&amp;table=&form.table:http;&amp;sort=rows'>"+
	SEL("rows",0)+String.capitalize(_(374,"rows"))+
	"</a></th>\n"
	"<th class='num'><a href='browser.pike?db=&form.db:http;&amp;table=&form.table:http;&amp;sort=size'>"+
	SEL("size",0)+_(377,"Size")+
	"</a></th>\n"
	"<th>Owner</th>\n"
	"</tr></thead>\n";
    }

    res += "<tbody>" + column( table_data, 3 )*"\n" +
      "</tbody></table></p>\n";

    // Query widget.

    res +=
      "<a name='dbquery'/><p>"
      "<textarea rows='12' cols='90' wrap='soft' name='query' "
      " style='font-size: 90%'>" +
      Roxen.html_encode_string (id->variables->query) + "</textarea><br />"
      "<table><tr><td>"
      "<submit-gbutton2 name=reset_q> "+_(378,"Reset query")+" </submit-gbutton2>"
      "</td><td>"
      "<submit-gbutton2 name=run_q> "+_(379,"Run query")+" </submit-gbutton2>"
      "</td><td style='font-size: smaller; padding-left: 10px'>" +
      _(0, "Tip: Put '--' on a line to ignore everything below it.") +
      "</td></tr></table></p>";

    // Query result.

    res += qres;
  }

  // Actions.

  res += "<p>";

#define ADD_ACTION(X) if(!actions[X][2] || \
			 DBManager.is_internal(id->variables->db) ) \
   res += sprintf("<a href='%s?db=%s&amp;action=%s'><gbutton>%s</gbutton></a>\n",\
		  id->not_query, id->variables->db, X, actions[X][0] )
  
  switch( id->variables->db )
  {
    case "local":
      foreach( ({ "move","backup","optimize","repair" }), string x )
	ADD_ACTION( x );
      break;
      
    default:
      foreach( sort(indices( actions )), string x )
	ADD_ACTION( x );
      break;
  }
  return res+"</p></st-page></subtablist></cv-split></content></tmpl>";
}
