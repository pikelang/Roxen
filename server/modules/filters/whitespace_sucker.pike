// This is a roxen module. Copyright © 2000, Roxen IS.

inherit "module";

constant cvs_version = "$Id: whitespace_sucker.pike,v 1.4 2001/04/18 23:31:55 nilsson Exp $";
constant thread_safe = 1;
constant module_type = MODULE_FILTER;
constant module_name = "Whitespace Sucker";
constant module_doc  = "Sucks the useless guts away from of your pages.";

void create() {

  defvar("comment", Variable.Flag(0, 0, "Strip HTML comments",
				  "Removes all &lt;!-- --&gt; type of comments") );
}

int gain;

string status()
{
  return sprintf("<b>%d bytes</b> of useless whitespace have been dropped.", gain);
}

static string most_significant_whitespace(string ws)
{
  int size = sizeof( ws );
  if( size )
    gain += size-1;
  return !size ? "" : has_value(ws, "\n") ? "\n"
		    : has_value(ws, "\t") ? "\t" : " ";
}

static array(string) remove_consecutive_whitespace(Parser.HTML p, string in)
{
  sscanf(in, "%{%[ \t\r\n]%[^ \t\r\n]%}", array ws_nws);
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
  if(!result
  || search(result->type, "text/")
  || !stringp(result->data)
  || id->prestate->keepws
  || id->misc->ws_filtered++)
    return 0;

  result->data = Parser.HTML()
    ->add_containers( ([ "pre":verbatim,
			 "textarea":verbatim,
			 "script":verbatim,
			 "style":verbatim ]) )
    ->add_quote_tag("!--", query("comment")&&"", "--")
    ->_set_data_callback( remove_consecutive_whitespace )
    ->finish( result->data )
    ->read();
  return result;
}
