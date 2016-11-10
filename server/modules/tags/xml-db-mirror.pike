//  Copyright © 2010 Roxen Internet Software AB.
//
//  Written by Jonas Walldén.


#include <module.h>

inherit "module";
inherit "roxenlib";

import Parser.XML.Tree;

constant thread_safe = 1;
constant module_type = MODULE_TAG | MODULE_PROVIDER;
string module_name = "Tags: XML-DB Mirror";
string module_doc = #"
<p>Mirrors records from an XML file to a MySQL database. The module expects
   the source file to have this structure:</p>

<pre>  &lt;?xml version=\"1.0\" encoding=\"...\"?>
  &lt;database name=\"...\"&gt;
    &lt;dbrecord&gt;
      &lt;some_field&gt;...&lt;/some_field&gt;
      &lt;another_field&gt;...&lt;/another_field&gt;
    &lt;/dbrecord&gt;
    &lt;dbrecord&gt;
      ...
    &lt;/dbrecord&gt;
  &lt;/database&gt;</pre>

<p>Field names are chosen by the author of this file. All fields are treated
   as VARCHAR(255) strings unless the field name has a <tt>_html</tt>
   suffix in which case it's a MEDIUMTEXT. The <tt>name</tt> attribute in
   the <tt>&lt;database&gt;</tt> tag is mapped to a table name in the
   selected database. Records will be recreated on import if they have
   changed but should otherwise keep their record ID.</p>" +

//  <p>The SQL tables <tt>tbl_</tt><i>name</i> and
//     <tt>tbl_</tt><i>name</i><tt>_html</tt> are created in this format:</p>
//  
//  <pre>  id  field          value
//    --  -------------  -------------
//     1  some_field     ...
//     1  another_field  ...
//     2  some_field     ...
//     2  another_field  ...</pre>

#"
<p>No whitespace stripping takes place, and data will be decoded into Unicode
   based on the <tt>encoding</tt> declaration in the XML header and stored in
   native widestring format.</p>"
#"
<p>This module also acts as a backend for the feed import system.</p>"
  ;

//  <p>An extra <tt>tbl_</tt><i>name</i><tt>_hash</tt> table keeps MD5 hashes of
//     each record in order to identify unchanged records across imports.</p>




//  FIXME:
//
//  This module doesn't employ a strict locking method. There is just a
//  mutex to avoid multiple imports running in parallel but <emit#xml-db>
//  queries can happen at any time. Extending the mutex to cover queries
//  would make them single-threaded and still not detect contention if used
//  in a shared database setup.
//
//  Currently the import task adds all new records before deleting old ones
//  so the only potential problem is momentarily getting duplicate hits in
//  searches.



//  Private state
Configuration conf;
string db_name;
mapping(string:string) iso_entities = ([ ]);
mapping(string:mapping) import_info = ([ ]);
roxen.BackgroundProcess import_process;
Thread.Mutex import_mutex = Thread.Mutex();


void create(Configuration conf)
{
  defvar("db_name",
	 Variable.DatabaseChoice("xml_db_" +
				 (conf ? Roxen.short_name(conf->name) : ""),
				 0,
				 "Database",
				 "")
	 ->set_configuration_pointer(my_configuration));
  
  defvar("source_files",
	 ({ "/path/to/db.xml" }),
	 "Source files",
	 TYPE_STRING_LIST | VAR_INITIAL,
	 "Paths to XML files to be monitored and imported when changed.");
  
  defvar("poll_interval",
	 120,
	 "Poll interval",
	 TYPE_INT,
	 "Poll interval in seconds for checking for updates to source files.");
}


string status()
{
  string res =
    "<h3>Statistics from Last Import</h3>"
    "<table cellspacing='0' cellpadding='2' border='0'>"
    "<tr>"
    "  <td><b>Path&nbsp;&nbsp;</b></td>"
    "  <td><b>Last Change</b></td>"
    "  <td><b>&nbsp;&nbsp;Added</b></td>"
    "  <td><b>&nbsp;&nbsp;Removed</b></td>"
    "  <td><b>&nbsp;&nbsp;Total</b></td>"
    "</tr>";
  foreach (sort(indices(import_info)), string path) {
    mapping info = import_info[path];
    if (!info->mtime) {
      //  None of the info is reliable since this module instance hasn't
      //  successfully imported anything.
      res +=
	"<tr>"
	"<td>" + Roxen.html_encode_string(path) + "&nbsp;&nbsp;</td>"
	"<td>n/a</td>"
	"<td align='right'>&nbsp;&nbsp;n/a</td>"
	"<td align='right'>&nbsp;&nbsp;n/a</td>"
	"<td align='right'>&nbsp;&nbsp;n/a</td>"
	"</tr>";
      continue;
    }
    string mtime_str ="<date brief='yes' unix-time='" + info->mtime + "'/>";
    res +=
      "<tr>"
      "<td>" + Roxen.html_encode_string(path) + "&nbsp;&nbsp;</td>"
      "<td>" + mtime_str + "</td>"
      "<td align='right'>&nbsp;&nbsp;" + (info->count_total - info->count_unchanged) + "</td>"
      "<td align='right'>&nbsp;&nbsp;" + info->count_deleted + "</td>"
      "<td align='right'>&nbsp;&nbsp;" + info->count_total + "</td>"
      "</tr>";
  }
  res += "</table>";
  return res;
}


Sql.Sql get_db()
{
  return DBManager.get(db_name, conf, 0, 0, "broken-unicode");
}


int(0..1) init_db()
{
  if (!get_db()) {
    mapping perms = DBManager.get_permission_map()[db_name];
    if (perms && perms[conf->name] == DBManager.NONE) {
      report_error("XML-DB Mirror: No permission to read database: %s\n",
		   db_name);
      return 0;
    }
    
    report_notice("XML-DB Mirror: No database present. Creating \"%s\".\n",
		  db_name);
    if (!DBManager.get_group("xml_db")) {
      DBManager.create_group("xml_db",
			     "XML-DB Mirror",
			     "Databases used by the XML-DB Mirror module",
			     "");
    }
    DBManager.create_db(db_name, 0, 1, "xml_db");
    DBManager.set_permission(db_name, conf, DBManager.WRITE);
    DBManager.is_module_db(this_object(), db_name);
    perms = DBManager.get_permission_map()[db_name];
    if (!get_db()) {
      report_error("XML-DB Mirror: Unable to create database.\n");
      return 0;
    }
  }
  return 1;
}

  
mapping(string:string) fetch_rec(Sql.Sql db, string tbl_name, int id)
{
  //  Don't use UNION since it interferes with result charset
  array(mapping) fields1 =
    db->query("SELECT * "
	      "  FROM " + tbl_name +
              " WHERE id = " + id);
  array(mapping) fields2 = 
    db->query("SELECT * "
	      "  FROM " + tbl_name + "_html "
              " WHERE id = " + id);
  mapping res = ([ ]);
  foreach (fields1, mapping rec)
    res[rec->field] = rec->value;
  foreach (fields2, mapping rec)
    res[rec->field] = rec->value;
  if (sizeof(res))
    res["_id"] = (string) id;
  return res;
}


string wash_tbl_name(string s)
{
  //  Borrowed from Sitebuilder.mangle_to_09_az
  s = replace(lower_case(s),
	      ({ " ", "\n", "\r", "\t", ".", "," }),
	      ({ "_", "_",  "_",  "_",  "_", "_" }) );
  s = filter(lower_case(Unicode.normalize(s, "NFKD")) / "",
	     lambda(string char) {
	       int c = sizeof(char) && char[0];
	       return ('0' <= c && c <= '9') ||
		      ('a' <= c && c <= 'z') ||
		      ('_' == c);
	     }) * "";
  return ((s / "_") - ({ "" }) ) * "_";
}


void init_iso_entities() {
  mapping all_entities =
    Roxen.iso88591 + Roxen.international + Roxen.symbols + Roxen.greek;
  foreach(indices(all_entities), string entity) {
    iso_entities[ entity - "&" - ";"] =
      "&#" + (int) all_entities[entity][0] + ";";
  }
}


void start(int when, Configuration _conf)
{
  conf = _conf;
  db_name = query("db_name");
  init_iso_entities();
}


void ready_to_receive_requests(Configuration c)
{
  int poll_secs = (int) query("poll_interval");
  import_process = roxen.BackgroundProcess(poll_secs, periodic_import);
}


void stop()
{
  if (import_process)
    import_process->stop();
  import_process = 0;
}


mapping(string:function) query_action_buttons()
{
  return ([ "Import Now!" : import_now ]);
}


void import_now()
{
  import_info = ([ ]);
  periodic_import();
}


void periodic_import()
{
  Thread.MutexKey key = import_mutex->lock();

  mixed err = catch {
      //  Open file and read data if timestamp is newer than last import
      //
      //  FIXME: Let recently changed files stabilize before importing?
      array(string) paths = query("source_files");
      foreach (paths, string path) {
	Stdio.File f = Stdio.File();
	if (f->open(path, "r")) {
	  Stdio.Stat st = f->stat();
	  if (!import_info[path])
	    import_info[path] = ([ ]);
	  if (st && (st->mtime > import_info[path]->mtime)) {
	    string xml = f->read();
	    if (xml && sizeof(xml)) {
	      if (int ok = import_xml(path, xml))
		import_info[path]->mtime = st->mtime;
	    } else {
	      report_warning("XML-DB Mirror: Source file \"%s\" is empty -- "
			     "skipping.\n", path);
	    }
	  }
	} else {
	  report_warning("XML-DB Mirror: Source file \"%s\" not found.\n",
			 path);
	}
      }
    };
  if (err) {
    report_debug("XML-DB Mirror: Internal error during import:\n\n%s\n",
		 describe_backtrace(err));
  }
}


//  Some helper methods for XML parsing

private SimpleNode find_node(SimpleNode node, string path)
{
  //  Just get first child that matches the given path
  foreach((path / "/") - ({ "" }), string segment) {
    array(string) tags = node->get_children()->get_tag_name();
    int pos = search(tags, segment);
    if (pos >= 0)
      node = node[pos];
    else
      return 0;
  }
  return node;
}

private array(SimpleNode) find_nodes(SimpleNode node, string|array path)
{
  //  Find all children at each level that match each path segment. When
  //  we are called recursively the path will already be in array form.
  array(string) segments = arrayp(path) ? path : (path / "/") - ({ "" });
  
  //  Always return an array even if no matches are found
  array(SimpleNode) res = ({ });
  
  if (sizeof(segments)) {
    res = filter(node->get_children(),
		 lambda(SimpleNode n) {
		   return
		     (n->get_node_type() == XML_ELEMENT) &&
		     (< n->get_tag_name(), "*" >)[segments[0]];
		 });
    
    //  If we've got any result and there are additional path segments
    //  left to process we run them all in parallel.
    if (sizeof(res) && sizeof(segments) > 1)
      res = Array.flatten(map(res, find_nodes, segments[1..]));
  }
  return res;
}

private string find_string_val(SimpleNode node, string path)
{
  //  If path ends with attribute we stop one level above
  if (has_value(path, "@")) {
    [path, string attr] = path / "@";
    node = find_node(node, path);
    return node && node->get_attributes()[attr];
  }
  else {
    node = find_node(node, path);
    return node && node->value_of_node();
  }
}


int(0..1) import_xml(string path, string xml)
{
  //  Decode XML charset and parse it
  SimpleNode root;
  mixed err = catch {
      xml = Parser.XML.autoconvert(xml);
	  // BOM handling...
      if (has_prefix(xml, "\xef\xbb\xbf")) {
        xml = utf8_to_string(xml)[1..];
      } else if (has_prefix(xml, "\xfeff")) {
        xml = xml[1..];
      }
      root = simple_parse_input(xml, iso_entities, 0);
    };
  if (err) {
    report_error("XML-DB Mirror: Syntax error parsing file \"%s\".\n", path);
    return 0;
  }
  if (SimpleNode db_node = find_node(root, "/database")) {
    //  Extract table name
    string tbl_name = wash_tbl_name(find_string_val(db_node, "@name"));
    
    //  Create database if needed
    if (!init_db())
      return 0;
    Sql.Sql db = get_db();
    mapping perms = DBManager.get_permission_map()[db_name];
    if (!perms || perms[conf->name] != DBManager.WRITE) {
      report_error("XML-DB Mirror: Needs write access to database \"%s\".\n",
		   db_name);
      return 0;
    }
    
    db->query("CREATE TABLE IF NOT EXISTS " + tbl_name + " ("
	      "  id INT,"
	      "  field VARCHAR(255),"
	      "  value VARCHAR(255),"
	      "  KEY (id)"
	      ") DEFAULT CHARACTER SET utf8");
    db->query("CREATE TABLE IF NOT EXISTS " + tbl_name + "_html ("
  	      "  id INT,"
	      "  field VARCHAR(255),"
	      "  value MEDIUMTEXT,"
	      "  KEY (id)"
	      ") DEFAULT CHARACTER SET utf8");
    db->query("CREATE TABLE IF NOT EXISTS " + tbl_name + "_hash ("
  	      "  md5 CHAR(32) BINARY,"
	      "  id INT,"
	      "  PRIMARY KEY (md5),"
	      "  KEY (id)"
	      ")");
    DBManager.is_module_table(this_object(), db_name, tbl_name);
    DBManager.is_module_table(this_object(), db_name, tbl_name + "_html");
    DBManager.is_module_table(this_object(), db_name, tbl_name + "_hash");
    
    //  Load existing MD5 hashes for quick detection of unchanged records.
    //  Also find next suitable record ID.
    mapping(int:int) valid_ids = ([ ]);
    int next_id = 1;
    mapping(string:int) md5hashes = ([ ]);
    array(mapping) md5recs = db->query("SELECT md5, id "
				       "  FROM " + tbl_name + "_hash");
    foreach (md5recs, mapping rec) {
      int rec_id = (int) rec->id;
      md5hashes[rec->md5] = rec_id;
      if (rec_id >= next_id)
	next_id = rec_id + 1;
    }
    md5recs = 0;
    
    //  Process records
    mapping info = ([ "count_total"     : 0,
		      "count_unchanged" : 0,
		      "count_deleted"   : 0 ]);
    foreach (find_nodes(db_node, "dbrecord"), SimpleNode rec_node) {
      info->count_total++;
      
      //  Extract fields
      string set_fields = "";
      string set_fields_html = "";
      string hashstr = "";
      foreach (find_nodes(rec_node, "*"), SimpleNode field_node) {
	//  String or blob field?
	string tag = field_node->get_tag_name();
	string val;
	if (has_suffix(tag, "_html")) {
	  val = field_node->get_children()->html_of_node(0) * "";
	  if (sizeof(set_fields_html))
	    set_fields_html += ",";
	  set_fields_html +=
	    "(" + next_id + ", '" + tag + "', '" + db->quote(val) + "')";
	} else {
	  val = field_node->value_of_node();
	  if (sizeof(set_fields))
	    set_fields += ",";
	  set_fields +=
	    "(" + next_id + ", '" + tag + "', '" + db->quote(val) + "')";
	}
	hashstr += tag + "|" + val + "|";
      }
      
      //  Hash the new record and see if already a duplicate
      string md5 =
	lower_case(String.string2hex(Crypto.MD5.hash(string_to_utf8(hashstr))));
      if (int existing_id = md5hashes[md5]) {
	//  Don't change this record but flag it as valid
	valid_ids[existing_id] = 1;
	info->count_unchanged++;
	continue;
      }
      
      //  Write new or updated record
      if (sizeof(set_fields)) {
	db->query("INSERT INTO " + tbl_name + " (id, field, value) "
                  "     VALUES " + set_fields);
      }
      if (sizeof(set_fields_html)) {
	db->query("INSERT INTO " + tbl_name + "_html (id, field, value) "
                  "     VALUES " + set_fields_html);
      }
      db->query("INSERT INTO " + tbl_name + "_hash (md5, id) "
                "     VALUES ('" + md5 + "', " + next_id + ")");
      valid_ids[next_id] = 1;
      next_id++;
    }
    
    //  Delete all old records whose IDs are no longer valid
    array(int) delete_ids = values(md5hashes) - indices(valid_ids);
    info->count_deleted = sizeof(delete_ids);
    if (info->count_deleted) {
      sort(delete_ids);
      foreach (delete_ids / 100.0, array(int) delete_id_chunk) {
	string id_chunk_str = (array(string)) delete_id_chunk * ",";
	db->query("DELETE FROM " + tbl_name + " "
                  "      WHERE id IN (" + id_chunk_str + ")");
	db->query("DELETE FROM " + tbl_name + "_html "
                  "      WHERE id IN (" + id_chunk_str + ")");
	db->query("DELETE FROM " + tbl_name + "_hash "
                  "      WHERE id IN (" + id_chunk_str + ")");
      }
    }
    
    //  Report stats
    report_notice("XML-DB Mirror: Import of \"%s\" done -- "
		  "%d records found (%d new or updated, %d unchanged), "
		  "%d old deleted.\n",
		  path,
		  info->count_total,
		  info->count_total - info->count_unchanged,
		  info->count_unchanged,
		  info->count_deleted);
    if (!import_info[path])
      import_info[path] = ([ ]);
    import_info[path] += info;
  }
  return 1;
}


class TagEmitXMLDB
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "xml-db";

  mapping(string:RXML.Type) req_arg_types = ([
    "db"            : RXML.t_text(RXML.PEnt)
  ]);
  
  mapping(string:RXML.Type) opt_arg_types = ([
    "id"            : RXML.t_text(RXML.PEnt),
    "search"        : RXML.t_text(RXML.PEnt),
    "search-fields" : RXML.t_text(RXML.PEnt)
  ]);
  
  private array(mapping) search_recs(Sql.Sql db, string tbl_name, string query,
				     int(0..1) use_wildcards,
				     void|array(string) in_fields)
  {
    string sql_where;
    if (use_wildcards) {
      string query_sql =
	db->quote(replace(lower_case(query), ({ "*", "?" }), ({ "%", "_" }) ));
      if (!has_prefix(query_sql, "%"))
	query_sql = "%" + query_sql;
      if (!has_suffix(query_sql, "%"))
	query_sql += "%";
      sql_where = "LOWER(value) LIKE '" + query_sql + "'";
    } else {
      sql_where = "value = '" + db->quote(query) + "'";
    }
    
    if (in_fields) {
      sql_where +=
	" AND field IN ('" + map(in_fields, db->quote) * "','" + "') ";
    }
    
    //  Find record IDs
    array(mapping) hits =
      db->query("(SELECT DISTINCT id "
		"   FROM " + tbl_name + 
                "  WHERE " + sql_where + ") "
		"UNION "
		"(SELECT DISTINCT id "
		"   FROM " + tbl_name + "_html "
                "  WHERE " + sql_where + ")");
    
    //  Populate results
    array(mapping) res = map(sort((array(int)) hits->id),
			     lambda(int id) {
			       return fetch_rec(db, tbl_name, id);
			     });
    return res;
  }
  
  array(mapping) get_dataset(mapping args, RequestID id)
  {
    //  Validate that the table exists
    Sql.Sql db = get_db();
    string tbl_name = wash_tbl_name(args->db);
    if (mixed err = catch {
	db->query("SELECT 1 "
		  "  FROM " + tbl_name + " "
                  " LIMIT 1");
      }) {
      RXML.parse_error("Could not access database \"" + tbl_name + "\".\n");
      return ({ });
    }
    
    if (string recid = args->id) {
      //  Returns all fields associated to a given record ID
      return ({ fetch_rec(db, tbl_name, (int) recid) });
    } else if (string query = args->search) {
      //  Returns all records whose field values contain the provided string.
      //  User can optionally limit search to named fields.
      array(string) in_fields = 0;
      if (string restr = args["search-fields"])
	in_fields = map(restr / ",", String.trim_all_whites);
      int use_wildcards = lower_case(args["wildcards"] || "no") != "no";
      return search_recs(db, tbl_name, query, use_wildcards, in_fields);
    }
    
    RXML.parse_error("Must provide \"id\" or \"search\" attribute.\n");
  }
}

/*
 * Provider interface.
 */

multiset(string) query_provides()
{
  return (< "feed_import_backend" >);
}

array(mapping(string:mixed)|string) read_article(string path,
						 int|void edit,
						 int|void discard_changes)
{
  return 0;
}

int(0..2) update_article(string path, string data, mapping md,
			 mapping|void extra_md, int|void no_conflicts,
			 void|function(string, mixed...:mixed) notify_cb)
{
  import_xml(path, data);
  return 1;
}

int prepare_article(string path)
{
  return 1;
}

int(0..1) check_imported(string source_path, int mtime, RoxenModule importer)
{
  return 0;
}

void delete_file(string source_path, RoxenModule loader, RoxenModule importer)
{
  return;
}

void reset_state(int|void force)
{
  return;
}


TAGDOCUMENTATION;
#ifdef manual
constant tagdoc = ([
  "emit#xml-db": ({ #"

<desc type='plugin'>
<p><short>Get or search for records in the mirrored database.</short></p>

<p>The returned records will contain all known fields as well as a special
   <tt>_id</tt> field with the record ID.</p>
</desc>

<attr name='db' value='string' required='required'>
  <p>Name of XML-DB database to use. This corresponds to the <tt>name</tt>
     attribute of the top-level <tt>&lt;database&gt;</tt> element in the
     imported XML file.</p>

  <p>Must be combined with either the <tt>id</tt> or the <tt>search</tt>
     attribute.</p>
</attr>

<attr name='id' value='int'>
  <p>Fetches a given record using it's ID.</p>
</attr>

<attr name='search' value='string'>
  <p>Performs a string search in all fields and records. The standard
     behavior is to require exact matches (disregarding case sensitivity).</p>

  <p>When combined with the <tt>search-fields</tt> attribute the query can
     be limited to a subset of record fields.</p>

  <p>You can also combine with the <tt>wildcards</tt> flag to indicate that
     searches should match substrings and allow <tt>*</tt> and <tt>?</tt> as
     wildcards.</p>
</attr>

<attr name='search-fields' value='string'>
  <p>A comma-separated list of field names which should be searched. If
     omitted all fields are searched.</p>
</attr>

<attr name='wildcards' value='yes|no'>
  <p>When enabled the search will match substrings and allow for <tt>*</tt>
     and <tt>?</tt> wildcards.</p>
</attr>
",
  ([ ])
  })
]);
#endif
