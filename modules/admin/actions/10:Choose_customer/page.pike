inherit "roxenlib";

object ce;

void create (object content_editor)
{
  ce = content_editor;
}

mapping|string handle (string sub, object id)
{
  return
    "<ul><sqloutput query='select distinct customers.id,customers.name,dns.domain from "
    "customers,dns where customers.id=dns.customer_id order by customers.name'>\n"
    "<li><a href='"+ce->query("location")+"#id#/"+ce->tablist[0]->tab+
    "/'>#name#</a> (<a href='http://www.#domain#'>http://www.#domain#/)</a><br></sqloutput></ul>";
}
