// This is a roxen module. Copyright © 1997-2001, Roxen IS.
//

constant cvs_version = "$Id: sqltag.pike,v 1.78 2001/06/11 21:02:53 nilsson Exp $";
constant thread_safe = 1;
#include <module.h>

inherit "module";

//<locale-token project="mod_sqltag">LOCALE</locale-token>
//<locale-token project="mod_sqltag">SLOCALE</locale-token>
#define SLOCALE(X,Y)	_STR_LOCALE("mod_sqltag",X,Y)
#define LOCALE(X,Y)	_DEF_LOCALE("mod_sqltag",X,Y)
// end locale stuff

// Module interface functions

constant module_type=MODULE_TAG|MODULE_PROVIDER;
LocaleString module_name=LOCALE(1,"Tags: SQL tags");
LocaleString module_doc =
LOCALE(2,
       "The SQL tags module provides the tags <tt>&lt;sqlquery&gt;</tt> and"
       "<tt>&lt;sqltable&gt;</tt> as well as being a source to the "
       "<tt>&lt;emit&gt;</tt> tag (<tt>&lt;emit source=\"sql\" ... &gt;</tt>)."
       "All tags send queries to SQL databases.");

TAGDOCUMENTATION
#ifdef manual
constant tagdoc=([
"sqltable":#"
<desc tag='tag'><p><short>
 Creates an HTML or ASCII table from the results of an SQL query.
</short></p>
</desc>

<attr name='ascii'><p>
 Create an ASCII table rather than a HTML table. Useful for
 interacting with <xref href='../graphics/diagram.tag' /> and <xref
 href='../text/tablify.tag' />.</p>
</attr>

<attr name='host' value='database'><p>
 Which database to connect to, usually a symbolic name set in the <xref
 href='../../administrator/installing/databases.xml'><module>SQL
 Databases</module></xref> module. If omitted the default database will
 be used.</p>
</attr>

<attr name='query' value='SQL statement'><p>
 The actual SQL-statement.</p>
</attr>

<attr name='parse'><p>
 If specified, the query will be parsed by the RXML parser.
 Useful if you wish to dynamically build the query.</p>
</attr>",

"sqlquery":#"
<desc tag='tag'><p><short>
 Executes an SQL query, but doesn't do anything with the
 result.</short> This is mostly used for SQL queries that change the
 contents of the database, for example INSERT or UPDATE.</p>
</desc>

<attr name='host' value='database'><p>
 Which database to connect to, usually a symbolic name set in the <xref
 href='../../administrator/installing/databases.xml'><module>SQL
 Databases</module></xref> module. If omitted the default
 database will be used.</p>
</attr>

<attr name='query' value='SQL statement'><p>
 The actual SQL-statement.</p>
</attr>

<attr name='parse'><p>
 If specified, the query will be parsed by the RXML parser. Useful if
 you wish to dynamically build the query. This attribute is deprecated
 and will have no effect if the servers compatibility level is above 2.1.</p>
</attr>

<attr name='mysql-insert-id' value='form-variable'><p>
 Set form-variable to the insert id used by Mysql for
 auto-incrementing columns. Note: This is only available with Mysql.</p>
</attr>",

"emit#sql":#"<desc plugin='plugin'><p><short>

 Use this source to connect to and query SQL databases for
 information.</short> The result will be available in variables named
 as the SQL columns.</p>
</desc>

<attr name='host' value='database'><p>
 Which database to connect to, usually a symbolic name set in the <xref
 href='../../administrator/installing/databases.xml'><module>SQL
 Databases</module></xref> module. If omitted the default
 database will be used.</p>
</attr>

<attr name='query' value='SQL statement'><p>
 The actual SQL-statement.</p>
</attr>"
]);
#endif


// --------------------------- Database query code --------------------------------

#if ROXEN_COMPAT <= 1.3
string compat_default_host;
#endif
string default_db;

array|object do_sql_query(mapping args, RequestID id,
			  void|int(0..1) big_query)
{
  string host;
  if (args->host)
  {
    host=args->host;
    args->host="SECRET";
  }
  if(args->db) {
    host = args->db;
    args->db = "SECRET";
  }

#if ROXEN_COMPAT <= 2.1
  if (args->parse && id->conf->query("compat_level") < "2.2")
    args->query = Roxen.parse_rxml(args->query, id);
#endif

  Sql.Sql con;
  array(mapping(string:mixed))|object result;
  mixed error;
  
#if ROXEN_COMPAT <= 1.3
  if( !args->db && (host || query("db")==" none") )
  {
    function sql_connect = id->conf->sql_connect;
    error = catch(con = sql_connect(host || compat_default_host));

    if (error)
      RXML.run_error(LOCALE(3,"Couldn't connect to SQL server")+
                     ": "+error[0]+"\n");

    // Got a connection now. Any errors below this point ought to be
    // syntax errors and should be reported with parse_error.
  }
  else
  {
#endif
    error = catch(con = DBManager.get( host || default_db || compat_default_host,
				       my_configuration() ));
    if (error)
      RXML.run_error(LOCALE(3,"Couldn't connect to SQL server")+
                     ": "+error[0]+"\n");
#if ROXEN_COMPAT <= 1.3
  }
#endif

  if (error = catch(result = (big_query?con->big_query(args->query):
                              con->query(args->query))))
  {
    error = con->error();
    if (error) error = ": " + error;
    error = sprintf("Query failed%s\n", error||".");
    RXML.parse_error(error);
  }

  args->dbobj=con;

  if(result && args->rowinfo) {
    int rows;
    if(arrayp(result)) rows=sizeof(result);
    if(objectp(result)) rows=result->num_rows();
    RXML.user_set_var(args->rowinfo, rows);
  }

  return result;
}


// -------------------------------- Tag handlers ------------------------------------

#if ROXEN_COMPAT <= 1.3
class TagSQLOutput {
  inherit RXML.Tag;
  constant name = "sqloutput";

  mapping(string:RXML.Type) req_arg_types = ([ "query":RXML.t_text(RXML.PEnt) ]);
  RXML.Type content_type = RXML.t_same;
  array(RXML.Type) result_types = ({ RXML.t_any(RXML.PXml) });

  class Frame {
    inherit RXML.Frame;
    inherit "roxenlib";

    array do_return(RequestID id) {
      NOCACHE();

      array res=do_sql_query(args, id);

      if (res && sizeof(res)) {
	result = do_output_tag(args, res, content, id);
	id->misc->defines[" _ok"] = 1; // The effect of <true>, since res isn't parsed.

	return 0;
      }

      if (args["do-once"]) {
	result = do_output_tag( args, ({([])}), content, id );
	id->misc->defines[" _ok"] = 1;
	return 0;
      }

      id->misc->defines[" _ok"] = 0;
      return 0;
    }
  }
}
#endif

class TagSqlplugin {
  inherit RXML.Tag;
  inherit "emit_object";
  constant name = "emit";
  constant plugin_name = "sql";
  mapping(string:RXML.Type) req_arg_types = ([ "query":RXML.t_text(RXML.PEnt) ]);
  mapping(string:RXML.Type) opt_arg_types = ([
    "host":RXML.t_text(RXML.PEnt),
    "db":RXML.t_text(RXML.PEnt),
  ]);

  class Response {
    inherit EmitObject;
    private object sqlres;
    private array(string) cols;
    private int fetched;

    private mapping(string:mixed) really_get_row() {
      array val = sqlres->fetch_row();
      if(val)
	fetched++;
      else
	return 0;
      return mkmapping(cols, val);
    }

    int num_rows_left() {
      return sqlres->num_rows() - fetched + !!next_row;
    }

    void create(object _sqlres) {
      sqlres = _sqlres;
      cols = sqlres->fetch_fields()->name;
    }
  }

  object get_dataset(mapping m, RequestID id) {
    return Response(do_sql_query(m-(["rowinfo":""]), id, 1));
  }
}

class TagSQLQuery {
  inherit RXML.Tag;
  constant name = "sqlquery";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  mapping(string:RXML.Type) req_arg_types = ([ "query":RXML.t_text(RXML.PEnt) ]);
  mapping(string:RXML.Type) opt_arg_types = ([
    "host":RXML.t_text(RXML.PEnt),
    "db":RXML.t_text(RXML.PEnt),
    "mysql-insert-id":RXML.t_text(RXML.PEnt), // t_var
  ]);

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      NOCACHE();

      array res=do_sql_query(args, id);

      if(args["mysql-insert-id"])
	if(args->dbobj && args->dbobj->master_sql)
	  RXML.user_set_var(args["mysql-insert-id"], args->dbobj->master_sql->insert_id());
	else
	  RXML.parse_error("No insert_id present.\n");

      id->misc->defines[" _ok"] = 1;
      return 0;
    }
  }
}

class TagSQLTable {
  inherit RXML.Tag;
  constant name = "sqltable";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  mapping(string:RXML.Type) req_arg_types = ([ "query":RXML.t_text(RXML.PEnt) ]);
  mapping(string:RXML.Type) opt_arg_types = ([
    "host":RXML.t_text(RXML.PEnt),
    "db":RXML.t_text(RXML.PEnt),
    "ascii":RXML.t_text(RXML.PEnt), // t_bool
    "nullvalue":RXML.t_text(RXML.PEnt),
  ]);

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      NOCACHE();

      object res=do_sql_query(args, id, 1);

      int ascii=!!args->ascii;
      string ret="";

      if (res) {
	string nullvalue=args->nullvalue||"";

	if (!ascii) {
	  ret="<tr>";
	  foreach(res->fetch_fields(), mapping m)
	    ret += "<th>"+m->name+"</th>";
	  ret += "</tr>\n";
	}

	array row;
	while(row=res->fetch_row()) {
	  if (ascii)
	    ret += map(row, lambda(mixed in) {
			      if(!in) return nullvalue;
			      return (string)in;
			    }) * "\t" + "\n";
	  else {
	    ret += "<tr>";
	    foreach(row, mixed value)
	      ret += "<td>" + (!value?nullvalue:(string)value) + "</td>";
	    ret += "</tr>\n";
	  }
	}

	if (!ascii)
	  ret=Roxen.make_container("table",
				   args-(["host":"","database":"","user":"",
					  "password":"","query":"","db":"",
					  "nullvalue":"","dbobj":""]), ret);

	id->misc->defines[" _ok"] = 1;
	result=ret;
	return 0;
      }

      id->misc->defines[" _ok"] = 0;
      return 0;
    }
  }
}


// ------------------------ Setting the defaults -------------------------

class DatabaseVar
{
  inherit Variable.StringChoice;
  array get_choice_list( )
  {
    return ({ " none" })
           + sort(DBManager.list( my_configuration() ));
  }
}

void create()
{
#if ROXEN_COMPAT <= 1.3
  defvar("hostname", "mysql://localhost/",
         LOCALE(4,"Default database"),
	 TYPE_STRING | VAR_INVISIBLE,
	 LOCALE(5,"The default database that will be used if no <i>host</i> "
	 "attribute is given to the tags. "
	 "The value is a database URL in this format:\n"
	 "<p><blockquote><pre>"
	 "<i>driver</i><b>://</b>"
	 "[<i>username</i>[<b>:</b><i>password</i>]<b>@</b>]"
	 "<i>host</i>[<b>:</b><i>port</i>]"
	 "[<b>/</b><i>database</i>]\n"
	 "</pre></blockquote>\n"
	 "<p>If the <i>SQL databases</i> module is loaded, it's also "
	 "possible to use an alias registered there. That's the "
	 "recommended way, since this (usually sensitive) data is "
	 "collected in one place then."));
#endif
  defvar( "db",
          DatabaseVar( " none",({}),0,
                       LOCALE(4,"Default database"),
                       LOCALE(8,"If this is defined, it's the "
                              "database this server will use as the "
                              "default database") ) );
}


// --------------------- More interface functions --------------------------

void start()
{
#if ROXEN_COMPAT <= 1.3
  compat_default_host = query("hostname");
#endif
  default_db          = query("db");
}

string status()
{
  if( query("db") != " none" )
  {
    if(mixed err = catch {
      object o = DBManager.get(query("db"),my_configuration());
      if(!o)
        error("The database specified as default database does not exist");
      return sprintf(LOCALE(6,"The default database is connected to %s "
                            "server on %s.")+
                     "<br />\n",
                     Roxen.html_encode_string (o->server_info()),
                     Roxen.html_encode_string (o->host_info()));
    })
    {
      return
        "<font color=\"red\">"+
        LOCALE(7,"The default database is not connected")+
        ":</font><br />\n" +
        replace( Roxen.html_encode_string( describe_error(err) ),
                 "\n", "<br />\n") +
        "<br />\n";
    }
  }
  return "";
}
