// This file is part of rimage. Copyright © 1998 - 2009, Roxen IS.

constant doc = "Makes a black-white image. If all red, green, blue channels of a pixel is larger or equal then the given color, the pixel will become white, otherwise black.";

void render(mapping args, mapping this, string channel, object id, object m)
{
  m->set_channel( this, channel, m->get_channel( this, channel )
                  ->threshold(@parse_color(args->color||"#010101")) );
}
