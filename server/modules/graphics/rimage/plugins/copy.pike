// This file is part of rimage. Copyright © 1998 - 2009, Roxen IS.

constant doc="Copy the contents of another channel to this channel. Supported 'source' channels are 'red' 'green' 'value' 'saturation' and 'image'";


void render( mapping args, mapping this, string channel, object id, object m )
{
  object i = m->get_channel( this, channel );

  switch( args->source )
  {
   case "red":
     i = i->color(255,0,0)->grey(255,0,0);
     break;
   case "green":
     i = i->color(0,255,0)->grey(0,255,0);
     break;
   case "blue":
     i = i->color(0,0,255)->grey(0,0,255);
     break;
   case "value":
     i = i->grey();
     break;
   case "saturation":
     i = i->rgb_to_hsv()->color(0,255,0)->grey(0,255,0);
     break;
  }

  m->set_channel( this. channel, i );
}
