constant doc="Colorize an image. The red, green and blue values of the pixels are multiplied with the given color. This works best on a grey image.";

void render( mapping args, mapping this, string channel, object id, object m )
{
  if(!this[channel]) return;
  this[channel]=this[channel]->color(@parse_color(args->color||"red"));
}

