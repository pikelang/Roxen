inherit "wizard";

/* $Id: edit.pike,v 1.1 1998/07/15 00:29:25 js Exp $ */

constant name = "Edit";
constant doc = "Edit something";

string page_0(object id)
{
  object gui=id->misc->content_editor;
  object wa=id->misc->workarea;
  object f=wa->vcfile( id->variables->filename, id, PERM_WRITE, 0 );
  object h=gui->get_handler_for( f );
  return "<b>Editing "+id->variables->filename+"</b><p>"+h->edit( f, id );
}

int verify_0(object id)
{
}

mapping wizard_done(object id)
{
  mixed res;
  multiset actions;
  mapping md;
  
  object gui=id->misc->content_editor;
  object wa=id->misc->workarea;
  object f=wa->vcfile( id->variables->filename, id, PERM_WRITE, 0 );
  object h=gui->get_handler_for( f );
  res = h->edit_done( f, id );
  md = f->metadata();
  if (md->__actions)
    if (md->__actions[ "edit" ])
      return res;
    else
      md->__actions[ "edit" ] = 1;
  else
    md->__actions = (< "edit" >);
  f->write_metadata( md );
  return res;
}
