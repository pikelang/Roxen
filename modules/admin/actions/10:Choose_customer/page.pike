inherit "roxenlib";

object ce;

void create (object content_editor)
{
  ce = content_editor;
}

mapping|string handle (string sub, object id)
{
  return
    "<sqloutput query='select id,name from customers order by name'>\n"
    "<a href='"+ce->query("location")+"#id#/"+ce->tablist[0]->tab+
    "/'>#name#</a><br></sqloutput>";
}
