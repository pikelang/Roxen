inherit "wizard";

constant name = "Upload File";


string page_0( object id )
{
  return "<b>Upload " + id->variables->path + "</b>"
    "<p><b>Select local file:</b> <input type=file name=the_file>";
}

string page_1( object id )
{
  string filename;
  string path;
  string result = "";
  array arr;

  if (!id->variables->filename)
  {
    filename = id->variables[ "the_file.filename" ];
    path = id->variables->path;
    filename = replace( filename, "\\", "/" );
    filename = (filename / "/")[-1];
    if (!strlen( path ))
      path = "/";
    else if (path[-1] != '/')
    {
      arr = path / "/";
      path = path + arr[ 0..sizeof( arr )-2 ] * "/" + "/";
    }
  }
  else
  {
    path = id->variables->path;
    filename = id->variables->filename;
  }
  path=combine_path( path, filename );
  arr = path / "/";
  path = arr[0..sizeof( arr )-2] * "/" + "/";
  filename = arr[-1];
  id->variables->path = path;
  id->variables->filename = filename;
  result += "Här kommer lite text"; //make_dir_list( id, path );
  if (1)
    result += "<p><var size=20 name=filename default=" + filename + ">";
  return result;
}

mixed wizard_done( object id )
{
  
}


