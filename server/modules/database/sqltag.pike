// This is a ChiliMoon module. Copyright © 1997-2001, Roxen IS.
//

constant cvs_version = "$Id: sqltag.pike,v 1.117 2004/07/11 13:40:56 _cvs_stephen Exp $";
constant thread_safe = 1;
#include <module.h>

inherit "module";


// Module interface functions

constant module_type = MODULE_TAG|MODULE_PROVIDER;
constant module_name = "Tags: SQL tags";
constant  module_doc =
("The SQL tags module provides the tags <tt>&lt;sqlquery&gt;</tt> and"
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
 Create an ASCII table rather than an HTML table. Useful for
 interacting with <xref href='../graphics/diagram.tag' /> and <xref
 href='../text/tablify.tag' />.</p>
</attr>

<attr name='db' value='database'><p>
 Which database to connect to, usually a symbolic name set in the <xref
 href='../../administrator_manual/installing/databases.xml'><module>SQL
 Databases</module></xref> module. If omitted the default database will
 be used.</p>
</attr>

<attr name='module' value='module name'><p>
 Use the database requested by the named module.</p>
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

<attr name='db' value='database'><p>
 Which database to connect to, usually a symbolic name set in the <xref
 href='../../administrator_manual/installing/databases.xml'><module>SQL
 Databases</module></xref> module. If omitted the default
 database will be used.</p>
</attr>

<attr name='module' value='module name'><p>
 Use the database requested by the named module.</p>
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

<attr name='rowinfo' value='variable'><p>
 Set the given variable to the number of rows processed.</p>
</attr>

<attr name='mysql-insert-id' value='variable'><p>
 Set the given variable to the insert id used by Mysql for
 auto-incrementing columns. Note: This is only available with Mysql.</p>
</attr>",

"emit#sql":#"<desc type='plugin'><p><short>

 Use this source to connect to and query SQL databases for
 information.</short> The result will be available in variables named
 as the SQL columns.</p>
</desc>

<attr name='db' value='database'><p>
 Which database to connect to, usually a symbolic name set in the <xref
 href='../../administrator_manual/installing/databases.xml'><module>SQL
 Databases</module></xref> module. If omitted the default
 database will be used.</p>
</attr>

<attr name='module' value='module name'><p>
 Use the database requested by the named module.</p>
</attr>

<attr name='query' value='SQL statement'><p>
 The actual SQL-statement.</p>
</attr>

<attr name='prefetch'><p>
 Tells the emit tag to prefetch all rows from the database so that
 any nested sqlqueries inside the emit will be run in the same SQL-session
 as the current query.</p>
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
</attr>"
]);
#endif


// --------------------------- Database query code --------------------------------

string default_db;

private class Csql_result {
  inherit Sql.sql_result;
  object sqlsession;
};

array|object do_sql_query(mapping args, RequestID id,
			  void|int(0..2) querytype)
			   // 0 query, 1 big_query, 2 query with last-insert-id
{
  string host;
  if(args->db)
    host=args->db, args->db="SECRET";
  else if(args->host)			     // Deprecated
    host=args->host, args->host="SECRET";
  else
    host=default_db;

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

  if(args->module) {
    RoxenModule module=id->conf->find_module(replace(args->module,"!","#"));
    if( !module )
      RXML.run_error( "Cannot find the module" + args->module );

    if( error = catch( con = module->get_my_sql( ro ) ) )
      RXML.run_error( "Couldn't connect to SQL server: " +
		      describe_error(error) + "\n");
      
    if( catch
    {
      string f=(querytype==1?"big_query":"query")+(ro?"_ro":"");
      result = bindings ?  
	module["sql_"+f]( args->query, bindings ) :
	module["sql_"+f]( args->query );
    } )
    {
      error = con->error();
      if (error) error = ": " + error;
      error = sprintf("Query failed%s\n", error||".");
      RXML.parse_error(error);
    }
  }
  else
  {
    error = catch(con = DBManager.get(host, my_configuration(), ro, id));
    if( !con )
      RXML.run_error( "Couldn't connect to SQL server"+
		      (error?": "+ describe_error (error) :"")+"\n" );

    function query_fn = (querytype==1 ? con->big_query : con->query); 
    if( catch(result = (bindings ? query_fn(args->query, bindings) : query_fn(args->query))) ) {
      error = con->error();
      if (error) error = ": " + error;
      error = sprintf("Query failed%s\n", error||".");
      RXML.parse_error(error);
    }
  }

  if(result && arrayp(result) && args->rowinfo) {
    int rows;
    rows=sizeof(result); // FIXME use the intrinsic value passed by SQL instead
    RXML.user_set_var(args->rowinfo, rows);
  }
  if(querytype==1)
    (result=Csql_result(result))->sqlsession = con;
  return querytype==2 ? con : result;
}


// ----------------------------- Tag handlers ---------------------------------

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
    "db":RXML.t_text(RXML.PEnt),
    "module":RXML.t_text(RXML.PEnt),
    "prefetch":RXML.t_text(RXML.PEnt),
  ]);

  object get_dataset(mapping args, RequestID id) {
    // Haven't verified that the NOCACHE here is actually needed, but
    // in the worst case it's just unnecessary.
    NOCACHE();
    return SqlEmitResponse(do_sql_query(args, id, !args->prefetch));
  }
}

class TagSQLQuery {
  inherit RXML.Tag;
  constant name = "sqlquery";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  mapping(string:RXML.Type) req_arg_types = ([ "query":RXML.t_text(RXML.PEnt) ]);
  mapping(string:RXML.Type) opt_arg_types = ([
    "db":RXML.t_text(RXML.PEnt),
    "module":RXML.t_text(RXML.PEnt),
    "rowinfo":RXML.t_text(RXML.PEnt), // t_var
    "mysql-insert-id":RXML.t_text(RXML.PEnt), // t_var
  ]);

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      NOCACHE();

      if(args["mysql-insert-id"]) {
        object con = do_sql_query(args, id, 2);
	if(con && con->master_sql->insert_id)
	  RXML.user_set_var(args["mysql-insert-id"],
			    con->master_sql->insert_id());
	else
	  RXML.parse_error("No insert_id present.\n");
      }
      else
         do_sql_query(args, id, 0);
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
    "db":RXML.t_text(RXML.PEnt),
    "module":RXML.t_text(RXML.PEnt),
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
				   args-(<"db","query","module",
					  "ascii","nullvalue">), ret);

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
  defvar( "db",
          DatabaseVar( " none",({}),0,
                       "Default database",
                       ("If this is defined, it's the "
			"database this server will use as the "
			"default database") ) );
}


// --------------------- More interface functions --------------------------

void start()
{
  default_db = query("db");
}

string status()
{
  if( query("db") != " none" )
  {
    if(mixed err = catch {
      object o = DBManager.get(query("db"),my_configuration());
      if(!o)
        error("The database specified as default database does not exist");
      return sprintf("The default database is connected to %s "
		     "server on %s.<br />\n",
                     Roxen.html_encode_string (o->server_info()),
                     Roxen.html_encode_string (o->host_info()));
    })
    {
      return
        "<font color='red'>"
        "The default database is not connected:</font><br />\n" +
        replace( Roxen.html_encode_string( describe_error(err) ),
                 "\n", "<br />\n") +
        "<br />\n";
    }
  }
  return "";
}
