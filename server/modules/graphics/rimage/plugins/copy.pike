constant doc="Copy the contents of another channel to this channel. Supported 'source' channels are 'red' 'green' 'value' 'saturation' and 'image'";


void render( mapping args, mapping this, string channel, object id, object m )
{
  object i;
  if(!this["image"]) return;
  switch( args->source )
  {
   case "red": 
     i = this["image"]->color(255,0,0)->grey(255,0,0);
     break;
   case "green": 
     i = this["image"]->color(0,255,0)->grey(0,255,0);
     break;
   case "blue": 
     i = this["image"]->color(0,0,255)->grey(0,0,255);
     break;
   case "value": 
     i = this["image"]->grey();  
     break;
   case "saturation": 
     i = this["image"]->rgb_to_hsv()->color(0,255,0)->grey(0,255,0);
     break;
   case "image":
     i = this["image"];
  }
    this[channel] = i;
}
