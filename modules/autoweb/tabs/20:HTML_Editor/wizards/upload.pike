inherit "wizard";

constant name = "Upload File";

#define ERROR (id->variables->error?"<error>"+\
	       id->variables->error+"</error>":"")

string page_0( object id )
{
  return ERROR + "<b>Upload to " + id->variables->path + "</b>"
    "<p><b>Select local file:</b> <input type=file name=the_file>";
}

static void cleanup_the_file( mapping state )
{
  if(state) {
    m_delete( state, "upload" );
    m_delete( state, "upload_co" );
  }
}

int verify_0( object id )
{
  werror("Variables %O\n", indices(id->variables));
  if(!id->variables["the_file.filename"]||
     !sizeof(id->variables["the_file.filename"]))
  {
    id->variables->error="No such file";
    return 1;
  }
  id->variables->filename=id->variables["the_file.filename"];
  if(id->misc->state->upload_co)
    remove_call_out(id->misc->state->upload_co);
  id->misc->state->upload = id->variables->the_file;
  //id->misc->state->upload_co = call_out( cleanup_the_file, 3600,
  //					 id->misc->state);
  m_delete(id->variables, "the_file");
  m_delete(id->variables, "error");
}

string page_1( object id )
{
  string filename;
  string path;
  string result = "";
  array arr;

  path = id->variables->path;
  filename = id->variables->filename;
  path = combine_path( path, filename );
  arr = path / "/";
  path = arr[0..sizeof( arr )-2] * "/" + "/";
  filename = arr[-1];
  id->variables->path = path;
  id->variables->filename = filename;
  result += ERROR+"Enter remote filename";
  result += "<p><var size=20 name=filename default=" + filename + ">";
  return result;
}

mixed verify_1( object id)
{
  object wa = id->misc->wa;
  string path;
  if(id->variables->filename[0]=='/')
    path=id->variables->filename;
  else
    path=combine_path( id->variables->path, id->variables->filename );

  if(file_stat(wa->real_path(id, path)))
  {
    id->variables->error = "File "+path+" exists.";
    return -1;
  }
  m_delete(id->variables, "error");
}

#include "edit_md.h"

string page_2(object id)
{
  return ERROR
    + page_editmetadata( id, combine_path(id->variables->path,
					  id->variables->filename),
			 id->misc->wa->
			 get_md_from_html(id->variables->filename,
					  id->misc->state->upload));
}

mixed wizard_done(object id)
{
  object wa = id->misc->wa;
  mapping md = ([ ]);
  string path;
  if(id->variables->filename[0]=='/')
    path=id->variables->filename;
  else
    path=combine_path( id->variables->path, id->variables->filename );

  if(file_stat(wa->real_path(id, path)))
  {
    id->variables->error = "File "+path+" exists.";
    return -1;
  }

  foreach (glob( "meta_*", indices( id->variables )), string s)
    md[ s-"meta_" ] = id->variables[ s ];
  md[ "content_type" ] = wa->name_to_type[ md[ "content_type" ] ];
  if (md[ "template" ] == "No template")
    m_delete( md, "template" );
  wa->save_md_file(id, path, md);
  wa->save_file(id, path, id->misc->state->upload);
  if(id->misc->state->upload_co)
    remove_call_out(id->misc->state->upload_co);
  m_delete( id->misc->state, "upload" );
  m_delete( id->misc->state, "upload_co" );
}

string parse_wizard_page(string form, object id, string wiz_name)
{
  // Big kludge. No shit?
  return "<!--Wizard-->\n"
    "<form action='' method=post enctype=multipart/form-data>\n"
    + ::parse_wizard_page(form, id, wiz_name)[32..];
}
