inherit "roxenlib";

object wa;

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
