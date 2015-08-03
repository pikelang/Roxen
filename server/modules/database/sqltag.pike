// This is a roxen module. Copyright © 1997 - 2009, Roxen IS.
//

constant cvs_version = "$Id$";
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
       "The SQL tags module provides the tags <tt>&lt;sqlquery&gt;</tt> and "
       "<tt>&lt;sqltable&gt;</tt> as well as being a source to the "
       "<tt>&lt;emit&gt;</tt> tag (<tt>&lt;emit source=\"sql\" ...&gt;</tt>). "
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

 <blockquote><p><i>driver</i><b>://</b>[<i>username</i>[<b>:</b><i>password</i>]<b>@</b>]<i>host</i>[<b>:</b><i>port</i>][<b>/</b><i>database</i>]</p></blockquote>

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
 and will have no effect if the server compatibility level is above 2.1.</p>
</attr>

<attr name='charset' value='string'><p>
 Use the specified charset for the SQL statement. See the description
 of the same attribute for the \"sql\" emit source for more info.</p>
</attr>

<attr name='ascii'><p>
 Create an ASCII table rather than an HTML table. Useful for
 interacting with <tag>diagram</tag> or <tag>tablify</tag>.</p>
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

 <blockquote><p><i>driver</i><b>://</b>[<i>username</i>[<b>:</b><i>password</i>]<b>@</b>]<i>host</i>[<b>:</b><i>port</i>][<b>/</b><i>database</i>]</p></blockquote>

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
 and will have no effect if the server compatibility level is above 2.1.</p>
</attr>

<attr name='bindings' value='name=variable,name=variable,...'><p>
 Specifies binding variables to use with this query. This is comma separated
 list of binding variable names and RXML variables to assign to those
 binding variables.</p>

 <p><i>Note:</i> For some databases it is necessary to use binding
 variables when inserting large values. Oracle, for instance, limits
 the query to 4000 bytes.</p>

 <ex-box>
<set variable='var.foo' value='texttexttext'/>
<sqlquery query='insert into mytable VALUES (4,:foo,:bar)' 
          bindings='foo=var.foo,bar=form.bar'/>
</ex-box>
</attr>

<attr name='mysql-insert-id' value='variable'><p>
 Set the given variable to the insert id used by MySQL for
 auto-incrementing columns. Note: This is only available when MySQL is
 used.</p>
</attr>

<attr name='charset' value='string'><p>
 Use the specified charset for the SQL statement. See the description
 for the \"sql\" emit source for more info.</p>
</attr>",

"emit#sql":#"<desc type='plugin'><p><short>
 Use this source to connect to and query SQL databases for
 information.</short> The result will be available in variables named
 as the SQL columns.</p>

 <p>NULL values in the SQL result are mapped to the special null
 value, <ent>roxen.null</ent>. That value expands to the empty string
 if inserted, and tests as false with <tag>if variable</tag> and true
 with <tag>if variable-exists</tag>.</p>

 <p><i>Compatibility note:</i> If the compatibility level is 4.5 or
 lower, an SQL NULL value instead maps to an undefined value in RXML,
 which is similar to that the RXML variable doesn't exist at all. That
 makes both <tag>if variable</tag> and <tag>if variable-exists</tag>
 return false for it, among other things.</p>
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

 <blockquote><p><i>driver</i><b>://</b>[<i>username</i>[<b>:</b><i>password</i>]<b>@</b>]<i>host</i>[<b>:</b><i>port</i>][<b>/</b><i>database</i>]</p></blockquote>

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

<attr name='bindings' value='name=variable,name=variable,...'><p>
 Specifies binding variables to use with this query. This is comma
 separated list of binding variable names and RXML variables to assign
 to those binding variables.</p>

 <p><i>Note:</i> For some databases it is necessary to use binding
 variables when inserting large datas. Oracle, for instance, limits the
 query to 4000 bytes.</p>

 <ex-box>
<set variable='var.foo' value='texttexttext'/>
<sqlquery query='insert into mytable VALUES (4,:foo,:bar)' 
          bindings='foo=var.foo,bar=form.bar'/>
</ex-box>
</attr>

<attr name='charset' value='string'><p>
 Use the specified charset for the sent SQL statement and returned
 text values.</p>

 <p>This will cause all SQL queries to be encoded with this charset.
 It will also normally cause all string results to be decoded with
 this charset, but there are exceptions as explained later. If the
 database connection supports it, the connection will be configured to
 use this charset too (at least MySQL 4.1 and later has such
 support).</p>

 <p>In many cases, it is difficult for the SQL interface to tell text
 and binary data apart in results. That is a problem since a text
 string should be decoded according to the charset while a binary
 octet string must not be decoded.</p>

 <p>If the connection supports it, using the special value
 <tt>unicode</tt> as charset is guaranteed to handle both text and
 binary result strings correctly so you don't have to worry about it.
 In that case you can assume the SQL query and text results covers the
 full Unicode range, and the connection will handle the charset issues
 internally. This is known to be supported with MySQL 4.1 and later.
 An RXML run error is thrown if it isn't supported.</p>

 <p>Otherwise, all string values are assumed to be text and are
 therefore decoded using the given charset. You can turn it off for
 specific columns through the \"binary-result\" attribute.</p>

 <p>If you use <tt>none</tt> as charset in this attribute then the
 charset handling described here is disabled for this query. That is
 useful to override a charset in the \"Default charset\" module
 setting.</p>

 <p>The charset specification in this attribute can optionally be a
 list like this:</p>

 <blockquote><p>charset=\"<i>recode-charset</i>,
 <i>connection-charset</i>\"</p></blockquote>

 <p>In this form, the <i>recode-charset</i> is used by Roxen to recode
 the query and results, and <i>connection-charset</i> is sent to the
 database driver to use for the connection. This is useful if the
 database server uses nonstandard names for its character sets. E.g.
 MySQL spells <tt>cp1252</tt> as \"<tt>latin1</tt>\" (which is the
 closest you get to <tt>iso-8859-1</tt> there), so to use that you'd
 say \"<tt>cp1252,latin1</tt>\" in this attribute. This list form is
 not applicable for the <tt>unicode</tt> case.</p>

 <p><i>Compatibility note:</i> In Roxen 4.5 this attribute only
 configured the charset for the connection; it didn't do any
 conversion of the query nor the results. This behavior still remains
 if the compatibility level is 4.5 or lower. You can also achieve the
 same effect by specifying \"<tt>none,<i>whatever</i></tt>\" as
 charset.</p>
</attr>

<attr name='binary-result' value='column names'>
 <p>A comma separated list of columns in the result to not treat as
 text and decode according to the \"charset\" attribute or the
 \"Default charset\" module setting. As a special case, no result
 column is decoded if the value is empty.</p>

 <p>This is only applicable if a charset is being used and it isn't
 \"unicode\" (or \"broken-unicode\").</p>
</attr>"
]);
#endif


// --------------------------- Database query code --------------------------------

float compat_level;

#if ROXEN_COMPAT <= 1.3
string compat_default_host;
#endif
string default_db, default_recode_charset, default_conn_charset;

protected int allow_sql_urls, allow_module_dbs;

// 0 if all dbs are allowed. Includes default_db if set.
protected mapping(string:int(1..1)) allowed_dbs = ([]);

private string restricted_rw_user, restricted_ro_user;

protected string get_restricted_rw_user()
{
  if (!restricted_rw_user || !DBManager.is_valid_db_user (restricted_rw_user)) {
    restricted_rw_user =
      DBManager.get_restricted_db_user (mkmultiset (indices (allowed_dbs)),
					my_configuration(), 0);
#if 0
    werror ("Got restricted_rw_user %O\n", restricted_rw_user);
#endif
  }
  return restricted_rw_user;
}

protected string get_restricted_ro_user()
{
  if (!restricted_ro_user || !DBManager.is_valid_db_user (restricted_ro_user)) {
    restricted_ro_user =
      DBManager.get_restricted_db_user (mkmultiset (indices (allowed_dbs)),
					my_configuration(), 1);
#if 0
    werror ("Got restricted_ro_user %O\n", restricted_ro_user);
#endif
  }
  return restricted_ro_user;
}


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
//!   This function recodes neither the query nor the result according
//!   to the specified charset, as opposed to the charset attribute to
//!   the sql tags.
//!
//! @throws
//!   Connection errors, access errors and syntax errors in @[db],
//!   @[host] and @[module] are thrown as RXML errors.
{
  string real_host = host;
  if (host) host = "CENSORED";

  Sql.Sql con;
  mixed error;

  if (!charset) charset = default_conn_charset;
  if (charset == "none") charset = 0;

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
	  con = my_configuration()->sql_connect(h, charset);
	};
    }
  }

  if (!con && !error)
#endif
  {
    if (!db) db = real_host;
    if (db && allowed_dbs && !allowed_dbs[db]) {
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

    string db_user = read_only ?
      (allowed_dbs ? get_restricted_ro_user() :
       DBManager.get_db_user (db, my_configuration(), 1)) :
      (allowed_dbs ? get_restricted_rw_user() :
       DBManager.get_db_user (db, my_configuration(), 0));

    if (!db_user) {
      report_warning ("Connection to database %O attempted from %O.\n",
		      db, id && id->raw_url);
      RXML.parse_error ("Database %O is not accessible "
			"from this configuration.\n", db);
    }

    error = catch {
	con = DBManager.low_get (db_user, db, reuse_in_thread, charset);
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

array|Sql.sql_result do_sql_query(mapping args, RequestID id,
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
  if (args->parse && compat_level < 2.2)
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
      if(sscanf(tmp, "%s=%s", tmp2, tmp3) == 2) {
	bindings[String.trim_all_whites(tmp2)] =
	  RXML.user_get_var( String.trim_all_whites(tmp3) );
      }
    }
  }

  string conn_charset;
  if (string|array(string) cs = args->charset) {
    if (arrayp (cs)) conn_charset = sizeof (cs) > 1 ? cs[1] : cs[0];
    else conn_charset = cs;
  }
  if (!conn_charset) conn_charset = default_conn_charset;

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
	con = module->get_my_sql (ro, conn_charset != "none" && conn_charset);
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
    con = get_rxml_sql_con (args->db, host, id, ro, 0, conn_charset);

    function query_fn = (big_query ? con->big_query : con->query); 
    if( error = catch( result = (bindings ? query_fn(args->query, bindings) : query_fn(args->query))) ) {
      error = sprintf("Query failed: %s\n",
		      con->error() || describe_error(error));
      RXML.run_error(error);
    }
  }

  if(result && args->rowinfo) {
    int rows;
    if(arrayp(result)) rows=sizeof(result);
    if(objectp(result)) rows=result->num_rows();
    RXML.user_set_var(args->rowinfo, rows);
    if(objectp(result)) m_delete(args, "rowinfo");
  }
  if (ret_con) {
    // NOTE: Use of this feature may lead to circularities...
    args->dbobj=con;
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

      array res= [array] do_sql_query(args, id);

      if (res) {
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
  Sql.sql_result sqlres;
  private Locale.Charset.Decoder decoder;
  private array(string) cols;
  private array(int(0..1)) charset_decode_col;
  private int fetched;

  mapping(string:mixed) really_get_row() {
    array val;
    if(sqlres && (val = sqlres->fetch_row()))
      fetched++;
    else {
      sqlres = 0;
      return 0;
    }

    if (compat_level > 4.5) {
      if (!decoder) {
	foreach (val; int i; string v) {
	  // Change in >= 5.0: Don't abuse RXML.nil for SQL NULL. RXML.nil
	  // means UNDEFINED in this context, i.e. that the variable
	  // doesn't exist at all. An SQL NULL otoh is just a special
	  // value in an existing variable, at least on the RXML level.

#if 0
	  // Afaics the following isn't of any use since the big_query
	  // wrapper in Sql.oracle handles the dbnull objects when it
	  // converts all types to strings. /mast

	  // Might be a dbnull object which considers
	  // itself false (e.g. in the oracle glue).
	  if ((x != 0) && stringp(x->type))
	    // Transform NULLString to "".
	    return x->type;
#endif

	  if (!v) val[i] = Val.null;
	}
      }

      else {
	// Same null handling as above, but also decode charsets.
	foreach (val; int i; string v) {
	  if (!v) val[i] = Roxen.sql_null;
	  else if (charset_decode_col[i]) {
	    if (mixed err = catch (val[i] = decoder->feed (v)->drain()))
	      if (objectp (err) && err->is_charset_decode_error)
		RXML.run_error (err->message());
	      else
		throw (err);
	  }
	}
      }
    }

    else
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

  void create(Sql.sql_result _sqlres, string charset, string binary_cols) {
    sqlres = _sqlres;
    if (sqlres) {
      cols = sqlres->fetch_fields()->name;

      if (charset) {
	if (mixed err = catch (decoder = Locale.Charset.decoder (charset))) {
#if defined (DEBUG) || defined (MODULE_DEBUG)
	  werror ("Error getting decoder for charset %O: %s",
		  charset, describe_error (err));
#endif
	  RXML.parse_error ("Unknown charset %O for decode.\n", charset);
	}

	if (binary_cols) {
	  charset_decode_col = allocate (sizeof (cols), 0);
	  multiset(string) bin_col_names =
	    mkmultiset (map (binary_cols / ",",
			     String.trim_all_whites) - ({""}));
	  if (sizeof (bin_col_names))
	    foreach (cols; int i; string name)
	      charset_decode_col[i] = !bin_col_names[name];
	}
	else
	  charset_decode_col = allocate (sizeof (cols), 1);
      }
    }
  }
}

#define GET_CHARSET_AND_ENCODE_QUERY(args, recode_charset) do {		\
    if (!recode_charset) recode_charset = default_recode_charset;	\
    if (!(<0, "none", "unicode", "broken-unicode">)[recode_charset]) {	\
      Locale.Charset.Encoder encoder;					\
      if (mixed err = catch {						\
	  encoder = Locale.Charset.encoder (recode_charset);		\
	}) {								\
	DO_IF_DEBUG (							\
	  werror ("Error getting encoder for charset %O: %s",		\
		  recode_charset, describe_error (err)));		\
	RXML.parse_error ("Unknown charset %O for encode.\n", recode_charset); \
      }									\
      if (mixed err = catch {						\
	  args->query = encoder->feed (args->query)->drain();		\
	})								\
	if (objectp (err) && err->is_charset_encode_error)		\
	  RXML.run_error (err->message());				\
	else								\
	  throw (err);							\
    }									\
    else								\
      recode_charset = 0;							\
  } while (0)

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

    m += ([]);

    string recode_charset;
    if (string|array(string) cs = m->charset) {
      if (stringp (cs))
	cs = m->charset = array_sscanf (cs, "%[^ \t,]%*[ \t],%*[ \t]%s");
      recode_charset = cs[0];
    }
    GET_CHARSET_AND_ENCODE_QUERY (m, recode_charset);

    return SqlEmitResponse([object(Sql.sql_result)] do_sql_query(m, id, 1),
			   recode_charset,
			   recode_charset && m["binary-result"]);
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

      string recode_charset;
      if (string|array(string) cs = args->charset) {
	if (stringp (cs))
	  cs = args->charset = array_sscanf (cs, "%[^ \t,]%*[ \t],%*[ \t]%s");
	recode_charset = cs[0];
      }
      GET_CHARSET_AND_ENCODE_QUERY (args, recode_charset);

      do_sql_query(args, id, 1, 1);

      Sql.Sql con = m_delete(args, "dbobj");

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

      string recode_charset;
      if (string|array(string) cs = args->charset) {
	if (stringp (cs))
	  cs = args->charset = array_sscanf (cs, "%[^ \t,]%*[ \t],%*[ \t]%s");
	recode_charset = cs[0];
      }
      GET_CHARSET_AND_ENCODE_QUERY (args, recode_charset);

      Sql.sql_result res = [object(Sql.sql_result)] do_sql_query(args, id, 1);

      int ascii=!!args->ascii;
      string ret="";

      if (res) {
	res = SqlEmitResponse (res, recode_charset, 0);

	string nullvalue=args->nullvalue||"";

	array(string) cols = res->sqlres->fetch_fields()->name;

	if (!ascii) {
	  ret="<tr>";
	  foreach (cols, string colname)
	    ret += "<th>" + Roxen.html_encode_string (colname) + "</th>";
	  ret += "</tr>\n";
	}

	while (mapping(string:mixed) entry = res->really_get_row()) {
	  array row = rows (entry, cols);
	  if (ascii)
	    ret += map(row, lambda(mixed in) {
			      if(!in) return nullvalue;
			      return (string)in;
			    }) * "\t" + "\n";
	  else {
	    ret += "<tr>";
	    foreach(row, string|Roxen.SqlNull value)
	      // FIXME: Missing quoting here.
	      ret += "<td>" + (value == Roxen.sql_null ?
			       nullvalue : value) + "</td>";
	    ret += "</tr>\n";
	  }
	}

	if (!ascii)
	  ret=Roxen.make_container("table",
				   args-(["host":"","database":"","user":"",
					  "password":"","query":"","db":"",
					  "nullvalue":"","dbobj":"",
					  "charset": ""]), ret);

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

  defvar ("allow_sql_urls", 0,
	  LOCALE(10, "Allow SQL URLs"),
	  TYPE_FLAG,
	  LOCALE(11, #"\
<p>Allow generic SQL URLs in the \"host\" attribute to the tags. This
can be a security hazard if users are allowed to write RXML - the
server will make the connection as the user it is configured to run
as.</p>

<p>In particular, allowing this makes it possible to write RXML that
connects directly to the socket of Roxen's internal MySQL server,
thereby bypassing the permissions set under the \"DBs\" tab. It is
therefore strongly recommended to keep this disabled and instead
configure all database connections through the \"DBs\" tab and
the \"Allowed databases\" setting.</p>"));

  defvar ("allowed_dbs", "",
	  LOCALE(12, "Allowed databases"),
	  TYPE_STRING,
	  LOCALE(13, #"\
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
inaccessible to the internal modules too.</p>"));

  defvar ("allow_module_dbs", 0,
	  LOCALE(14, "Support \"module\" attribute"),
	  TYPE_FLAG,
	  LOCALE(15, #"\
<p>Support the deprecated \"module\" attribute to the tags.</p>"));

  defvar ("charset", "",
	  LOCALE(16, "Default charset"),
	  TYPE_STRING,
	  LOCALE(17, #"\
<p>The default value to use for the <i>charset</i> attribute to the
SQL tags. See the description of the same attribute for the \"sql\"
emit source for more details.</p>"));
}


// --------------------- More interface functions --------------------------

multiset(string) query_provides() {return (<"rxml_sql">);}

void start()
{
  compat_level = my_configuration() && my_configuration()->compat_level();
 
#if ROXEN_COMPAT <= 1.3
  compat_default_host = query("hostname");
#endif
  default_db          = query("db");

  default_conn_charset = 0;
  sscanf (query ("charset"), "%[^ \t,]%*[ \t],%*[ \t]%s",
	  default_recode_charset, default_conn_charset);
  if (!default_conn_charset) default_conn_charset = default_recode_charset;
  if (default_recode_charset == "") default_recode_charset = 0;
  if (default_conn_charset == "") default_conn_charset = 0;

  allow_sql_urls = query ("allow_sql_urls");
  allow_module_dbs = query ("allow_module_dbs");

  restricted_rw_user = restricted_ro_user = 0;

  string dbs = query ("allowed_dbs");
  if (dbs == "*") allowed_dbs = 0;
  else {
    allowed_dbs = ([]);
    foreach (dbs / ",", string db) {
      db = String.trim_all_whites (db);
      if (db != "") allowed_dbs[db] = 1;
    }
    if (default_db != " none")
      allowed_dbs[default_db] = 1;
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

#if 0
  // Since these settings have secure values by default in 5.0, it's
  // not worth bothering the user with these warnings.

  if (allow_sql_urls)
    res += "<p><font color=\"red\">" + LOCALE(18, "Security warning:") +
      "</font> " +
      LOCALE(19, "Connections to arbitrary databases allowed. See the "
	     "\"Allow SQL URLs\" setting.") +
      "</p>\n";

  if (!allowed_dbs)
    res += "<p><font color=\"red\">" + LOCALE(18, "Security warning:") +
      "</font> " +
      LOCALE(20, "Connections to all configured database allowed. See the "
	     "\"Allowed databases\" setting.") +
      "</p>\n";

  if (allow_module_dbs)
    res += "<p><font color=\"red\">" + LOCALE(18, "Security warning:") +
      "</font> " +
      LOCALE(21, "Connections to module databases allowed. See the "
	     "\"Support 'module' attribute\" setting.") +
      "</p>\n";
#endif

  return res;
}
