constant doc=" corners='col1,col2,col3,col4' xpos= ypos= width= height=";
void render( mapping args, mapping this, string channel, object id, object m)
{
  int xs = (int)(args->width  || this->width);
  int ys = (int)(args->height || this->height);
  int xp = (int)args->xpos;
  int yp = (int)args->ypos;
  
  if(!this[channel]) this[channel] = Image.image( xs+xp, ys+yp );
  this[channel]->tuned_box( xp,yp,xp+xs-1,yp+ys-1,
			   Array.map((args->corners||"black,white,black,white")/",", Colors.parse_color));
}
