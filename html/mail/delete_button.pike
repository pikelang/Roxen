inherit "roxenlib";
#define UID id->misc->_automail_user

mapping parse(object id)
{
  string t = parse_rxml( "<mail-verify-login>", id );
  if(!UID) return 0;
  if(!id->variables->button) return 0;
  int num = (int)id->variables->button;
  array b = UID->get( "html_buttons" );

  if(b && sizeof(b) > num)
    b = b[..num-1] + b[num+1..];

  UID->set( "html_buttons", b );
  return http_redirect("edit_buttons.html",id);
}
