#include <config_interface.h>
#include <config.h>
#include <roxen.h>
//<locale-token project="roxen_config">_</locale-token>
#define _(X,Y)	_STR_LOCALE("roxen_config",X,Y)

mapping actions = ([
  // name         title                      function   must be internal
  "move":   ({  _(401,"Copy or move database"),move_db,   0 }),
  "delete": ({  _(402,"Delete this database"), delete_db, 0 }),
  "group":  ({  _(324,"Change group for this database"), change_group, 0 }),
  "clear":  ({  _(403,"Delete all tables"),    clear_db,  0 }),
  "backup": ({  _(404,"Make a backup"),        backup_db, 1 }),
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

mixed backup_db( string db, RequestID id )
{
  if( id->variables["ok.x"] )
  {
    DBManager.backup( db,
		      (id->variables->dir == "auto" ? 0 :
		       id->variables->dir )  );
    return 0;
  }
  return
    "<b>"+_(405,"Directory")+":</b> <input name='dir' size='60' value='auto' /><br />"
    "<i>The directory the backup will be saved in. If you chose auto, Roxen will generate a directory name that includes the database name and todays date.</i>"
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
  if( id->variables["ok.x"] )
  {
    if( id->variables->type=="external" )
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
                         _(409,"%s is an internal database, used by roxen."
			   "Please select another name")+
                         "</font>", id->variables->name );
         break;
	default:
	 if( Roxen.is_mysql_keyword( id->variables->name ) )
	   warning = sprintf("<font color='&usr.warncolor;'>"+
			     _(410,"%s is a MySQL keyword, used by MySQL."
			       "Please select another name")+
			     "</font>", id->variables->name );
	 break;
      }
    if( !strlen( warning ) )
    {
      int ni, move_later;
      // In all cases, create the new db.
      if( catch {
	DBManager.create_db( id->variables->name, id->variables->url,
			     (ni = (id->variables->type == "internal")),
			     id->variables->group );
      } )
	move_later = 1;

      Sql.Sql odb = DBManager.cached_get( db );
      if( move_later )
	DBManager.set_url( id->variables->name,
			   id->variables->url,
			   ni );
      Sql.Sql ndb = DBManager.cached_get( id->variables->name );

      // And copy the data...
      if( DBManager.is_internal( db ) && ni )
      {
	// Both are internal.
	// So... Use the backup thingies.
	if( db != id->variables->name )
	{
	  DBManager.backup( db, "/tmp/tmpdb" );
	  DBManager.restore( db, "/tmp/tmpdb", id->variables->name );
	  DBManager.delete_backup( db, "/tmp/tmpdb" );
	}
      }
      else
      {
	foreach( DBManager.db_tables( db ), string table )
	{
	  // Note: This _only_ works with MySQL.
	  mixed err;

	  werror( "Copying the table "+table+" ... ");

	  if( err = catch {
	    string def;
	    if( catch( def = 
		   odb->query( "SHOW CREATE TABLE "+table )[0]
		       ["Create Table"] ) )
	    {
	      array res = odb->query( "DESCRIBE "+table );
	      report_warning( _(411,"While copying %s.%s: "
				"The source database does not "
				"support %s.\nThe copy will not "
				"contain all metadata")+"\n",
			      db,table,"SHOW CREATE TABLE" );
	      def = "CREATE TABLE "+table+ "(";
	      array defs = ({});
	      int has_multi_pri = -1;
	      foreach( res->Key, string p )
		has_multi_pri += (p == "PRI");
	      foreach( res, mapping m )
	      {
		// FIXME: A real keyword list with alternatives here.
		if( m->Field == "when" )
		{
		  report_warning( _(412,"The source database used the string "
				    "%s as a fieldname.\nThis is reserved in "
				    "newer MySQL versions.\nSubstituting "
				    "with %s")+"\n",
				  m->Field, "whn" );
		  m->Field = "whn";
		}

		defs +=
		  ({
		    (m->Field+" "+m->Type+" "
		     +(m->Null=="YES"?"":"NOT NULL ")+
		     ("DEFAULT "+(m->Default?"'"+m->Default+"'":"NULL")+" ")+
		     ((has_multi_pri<1 && (m->Key == "PRI")) ?
		      ("PRIMARY KEY") : "" )
		     + " " +m->Extra )
		  });
	      }
	      def += defs * "," + ")";
	    }
	    
	    sscanf( def, "%s TYPE=%*s", def );
	    if( catch ( ndb->query( def ) ) )
	      ndb->query( "DELETE FROM "+table );
	    foreach( odb->query( "SELECT * FROM "+table ), mapping row )
	    {
	      if( row->when )
	      {
		row->whn = row->when;
		m_delete( row, "when" );
	      }
	      ndb->query( DBManager.insert_statement( id->variables->name,
						      table, row ) );
	    }
	  })
	  {
	    report_error( _(413,"Failed to copy data from source table.\n")+
			  describe_error( err )+"\n" );
	    break;
	  }
	}
      }

      switch( id->variables->what )
      {
	case "copy": // move, no delete
	case "dup":  // create new. Same as copy right now.
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

  if(!id->variables->type)
    id->variables->type =
      DBManager.is_internal( db ) ? "internal" : "external";

  if( !id->variables->url )
    id->variables->url  = DBManager.db_url( db ) || "";

  return
    "<gtext scale=0.6>"+_(414,"Move or copy this database")+"</gtext><br />\n"
    +warning+
    "<table>\n"
    "<tr><td><b>"+_(415,"Action")+":</b></td>"
    "<td><default variable='form.what'><select name=what>\n"
//     "   <option value='copy'>"+_(0,"Move but do not delete old data")+
//     "</option>\n"
    "   <option value='dup'>"+_(416,"Copy the data to a new database")+
    "</option>\n"
    "   <option value='move'>"+_(417,"Move database")+"</option>\n"
    "  </select></default>\n"
    "  <tr>\n"
    "    <td><b>"+ _(418,"New name")+
    ":</b></td> <td><input name='name' value='&form.name;'/></td>\n"
    "<td><b>"+_(419,"Type")+":</b></td> <td width='100%'>\n"
#"   <default variable=form.type><select name=type>
       <option value='internal'>  Internal  </option>
       <option value='external'>  External  </option>
     </select></default>
    </td>
  </tr>
  <tr>
  <td valign=top colspan='2'>
    <i>"+
    _(420,"The new name of the database. You do not have to change the "
      "name if you change the database type from internal to external, "
      "or change the URL of an external database. To make it easy on "
      "your users, use all lowercaps characters, and avoid hard to type "
      "characters")+
    "</i>\n"

    "</td>\n"
    "<td valign=top colspan='2' width='100%'>\n"

    "<i>"+
    _(421,"The database type. Internal means that it will be stored"
      " in the Roxen MySQL database, and the permissions of the"
      " database will be automatically manged by Roxen. External"
      " means that the database resides in another database.")+"</i>\n"
    "</td>\n"
    "</tr>\n"
    "<tr>\n"
    "<td><nbsp><b>URL:</b></nbsp></td>\n"
    "<td colspan='3'><input name='url' size=50 value='&form.url;'/></td>\n"
    "</tr>\n"
    "<tr><td colspan='4'><i>\n"+
    _(422,"This URL is only used for </i>External<i> databases, it is "
      "totally ignored for databases defined internally in Roxen ")+
    "\n</i>\n"
    "</td></tr>\n"
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
		    " No data will be deleted from the remote datbase.");
    
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

  foreach( DBManager.db_tables( db ), string r )
    sq->query( "drop table "+r );

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


int is_encode_value( string what )
{
  if( !stringp(what) )
    return 0;
  return strlen(what) >= 5 && !search( what, "¶ke" );
}

string format_decode_value( string what )
{
  string trim_comments( string what ) /* Needs work */
  {
    string a, b;
    while( sscanf( what, "%s/*%*s*/%s", a, b ) )
      what = a+b;
    return what;
  };

  // Type is program or object?
  if( (what[4] & 15) == 5 || (what[4] & 15) == 3 )
    return Roxen.html_encode_string(
      sprintf("<"+_(233,"bytecode data")+" ("+
	      _(505,"%d bytes")+")>", strlen(what)));
  
  catch
  {
    return
      "<pre>"+
      Roxen.html_encode_string(trim_comments(sprintf("%O",decode_value(what))))+
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

string format_float( float x )
{
  if( x >= 10000.0 )    return (string)((int)x);
  if( x >= 100.0 )      return sprintf("%.1f", x );
  if( x >= 10.0 )       return sprintf("%.2f", x );
  return sprintf("%.3f", x );
}

int is_int( mixed what )
{
  return stringp(what) && equal(({what}),array_sscanf(what, "%[0-9]"));
}

// NOTE: Returns true for integers too.
int is_float( mixed what )
{
  return stringp(what) && equal(what/".",array_sscanf(what, "%[0-9].%[0-9]"));
}

string format_int( int x )
{
  return (string)x;
}

mapping|string parse( RequestID id )
{
  if( id->variables->image )
    return m_delete( .State->images, id->variables->image );

  if( !id->variables->db ||
      !( CU_AUTH( "Edit Global Variables" ) ) )
    return Roxen.http_redirect( "/dbs/", id );

  string res =
    "<use file='/template'/><tmpl>"
    "<topmenu base='../' selected='dbs'/>"
    "<content><cv-split><subtablist width='100%'><st-tabs>"
    "<insert file='subtabs.pike'/></st-tabs><st-page>"
    "<input type=hidden name='sort' value='&form.sort:http;' />\n"
    "<input type=hidden name='db' value='&form.db:http;' />\n";

  if( id->variables->action && actions[ id->variables->action ])
  {
    mixed tmp = actions[ id->variables->action ][1]( id->variables->db, id );
    if( stringp( tmp ) )
      return res+tmp+"\n</st-page></content></tmpl>";
    if( tmp )
      return tmp;
  }

  Sql.Sql db;
  catch {
    db = DBManager.get( id->variables->db );
  };
  string url = DBManager.db_url( id->variables->db );

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
  
  array sel_t_columns = ({});

  object user = id->misc->config_user;
  QueryHistory hs;
  if( !(hs = user->settings->getvar( "db_history" ) ) )
  {
    user->settings->defvar( "db_history", (hs = QueryHistory( )) );
    user->settings->restore();
  }
  if( (!id->variables->query || id->variables["clear_q.x"]) )
  {
    mapping h = hs->query();
    catch {
      if( id->variables->table )
	sel_t_columns = DBManager.db_table_fields( id->variables->db,
						   id->variables->table )
	  ->name;
      if( h[id->variables->db+"."+id->variables->table] )
	id->variables->query = h[id->variables->db+"."+id->variables->table];
      else if( id->variables->table )
	id->variables->query = "SELECT "+(sel_t_columns*", ")+" FROM "+id->variables->table;
      else if( DBManager.is_mysql( id->variables->db ) )
	id->variables->query = "SHOW TABLES";
      else
	id->variables->query = "";
    };
  }

  if(db && id->variables["run_q.x"])
  {
    hs->query()[ id->variables->db+"."+id->variables->table ]
      = id->variables->query-"\r";
    user->settings->save();

    string query = "";
    // 1: Normalize.
    foreach( replace((id->variables->query-"\r"),"\t"," ")/"\n", string q )
    {
      q = (q/" "-({""}))*" ";
      if( strlen(q) && (q[0] == ' ') )  q = q[1..];
      if( strlen(q) && (q[-1] == ' ') ) q = q[..strlen(q)-2];
      query +=  q + "\n";
    }
    foreach( (query/";\n")-({""}), string q )
    {
      float qtime = 0.0;
      int qrows;
      qres += "<table celpadding=2><tr>";
      mixed e = catch {
	multiset right_columns = (<>);
	int h = gethrtime();
	object big_q = db->big_query( q );
	qtime = (gethrtime()-h)/1000000.0;
	int column;
	if( big_q )
	{
	  foreach( big_q->fetch_fields(), mapping field )
	  {
	    switch( field->type  )
	    {
	      case "long":
	      case "int":
	      case "short":
		right_columns[column]=1;
		qres += "<td align=right>";
		break;
	      default:
		qres += "<td>";
	    }
	    qres += "<b><font size=-1>"+field->name+
	      "</font size=-1></b></td>\n";
	    column++;
	  }
	  qres += "</tr>";

	  while( array q = big_q->fetch_row() )
	  {
	    qrows++;
	    qres += "<tr valign=top>";
	    for( int i = 0; i<sizeof(q); i++ )
	      if( !q[i] )
		qres +=
		  "<td align=right><i><font size=-2>NULL</font></i></td>";
	      else if( intp( q[i] ) || is_int(q[i]) )
		qres += "<td align=right>"+format_int((int)q[i])+"</td>";
	      else if( floatp( q[i] ) || is_float(q[i]) )
		qres += "<td align=right>"+format_float((float)q[i])+"</td>";
	      else if( is_image( q[i] ) )
		qres +=
		  "<td><img src='browser.pike?image="+store_image( q[i] )+
		  "' /></td>";
	      else if( is_encode_value( q[i] ) )
		qres += "<td>"+ format_decode_value(q[i]) +"</td>";
	      else if( right_columns[i] )
		qres += "<td align=right>"+ Roxen.html_encode_string(q[i]) +
		  "</td>";
	      else
		qres += "<td>"+ Roxen.html_encode_string(q[i]) +"</td>";
	    qres += "</tr>\n";
	  }
	}
      };
      if( e )
	qres += "<tr><td> <font color='&usr.warncolor;'>"+
	  sprintf((string)_(380,"While running %s: %s"), q,
		  describe_error(e) )+
	  "</td></tr>\n";
      qres += "</table>"+
	sprintf( _(426,"Query took %[0].3fs, %[1]d rows in the reply")+
		 "\n<br />", qtime, qrows);
    }
  }


  string table_module_info( string table )
  {
    mapping mi = DBManager.module_table_info( id->variables->db, table );
    string res = "";

    if(!mi->comment)
      return "";
    
    if( strlen(mi->conf) && strlen(mi->module) )
    {
      Configuration c = roxen.find_configuration( mi->conf );
      RoxenModule   m = c && c->find_module( mi->module );
      ModuleInfo    i = roxen.find_module( (mi->module/"#")[0] );
      string mn;

      if( c && m )
	mn =  "<a href='../sites/site.html/"+
	  Roxen.http_encode_url(mi->conf)+"/n!n/"+
	  replace(mi->module,"#","!")+"/"+
	  "'>"+i->get_name()+"</a> in "+c->query_name();
      else if( i )
	mn =  sprintf((string)_(427,"the deleted module %s from %s"),
		      i->get_name(), mi->conf );
      res=sprintf((string)_(428,"Defined by %s"),mn)+"<br />";
    }

    sscanf( mi->comment, "%s\0%s", mi->tbl, mi->comment );
    if( mi->tbl && mi->tbl != table)
      if( mi->tbl != (string)0 )
	return sprintf(_(429,"The table is known as '%s' in the module"),
		       mi->tbl )+"<br />"+res+mi->comment;
      else
	return sprintf(_(430,"The table is an anymous table defined by "
			 "the module"), mi->tbl )+
	  "<br />"+res+mi->comment;

    return res+mi->comment;
  };


  if( id->variables->table )
    res += "<input type=hidden name='table' value='&form.table:http;' />\n";

  res +=
    "<br />"
    "<table cellspacing=3 cellpadding=0 border=0 width=100%><tr><td>"
    "<colorscope bgcolor='&usr.content-bg;' text='&usr.fgcolor;'>"
    "<cimg border='0' format='gif' src='&usr.database-small;' alt='' "
    "max-height='20'/></td><td width=100%>"
    "<gtext fontsize='20'>"+id->variables->db+
    "</gtext></colorscope></td></tr>"
    "<tr><td></td><td>";

  if( !url )
    res += "<b>Internal database</b>";
  else
    res += "<b>"+url+"</b>";

  res += "</td></tr><tr><td></td><td>";

  res += table_module_info( "" );
  
  res +="<br /><a href='edit_group.pike?group="+
    Roxen.http_encode_url(DBManager.db_group( id->variables->db ))+"'>"+
    sprintf( (string)
	     _(506,"Member of the %s database group"),
	     DBManager.get_group( DBManager.db_group( id->variables->db ) )
	     ->lname )
    + "</a>";

  res += "<table>";

  array table_data = ({});
  int sort_ok;
  string deep_table_info( string table )
  {
    array data = DBManager.db_table_fields( id->variables->db, table );
    if( !data )
      return sprintf((string)_(507,"Cannot list fields in %s databases"), 
		     DBManager.db_driver(id->variables->db) );
    string res = "<tr><td></td><td colspan='3'><table>";
    foreach( data, mapping r )
    {
      res += "<tr>\n";
      res += "<td><font size=-1><b>"+r->name+"</b></font></td>\n";
      res += "<td><font size=-1>"+r->type+"</font></td>\n";
      res += "</tr>\n";
    }
    return res+ "</table></td></tr>";
  };

  void add_table_info( string table, mapping tbi )
  {
    string res = "";
    res += "<tr>\n";
    res += "<td> <cimg src='&usr.table-small;' max-height='12'/> </td>\n";
    res += "<td> <a href='browser.pike?sort=&form.sort:http;&"
      "db=&form.db:http;&table="+Roxen.http_encode_url(table)+"'>"+
      table+"</a> </td>";

    
    if( tbi )
      res += "<td align=right> <font size=-1>"+
	tbi->rows+" "+_(374,"rows")+"</font></td><td align=right>"
	"<font size=-1>"+
	(( (int)tbi->data_length+(int)tbi->index_length) ? 	
	 ( (int)tbi->data_length+(int)tbi->index_length)/1024+_(375,"KiB"):
	 "")+
	"</font></td>";

    if( id->variables->table == table )
      res += "</tr>\n<tr><td colspan='4'><font size='-1'>"
	+ table_module_info( table )+"</font></td></tr>\n";

    if( tbi )
      sort_ok = 1;

    table_data += ({({
      table,
      (tbi ?(int)tbi->data_length+ (int)tbi->index_length:0),
      (tbi ?(int)tbi->rows:0),
      res+
      ( id->variables->table == table ?
	deep_table_info( table ) : "")
    })});
  };

  if (db) {
    foreach( DBManager.db_tables( id->variables->db )-({0}), string tb )
      add_table_info(tb,
		     DBManager.db_table_information(id->variables->db, tb));
  }

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
#define SEL(X,Y) ((id->variables->sort==X||(Y&&!id->variables->sort))?"<img src='&usr.selected-indicator;' border=0 alt='&gt;' />":"")

  if( sort_ok )
  {
    res +=
      "<tr><td align=right>"+

      SEL("name",1)+"</td>"
      "<td><b><a href='browser.pike?db=&form.db:http;&table=&form.table:http;&sort=name'>"+
      _(376,"Name")+
      "</a></b></td>\n"
      "<td align=right><b><a href='browser.pike?db=&form.db:http;&table=&form.table:http;&sort=rows'>"+

      SEL("rows",0)+String.capitalize(_(374,"rows"))+
      "</a></b></td>\n"
      "<td align=right><b><a href='browser.pike?db=&form.db:http;&table=&form.table:http;&sort=size'>"+

      SEL("size",0)+_(377,"Size")+
      "</a></b></td>\n"
      "</tr>";
  }

  res += column( table_data, 3 )*"\n";

  res += "</table></td></tr></table>";


  res +=
    "<table><tr><td valign=top><font size=-1>"
    "<textarea rows=8 cols=50 wrap=soft name='query'>&form.query:html;</textarea>"
    "</font></td><td valign=top>"
    "<submit-gbutton2 name=clear_q> "+_(378,"Clear query")+" </submit-gbutton2>"
    "<br />"
    "<submit-gbutton2 name=run_q> "+_(379,"Run query")+" </submit-gbutton2>"
    "<br /></td></tr></table>";


  res += qres;


#define ADD_ACTION(X) if(!actions[X][2] || \
			 DBManager.is_internal(id->variables->db) ) \
   res += sprintf("<a href='%s?db=%s&action=%s'><gbutton>%s</gbutton></a>\n",\
		  id->not_query, id->variables->db, X, actions[X][0] )
  
  switch( id->variables->db )
  {
    case "local":
      foreach( ({ "move","backup" }), string x )
	ADD_ACTION( x );
      break;
      
    default:
      foreach( sort(indices( actions )), string x )
	ADD_ACTION( x );
      break;
  }
  return res+"</st-page></subtablist></cv-split></content></tmpl>";
}
