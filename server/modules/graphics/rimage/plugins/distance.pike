constant doc = "Makes an grey-scale image, for mask-channel use. The given 'color' are used for coordinates in the color cube. Each resulting pixel is the distance from this point to the source pixel color, in the RGB color cube, squared, rightshifted 8 steps";

void render( mapping args, mapping this, string channel, object id, object m )
{
  if(!this[channel]) return;
  this[channel]=
    this[channel]->distanceq(@Colors.parse_color(args->color||"black"));
}
