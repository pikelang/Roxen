#include "common.pike";

constant name="Delete a mailbox...";

string page_0( object id )
{
  return (#"<font size=+1>Delete this mailbox:</font><br>
 <var type=select name=mbox options='"+(UID->mailboxes()->name*",")+"'><br>");
}


void wizard_done( object id )
{
  mapping v = id->variables;
  if(strlen(v->mbox-" "))
  {
    object m = UID->get_or_create_mailbox( v->mbox );
    m->delete();
  }
  array button = 
  ({
    "Move to "+v->mbox,
    (< "mail" >),
    (< "move_mail_to_"+v->mbox >),
  });
  array b = UID->get( "html_buttons" ) || ({});
  foreach(b, array b2) if(equal(b2,button)) b-=({b2});
  UID->set( "html_buttons", b );
}
