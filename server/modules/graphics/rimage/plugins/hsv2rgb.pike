constant doc="Convert the channel from hsv to rgb";

void render(mapping args, mapping this, string channel, object id, object m)
{
  m->set_channel( this, channel, m->get_channel( this, channel )->hsv_to_rgb() );
}
