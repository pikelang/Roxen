inherit "roxenlib";

object wa;

constant wanted_buttons = ({ ({ "Remove File"}) });

array get_buttons(object id)
{
  return wanted_buttons;
}

void create (object webadm)
{
  wa = webadm;
}

mapping|string handle (string sub, object id)
{
  string res=Stdio.read_bytes(combine_path(__FILE__,"../","page.html"));
  return "hej";
}
