// This is a roxen module. Copyright © 2000 - 2009, Roxen IS.

inherit "module";

constant cvs_version = "$Id$";
constant thread_safe = 1;
constant module_type = MODULE_FILTER;
constant module_name = "Whitespace Remover";
constant module_doc  = "Removes all whitespace from pages.";

void create() {

  defvar("comment",
	 Variable.Flag(0, 0, "Strip HTML comments",
		       "Removes all &lt;!-- --&gt; type of comments") );
  defvar("verbatim",
	 Variable.StringList( ({ "pre", "textarea", "script", "style",
				 "code" }),
			      0, "Verbatim tags",
			      "Whitespace stripping is not performed on the "
			      "contents of these tags." ) );
}

int gain;

string status()
{
  return sprintf("<b>%d bytes</b> have been dropped.", gain);
}

protected string most_significant_whitespace(string ws)
{
  int size = sizeof( ws );
  if( size )
    gain += size-1;
  return !size ? "" : has_value(ws, "\n") ? "\n"
		    : has_value(ws, "\t") ? "\t" : " ";
}

protected array(string) remove_consecutive_whitespace(Parser.HTML p, string in)
{
  sscanf(in, "%{%[ \t\r\n]%[^ \t\r\n]%}", array(array(string)) ws_nws);
  if(sizeof(ws_nws))
  {
    ws_nws = Array.transpose( ws_nws );
    ws_nws[0] = map(ws_nws[0], most_significant_whitespace);
  }
  return ({ Array.transpose( ws_nws ) * ({}) * "" });
}

array(string) verbatim(Parser.HTML p, mapping(string:string) args, string c) {
  return ({ p->current() });
}

mapping filter(mapping result, RequestID id)
{
  if(!result)
    return 0;
  string|array(string) type = result->type;
  if (arrayp(type))
    type = type[0];
  if (!type ||
      !has_prefix(type, "text/html") &&
      !has_prefix(type, "text/xml") &&
      !has_prefix(type, "application/xml") &&
      !has_suffix(type, "+xml"))
    return 0;
  type = (id->misc->moreheads && id->misc->moreheads["Content-Type"]);
  if (type &&
      !has_prefix(type, "text/html") &&
      !has_prefix(type, "text/xml") &&
      !has_prefix(type, "application/xml") &&
      !has_suffix(type, "+xml"))
    return 0;
  if (!stringp(result->data) ||
      id->prestate->keepws ||
      id->misc->ws_filtered++)
    return 0;

  Parser.HTML parser = Parser.HTML();
  foreach(query("verbatim"), string tag)
    parser->add_container( tag, verbatim );
  parser->add_quote_tag("!--", query("comment")&&"", "--");
  parser->_set_data_callback( remove_consecutive_whitespace );
  result->data = parser->finish( result->data )->read();
  return result;
}
