// This is a roxen module. Copyright © 2000, Roxen IS.

inherit "module";

constant cvs_version = "$Id: whitespace_sucker.pike,v 1.2 2000/12/11 02:35:03 nilsson Exp $";
constant thread_safe = 1;
constant module_type = MODULE_FILTER;
constant module_name = "Whitespace Sucker";
constant module_doc  = "Sucks the useless guts away from of your pages.";

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

mapping filter(mapping result, RequestID id)
{
  if(!result
  || search(result->type, "text/")
  || !stringp(result->data)
  || id->prestate->keepws
  || id->misc->ws_filtered++)
    return 0;

  result->data = Parser.HTML()
    ->add_container("pre", lambda(Parser.HTML p, mapping(string:string) args, string c) {
			     if(!sizeof(args)) return ({ "<pre>"+c+"</pre>" });
			     return ({ Roxen.make_container("pre", args, c) });
			   })
    ->_set_data_callback( remove_consecutive_whitespace )
    ->finish( result->data )
    ->read();
  return result;
}
