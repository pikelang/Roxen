constant doc="Convert the channel to a greyscale image";

void render(mapping args, mapping this, string channel, object id, object m)
{
  if(this[channel])
    this[channel] = this[channel]->grey();
}
