inherit "roxenlib";

object ac = 0, ce;

void create (object content_editor)
{
  ce = content_editor;
}

mapping|string handle(string sub, object id)
{
  mixed res;
  if(id->variables->adduser)
    res="<automail-admin-adduser customer="+id->variables->customer+">";
  else if(id->variables->delete_user)
    res= "<automail-admin-delete-user>";
  else
    res= "<automail-admin-matrix customer="+id->variables->customer+">";

  // Kludge(tm)
  res=parse_rxml(res,id);
  if(id->misc->do_redirect)
    return http_redirect(id->not_query,id);
  else
    return res;
}
