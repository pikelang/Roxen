constant doc="Convert the channel from rgb to hsv";

void render(mapping args, mapping this, string channel, object id, object m)
{
  m->set_channel( this, channel, m->get_channel( this, channel )->rgb2hsv() );
}
