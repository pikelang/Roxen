
constant box      = "small";
constant box_initial = 1;
constant box_position = -1;

constant box_name = "Documentation links";
constant box_doc = "Links to the inline documentation";

string parse( RequestID id )
{
  string docs = "";
  function exists =
     id->conf->find_module( "config_filesystem#0" )->stat_file;

//    docs += "<a href='"+path("whatsnew.html")+"'>"
//      "Release notes</a><br />";

  void add_doc_link(string doc_path, string title) {
    if (exists(doc_path))
      docs +=
	"<tr><td valign='top'>"
	"<a href='" + (doc_path - "index.html") + "'>"
	"<font size='-1'>" + title + "</font>"
	"</a>"
	"</td></tr>";
  };
  
  foreach( ({ "docs/roxen/3.2/" }), string rpath )
  {
    add_doc_link(rpath + "content_editor_manual_(instant)/index.html",
		 "Content Editor (Instant Edition)");

    add_doc_link(rpath + "content_editor_manual_(advanced)/index.html",
		 "Content Editor (Advanced Edition)");

    add_doc_link(rpath + "web_developer_manual/index.html",
		 "Web Developer");

    add_doc_link(rpath + "system_developer_manual/index.html",
		 "System Developer");

    add_doc_link(rpath + "administrator_manual/index.html",
		 "Administrator");

    add_doc_link(rpath + "forms_and_response_module/index.html",
		 "Forms And Response Module");

    add_doc_link(rpath + "categorization_module/index.html",
		 "Categorization Module");

    add_doc_link(rpath + "tutorial/index.html",
		 "Tutorials");
  }

  foreach( ({ "docs/roxen/2.2/", "docs/roxen/2.1/" }), string rpath )
  {
    add_doc_link(rpath + "creator/index.html",
		 "Web Site Creator");

    add_doc_link(rpath + "administrator/index.html",
		 "Administrator Manual");

    add_doc_link(rpath + "user/index.html",
		 "User Manual");

    if (exists(rpath + "tutorial/rxml/index.html"))
      add_doc_link(rpath + "tutorial/rxml/index.html",
		   "RXML Tutorial");
    else if (exists(rpath + "tutorial/rxml_tutorial.html"))
      add_doc_link(rpath + "tutorial/rxml/index.html",
		   "RXML Tutorial");

    add_doc_link(rpath + "programmer/index.html",
		 "Programmer Manual");
  }

  foreach( ({"docs/pike/7.1/","docs/pike/7.0/" }), string ppath )
  {
    add_doc_link(ppath + "tutorial/index.html",
		 "Pike Tutorial");
  }

  if( docs == "" )
    docs =
      "<tr><td><font color='&usr.warncolor;'>"
      "No documentation found at all"
      "</font></td></tr>";
  
  docs = "<table>" + docs + "</table>";
  
  return "<box type='"+box+"' title='"+box_name+"'>"+docs+"</box>";
}

