/*
 * Locale stuff.
 * <locale-token project="roxen_config"> _ </locale-token>
 */
#include <roxen.h>
#define _(X,Y)	_DEF_LOCALE("roxen_config",X,Y)


constant box      = "small";
constant box_initial = 1;
constant box_position = -1;

String box_name = _(0,"Documentation links");
String box_doc = _(0,"Links to the inline documentation");

#define path(X) X
string parse( RequestID id )
{
  string docs = "";
  function exists =
     values(id->conf->modules["config_filesystem"]->copies)[0]->stat_file;

  foreach( ({ "docs/roxen/2.2/", "docs/roxen/2.1/" }), string rpath )
  {
  if( exists( "standard/" + rpath + "creator/index.html" ) )
    docs += "<a href='"+path(rpath+"creator/")+"'>Web Site Creator</a><br />";

  if( exists( "standard/" + rpath + "administrator/index.html" ) )
    docs += "<a href='"+path(rpath+ "administrator/")+"'>Administrator Manual</a><br />";

  if( exists( "standard/" + rpath + "user/index.html" ) )
    docs += "<a href='"+path(rpath+ "user/")+"'>User Manual</a><br />";

  if( exists( "standard/" + rpath + "tutorial/rxml/index.html" ) )
    docs += "<a href='"+path(rpath+ "tutorial/rxml/")+"'>RXML Tutorial</a><br />";

  else if( exists( "standard/" + rpath + "rxml_tutorial/index.html" ) )
    docs += "<a href='"+path(rpath+ "rxml_tutorial/")+"'>RXML Tutorial</a><br />";

  if( exists( "standard/"+rpath+"programmer/index.html") )
    docs += "<a href='"+path(rpath+ "programmer/")+"'>Programmer Manual</a><br />";
  }

  foreach( ({"docs/pike/7.1/","docs/pike/7.0/" }), string ppath )
  {
  if( exists( "standard/"+ppath+"tutorial/index.html") )
    docs += "<a href='"+path(ppath+ "tutorial/")+"'>Pike Tutorial</a><br />";

  if( docs == "" )
    docs="<font color='&usr.warncolor;'>No documentation found at all</font>";
  }
  return "<box type='"+box+"' title='"+box_name+"'>"+docs+"</box>";
}

