inherit "wizard";
import AutoWeb;

constant name = "Upload File";

string page_0( object id )
{
  return "<b>Upload to "+id->variables->path+"</b>"
    +Error(id)->get() + 
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
  //werror("Variables %O\n", id->variables);
  if(!id->variables["the_file.filename"]||
     !sizeof(id->variables["the_file.filename"])||
     !sizeof(id->variables["the_file"]))
  {
    Error(id)->set("No such file "+id->variables["the_file.filename"]);
    return 1;
  }
  id->variables->filename=id->variables["the_file.filename"];
  if(id->misc->state->upload_co)
    remove_call_out(id->misc->state->upload_co);
  id->misc->state->upload = id->variables->the_file;
  //id->misc->state->upload_co =
  //	    call_out( cleanup_the_file, 3600, id->misc->state);
  m_delete(id->variables, "the_file");
  Error(id)->reset();
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
  result += Error(id)->get()+"<b>Enter remote filename:</b>";
  result += "<var size=20 name=filename default=" + filename + ">";
  return result;
}

mixed verify_1( object id)
{
  string path;
  if(id->variables->filename[0]=='/')
    path=id->variables->filename;
  else
    path=combine_path( id->variables->path, id->variables->filename );

  if(AutoFile(id, path)->type()=="File")
  {
    Error(id)->set("File <b>"+html_encode_string(path)+"</b> exists.");
    return -1;
  }
  
  if(AutoFile(id, path)->type()=="Directory")
  {
    Error(id)->set("Directory <b>"+html_encode_string(path)+"</b> exists.");
    return -1;
  }
  
  Error(id)->reset();
}

string page_2(object id)
{
  return Error(id)->get()
    + EditMetaData()->page(id, combine_path( id->variables->path,
					     id->variables->filename),
			   MetaData(id, id->variables->filename)->
			   get_from_html(id->misc->state->upload));
}

mixed wizard_done(object id)
{
  EditMetaData()->done(id, combine_path( id->variables->path,
					 id->variables->filename));
  AutoFile(id, combine_path( id->variables->path, id->variables->filename))->
    save(id->misc->state->upload);
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
