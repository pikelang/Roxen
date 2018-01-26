//! A mapping class

inherit Variable.Variable;

#include <roxen.h>

// Locale macros
//<locale-token project="roxen_config"> LOCALE </locale-token>

#define LOCALE(X,Y)    \
  ([string](mixed)Locale.translate("roxen_config",roxenp()->locale->get(),X,Y))

constant type = "Mapping";
int width = 0;

string transform_to_form( mixed what )
//! Override this function to do the value->form mapping for
//! individual elements in the array.
{
  return (string)what;
}

mixed transform_from_form( string what,mapping v )
{
  return what;
}

protected int _current_count = time()*100+(gethrtime()/10000);
int(0..1) set_from_form(RequestID id)
{
  int rn, do_goto;
  mapping new = ([]);
  mapping vl = get_form_vars(id);
  // first do the assign...
  if( (int)vl[".count"] != _current_count )
    return 0;
  _current_count++;

  // Update all values
  foreach( indices(vl), string vv )
    if( sscanf( vv, ".set.%da", rn ) && vl[".set."+rn+"b"] ) {
      new[vl[".set."+rn+"a"]] = transform_from_form( vl[".set."+rn+"b"], vl );
      m_delete(id->real_variables, path()+vv);
      m_delete(id->real_variables, path()+".set."+rn+"b");
    }

  // then the possible add.
  if( vl[".new.x"] )
  {
    do_goto = 1;
    m_delete( id->real_variables, path()+".new.x" );
    new[""] = transform_from_form( "",vl );
  }

  // .. and delete ..
  foreach( indices(vl), string vv )
    if( sscanf( vv, ".delete.%d.x%*s", rn )==2 )
    {
      do_goto = 1;
      m_delete( id->real_variables, path()+vv );
      m_delete( new, vl[".set."+rn+"a"] );
      m_delete( new, vl[".set."+rn+"b"] );
    }

  if(equal(new,query())) return 0;

  array b;
  mixed q = catch( b = verify_set_from_form( new ) );
  if( q || sizeof( b ) != 2 )
  {
    if( q )
      set_warning( q );
    else
      set_warning( "Internal error: Illegal sized array "
		   "from verify_set_from_form\n" );
    return 0;
  }

  int ret;
  if( b )
  {
    set_warning( b[0] );
    set( b[1] );
    ret = 1;
  }

  if( do_goto && !id->misc->do_not_goto )
  {
    RequestID nid = id;
    while( nid->misc->orig )
      nid = id->misc->orig;

    string section = RXML.get_var("section", "var");
    string query = nid->query;
    if( !query )
      query = "";
    else
      query += "&";

    //  The URL will get a fragment identifier below and since some
    //  broken browsers (MSIE) incorrectly includes the fragment in
    //  the last variable value we'll place section before random.
    query +=
      (section ? ("section=" + section + "&") : "") +
      "random=" + random(4949494);
    query += "&_roxen_wizard_id=" + Roxen.get_wizard_id_cookie(id);
    nid->misc->moreheads =
      ([
	"Location":nid->not_query+(nid->misc->path_info||"")+
	"?"+query+"#"+path(),
      ]);
    if( nid->misc->defines )
      nid->misc->defines[ " _error" ] = 302;
    else if( id->misc->defines )
      id->misc->defines[ " _error" ] = 302;
  }

  return ret;
}


array(string) render_row(string prefix, mixed val, int width)
{
  return ({ Variable.input( prefix+"a", val[0], width ),
	    Variable.input( prefix+"b", val[1], width ) });
}

LocaleString key_title = LOCALE(376, "Name");
LocaleString val_title = LOCALE(473, "Value");

string render_view( RequestID id, void|mapping additional_args )
{
  mapping val = query();
  string res = "<table>\n";

  if(sizeof(val))
  {
    res += "<tr><th>" + key_title + "</th>"
      "<th>" + val_title + "</th></tr>";
    foreach( sort(indices(val)), mixed var )
    {
      res += "<tr>\n"
	"<td>"+var+"</td>"
        "<td>"+transform_to_form(val[var])+"</td>\n"
	"</tr>\n";
    }
  }
  res += "</table>\n\n";
  return res;
}

string render_form( RequestID id, void|mapping additional_args )
{
  string prefix = path()+".";
  int i;

#define BUTTON(X,Y) ("<submit-gbutton2 name='"+X+"'>"+Y+"</submit-gbutton2>")
  string res = "<table id='" + path() + #"'>\n"
    "<input type='hidden' name='"+prefix+"count' value='"+_current_count+"' />\n";

  mapping val = query();

  if(sizeof(val)) {
    res += "<tr><th>" + key_title + "</th>"
      "<th>" + val_title + "</th></tr>";

    foreach( sort(indices(val)), mixed var ) {
      res += "<tr>\n<td>"+
	render_row(prefix+"set."+i,
		   ({ var,transform_to_form(val[var]) }) ,
		   width) * "</td><td>"
	+ "</td>\n";
      res += "\n<td class='button-cell'>"+
	BUTTON(prefix+"delete."+i, LOCALE(227, "Delete") )
	+"</td>";
      "</tr>";
      i++;
    }
  }

  res += "\n<tr><td colspan='3'>" +
     BUTTON(prefix+"new", LOCALE(297, "New row") )+
     "</td></tr></table>\n\n";

  return res;
}
