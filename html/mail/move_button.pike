inherit "roxenlib";
#define UID id->misc->_automail_user

mapping parse(object id)
{
  string t = parse_rxml( "<mail-verify-login>", id );
  if(!UID) return 0;
  if(!id->variables->button) return 0;
  int num = (int)id->variables->button;

  array b = UID->get( "html_buttons" );
  array pre;
  array post;
  if(b && sizeof(b) > num)
  {
    pre = b[..num-1];
    post = b[num+1..];
    if((int)id->variables->dir < 0)
    {
      b = (pre[..sizeof(pre)-2] + b[num..num] + 
	   ({pre[-1]}) + post);
    } else {
      b = (pre + post[0..0] + b[num..num] + post[1..]);
    }
  }
  UID->set( "html_buttons", b );
  return http_redirect("edit_buttons.html",id);
}
