// Locale stuff.
// <locale-token project="roxen_config"> _ </locale-token>

#include <roxen.h>
#define _(X,Y)	_DEF_LOCALE("roxen_config",X,Y)


constant box      = "small";
constant box_initial = 1;
constant box_position = -1;

LocaleString box_name = _(363,"Documentation links");
LocaleString box_doc = _(364,"Links to the inline documentation");

string parse( RequestID id )
{
  string docs = "";
  function exists =
     id->conf->find_module( "config_filesystem#0" )->stat_file;
  int list_style = sizeof(RXML.user_get_var("list-style-boxes", "usr"));

//    docs += "<a href='"+path("whatsnew.html")+"'>"+
//      _(390,"Release notes")+"</a><br />";

  void add_doc_link(string doc_path, string title) {
    if (exists(doc_path)) {
      string s = "<a href='" + (doc_path - "index.html") + "'>"
	"<font size='-1'>" + title + "</font>"
	"</a>";
      if (list_style)
	docs +=
	  "<li style='margin-left: -0.9em; margin-right: 0.9em;'>"+
	  s+"</li>";
      else
	docs +=
	  "<tr><td valign='top'>"+s+"</td></tr>";
    }
  };
  
  foreach( ({ "docs/roxen/3.4/" }), string rpath )
  {
    add_doc_link(rpath + "content_editor_manual/index.xml",
		 _(524, "Content Editor"));

    add_doc_link(rpath + "content_editor_manual_(i)/index.xml",
		 _(512, "Content Editor (Instant Edition)"));

    add_doc_link(rpath + "content_editor_manual_(i_m)/index.xml",
		 _(357, "Content Editor (Instant Edition for Mac)"));

    add_doc_link(rpath + "web_developer_manual/index.xml",
		 _(514, "Web Developer"));

    add_doc_link(rpath + "administrator_manual/index.xml",
		 _(516, "Administrator"));

    add_doc_link(rpath + "system_developer_manual_java/index.xml",
		 _(390, "System Developer (Java)"));

    add_doc_link(rpath + "system_developer_manual/index.xml",
		 _(515, "System Developer (Pike)"));

    add_doc_link(rpath + "forms_and_response_module/index.xml",
		 _(517, "Forms And Response Module"));

    add_doc_link(rpath + "categorization_module/index.xml",
		 _(518, "Categorization Module"));

    add_doc_link(rpath + "forum_manual/index.xml",
		 _(523, "Forum Module"));
    
    add_doc_link(rpath + "tutorial/index.xml",
		 _(519, "Tutorials"));

    add_doc_link(rpath + "faq/main/index.xml",
		 _(458, "FAQ"));
  }

  foreach( ({ "docs/roxen/2.2/", "docs/roxen/2.1/" }), string rpath )
  {
    add_doc_link(rpath + "creator/index.html",
		 _(391, "Web Site Creator"));

    add_doc_link(rpath + "administrator/index.html",
		 _(392, "Administrator Manual"));

    add_doc_link(rpath + "user/index.html",
		 _(393, "User Manual"));

    if (exists(rpath + "tutorial/rxml/index.html"))
      add_doc_link(rpath + "tutorial/rxml/index.html",
		   _(394, "RXML Tutorial"));
    else if (exists(rpath + "tutorial/rxml_tutorial.html"))
      add_doc_link(rpath + "tutorial/rxml/index.html",
		   _(394, "RXML Tutorial"));

    add_doc_link(rpath + "programmer/index.html",
		 _(395, "Programmer Manual"));
  }

  foreach( ({"docs/pike/7.1/","docs/pike/7.0/" }), string ppath )
  {
    add_doc_link(ppath + "tutorial/index.xml",
		 _(396, "Pike Tutorial"));
  }

  if( docs == "" )
  {
    docs =
      "<font color='&usr.warncolor;'>" +
      _(397, "No documentation found at all") + 
      "</font>";
  }
  else
  {
    if (list_style)
      docs = "<ul>" + docs + "</ul>";
    else
      docs = "<table>" + docs + "</table>";
  }
  
  return "<box type='"+box+"' title='"+box_name+"'>"+docs+"</box>";
}

