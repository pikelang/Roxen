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


array(mapping) get_events(array where, string sort, string sort_dir, string group_by)
{
  Sql.Sql sql = DBManager.get( query( "db" ) );
  string w = map(where, lambda(object o) { return o->query(sql); } ) * " AND ";

  string select =
    "calls, "
    "real_ns/1000 as real_us, real_ns/calls/1000 as real_us_average, "
    "cpu_ns/1000 as cpu_us, cpu_ns/calls/1000 as cpu_us_average";
  string group_select =
    "SUM(calls) as calls, "
    "SUM(real_ns/1000) as real_us, SUM(real_ns/calls/1000) as real_us_average, "
    "SUM(cpu_ns/1000) as cpu_us, SUM(cpu_ns/calls/1000) as cpu_us_average";
  string q = "SELECT session, config, file, event_name, event_class, "+
	     (group_by? group_select: select)+" "
	     "  FROM average_profiling "+
	     (sizeof(w)? "WHERE " + w: "")+
	     (group_by? " GROUP BY "+group_by:"")+
	     (sort? " ORDER BY "+sort+" "+(sort_dir||""): "");
  //werror("Query: %O\n", q);
  return sql->query( q );
}

class TagEmitAPEvents
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "ap-events";

  class WhereEqual(string column, string value)
  {
    string query(Sql.Sql db)
    {
      return sprintf("%s = '%s'", column, db->quote(value));
    }
  }
  
  class WhereLike(string column, string value)
  {
    string query(Sql.Sql db)
    {
      return sprintf("%s like '%s'", column, db->quote(value));
    }
  }
  
  array get_dataset(mapping args, RequestID id)
  {
    array where = ({});

    void fix_arg(string name)
    {
      if(args[name] && args[name] != "")
	where += ({ WhereEqual(replace(name, "-", "_"), args[name]) });
    };
    
    map(({ "config", "config", "file", "event-class", "event-name"}), fix_arg);
    
    if(sizeof(args["file-glob"]||""))
      where += ({ WhereLike("file", args["file-glob"]) });
    
    if(sizeof(args["order-by"] || ""))
      args["order-by"] = replace(args["order-by"], "-", "_");
    else
      m_delete(args, "order-by");
    
    if(sizeof(args["group-by"] || ""))
      args["group-by"] = replace(args["group-by"], "-", "_");
    else
      m_delete(args, "group-by");
    
    return sql2emit(get_events(where, args["order-by"], args["sort-dir"],
			       args["group-by"]));
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

<form>
  <table cellspacing='0' cellpadding='0' border='0'>
    <tr>
      <td><b>Session:</b></td>
      <td>
        <default name='session' value='&form.session;'>
  	  <select name='session'>
  	    <option value=''>-- All --</option>
  	    <emit source='ap-names' column='session'>
  	      <option value='&_.name;'>&_.name;</option>
  	    </emit>
  	  </select>
        </default>
      </td>

      <td><b>Config:</b></td>
      <td>
        <default name='config' value='&form.config;'>
          <select name='config'>
            <option value=''>-- All --</option>
            <emit source='ap-names' column='config'>
              <option value='&_.name;'>&_.name;</option>
            </emit>
          </select>
        </default>
      </td>
    </tr>

    <tr>
      <!--
      <td><b>File:</b></td>
      <td>
        <default name='file' value='&form.file;'>
          <select name='file'>
            <option value=''>-- All --</option>
            <emit source='ap-names' column='file'>
              <option value='&_.name;'>&_.name;</option>
            </emit>
          </select>
        </default>
      </td>
      -->
      <td><b>File glob:</b></td>
      <td colspan='3'>
        <input type='text' name='file-glob' value='&form.file-glob;' size='80'/>
      </td>
    </tr>

    <tr>
      <td><b>Event Class:</b></td>
      <td>
        <default name='event-class' value='&form.event-class;'>
          <select name='event-class'>
            <option value=''>-- All --</option>
            <emit source='ap-names' column='event_class'>
              <option value='&_.name;'>&_.name;</option>
            </emit>
          </select>
        </default>
      </td>

      <td><b>Event Name:</b></td>
      <td>
        <default name='event-name' value='&form.event-name;'>
          <select name='event-name'>
            <option value=''>-- All --</option>
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
            <option value='real-us'>Real</option>
            <option value='cpu-us'>CPU</option>
            <option value='calls'>Calls</option>
            <option value='session'>Session</option>
            <option value='config'>Config</option>
            <option value='file'>File</option>
            <option value='event-class'>Event Class</option>
            <option value='event-name'>Event Name</option>
          </select>
        </default>
      </td>
      <td><b>Direction:</b></td>
      <td>
        <default name='sort-dir' value='&form.sort-dir;'>
          <select name='sort-dir'>
            <option value='DESC'>Descending</option>
            <option value='ASC'>Ascending</option>
          </select>
        </default>
      </td>
    </tr>

    <tr>
      <td><b>Broup by:</b></td>
      <td>
        <default name='group-by' value='&form.group-by;'>
          <select name='group-by'>
            <option value=''>-- None --</option>
            <option value='file'>File</option>
            <option value='event-class'>Event Class</option>
            <option value='event-name'>Event Name</option>
          </select>
        </default>
      </td>
    </tr>

  </table>
  <table><tr><td><input type='submit' name='update' value=' Update ' /></td></tr></table>
</form>

<if match='x&form.page; is x'>
  <set variable='form.page' value='1'/>
</if>

<set variable='var.maxrows' value='40'/>
<set variable='var.skiprows' expr='&var.maxrows; * (&form.page; - 1)'/>

<define variable='var.emit-args'>
  session='&form.session;'
  config='&form.config;'
  file='&form.file;'
  file-glob='&form.file-glob;'
  event-class='&form.event-class;'
  event-name='&form.event-name;'
  order-by='&form.sort;'
  sort-dir='&form.sort-dir;'
  group-by='&form.group-by;'
</define>

<emit source='ap-events' ::='&var.emit-args;' rowinfo='var.rows'/>
<set variable='var.pages' expr='1 + &var.rows;/&var.maxrows;'/>

<if sizeof='form.session == 0'>
  <set variable='var.show-session' value='t'/>
</if>
<if sizeof='form.config == 0'>
  <set variable='var.show-config' value='t'/>
</if>
<if sizeof='form.file == 0'>
  <set variable='var.show-file' value='t'/>
</if>
<if sizeof='form.event-class == 0'>
  <set variable='var.show-event-class' value='t'/>
</if>
<if sizeof='form.event-name == 0'>
  <set variable='var.show-event-name' value='t'/>
</if>

<if variable='form.group-by == file'>
  <unset variable='var.show-event-class'/>
  <unset variable='var.show-event-name'/>
</if>
<if variable='form.group-by == event-class'>
  <unset variable='var.show-file'/>
  <unset variable='var.show-event-name'/>
</if>
<if variable='form.group-by == event-name'>
  <unset variable='var.show-file'/>
  <unset variable='var.show-event-class'/>
</if>

<if variable='var.rows > 0'>
  Found &var.rows; hits.<br />
  <pager/>
  <table cellspacing='0'>
    <tr bgcolor='#dee2eb'>
      <if variable='var.show-session'>
  	<td><b>Session</b>&nbsp;</td>
      </if>
      <if variable='var.show-config'>
  	<td><b>Config</b>&nbsp;</td>
      </if>
      <if variable='var.show-file'>
  	<td><b>File</b>&nbsp;</td>
      </if>
      <if variable='var.show-event-class'>
  	<td><b>Event&nbsp;Class</b>&nbsp;</td>
      </if>
      <if variable='var.show-event-name'>
  	<td><b>Event&nbsp;Name</b>&nbsp;</td>
      </if>
      <td><b>Calls</b>&nbsp;</td>
      <td><b>Real&nbsp;(탎)</b>&nbsp;</td>
      <td><b>Av.&nbsp;Real&nbsp;(탎)</b>&nbsp;</td>
      <td><b>CPU&nbsp;(탎)</b>&nbsp;</td>
      <td><b>Av.&nbsp;CPU&nbsp;(탎)</b></td>
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
        <if variable='var.show-session'>
  	  <td>&_.session;</td>
  	</if>
        <if variable='var.show-config'>
  	  <td>&_.config;</td>
  	</if>
        <if variable='var.show-file'>
  	  <td>&_.file;</td>
  	</if>
        <if variable='var.show-event-class'>
  	  <td>&_.event-class;</td>
  	</if>
        <if variable='var.show-event-name'>
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
</if>

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
