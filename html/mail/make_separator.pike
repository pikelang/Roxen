#define UID id->misc->_automail_user
inherit "common.pike";

constant name = "Create a separator";

string page_0( object id )
{
  return #"<font size=+1>Separator type</font><br><var name=title
 type=select options='Space,New line'><br>
<font size=+1>Present on page</font><br><var name=type 
 type=select options='Mail,Mailbox,Both' default=Mail><br>";
}

mapping wizard_done( object id )
{
  multiset where;

  switch(id->variables->type)
  {
   case "Mail":     where = (< "mail" >);           break;
   case "Mailbox":  where = (< "mailbox" >);        break;
   default:         where = (< "mail","mailbox" >); break;
  }

  array button = 
  ({
    id->variables->title[0]=='S'?"<nobr> &nbsp; </nobr>":"<br>",
    where,
  });

  array b = UID->get( "html_buttons" );
  if(!b) b = ({});
  b += ({ button });
  UID->set( "html_buttons", b );
  return http_redirect( "edit_buttons.html", id );
}
