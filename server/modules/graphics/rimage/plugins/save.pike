constant doc = "save the current channel to the slot specified by 'to'";

void render(mapping args, mapping this, string channel, object id, object m)
{
  id->misc[ "__pimage_"+args->to ] = this[channel]->copy();
}
