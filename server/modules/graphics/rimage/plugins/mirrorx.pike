constant doc="Mirror the image along the X axis";

void render(mapping args, mapping this, string channel, object id, object m)
{
  m->set_channel( this, channel, m->get_channel( this, channel )->mirrorx() );
}
