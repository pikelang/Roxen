#define UID id->misc->_automail_user
inherit "common.pike";

constant name = "Create a custom button";
constant common_actions = ({
  ({ "delete", "Delete mail", 0 }),
  ({ "move_mail", "Move mail to mailbox <var name=move_mailbox type=select options='#mboxes#'>", 0 }),
  ({ "copy_mail", "Copy mail to mailbox <var name=copy_mailbox type=select options='#mboxes#'>", 1 }),
  ({ "forward_mail", "Forward mail to email <font size=-1><var size=30 name=email></font>", 1 }),
});

constant mail_actions = ({
  ({ "next", "Move to next mail", 0 }),
  ({ "next_unread", "Move to next unread mail", 0 }),
  ({ "previous", "Move to previous mail", 1 }),
  ({ "previous_unread", "Move to previous unreda mail", 1 }),
  ({ "show_unread", "Go to mailbox page and show unread mail", 1 }),
  ({ "show_all", "Go to mailbox page and show all mail", 1 }),
});

constant mbox_actions = ({
  ({ "show_unread", "Show unread mail only", 0 }),
  ({ "show_all", "Show all mail", 0 }),
  ({ "select_unread", "Select all unread mail", 0 }),
  ({ "select_all", "Select all mail", 0 }),
});


string page_0( object id )
{
  return #"<font size=+1>Button title</font><br><var name=title 
 type=string size=15><br>
<font size=+1>Present on page</font><br><var name=type 
 type=select options='Mail,Mailbox,Both' default=Mail><br>";
}

string show_action( array act, object id )
{
  int show_all;
  if(id->variables->show_type &&
     id->variables->show_type[0]=='A')
    show_all=1;

  if(act[2] && !show_all) return "";
  return "<tr><td><var type=checkbox name=a_"+act[0]+"> "+
    replace(act[1],"#mboxes#",(UID->mailboxes()->name*","))+"</td></tr>";
}

string page_1( object id )
{
  array act;
  string a=
#"Limit selection to <var type=select name=show_type
  onChange='document.forms[0].submit()' 
  options='All actions,Normal actions' 
  default='Normal actions'><br><p><br>",res="", pre="";

  switch( id->variables->type )
  {
   case "Mail":
     pre = #"<blockquote>The selected actions will be performed on 
the current mail</blockquote><p>";
     act = sort(common_actions+mail_actions);
     break;
   case "Mailbox":
     pre = #"<blockquote>The selected actions will be performed on the
 selected mail (one or more mail at a time)</blockquote>";
     act = sort(common_actions+mbox_actions);
     break;
   case "Both":
     pre = #"<blockquote>The selected actions will be performed on the
 selected mail when the button is pressed on the mailbox page, and on
 the current mail when it is pressed on the mail page</blockquote><p>";	
     act = sort(common_actions);
     break;
  }

  foreach( act, array s )
    res += show_action( s, id );
      
  return "<font size=+1>Select the actions the button will invoke</font><br>"
    +"<i><font size=-1>"+pre+
#"<p><blockquote>The actions will be performed in an
 order that makes sense, e.g., if you select 'Move to next mail' and
 'Delete mail', the deletion will be done before the move. Another
 example: If you select 'Forward to email 'per@idonex.se'' and
 'Delete', the mail will be forwarded before it is
 deleted.</blockquote></font></i>"+
    a+"<table cellpadding=0 cellspacing=0 border=0>" + res + "</table>";
      
}

// string page_2( object id )
// {
//   return "";
// }


void wizard_done( object id )
{
  multiset actions = (< >);
  filter_checkbox_variables( id->variables );
  foreach(glob("a_*", indices(id->variables)), string v)
  {
    switch(v)
    {
     case "a_move_mail": 
       actions[ "move_mail_to_"+id->variables->move_mailbox ]=1;
       break;
     case "a_copy_mail": 
       actions[ "copy_mail_to_"+id->variables->copy_mailbox ]=1;
       break;
     case "a_bounce_mail": 
       actions[ "bounce_mail_to_"+id->variables->email ]=1;
       break;
    default:
      actions[v[2..]]=1;
    }
  }
  multiset where;

  switch(id->variables->type)
  {
   case "Mail":     where = (< "mail" >);           break;
   case "Mailbox":  where = (< "mailbox" >);        break;
   default:         where = (< "mail","mailbox" >); break;
  }

  array button = 
  ({
    id->variables->title,
    where,
    actions,
  });

  array b = UID->get( "html_buttons" );
  if(!b) b = ({});
  b += ({ button });
  UID->set( "html_buttons", b );
}
