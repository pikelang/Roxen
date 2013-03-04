// This is a roxen module. Copyright © 2000 - 2009, Roxen IS.

inherit "module";

constant cvs_version = "$Id$";
constant thread_safe = 1;
constant module_type = MODULE_FILTER;
constant module_name = "Word highlighter";
constant module_doc  = "Highlights the words stored in the form variable "
  "<tt>highlight</tt>. The string is splitted on \",\".";

void create() {

  defvar("pre", Variable.String("<font style=\"background-color: yellow\">", 0,
				"Pre string",
				"The string that will be inserted before "
				"any occurence of a to-be-highlighted word.") );

  defvar("post", Variable.String("</font>", 0,
				 "Post string",
				 "The string that will be inserted after "
				 "any occurence of a to-be-highlighted word.") );
}

string do_highlighting(string txt, RequestID id) {
  array from = id->variables->highlight/",";
  from = map(from, lower_case) + map(from, upper_case) + map(from, String.capitalize);
  string pre = query("pre"), post = query("post");
  array to = map(from, lambda(string in) { return pre+in+post; } );

  Parser.HTML p = Parser.HTML();
  p->add_quote_tag("!--", 0, "--");
  p->_set_data_callback(lambda(Parser.HTML p, string in) {
			  return ({ replace(in, from, to) });
			} );

  return p->finish(txt)->read();
}

mapping|void filter(mapping result, RequestID id) {
  if (!result) return;
  string|array(string) type = result->type;
  if (arrayp(type))
    type = type[0];
  if(!result                   // If nobody had anything to say, neither do we.
     || !id->variables->highlight // No highlight?
     || id->variables->highlight==""
     || !stringp(result->data)    // Got a file object. Hardly ever happens anyway.
     || !glob("text/*", type) )
    return 0; // Signal that we didn't rewrite the result for good measure.

  result->data = do_highlighting(result->data, id);
  return result;
}
