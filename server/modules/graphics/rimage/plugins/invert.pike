constant doc = "Invert the specified channel.";

void render( mapping args, mapping this, string channel, object id, object m )
{
  if(!this[channel]) return;
  this[channel] = this[channel]->invert();
}
