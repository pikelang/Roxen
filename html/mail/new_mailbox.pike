#include "common.pike";

constant name="Create a new mailbox...";

string error="";
string page_0( object id )
{
  id->variables->tabname="Create mailbox";
  string res=(#"<font color=red size=+1>"+error+
#"</font><font size=+1>Mailbox name:</font><br>
 <var name=mbox><br>

 Create a new button to quickly move the current mail to
this mailbox<br>

<var type=toggle name=button><blockquote><i>If 'Yes', a new button will
be created on the mail page, pressing it will move the currently
viewed mail to this new mailbox.</i></blockquote>");
 error="";
 return res;
}

string quote(string in)
{
  return "`"+in+"'";
}

constant forbidden = ({ ",", "&", "<", ">" });
int verify_0(object id)
{

// id->variables->mbox=replace(id->variables->mbox,
// 		               " ",sprintf("%c",148));
//
  if(sizeof(id->variables->mbox/"" - forbidden) !=
     sizeof(id->variables->mbox))
  {
    error=("Mailbox names may not contain "+
	   html_encode_string(String.
			      implode_nicely(Array.map(forbidden,quote), "or"))
	   +"<br>");
    return 1;
  }
  return 0;
}

void wizard_done( object id )
{

  mapping v = id->variables;
  if(strlen(v->mbox-" "))
    UID->get_or_create_mailbox( v->mbox );
  werror("%O", v);
  if((int)id->variables->button)
  {
    array button = 
    ({
      "Move to "+v->mbox,
      (< "mail", "mailbox" >),
      (< "move_mail_to_"+v->mbox >),
    });
    array b = UID->get( "html_buttons" );
    if(!b) b = ({});
    b += ({ button });
    UID->set( "html_buttons", b );
  }
}
