// Locale stuff.
// <locale-token project="roxen_config"> _ </locale-token>

#include <roxen.h>
#define _(X,Y)	_DEF_LOCALE("roxen_config",X,Y)


constant box      = "small";
constant box_initial = 0;
constant box_position = -1;

String box_name = _(363,"Documentation links");
String box_doc = _(364,"Links to the inline documentation");

#define path(X) X
string parse( RequestID id )
{
  string docs = "";
  function exists =
     id->conf->find_module( "config_filesystem#0" )->stat_file;

//    docs += "<a href='"+path("whatsnew.html")+"'>"+
//      _(390,"Release notes")+"</a><br />";
  
  foreach( ({ "docs/roxen/3.2/" }), string rpath )
  {
    if( exists(  rpath + "content_editor_manual_(instant)/index.html" ) )
      docs += "<a href='"+path(rpath+"content_editor_manual_(instant)/")+"'>"+
	_(391,"Content Editor (Instant Edition)")+"</a><br />";

      if( exists(  rpath + "content_editor_manual_(advanced)/index.html" ) )
      docs += "<a href='"+path(rpath+"content_editor_manual_(advanced)/")+"'>"+
	_(391,"Content Editor (Advanced Edition)")+"</a><br />";

      if( exists(  rpath + "web_developer_manual/index.html" ) )
      docs += "<a href='"+path(rpath+"web_developer_manual/")+"'>"+
	_(391,"Web Developer")+"</a><br />";

      if( exists(  rpath + "system_developer_manual/index.html" ) )
      docs += "<a href='"+path(rpath+"system_developer_manual/")+"'>"+
	_(391,"System Developer")+"</a><br />";

      if( exists(  rpath + "administrator_manual/index.html" ) )
      docs += "<a href='"+path(rpath+"administrator_manual/")+"'>"+
	_(391,"Administrator")+"</a><br />";

      if( exists(  rpath + "forms_and_response_module/index.html" ) )
      docs += "<a href='"+path(rpath+"forms_and_response_module/")+"'>"+
	_(391,"Forms And Response Module")+"</a><br />";

      if( exists(  rpath + "categorization_module/index.html" ) )
      docs += "<a href='"+path(rpath+"categorization_module/")+"'>"+
	_(391,"Categorization Module")+"</a><br />";
  }

  foreach( ({ "docs/roxen/2.2/", "docs/roxen/2.1/" }), string rpath )
  {
    if( exists(  rpath + "creator/index.html" ) )
      docs += "<a href='"+path(rpath+"creator/")+"'>"+
	_(391,"Web Site Creator")+"</a><br />";

    if( exists( rpath + "administrator/index.html" ) )
      docs += "<a href='"+path(rpath+ "administrator/")+"'>"+
	_(392,"Administrator Manual")+"</a><br />";

    if( exists( rpath + "user/index.html" ) )
      docs += "<a href='"+path(rpath+ "user/")+"'>"+
	_(393,"User Manual")+"</a><br />";

    if( exists( rpath + "tutorial/rxml/index.html" ) )
      docs += "<a href='"+path(rpath+ "tutorial/rxml/")+"'>"+
	_(394,"RXML Tutorial")+"</a><br />";
    else if( exists( rpath + "rxml_tutorial/index.html" ) )
      docs += "<a href='"+path(rpath+ "rxml_tutorial/")+"'>"+
	_(394,"RXML Tutorial")+"</a><br />";

    if( exists( rpath+"programmer/index.html") )
      docs += "<a href='"+path(rpath+ "programmer/")+"'>"+
	_(395,"Programmer Manual")+"</a><br />";
  }

  foreach( ({"docs/pike/7.1/","docs/pike/7.0/" }), string ppath )
  {
    if( exists( ppath+"tutorial/index.html") )
      docs += "<a href='"+path(ppath+ "tutorial/")+"'>"+
	_(396,"Pike Tutorial")+"</a><br />";
  }

  if( docs == "" )
    docs="<font color='&usr.warncolor;'>"+
      _(397,"No documentation found at all")+"</font>";

  return "<box type='"+box+"' title='"+box_name+"'>"+docs+"</box>";
}

