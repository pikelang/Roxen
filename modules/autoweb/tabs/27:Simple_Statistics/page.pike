inherit "roxenlib";

object wa;

int vis;

int visible(object id)
{
  if(sizeof(id->conf->get_provider("sql")->sql_object(id)->
    query("select feature from features where feature='Simple LogView' and"
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
  if(!visible(id))
    return "";
  string res=Stdio.read_bytes(combine_path(__FILE__,"../","page.html"));
  return res;
}
