#include <config_interface.h>
#include <config.h>
#include <roxen.h>
//<locale-token project="roxen_config">_</locale-token>
#define _(X,Y)	_STR_LOCALE("roxen_config",X,Y)

mapping images = ([]);
int image_id = time() ^ gethrtime();

string is_image( string x )
{
  if( !search( x, "GIF" ) )
    return "gif";
  if( has_value( x, "JFIF" ) )
    return "jpeg";
  if( !search( x, "\x89PNG" ) )
    return "png";
}

string store_image( string x )
{
  string id = (string)image_id++;

  images[ id ] = ([
    "type":"image/"+(is_image( x )||"unknown"),
    "data":x,
    "len":strlen(x),
  ]);
  
  return id;
}

mapping|string parse( RequestID id )
{
  if( id->variables->image )
  {
    return m_delete( images, id->variables->image );
  }
  Sql.Sql db = DBManager.get( id->variables->db );
  string url = DBManager.db_url( id->variables->db );
  string res =
    "<use file='/template'/><tmpl>"
    "<topmenu base='../' selected='dbs'/>"
    "<content><cv-split><subtablist width='100%'><st-tabs>"
    "<!--<insert file='subtabs.pike'/>--></st-tabs><st-page>"
    "<input type=hidden name='db' value='&form.db:http;' />\n";

  if( id->variables->table )
    res += "<input type=hidden name='table' value='&form.table:http;' />\n";

  res +=
    "<br />"
    "<table cellspacing=0 cellpadding=0 border=0 width=100% bgcolor='&usr.titlebg;'><tr><td>"
    "<colorscope bgcolor='&usr.titlebg;' text='&usr.titlefg;'>"
    "<cimg border='0' format='gif' src='&usr.database-small;' alt='' "
    "max-height='20'/></td><td>"
    "<gtext fontsize='20'>"+id->variables->db+
    "</gtext></colorscope></td></tr>"
    "<tr><td></td><td>";
  
  if( !url )
    res += "<b>Internal database</b>";
  else
    res += "<b>"+url+"</b>";

  res += "</td></tr><tr><td></td><td>";

  res += "<table>";

  array table_data = ({});
  int sort_ok;
  array sel_t_columns = ({});
  string deep_table_info( string table )
  {
    string res = "<tr><td></td><td colspan='3'><table>";
    array data = db->query( "describe "+table );
    foreach( data, mapping r )
    {
      if( search( lower_case(r->Type), "blob" ) == -1 )
	sel_t_columns += ({ r->Field });
      res += "<tr>\n";
      res += "<td><font size=-1><b>"+r->Field+"</b></font></td>\n";
      res += "<td><font size=-1>"+r->Type+"</font></td>\n";
      res += "<td><font size=-1>"+(strlen(r->Key)?_(0,"Key"):"")+"</font></td>\n";
      res += "<td><font size=-1>"+r->Extra+"</font></td>\n";
      res += "</tr>\n";
    }
    return res+ "</table></td></tr>";
  };

  void add_table_info( string table, mapping tbi )
  {
    string res ="";
    res += "<tr>\n";
    res += "<td> <cimg src='&usr.table-small;' max-height='12'/> </td>\n";
    res += "<td> <a href='browser.pike?db=&form.db:http;&table="+
      Roxen.http_encode_string(table)+"'>"+table+"</a> </td>";

    
    if( tbi )
    {
      res += "<td align=right> <font size=-1>"+
	tbi->Rows+" "+_(0,"rows")+"</font></td><td align=right><font size=-1>"+
	( (int)tbi->Data_length+(int)tbi->Index_length)/1024+_(0,"KiB")+
	"</font></td>";
    }
    res += "</tr>\n";
    if( tbi )
      sort_ok = 1;
    table_data += ({({ table,
		     (tbi ?(int)tbi->Data_length+ (int)tbi->Index_length:0),
		     (tbi ?(int)tbi->Rows:0),
		     res+
		       ( id->variables->table == table ?
			 deep_table_info( table ) : "")
		  })});
  };

  if( catch
  {
    array(mapping) tables = db->query( "show table status" );
    
    foreach( tables, mapping tb )
      add_table_info( tb->Name, tb );
  } )
  {
    if( catch
    {
      object _tables = db->big_query( "show tables" );
      array tables = ({});
      while( array q = _tables->fetch_row() )
	tables += q;
      foreach( tables, string tb )
	add_table_info( tb, 0 );
    } )
      ;
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
      "<tr><td align=right>"+SEL("name",1)+"</td>"
      "<td><b><a href='browser.pike?db=&form.db:http;&sort=name'>"+
      _(0,"Name")+
      "</a></b></td>\n"
      "<td align=right><b><a href='browser.pike?db=&form.db:http;&sort=rows'>"+
      SEL("rows",0)+String.capitalize(_(0,"rows"))+
      "</a></b></td>\n"
      "<td align=right><b><a href='browser.pike?db=&form.db:http;&sort=size'>"+
      SEL("size",0)+_(0,"Size")+
      "</a></b></td>\n"
      "</tr>";
  }
  res += column( table_data, 3 )*"\n";

  res += "</table></td></tr></table>";

  if( !id->variables->query || id->variables["clear_q.x"] )
    if( id->variables->table )
      id->variables->query = "SELECT "+(sel_t_columns*", ")+" FROM "+id->variables->table;
    else
      id->variables->query = "SHOW TABLES";

  res +=
    "<table><tr><td valign=top><font size=-1>"
    "<textarea rows=4 cols=40 name='query'>&form.query:html;</textarea>"
    "</font></td><td valign=top>"
    "<submit-gbutton2 name=clear_q> "+_(0,"Clear query")+" </submit-gbutton2>"
    "<br />"
    "<submit-gbutton2 name=run_q> "+_(0,"Run query")+" </submit-gbutton2>"
    "<br /></td></tr></table>";

  if( id->variables["run_q.x"] )
  {
    mixed e = catch {
      string q = id->variables->query;

      string a, b, c;
      multiset right_columns = (<>);
//      multiset image_columns = (<>), 
//       while( sscanf( q, "%sIMAGE(%s)%s", a, b, c ) == 3 )
//       {
// 	q = a+b+c;
// 	image_columns[String.trim_all_whites(b)]=1;
//       }

      object big_q = db->big_query( q );

      res += "<table celpadding=2><tr>";

      int column;
      foreach( big_q->fetch_fields(), mapping field )
      {
	switch( field->type  )
	{
	  case "long":
	  case "int":
	  case "short":
	    right_columns[column]=1;
	    res += "<td align=right>";
	    break;
	  default:
	    res += "<td>";
	}
	res += "<b><font size=-1>"+field->name+"</font size=-1></b></td>\n";
// 	if( image_columns[field->name] )
// 	  image_columns[column] = 1;
	column++;
      }
      res += "</tr>";
      
      while( array q = big_q->fetch_row() )
      {
	res += "<tr>";
	for( int i = 0; i<sizeof(q); i++ )
	  if( /* image_columns[i] ||*/ is_image( q[i] ) )
	    res +=
           "<td><img src='browser.pike?image="+store_image( q[i] )+"' /></td>";
	  else if( right_columns[i] )
	    res += "<td align=right>"+ Roxen.html_encode_string(q[i]) +"</td>";
	  else
	    res += "<td>"+ Roxen.html_encode_string(q[i]) +"</td>";
      }
      res += "</table>";
    };
    if( e )
      res += "<font color='&usr.warncolor;'>"+describe_error(e)+"</font>";
  }
  
  // TODO: actions:
  //    move
  //    rename ( !(local || shared) )
  //    delete ( !(local || shared) )
  //    clear
      return res+"</st-page></subtablist></cv-split></content></tmpl>";
}
