constant doc = "Remove all 'empty' space around image in the selected channel";

void render( mapping args, Image.Layer this, string channel, object id, object m )
{
  m->set_channel( this, channel, m->get_channel( this, channel )->autocrop() );
}
