inherit "roxenlib";

object wa;

int visible(object id)
{
  if(id->misc->autoweb_backdoor)
    return 1;
  if(sizeof(id->conf->get_provider("sql")->sql_object(id)->
    query("select feature from features where feature='Template Editor' and"
	  " customer_id='"+id->misc->customer_id+"'")))
    return vis=1;
  else
    return vis=0;
}


void create (object webadm)
{
  wa = webadm;
}

mapping|string handle (string sub, object id)
{
  // werror("sub '"+sub+"'\n");
  if(!sub||sub==""||sub=="index.html")
    sub = "page.html";
  string res=Stdio.read_bytes(combine_path(__FILE__, "../", sub));
  return res;
}
