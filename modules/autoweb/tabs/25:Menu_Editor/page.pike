inherit "roxenlib";

object wa;

array wanted_buttons = ({ });

array get_buttons(object id)
{
  return wanted_buttons;
}

void create (object webadm)
{
  wa = webadm;
}

string|mapping handle(string sub, object id)
{
  wanted_buttons=({ });
  if(!id->misc->state)
    id->misc->state=([]);
  string resource="/";
  string base_url = id->not_query[..sizeof(id->not_query)-sizeof(sub)-1];

  if(2==sscanf(sub, "%s/%s", sub, resource))
    resource = "/"+resource;
  switch(sub) {
  case "":
    break;
  case "go":
    break;
  default:
    return "What?";
  }
  return "Menu Editor";
}
