/*
 * Locale stuff.
 * <locale-token project="roxen_config"> _ </locale-token>
 */
#include <roxen.h>
#define _(X,Y)	_DEF_LOCALE("roxen_config",X,Y)


constant box      = "small";
constant box_initial = 1;
constant box_position = -1;

String box_name = _(363,"Documentation links");
String box_doc = _(364,"Links to the inline documentation");

#define path(X) X
string parse( RequestID id )
{
  string docs = "";
  function exists =
     id->conf->find_module( "config_filesystem#0" )->stat_file;

  docs += "<a href='"+path("whatsnew.html")+"'>"+
    _(0,"Release notes")+"</a><br />";
  
  foreach( ({ "docs/roxen/2.2/", "docs/roxen/2.1/" }), string rpath )
  {
    if( exists(  rpath + "creator/index.html" ) )
      docs += "<a href='"+path(rpath+"creator/")+"'>"+
	_(0,"Web Site Creator")+"</a><br />";

    if( exists( rpath + "administrator/index.html" ) )
      docs += "<a href='"+path(rpath+ "administrator/")+"'>"+
	_(0,"Administrator Manual")+"</a><br />";

    if( exists( rpath + "user/index.html" ) )
      docs += "<a href='"+path(rpath+ "user/")+"'>"+
	_(0,"User Manual")+"</a><br />";

    if( exists( rpath + "tutorial/rxml/index.html" ) )
      docs += "<a href='"+path(rpath+ "tutorial/rxml/")+"'>"+
	_(0,"RXML Tutorial")+"</a><br />";
    else if( exists( rpath + "rxml_tutorial/index.html" ) )
      docs += "<a href='"+path(rpath+ "rxml_tutorial/")+"'>"+
	_(0,"RXML Tutorial")+"</a><br />";

    if( exists( rpath+"programmer/index.html") )
      docs += "<a href='"+path(rpath+ "programmer/")+"'>"+
	_(0,"Programmer Manual")+"</a><br />";
  }

  foreach( ({"docs/pike/7.1/","docs/pike/7.0/" }), string ppath )
  {
    if( exists( ppath+"tutorial/index.html") )
      docs += "<a href='"+path(ppath+ "tutorial/")+"'>"+
	_(0,"Pike Tutorial")+"</a><br />";
  }

  if( docs == "" )
    docs="<font color='&usr.warncolor;'>"+
      _(0,"No documentation found at all")+"</font>";

  return "<box type='"+box+"' title='"+box_name+"'>"+docs+"</box>";
}

