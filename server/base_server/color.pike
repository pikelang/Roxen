// Color support for roxen. 

string cvs_version = "$Id: color.pike,v 1.3 1997/01/29 04:59:32 per Exp $";

mapping (string:array(int)) colors = ([]);

array(int) parse_color(string from)
{
  int c;
  if(!from || !strlen(from)) return ({ 0,0,0 });

  if(colors[from]) return colors[from];

  if(from[0]=='#')
  {
    c = (int)("0x"+from[1..]);
    if(strlen(from)>6)
      return ({ c>>16, (c>>8)&255, c&255 });
    return ({ (c>>8)<<4, ((c>>4)&15)<<4, (c&15)<<4 });
  } else if(from[0]=='%') {
    int c,m,y,k;
    sscanf(from[1..], "%d,%d,%d,%d", c, m, y, k);
    int r=100, b=100, g=100;
    r-=c+k; g-=m+k; b-=y+k;
    if(r<0) r=0;
    if(g<0) g=0;
    if(b<0) b=0;
    return ({ (int)(r*2.55), (int)(g*2.55), (int)(b*2.55) });
  }

  if(colors[from]) return colors[from];

  if(c=(int)("0x"+from))
  {
    if(strlen(from)>5)
      return ({ c>>16, (c>>8)&255, c&255 });
    return ({ (c>>8)<<4, ((c>>4)&15)<<4, (c&15)<<4 });
  }

  from = replace(lower_case(from)-" ", "gray", "grey");
  if(sscanf(from, "grey%d", c))
    return ({ (c*255)/100, (c*255)/100, (c*255)/100, });

  if(colors[from]) return colors[from];
  return ({ 0,0,0 });
}

string color_name(array (int) from)
{
  if(!arrayp(from) || sizeof(from)!=3) return "-";
  foreach(values(colors), array c)
    if(equal(c,from))
      return search(colors,c);
  if(equal(parse_color("grey"+(((int)from[0]*100)/255)),from))
    return "grey"+(((int)from[0]*100)/255);
  return sprintf("#%02x%02x%02x", @from);
}

void create()
{
  array err;
  if(err=catch(colors = decode_value(read_bytes("etc/rgb.dat"))))
    perror("Color subsystem: Failed to read RGB data from etc/rgb.dat.\n"+
	   err[0]);
  add_constant("parse_color", parse_color);
  add_constant("color_name", color_name);
}
