constant doc="Convert the channel from hsv to rgb";

void render(mapping args, mapping this, string channel, object id, object m)
{
  if(this[channel])
    this[ channel ] = this[ channel ]->hsv_to_rgb();
}
