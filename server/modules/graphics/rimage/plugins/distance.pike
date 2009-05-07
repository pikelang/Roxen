// This file is part of rimage. Copyright © 1998 - 2009, Roxen IS.

constant doc = "Makes an grey-scale image, for mask-channel use. The given 'color' are used for coordinates in the color cube. Each resulting pixel is the distance from this point to the source pixel color, in the RGB color cube, squared, rightshifted 8 steps";

void render( mapping args, mapping this, string channel, object id, object m )
{
  object i = m->get_channel( this, channel );
  m->set_channel( this, channel, i->distanceq(@Colors.parse_color(args->color||"black")));
}
