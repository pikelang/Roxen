
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
  int list_style = sizeof(RXML.user_get_var("list-style-boxes", "usr"));

//    docs += "<a href='"+path("whatsnew.html")+"'>"
//      "Release notes</a><br />";

  void add_doc_link(string doc_path, string title) {
    if (exists(doc_path)) {
      string s = "<a href='" + (doc_path - "index.html") + "'>"
	"<font size='-1'>" + title + "</font>"
	"</a>";
      if (list_style)
	docs +=
	  "<li style='margin-left: -0.9em; margin-right: 0.9em;'>"+
	  s+"</br></li>\n";
      else
	docs +=
	  "<tr><td valign='top'>"+s+"</td></tr>\n";
    }
  };
  
  foreach( ({ "docs/roxen/4.0/", "docs/chilimoon/2004/" }), string rpath )
  {
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

    add_doc_link(rpath + "faq/main/index.xml",
		 "FAQ");
  }

  foreach( ({"docs/pike/7.6/", "docs/pike/7.7/" }), string ppath )
  {
    add_doc_link(ppath + "tutorial/index.html",
		 "Pike Tutorial");
  }

  if( docs == "" )
  {
    docs =
      "<font color='&usr.warncolor;'>No documentation found at all</font>";
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

