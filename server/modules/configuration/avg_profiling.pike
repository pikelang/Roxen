// This is a roxen module. Copyright © 2001 - 2009, Roxen IS.

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
    DBManager.is_module_table( this_object(), query("db"),
			       "average_profiling",
			       "Average profiling information taken from "
			       "the built-in profiling system in Roxen. "
			       "Start Roxen with the define AVERAGE_PROFILNG"
			       " to collect data.");
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
    "real_ns/1000 as real_ms, round(real_ns/calls/1000, 2) as real_ms_average, "
    "cpu_ns/1000 as cpu_ms, round(cpu_ns/calls/1000, 2) as cpu_ms_average";
  string group_select =
    "SUM(calls) as calls, "
    "SUM(real_ns/1000) as real_ms, round(SUM(real_ns/calls/1000), 2) as real_ms_average, "
    "SUM(cpu_ns/1000) as cpu_ms, round(SUM(cpu_ns/calls/1000), 2) as cpu_ms_average";
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
      return sprintf("%s like '%s'", column,
		     replace(db->quote(value),
			     ({ "*", "?", "%", "_" }),
			     ({ "%", "_", "\\%", "\\_" }) ));
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
    
    map(({ "config", "config", "file", "event-class", "event-name", "session"}),
	   fix_arg);
    
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
  <if variable='var.pages > 1'>
    <for from='1' to='&var.pages;' step='1' variable='var.page'>
      <if variable='var.page == &form.page;'>
  	<b>[&var.page;]</b>
      </if><else>
  	<a href='&page.path;?session=&form.session;&amp;config=&form.config;&amp;file=&form.file;&amp;event-class=&form.event-class;&amp;event-name=&form.event-name;&amp;order-by=&form.order-by;&amp;sort-dir=&form.sort-dir;&amp;page=&var.page;'>[&var.page;]</a>
      </else>&nbsp;
    </for>
  </if>
</define>

<define container='box' scope='args'>
  <table border='0' cellpadding='1' cellspacing='0' width='100%' bgcolor='#dee2eb'>
      <tr nowrap='nowrap'>
        <td bgcolor='#dee2eb' nowrap='nowrap' valign='bottom'>
	  &nbsp;<gtext fontsize='12' font='franklin gothic demi'
	               bgcolor='dee2eb'>&args.title;</gtext></td>
      </tr>
      <tr>
        <td>
 	  <table bgcolor='#ffffff' cellspacing='0' cellpadding='3'
	         border='0' width='100%'>
            <tr>
	      <td><contents/></td>
	    </tr>
	  </table>
	</td>
      </tr>
    </table>
</define>

<body bgcolor='white'>

<if not='not' variable='form.order-by'>
  <set variable='form.order-by' value='real-ms'/>
</if>

<if not='not' variable='form.sort-dir'>
  <set variable='form.sort-dir' value='DESC'/>
</if>

<box title='Selection'>
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
  
  	<td><b>Configuration:</b></td>
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
  	  <default name='order-by' value='&form.order-by;'>
  	    <select name='order-by'>
  	      <option value='real-ms'>Real</option>
  	      <option value='cpu-ms'>CPU</option>
  	      <option value='calls'>Calls</option>
  	      <option value='session'>Session</option>
  	      <option value='config'>Configuration</option>
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
  	<td><b>Group by:</b></td>
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
    <table>
      <tr><td><input type='submit' name='update' value=' Update ' /></td></tr>
    </table>
  </form>
</box>

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
  order-by='&form.order-by;'
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
  <unset variable='var.show-session'/>
  <unset variable='var.show-config'/>
  <unset variable='var.show-event-class'/>
  <unset variable='var.show-event-name'/>
</if>
<if variable='form.group-by == event-class'>
  <unset variable='var.show-session'/>
  <unset variable='var.show-config'/>
  <unset variable='var.show-file'/>
  <unset variable='var.show-event-name'/>
</if>
<if variable='form.group-by == event-name'>
  <unset variable='var.show-session'/>
  <unset variable='var.show-config'/>
  <unset variable='var.show-file'/>
  <unset variable='var.show-event-class'/>
</if>

<box title='Result'>
  Found &var.rows; hits.<br />
  <if variable='var.rows > 0'>
    <pager/>
    <table cellspacing='0'>
      <tr bgcolor='#dee2eb'>
  	<if variable='var.show-session'>
  	  <td><b>Session</b>&nbsp;</td>
  	</if>
  	<if variable='var.show-config'>
  	  <td><b>Configuration</b>&nbsp;</td>
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
  	<td><b>Real&nbsp;(ms)</b>&nbsp;</td>
  	<td><b>Av.&nbsp;Real&nbsp;(ms)</b>&nbsp;</td>
  	<td><b>CPU&nbsp;(ms)</b>&nbsp;</td>
  	<td><b>Av.&nbsp;CPU&nbsp;(ms)</b></td>
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
  	  <td align='right'>&_.real-ms;</td>
  	  <td align='right'>&_.real-ms-average;</td>
  	  <td align='right'>&_.cpu-ms;</td>
  	  <td align='right'>&_.cpu-ms-average;</td>
  	</tr>
      </emit>
    </table>
    
    <pager/>
  </if>
</box>

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
