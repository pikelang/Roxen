// This is a roxen module. Copyright © 1997 - 2004, Roxen IS.
//

constant cvs_version = "$Id: sqltag.pike,v 1.111 2008/09/15 18:36:49 mast Exp $";
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

<attr name='db' value='database'><p>
 Which database to connect to, among the list of databases configured
 under the \"DBs\" tab in the administrator interface. If omitted then
 the default database will be used.</p>
</attr>

<attr name='host' value='url'><p>
 A database URL to specify the database to connect to, if permitted by
 the module settings. If omitted then the default database will be
 used.</p>

 <p>The database URL is on this format:</p>

 <blockquote><i>driver</i><b>://</b>[<i>username</i>[<b>:</b><i>password</i>]<b>@</b>]<i>host</i>[<b>:</b><i>port</i>][<b>/</b><i>database</i>]</blockquote>

 <p>where <i>driver</i> is the database protocol, e.g. \"odbc\",
 \"mysql\", \"oracle\", \"postgres\", etc.</p>

 <p>For compatibility this can also be a database name as given to the
 \"db\" attribute.</p>
</attr>

<attr name='module' value='string'><p>
 Access the local database for the specified Roxen module, if
 permitted by the module settings. This attribute is deprecated.</p>
</attr>

<attr name='query' value='SQL statement'><p>
 The actual SQL-statement.</p>
</attr>

<attr name='parse'><p>
 If specified, the query will be parsed by the RXML parser.
 Useful if you wish to dynamically build the query.</p>
</attr>

<attr name='charset' value='string'><p>
 Use the specified charset for the SQL statement. See the description
 for the \"sql\" emit source for more info.</p>
</attr>

<attr name='ascii'><p>
 Create an ASCII table rather than an HTML table. Useful for
 interacting with <xref href='../graphics/diagram.tag' /> and <xref
 href='../text/tablify.tag' />.</p>
</attr>",

"sqlquery":#"
<desc tag='tag'><p><short>
 Executes an SQL query, but doesn't do anything with the
 result.</short> This is mostly used for SQL queries that change the
 contents of the database, for example INSERT or UPDATE.</p>
</desc>

<attr name='db' value='database'><p>
 Which database to connect to, among the list of databases configured
 under the \"DBs\" tab in the administrator interface. If omitted then
 the default database will be used.</p>
</attr>

<attr name='host' value='url'><p>
 A database URL to specify the database to connect to, if permitted by
 the module settings. If omitted then the default database will be
 used.</p>

 <p>The database URL is on this format:</p>

 <blockquote><i>driver</i><b>://</b>[<i>username</i>[<b>:</b><i>password</i>]<b>@</b>]<i>host</i>[<b>:</b><i>port</i>][<b>/</b><i>database</i>]</blockquote>

 <p>where <i>driver</i> is the database protocol, e.g. \"odbc\",
 \"mysql\", \"oracle\", \"postgres\", etc.</p>

 <p>For compatibility this can also be a database name as given to the
 \"db\" attribute.</p>
</attr>

<attr name='module' value='string'><p>
 Access the local database for the specified Roxen module, if
 permitted by the module settings. This attribute is deprecated.</p>
</attr>

<attr name='query' value='SQL statement'><p>
 The actual SQL-statement.</p>
</attr>

<attr name='parse'><p>
 If specified, the query will be parsed by the RXML parser. Useful if
 you wish to dynamically build the query. This attribute is deprecated
 and will have no effect if the servers compatibility level is above 2.1.</p>
</attr>

<attr name='bindings' value='\"name=variable,name=variable,...\"'><p>
Specifies binding variables to use with this query. This is comma separated
list of binding variable names and RXML variables to assign to those
binding variables.
<i>Note:</i> For some databases it is necessary to use binding variables when
inserting large datas. Oracle, for instance, limits the query to 4000 bytes.
<ex-box>
<set variable='var.foo' value='texttexttext' />
<sqlquery query='insert into mytable VALUES (4,:foo,:bar)' 
          bindings='foo=var.foo,bar=form.bar' />
</ex-box>
</p>
</attr>

<attr name='mysql-insert-id' value='variable'><p>
 Set the given variable to the insert id used by MySQL for
 auto-incrementing columns. Note: This is only available with MySQL.</p>
</attr>

<attr name='charset' value='string'><p>
 Use the specified charset for the SQL statement. See the description
 for the \"sql\" emit source for more info.</p>
</attr>",

"emit#sql":#"<desc type='plugin'><p><short>

 Use this source to connect to and query SQL databases for
 information.</short> The result will be available in variables named
 as the SQL columns.</p>
</desc>

<attr name='db' value='database'><p>
 Which database to connect to, among the list of databases configured
 under the \"DBs\" tab in the administrator interface. If omitted then
 the default database will be used.</p>
</attr>

<attr name='host' value='url'><p>
 A database URL to specify the database to connect to, if permitted by
 the module settings. If omitted then the default database will be
 used.</p>

 <p>The database URL is on this format:</p>

 <blockquote><i>driver</i><b>://</b>[<i>username</i>[<b>:</b><i>password</i>]<b>@</b>]<i>host</i>[<b>:</b><i>port</i>][<b>/</b><i>database</i>]</blockquote>

 <p>where <i>driver</i> is the database protocol, e.g. \"odbc\",
 \"mysql\", \"oracle\", \"postgres\", etc.</p>

 <p>For compatibility this can also be a database name as given to the
 \"db\" attribute.</p>
</attr>

<attr name='module' value='string'><p>
 Access the local database for the specified Roxen module, if
 permitted by the module settings. This attribute is deprecated.</p>
</attr>

<attr name='query' value='SQL statement'><p>
 The actual SQL-statement.</p>
</attr>

<attr name='bindings' value='\"name=variable,name=variable,...\"'><p>
Specifies binding variables to use with this query. This is comma separated
list of binding variable names and RXML variables to assign to those
binding variables.
<i>Note:</i> For some databases it is necessary to use binding variables when
inserting large datas. Oracle, for instance, limits the query to 4000 bytes.
<ex-box>
<set variable='var.foo' value='texttexttext' />
<sqlquery query='insert into mytable VALUES (4,:foo,:bar)' 
          bindings='foo=var.foo,bar=form.bar' />
</ex-box>
</p>
</attr>

<attr name='charset' value='string'><p>
 Use the specified charset for the SQL statement and returned text
 values.</p>

 <p>The valid charsets depend on the type of database connection.
 However, the special value \"unicode\" configures the connection to
 accept and return unencoded (possibly wide) unicode strings (provided
 the connection supports this).</p>

 <p>An RXML run error is thrown if the database connection doesn't
 support the given charset or has no charset support at all. (At least
 MySQL 4.1 and later has support.)</p>
</attr>"
]);
#endif


// --------------------------- Database query code --------------------------------

#if ROXEN_COMPAT <= 1.3
string compat_default_host;
#endif
string default_db, default_charset;

int allow_sql_urls, allow_module_dbs;
mapping(string:int(1..1)) allowed_dbs = ([]); // 0 if all dbs are allowed.

//  Cached copy of conf->query("compat_level"). This setting is defined
//  to require a module reload to take effect so we only query it when
//  start() is called.
string compat_level;


Sql.Sql get_rxml_sql_con (string db, void|string host, void|RequestID id,
			  void|int read_only, void|int reuse_in_thread,
			  void|string charset)
//! This function is useful from other modules via the
//! @tt{"rxml_sql"@} provider interface: It applies the security
//! settings configured in this module to check whether the requested
//! database is allowed. It should be used in any module that allows
//! users to make sql queries to databases through rxml or other
//! server side scripts.
//!
//! @param db
//!   Corresponds to the @tt{"db"@} attribute to the @tt{<sql>@} tag.
//!   Defaults to the "Default database" module setting.
//!
//! @param host
//!   Corresponds to the @tt{"host"@} attribute to the @tt{<sql>@}
//!   tag.
//!
//! @param id
//!   Note: Optional.
//!
//! @param read_only
//! @param reuse_in_thread
//! @param charset
//!   Passed on to @[DBManager.get] (if called). The default charset
//!   configured in this module is used if @[charset] isn't given.
//!
//! @throws
//!   Connection errors, access errors and syntax errors in @[db],
//!   @[host] and @[module] are thrown as RXML errors.
{
  string real_host = host;
  if (host) host = "CENSORED";

  Sql.Sql con;
  mixed error;

#if ROXEN_COMPAT <= 1.3
  if( !db && (real_host || default_db == " none") ) {
    string h = real_host || compat_default_host;
    if (h && has_prefix (h, "mysql://")) {
      if (real_host && !allow_sql_urls) {
	report_warning ("Connection to %O attempted from %O.\n",
			real_host, id && id->raw_url);
	RXML.parse_error ("Database access through SQL URLs not allowed.\n");
      }

      error = catch {
	  con = my_configuration()->
	    sql_connect(h, charset || default_charset);
	};
    }
  }

  if (!con && !error)
#endif
  {
    if (!db) db = real_host;
    if (db && allowed_dbs && !allowed_dbs[db] && db != default_db) {
      report_warning ("Connection to database %O attempted from %O.\n",
		      db, id && id->raw_url);
      RXML.parse_error ("Database %O is not in the list "
			"of allowed databases.\n", db);
    }

    if (!db) {
      if (default_db != " none") db = default_db;
      else if (compat_default_host &&
	       !has_prefix (compat_default_host, "mysql://"))
	db = compat_default_host;
      else
	RXML.parse_error ("No database specified and no default database "
			  "configured.\n");
    }

    error = catch {
	con = DBManager.get (db, my_configuration(), read_only,
			     reuse_in_thread, charset || default_charset);
      };
  }

  if (error || !con) {
#if 0
    werror (describe_backtrace (error));
#endif
    RXML.run_error(error ? describe_error (error) :
		   (LOCALE(3,"Couldn't connect to SQL server") + "\n"));
  }

  return con;
}

array|object do_sql_query(mapping args, RequestID id,
			  void|int(0..1) big_query,
			  void|int(0..1) ret_con)
{
  string host;
  if (args->host)
  {
    host=args->host;
    args->host="SECRET";
  }
#if ROXEN_COMPAT <= 2.1
  if (args->parse && compat_level < "2.2")
    args->query = Roxen.parse_rxml(args->query, id);
#endif

  Sql.Sql con;
  array(mapping(string:mixed))|object result;
  mixed error;
  int ro = !!args["read-only"];

  mapping bindings;
  
  if(args->bindings) {
    bindings = ([ ]);
    foreach(args->bindings / ",", string tmp) {
      string tmp2,tmp3;
      if(sscanf(String.trim_all_whites(tmp),"%s=%s", tmp2, tmp3) == 2) {
	bindings[tmp2] = RXML.user_get_var( tmp3 );
      }
    }
  }

  if( args->module )
  {
    if (!allow_module_dbs) {
      report_warning ("Connection to module database for %O "
		      "attempted from %O.\n", args->module, id->raw_url);
      RXML.parse_error ("Invalid \"module\" attribute - "
			"database access through modules not allowed.\n");
    }

    RoxenModule module=id->conf->find_module(replace(args->module,"!","#"));
    if( !module )
      RXML.run_error( (string)LOCALE(9,"Cannot find the module %s"),
		      args->module );

    if( error = catch {
	con = module->get_my_sql (ro, args->charset || default_charset);
      } ) {
#if 0
      werror (describe_backtrace (error));
#endif
      RXML.run_error(LOCALE(3,"Couldn't connect to SQL server")+
		     ": "+ describe_error (error) +"\n");
    }
      
    if( error = catch
    {
      string f=(big_query?"big_query":"query")+(ro?"_ro":"");
      result = bindings ?  
	module["sql_"+f]( args->query, bindings ) :
	module["sql_"+f]( args->query );
    } )
    {
      error = sprintf("Query failed: %s\n",
		      con->error() || describe_error(error));
      RXML.run_error(error);
    }
  }
  else
  {
#if ROXEN_COMPAT <= 1.3
    if( !args->db && (host || default_db == " none") ) {
      string h = host || compat_default_host;
      if (h && has_value (h, "://")) {
	if (host && !allow_sql_urls) {
	  report_warning ("Connection to %O attempted from %O.\n",
			  host, id->raw_url);
	  RXML.parse_error ("Invalid \"host\" attribute - "
			    "database access through SQL URLs not allowed.\n");
	}
	error = catch {
	    con = id->conf->sql_connect(h, args->charset || default_charset);
	  };
      }
    }

    if(!con)
#endif
    {
      string db = host || args->db;
      if (db && allowed_dbs && !allowed_dbs[db] && db != default_db) {
	report_warning ("Connection to database %O attempted from %O.\n",
			db, id->raw_url);
	RXML.parse_error ("Database %O is not in the list "
			  "of allowed databases.\n", db);
      }
      error = catch(con = DBManager.get( db || default_db||compat_default_host,
					 my_configuration(), ro, 0,
					 args->charset || default_charset));
    }

    if( !con ) {
#if 0
      werror (describe_backtrace (error));
#endif
      RXML.run_error(LOCALE(3,"Couldn't connect to SQL server")+
		     (error?": "+ describe_error (error) :"")+"\n");
    }

    function query_fn = (big_query ? con->big_query : con->query); 
    if( error = catch( result = (bindings ? query_fn(args->query, bindings) : query_fn(args->query))) ) {
      error = sprintf("Query failed: %s\n",
		      con->error() || describe_error(error));
      RXML.run_error(error);
    }
  }

  if (ret_con) {
    // NOTE: Use of this feature may lead to circularities...
    args->dbobj=con;
  }
  if(result && args->rowinfo) {
    int rows;
    if(arrayp(result)) rows=sizeof(result);
    if(objectp(result)) rows=result->num_rows();
    RXML.user_set_var(args->rowinfo, rows);
    if(objectp(result)) m_delete(args, "rowinfo");
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

inherit "emit_object";

class SqlEmitResponse {
  inherit EmitObject;
  private object sqlres;
  private array(string) cols;
  private int fetched;

  private mapping(string:mixed) really_get_row() {
    array val;
    if(sqlres && (val = sqlres->fetch_row()))
      fetched++;
    else {
      sqlres = 0;
      return 0;
    }
    val = map(val, lambda(mixed x) {
		     if (x) return x;
		     // Might be a dbnull object which considers
		     // itself false (e.g. in the oracle glue).
		     if ((x != 0) && stringp(x->type))
		       // Transform NULLString to "".
		       return x->type;
		     // It's 0 or a null object. Treat it as the value
		     // doesn't exist at all (ideally there should be
		     // some sort of dbnull value at the rxml level
		     // too to tell these cases apart).
		     return RXML.nil;
		   });
    return mkmapping(cols, val);
  }

  int num_rows_left() {
    if(!sqlres) return !!next_row;
    return sqlres->num_rows() - fetched + !!next_row;
  }

  void create(object _sqlres) {
    sqlres = _sqlres;
    if (sqlres) cols = sqlres->fetch_fields()->name;
  }
}

class TagSqlplugin {
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "sql";
  mapping(string:RXML.Type) req_arg_types = ([ "query":RXML.t_text(RXML.PEnt) ]);
  mapping(string:RXML.Type) opt_arg_types = ([
    "host":RXML.t_text(RXML.PEnt),
    "db":RXML.t_text(RXML.PEnt),
  ]);

  object get_dataset(mapping m, RequestID id) {
    // Haven't verified that the NOCACHE here is actually needed, but
    // in the worst case it's just unnecessary.
    NOCACHE();
    return SqlEmitResponse(do_sql_query(m+([]), id, 1));
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

      array res=do_sql_query(args, id, 0, 1);

      object con = args->dbobj;
      m_delete(args, "dbobj");

      if(args["mysql-insert-id"]) {
	if(con && con->master_sql)
	  RXML.user_set_var(args["mysql-insert-id"],
			    con->master_sql->insert_id());
	else
	  RXML.run_error("No insert_id present.\n");
      }
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
	      ret += "<td>" + (string)(value || nullvalue) + "</td>";
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
	 LOCALE(5, #"
<p>The default database that will be used if no \"host\" attribute
is given to the tags. The value is a database URL on this format:</p>

<blockquote><i>driver</i><b>://</b>[<i>username</i>[<b>:</b><i>password</i>]<b>@</b>]<i>host</i>[<b>:</b><i>port</i>][<b>/</b><i>database</i>]</blockquote>

<p>where <i>driver</i> is the database protocol, e.g. \"odbc\",
\"mysql\", \"oracle\", \"postgres\", etc.</p>

<p>It is also possible to specify a database name from the \"DBs\" tab
here, but the recommended way is to use the \"Default database\"
setting instead.</p>"));
#endif

  defvar( "db",
          DatabaseVar( " none",({}),0,
                       LOCALE(4,"Default database"),
		       LOCALE(8, #"\
<p>If this is set, it is the default database to connect to.</p>

<p>If both \"Allow SQL URLs\" and \"Allowed databases\" are disabled
then this is the only database that the tags will use, and the
\"host\" and \"db\" attributes are effectively disabled.</p>") ) );

  defvar ("allow_sql_urls", 1,
	  LOCALE(0, "Allow SQL URLs"),
	  TYPE_FLAG,
	  LOCALE(0, #"\
<p>Allow generic SQL URLs in the \"host\" attribute to the tags. This
can be a security hazard if users are allowed to write RXML - the
server will make the connection as the user it is configured to run
as.</p>

<p>In particular, allowing this makes it possible to write RXML that
connects directly to the socket of Roxen's internal MySQL server,
thereby bypassing the permissions set under the \"DBs\" tab. It is
therefore strongly recommended to keep this disabled and instead
configure all database connections through the \"DBs\" tab.</p>

<p>Compatibility note: For compatibility reasons, this setting is
enabled by default in Roxen 4.5 but will be disabled in 5.0.</p>"));

  defvar ("allowed_dbs", "*",
	  LOCALE(0, "Allowed databases"),
	  TYPE_STRING,
	  LOCALE(0, #"\
<p>A comma-separated list of the databases under the \"DBs\" tab that
are allowed in the \"db\" attribute to the tags. The database in the
\"Default database\" setting is also implicitly allowed. Set to \"*\"
to make no restriction. In addition to this check, the permission
settings under the \"DBs\" tab are applied.</p>

<p>By default no databases are allowed, thus forcing you to list all
allowed databases here and/or in the \"Default database\" setting.
Note that specifying \"*\" can be a security hazard since that makes
it possible to access internal databases (some of which can contain
sensitive security information). It is not possible to restrict access
to those databases under the \"DBs\" tab since that would make them
inaccessible to the internal modules too.</p>

<p>Compatibility note: For compatibility reasons, this setting is set
to \"*\" by default in Roxen 4.5 but will be disabled in 5.0.</p>"));

  defvar ("allow_module_dbs", 1,
	  LOCALE(0, "Support \"module\" attribute"),
	  TYPE_FLAG,
	  LOCALE(0, #"\
<p>Support the deprecated \"module\" attribute to the tags.</p>

<p>Compatibility note: For compatibility reasons, this setting is
enabled by default in Roxen 4.5 but will be disabled in 5.0.</p>"));

  defvar ("charset", "",
	  LOCALE(10, "Default charset"),
	  TYPE_STRING,
	  LOCALE(11, #"\
<p>The default value to use for the <i>charset</i> attribute to the
SQL tags. See the description for the \"sql\" emit source for more
details.</p>

<p>Note that not all database connection supports this, and the tags
will throw errors if this is used in such cases. MySQL 4.1 or later
supports it.</p>"));
}


// --------------------- More interface functions --------------------------

multiset(string) query_provides() {return (<"rxml_sql">);}

void start()
{
#if ROXEN_COMPAT <= 1.3
  compat_default_host = query("hostname");
#endif
  default_db          = query("db");
  default_charset = query ("charset");
  if (default_charset == "") default_charset = 0;
  compat_level = my_configuration()->query("compat_level");

  allow_sql_urls = query ("allow_sql_urls");
  allow_module_dbs = query ("allow_module_dbs");

  string dbs = query ("allowed_dbs");
  if (dbs == "*") allowed_dbs = 0;
  else {
    allowed_dbs = ([]);
    foreach (dbs / ",", string db) {
      db = String.trim_all_whites (db);
      if (db != "") allowed_dbs[db] = 1;
    }
  }
}

string status()
{
  string res = "";

  if( default_db != " none" )
  {
    if(mixed err = catch {
      object o = DBManager.get(default_db, my_configuration());
      if(!o)
        error("The database specified as default database does not exist");
      res += "<p>" +
	sprintf(LOCALE(6,"The default database is connected to %s "
		       "server on %s."),
		Roxen.html_encode_string (o->server_info()),
		Roxen.html_encode_string (o->host_info())) +
	"</p>\n";
    })
    {
      res +=
	"<p><font color=\"red\">"+
        LOCALE(7,"The default database is not connected")+
	":</font><br />\n" +
        replace( Roxen.html_encode_string( describe_error(err) ),
                 "\n", "<br />\n") +
	"</p>\n";
    }
  }

  if (allow_sql_urls)
    res += "<p><font color=\"red\">" + LOCALE(0, "Security warning:") +
      "</font> " +
      LOCALE(0, "Connections to arbitrary databases allowed. See the "
	     "\"Allow SQL URLs\" setting.") +
      "</p>\n";

  if (!allowed_dbs)
    res += "<p><font color=\"red\">" + LOCALE(0, "Security warning:") +
      "</font> " +
      LOCALE(0, "Connections to all configured database allowed. See the "
	     "\"Allowed databases\" setting.") +
      "</p>\n";

  if (allow_module_dbs)
    res += "<p><font color=\"red\">" + LOCALE(0, "Security warning:") +
      "</font> " +
      LOCALE(0, "Connections to module databases allowed. See the "
	     "\"Support 'module' attribute\" setting.") +
      "</p>\n";

  return res;
}
