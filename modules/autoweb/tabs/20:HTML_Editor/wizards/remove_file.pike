inherit "wizard";
import AutoWeb;

constant name = "Remove File";

string page_0( object id )
{
  return "Are you sure you want to remove the file<b> "+
    html_encode_string(MIME.decode_base64(id->variables->path))+"</b>?";
}

mixed wizard_done( object id )
{
  string path = MIME.decode_base64(id->variables->path);
  AutoFile(id, path)->rm();
  AutoFile(id, path+".md")->rm();
  
}


