inherit "wizard";

constant name = "New...";

#define ERROR (id->variables->error?"<error>"+\
	       id->variables->error+"</error>":"")

string page_0( object id )
{
  return ERROR + "<b>Upload to " + id->variables->path + "</b>"
    "<p><b>Select local file:</b> <input type=file name=the_file>";
}


int verify_0( object id )
{
  return 1;
}
mixed wizard_done(object id)
{
  return "foo";
}
