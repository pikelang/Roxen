inherit "wizard";

constant name = "Create File";


string page_0( object id )
{
  return sprintf("<pre>%O</pre>",id->variables);
  return "<b>Select filename:</b>"
    "<var name=filename type=string "
    "size=40 default=\""+
    replace((id->variables->path||"/")+"/", "//", "/") + "\">";
}

mixed wizard_done( object id )
{
  id->misc->wa->save_file(id, id->variables->filename, "");
}


