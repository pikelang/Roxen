array describe_metadata_var(array in)
{
  return ({ "<font size=+1><b>"+in[0]+"</b></font>", 
	    "<var name='"+in[1]+"' default='"+in[2]+"' "+
	    (in[3]==3?"choices='"+in[5]+"' ":" ")+
	    " type='"+
 	    ((in[3]==0)?"string":"")+
 	    (in[3]==1?"text":"")+
 	    (in[3]==3?"select":"")+
	    "'>",
	    ({ "<font size=-1><i>"+in[4]+"</i></font>" }) });
}

array get_content_types( object id, object wa )
{
  return indices( wa->name_to_type );
}

string get_content_type( string f, object id, object wa, mapping|void m )
{
  string ct;

  if (m) {
    ct = m[ "content_type" ];

    if (wa->content_types[ ct ])
      return wa->content_types[ ct ]->name;
  }
  if (f) {
    ct = wa->get_md(id, f)[ "content_type" ];

    if (wa->content_types[ ct ])
      return wa->content_types[ ct ]->name;
  }
  return wa->content_types[ "text/html" ]->name;
}


string page_editmetadata( object id, mapping|void m)
{
  object wa = id->misc->wa;
  string f = id->variables->path;

  if(!m && f)
    m = wa->get_md(id, f);
  
  foreach (glob( "__*", indices( m ) ), string s)
    m_delete( m, s );
  
  array (string) templates = ({ "No template", "default.tmpl" });
  
  array rows = ({
    ({ "Type", "meta_content_type", 
       get_content_type(f, id, wa, m), 3,
       " This is the type of the file. "
       /* Normal for text-files is text/html,"
	  " most images are image/gif or image/jpeg."*/,
       get_content_types( id, wa ) * ","
    }),
    ({ "Template", "meta_template", m->template||"No template", 3,
       " This is the template used on this page. You can see all templates "
       "available under the 'templates' tab.", templates * ","
    }),
    ({ "Title", "meta_title", m->title||"No title", 0,
       " This is the title of the page. Make sure that it accurately "
       "describes it"
    }),
    ({ "Keywords", "meta_keywords", m->keywords||"", 0,
       " Document keywords. These are primarily used when search-engines "
       "are indexing the site."
    }),
    ({ "Description<p><br><br><br>", "meta_description", 
       m->description||"\n", 1,
       " Document description. this is also primarily used when "
       "search-engines are indexing the site."
    }),
  });
  
  return "<b>File Metadata for "+id->variables->path+":</b><p>\n" + 
    html_table(({ "Data", "Value", ({ "Description" }) }),
	       Array.map(rows, describe_metadata_var));
}
