inherit "module.pike";

constant module_name = "Average Profiling";
constant module_doc = "Access the average profiling information";
constant module_type = MODULE_TAG|MODULE_LOCATION;

class DatabaseVar
{
  inherit Variable.StringChoice;
  array get_choice_list( )
  {
    return sort(DBManager.list( my_configuration() ));
  }
}

void create()
{
  defvar ("location",
	  Variable.Location("/avarage_profiling/", 0,
			    "Avarage Profiling location",
			    "The location of the Avarage Profiling Interface."));
  
  defvar( "db",
          DatabaseVar( "local",({}),0, "Database", "The database" ));
}

void dump_iter( function cb )
{
  foreach( roxen->configurations - ({ this_object() }),
	   Configuration c )
  {
    mapping p;
    if( (p=c->profiling_info) )
      foreach( indices( p ), string f )
      {
	mapping i = p[f]->data;
	foreach( indices( i ), string e )
	  cb( c, f, e, @i[e] );
      }
    c->profiling_info = ([]);
  }
}

void dump_to_db( )
{
  Sql.Sql sql = DBManager.get( query( "db" ) );

  catch {
    sql->query( "CREATE TABLE average_profiling ( "
		"           session INT,"
		"           calls   INT,"
		"           real_ns INT,"
		"           cpu_ns  INT,"
		"           config  VARCHAR(30),"
		"           file    VARCHAR(100),"
		"           event_name  VARCHAR(100),"
		"           event_class VARCHAR(20) )"
	      );
  };
  
  array q = sql->query( "SELECT MAX(session) as m FROM average_profiling" );

  int session;

  if( sizeof( q ) )
    session = ((int)q[0]->m)+1;
  else
    session = 1;
  
  void dump_row( Configuration c, string file, string event,
		 int realtime, int cputime, int calls )
  {
    array q = event / ":";
    string ev_n = q[..sizeof(q)-2]*":";
    string ev_c = q[-1];
    
    sql->query( "INSERT INTO average_profiling VALUES "
		"(%d,%d,%d,%d,%s,%s,%s,%s)",
		session, calls, realtime, cputime, c->query_name(),
		file, ev_n, ev_c );
    
  };


  dump_iter( dump_row );
}

void flush()
{
  foreach( roxen->configurations, object c )
    c->profiling_info = ([]);
}


void clear_db()
{
  Sql.Sql sql = DBManager.get( query( "db" ) );
  catch {
    sql->query( "DELETE FROM average_profiling" );
  };
}


mapping(string:function) query_action_buttons()
{
  return ([
    "Clear profiling information":flush,
    "Dump to database":dump_to_db,
    "Clear database":clear_db,
  ]);
}

array(mapping) sql2emit(array(mapping) rows)
{
  return
    map(rows, lambda(mapping row) {
		return mkmapping(map(indices(row), replace, "_", "-"),
				 values(row));
	      });
}


array(mapping) get_events(mapping where, string sort, string sort_dir)
{
  Sql.Sql sql = DBManager.get( query( "db" ) );
  string w = map(indices(where),
		 lambda(string name)
		 {
		   return sprintf("%s = '%s'", name, sql->quote(where[name]));
		 }) * " AND ";
  string q = "SELECT session, config, file, calls, "
	     "       real_ns/1000 as real_us, real_ns/calls/1000 as real_us_average, "
	     "       cpu_ns/1000 as cpu_us, cpu_ns/calls/1000 as cpu_us_average, "
	     "       event_name, event_class "
	     "  FROM average_profiling "+
	     (sizeof(w)? "WHERE " + w: "")+
	     (sort? " ORDER BY "+sort+" "+(sort_dir||""): "");
  return sql->query( q );
}

class TagEmitAPEvents
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "ap-events";

  array get_dataset(mapping args, RequestID id)
  {
    mapping where = ([]);

    void fix_arg(string name)
    {
      if(args[name] && args[name] != "")
	where[replace(name, "-", "_")] = args[name];
    };
    
    map(({ "config", "config", "file", "event-class", "event-name"}), fix_arg);

    if(args["order-by"] == "")
      m_delete(args, "order-by");
    
    return sql2emit(get_events(where, args["order-by"], args["sort-dir"]));
  }
}

array(mapping) get_names(string column, string where)
{
  Sql.Sql sql = DBManager.get( query( "db" ) );
  string q = "SELECT DISTINCT "+column+" as name "
	     "  FROM average_profiling "+
	     (where? " WHERE " + where + " ": "")+
	     "  ORDER BY "+column+" ";
  return sql->query(q);
}

class TagEmitAPNames
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "ap-names";

  array get_dataset(mapping args, RequestID id)
  {
    return get_names(args->column, args->where);
  }
}


//class TagEmitUrl
//{
//  inherit RXML.Tag;
//  constant name = "emit";
//  constant plugin_name = "ap-names";
//
//  class Url
//  {
//    Standards.URI url;
//    
//    class Entity(string entity_name)
//    {
//	inherit RXML.Value;
//	mixed rxml_var_eval(RXML.Context c, string var,
//			    string scope_name, void|RXML.Type type) {
//	  switch(entity_name)
//	  {
//	    case "protocol":
//	      return ENCODE_RXML_TEXT(url->protocol);
//	    case "host":
//	      return ENCODE_RXML_TEXT(url->host);
//	    case "port":
//	      return ENCODE_RXML_INT(url->port);
//	    default:
//	      return ENCODE_RXML_TEXT("Hepp");
//	  }
//	  return RXML.nil;
//	}
//    }
//
//    void create(string _url)
//    {
//	url = Standards.URI(_url);
//    }
//  }
//  
//  Url url;
//  array get_dataset(mapping args, RequestID id)
//  {
//    url = Url(args->url);
//    return ({ ([
//	"protocol":   url->Entity("protocol"),
//	"host":       url->Entity("host"),
//	"port":       url->Entity("port"),
//	"hostport":   url->Entity("hostport"),
//	"prestates":  url->Entity("prestates"),
//	"path":       url->Entity("path"),
//	"dirpath":    url->Entity("dirpath"),
//	"filename":   url->Entity("filename"),
//	"query":      url->Entity("query"),
//	"query-rest": url->Entity("query-rest"),
//	"query-full": url->Entity("query-full"),
//	"fragment":   url->Entity("fragment"),
//	"url":        url->Entity("url")
//    ]) });
//  }
//}

mapping find_file (string f, RequestID id)
{
  string res = #"
<html>
<head>
  <title>Avarage Profiling</title>
</head>

<define tag='pager'>
  <for from='1' to='&var.pages;' step='1' variable='var.page'>
    <if variable='var.page == &form.page;'>
      <b>[&var.page;]</b>
    </if><else>
      <a href='&page.path;?session=&form.session;&amp;config=&form.config;&amp;file=&form.file;&amp;event-class=&form.event-class;&amp;event-name=&form.event-name;&amp;sort-by=&form.sort-by;&amp;sort-dir=&form.sort-dir;&amp;page=&var.page;'>[&var.page;]</a>
    </else>&nbsp;
  </for>
</define>

<body bgcolor='white'>

<font size='-1'><form>
  <h1>Filter</h1>
  <table cellspacing='0' cellpadding='0' border='0'>
    <tr>
      <td><b>Session:</b></td>
      <td>
        <default name='session' value='&form.session;'>
  	  <select name='session'>
  	    <option value=''>All</option>
  	    <emit source='ap-names' column='session'>
  	      <option value='&_.name;'>&_.name;</option>
  	    </emit>
  	  </select>
        </default>
      </td>
    </tr>

    <tr>
      <td><b>Config:</b></td>
      <td>
        <default name='config' value='&form.config;'>
          <select name='config'>
            <option value=''>All</option>
            <emit source='ap-names' column='config'>
              <option value='&_.name;'>&_.name;</option>
            </emit>
          </select>
        </default>
      </td>
    </tr>

    <tr>
      <td><b>File:</b></td>
      <td>
        <default name='file' value='&form.file;'>
          <select name='file'>
            <option value=''>All</option>
            <emit source='ap-names' column='file'>
              <option value='&_.name;'>&_.name;</option>
            </emit>
          </select>
        </default>
      </td>
    </tr>

    <tr>
      <td><b>Event Class:</b></td>
      <td>
        <default name='event-class' value='&form.event-class;'>
          <select name='event-class'>
            <option value=''>All</option>
            <emit source='ap-names' column='event_class'>
              <option value='&_.name;'>&_.name;</option>
            </emit>
          </select>
        </default>
      </td>
    </tr>

    <tr>
      <td><b>Event Name:</b></td>
      <td>
        <default name='event-name' value='&form.event-name;'>
          <select name='event-name'>
            <option value=''>All</option>
            <if sizeof='form.event-class == 0'>
              <emit source='ap-names' column='event_name'>
                <option value='&_.name;'>&_.name;</option>
              </emit>
            </if>
            <else>
              <emit source='ap-names' column='event_name'
                    where=\"event_class = '&form.event-class;'\">
                <option value='&_.name;'>&_.name;</option>
              </emit>
            </else>
          </select>
        </default>
      </td>
    </tr>

    <tr>
      <td><b>Sort by:</b></td>
      <td>
        <default name='sort' value='&form.sort;'>
          <select name='sort'>
            <option value='session'>Session</option>
            <option value='config'>Config</option>
            <option value='file'>File</option>
            <option value='event_class'>Event Class</option>
            <option value='event_name'>Event Name</option>
            <option value='calls'>Calls</option>
            <option value='real_ns'>Real ns</option>
            <option value='cpu_ns'>CPU ns</option>
          </select>
        </default>
        &nbsp;Direction:
        <default name='sort-dir' value='&form.sort-dir;'>
          <select name='sort-dir'>
            <option value='ASC'>Ascending</option>
            <option value='DESC'>Descending</option>
          </select>
        </default>
      </td>
    </tr>
  </table>
  <table><tr><td><input type='submit' name='update' value=' Update ' /></td></tr></table>
</form></font>

<if match='x&form.page; is x'>
  <set variable='form.page' value='1'/>
</if>

<set variable='var.maxrows' value='40'/>
<set variable='var.skiprows' expr='&var.maxrows; * (&form.page; - 1)'/>

<define variable='var.emit-args'>
  session='&form.session;'
  config='&form.config;'
  file='&form.file;'
  event-class='&form.event-class;'
  event-name='&form.event-name;'
  order-by='&form.sort;'
  sort-dir='&form.sort-dir;'
</define>

<emit source='ap-events' ::='&var.emit-args;' rowinfo='var.rows'/>
<set variable='var.pages' expr='&var.rows;/&var.maxrows;'/>
<h1>Statistics</h1>
<pager/>
<table cellspacing='0'>
  <tr bgcolor='#dee2eb'>
    <if sizeof='form.session == 0'>
      <td><b>Session</b></td>
    </if>
    <if sizeof='form.config == 0'>
      <td><b>Config</b></td>
    </if>
    <if sizeof='form.file == 0'>
      <td><b>File</b></td>
    </if>
    <if sizeof='form.event-class == 0'>
      <td><b>Event Class</b></td>
    </if>
    <if sizeof='form.event-name == 0'>
      <td><b>Event Name</b></td>
    </if>
    <td><b>Calls</b></td>
    <td><b>Real (탎)</b></td>
    <td><b>Average Real (탎)</b></td>
    <td><b>CPU (탎)</b></td>
    <td><b>Average CPU (탎)</b></td>
  </tr>

  <set variable='var.bgcolor' value='#dee2eb'/>
  <emit source='ap-events' ::='&var.emit-args;'
        maxrows='50'
        rowinfo='var.rows'
        maxrows='&var.maxrows;'
        skiprows='&var.skiprows;'
        remainderinfo='var.remainder'>
    <if variable='var.bgcolor == white'>
      <set variable='var.bgcolor' value='#dee2eb'/>
    </if><else>
      <set variable='var.bgcolor' value='white'/>
    </else>
    <tr bgcolor='&var.bgcolor;'>
      <if sizeof='form.session == 0'>
        <td>&_.session;</td>
      </if>
      <if sizeof='form.config == 0'>
        <td>&_.config;</td>
      </if>
      <if sizeof='form.file == 0'>
        <td>&_.file;</td>
      </if>
      <if sizeof='form.event-class == 0'>
        <td>&_.event-class;</td>
      </if>
      <if sizeof='form.event-name == 0'>
        <td>&_.event-name;</td>
      </if>
      <td align='right'>&_.calls;</td>
      <td align='right'>&_.real-us;</td>
      <td align='right'>&_.real-us-average;</td>
      <td align='right'>&_.cpu-us;</td>
      <td align='right'>&_.cpu-us-average;</td>
    </tr>
  </emit>
</table>

<pager/>

</body>
</html>
";
  return Roxen.http_rxml_answer(res, id);
}

string status()
{
  string res = "";
  res += "Database: "+query("db")+"<br />\n";
  res += "Interface: <a href=\""+query("location")+"\">"+
	 query("location")+"</a><br /><br />\n";

  res += "<font size=\"+1\"><b>Statistics</b></font>"
	 "<table><tr><td><b>Configuration</b></td><td><b>Pages</b></td></tr>";
  foreach( roxen->configurations - ({ this_object() }), Configuration c )
    res += "<tr><td>"+c->query_name()+"</td>"
	   "<td align=\"right\">"+sizeof(indices(c->profiling_info))+"</td></tr>";
  return res+"</table>";
}
