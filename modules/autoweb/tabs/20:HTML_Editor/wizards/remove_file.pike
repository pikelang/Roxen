inherit "wizard";
import AutoWeb;

constant name = "Remove File";

string page_0( object id )
{
  return "Remove file <b>"+
    html_encode_string(id->variables->path)+"</b> ?";
}

mixed wizard_done( object id )
{
  AutoFile(id, id->variables->path)->rm();
  AutoFile(id, id->variables->path+".md")->rm();
  
  // FIX ME redirect to ../
}


