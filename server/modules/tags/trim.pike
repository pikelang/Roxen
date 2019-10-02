#include <config.h>
#include <module.h>
inherit "module";

constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Tags: Trim";
constant module_doc  = "Tag for trimming strings.";


void create(Configuration conf)
{
  set_module_creator("Based on code contributed by "
		     "Pontus Östlund, &lt;spam@poppa.se&gt;.");
}


class TagTrim
{
  inherit RXML.Tag;

  constant name = "trim";
  mapping(string:RXML.Type) opt_arg_types = ([
    "char"   : RXML.t_text(RXML.PEnt),
    "left"   : RXML.t_text(RXML.PEnt),
    "right"  : RXML.t_text(RXML.PEnt),
    "center" : RXML.t_text(RXML.PEnt),
    "length" : RXML.t_text(RXML.PEnt),
    "glue"   : RXML.t_text(RXML.PEnt),
    "words"  : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      result = 0;

      if (args->left)
        result = ltrim(content, args->char);
      if (args->right)
        result = rtrim(result || content, args->char);

      if (!args->left && !args->right)
	result = trim(content, args->char);
      
      if (args->center) {
        if (!args->length)
          RXML.parse_error("Missing required attribute \"length\".");
        result = ctrim(result || content, (int)args->length, args->words,
		       args->glue);
      }
      
      return 0;
    }
  }
}

string trim(string in, string|void char)
{
  return (char && sizeof(char)) ?
    rtrim(ltrim(in, char), char) :
    String.trim_all_whites(in);
}

string ltrim(string in, string|void char)
{
  if (char && sizeof(char)) {
    if (has_value(char, "-"))
      char = (char - "-") + "-";
    if (has_value(char, "]"))
      char = "]" + (char - "]");
    if (char == "^") {
      //  Special case for ^ since that can't be represented in the sscanf
      //  set. We'll expand the set with a wide character that is illegal
      //  Unicode and hence won't be found in regular strings.
      char = "\xFFFFFFFF^";
    }
    sscanf(in, "%*[" + char + "]%s", in);
  } else
    sscanf(in, "%*[ \n\r\t\0]%s", in);
  return in;
}

string rtrim(string in, string|void char)
{
  return reverse(ltrim(reverse(in), char));
}

string ctrim(string in, int len, int cut_between_words, string|void glue)
{
  if (sizeof(in) <= len)
    return in;

  //  Take glue string into account when computing max length
  glue = glue || "...";
  if (sizeof(glue) > len)
    RXML.run_error("Glue string longer than requested length.\n");
  len -= sizeof(glue);
  
  int right_len = len / 2;
  int left_len = len - right_len;
  string left = String.trim_all_whites(in[..left_len - 1]);
  string right = String.trim_all_whites(in[sizeof(in) - right_len..]);
  
  //  Cut between words if needed
  if (cut_between_words) {
    //  Only search for word delimiters if we haven't already cut at one
    int pos;
    if (in[sizeof(left)] != ' ')
      if ((pos = search(reverse(left), " ")) > -1)
	left = left[..sizeof(left) - pos - 2];
    if (in[sizeof(in) - sizeof(right) - 1] != ' ')
      if ((pos = search(right, " ")) > -1)
	right = right[pos + 1..];
  }
  
  return left + glue + right;
}

//------------------------------------------------------------------------------

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc = ([
"trim" :
#"<desc type='cont'><p><short>
Trims characters from the string. If neither <tt>left</tt>, <tt>center</tt>
or <tt>right</tt> attributes are provided it will trim from both ends of the
given string. If <tt>char</tt> is unspecified the trim operation removes
whitespace.</short></p></desc>

<attr name='left' optional='optional'><p>
Only trim the left side of the string.</p></attr>

<attr name='right' optional='optional'><p>
Only trim the right side of the string.</p></attr>

<attr name='char' value='character|string' optional='optional'><p>
Trim the string from character(s) in <tt>char</tt>. If not provided whitespace
will be removed instead.</p>
<ex><trim char='/' right=''>/some/path/</trim></ex>
</attr>

<attr name='center' optional='optional'><p>
Trims the string from the center. Requires the attribute <tt>length</tt>.
The resulting string may be shorter due to whitespace trimming but will
never exceed the maximum length.</p>
<ex><trim center='' length='20'>A long and meaningless string</trim></ex>
</attr>

<attr name='length' value='int' optional='optional'><p>
Combine with attribute <tt>center</tt> to set the maximum length of a
center-trimmed string.</p></attr>

<attr name='glue' value='string' optional='optional' default='...'><p>
Only applies together with attribute <tt>center</tt>. Defines what string to
use when gluing the left and right side of the string together.</p></attr>

<attr name='words' optional='optional'><p>
Only applies together with attribute <tt>center</tt>. Requests the cutting
to take place at spaces that delimit words in the string.</p></attr>"
]);
#endif /* manual */
