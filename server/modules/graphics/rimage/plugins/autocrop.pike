constant doc = "Remove all 'empty' space around image in the selected channel";

void render( mapping args, mapping this, string channel, object id, object m )
{
  this[channel] = this[channel]->autocrop();
}
