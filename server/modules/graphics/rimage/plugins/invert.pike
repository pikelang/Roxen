constant doc = "Invert the specified channel.";

void render( mapping args, mapping this, string channel, object id, object m )
{
  m->set_channel( this, channel, m->get_channel( this, channel )->invert() );
}
