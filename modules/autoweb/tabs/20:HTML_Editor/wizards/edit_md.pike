inherit "wizard";
import AutoWeb;

constant name = "Edit Metadata";

string page_0( object id )
{
  werror("Sallad %O\n", id->variables->path);
  return EditMetaData()->page(id, id->variables->path);
}

mixed wizard_done( object id )
{
  EditMetaData()->done(id, id->variables->path);
}
