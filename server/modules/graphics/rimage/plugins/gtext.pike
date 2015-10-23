// This file is part of rimage. Copyright © 1998 - 2009, Roxen IS.

inherit "roxenlib";

constant doc = "This plugin uses the gtext module. You must have it enabled on the server. Arguments are identical to 'gtext', with one exception: 'text' is the text that should be rendered. 'xpos' and 'ypos' are the image coordinates to use.";

void render( mapping args, mapping this, string channel, object id, object m)
{
  string txt = args->text;
  int xp = (int)args->xpos;
  int yp = (int)args->xpos;
  m_delete(args, "xpos");
  m_delete(args, "ypos");
  m_delete(args, "text");

  string prefix = parse_rxml( make_tag("gtext-id", args, 1), id );

  mapping a = ([
    "file":prefix+"^"+txt,
    "xpos":xp,
    "ypos":yp,
  ]);

  return m->plugin_for( "load" )( a, this, channel, id, m ); // cute. :-)
}
