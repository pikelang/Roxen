inherit "wizard";
import AutoWeb;

constant name = "Edit Metadata";

string page_0( object id )
{
  return EditMetaData()->page(id, id->variables->path);
}

mixed wizard_done( object id )
{
  EditMetaData()->done(id, id->variables->path);
}
