inherit "roxenlib";

object ac = 0, ce;

void create (object content_editor)
{
  ce = content_editor;
}

mapping|string handle (string sub, object id)
{
  string res=Stdio.read_bytes(combine_path(__FILE__,"../","page.html"));
  return res;
}
