inherit "wizard";

constant name = "Upload File";

string page_0( object id )
{
  return "<b>Upload to "+id->variables->path+"</b>"
    +AutoWeb.Error(id)->get() + 
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
    AutoWeb.Error(id)->set("No such file "+id->variables["the_file.filename"]);
    return 1;
  }
  id->variables->filename=id->variables["the_file.filename"];
  if(id->misc->state->upload_co)
    remove_call_out(id->misc->state->upload_co);
  id->misc->state->upload = id->variables->the_file;
  //id->misc->state->upload_co =
  //	    call_out( cleanup_the_file, 3600, id->misc->state);
  m_delete(id->variables, "the_file");
  AutoWeb.Error(id)->reset();
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
  result += AutoWeb.Error(id)->get()+"<b>Enter remote filename:</b>";
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

  if(AutoWeb.AutoFile(id, path)->type()=="File")
  {
    AutoWeb.Error(id)->set("File "+path+" exists.");
    return -1;
  }
  AutoWeb.Error(id)->reset();
}

string page_2(object id)
{
  return AutoWeb.Error(id)->get()
    + AutoWeb.EditMetaData()->page(id, id->variables->path+
				   id->variables->filename,
             AutoWeb.MetaData(id, id->variables->filename)->
             get_from_html(id->misc->state->upload));
}

mixed wizard_done(object id)
{

  AutoWeb.EditMetaData()->done(id);
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
