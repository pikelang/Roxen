inherit "roxenlib";

object wa;

void create (object webadm)
{
  wa = webadm;
}

mapping|string handle (string sub, object id)
{
  string res=Stdio.read_bytes(combine_path(__FILE__,"../","page.html"));
  return res;
}
