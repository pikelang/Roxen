// Color support for roxen. 

string cvs_version = "$Id: color.pike,v 1.7 1997/05/15 20:53:04 per Exp $";

mapping (string:array(int)) colors = ([]);
mapping (string:string) html_32_colors =
([
  "black":"#000000", "green":"#008000", "silver":"#C0C0C0", "lime":"#00FF00",
  "gray":"#808080", "olive":"#808000", "white":"#FFFFFF","yellow":"#FFFF00",
  "maroon":"#800000", "navy":"#000080", "red":"#FF0000", "blue":"#0000FF",
  "purple":"#800080", "teal":"#008080", "fuchsia":"#FF00FF", "aqua":"#00FFFF",
]);

array(int) parse_color(string from)
{
  int c;
  if(!from || !strlen(from)) return ({ 0,0,0 });

  from = lower_case(from);
  
  if(html_32_colors[from])  from = html_32_colors[from];
  else if(colors[from]) return colors[from];

  if(from[0]=='#')
  {
    c = (int)("0x"+from[1..]);
    if(strlen(from)>6)
      return ({ c>>16, (c>>8)&255, c&255 });
    return ({ (c>>8)<<4, ((c>>4)&15)<<4, (c&15)<<4 });
  } else if(from[0]=='@') {
    float h, s, v;
    float r, g, b;
    sscanf(from[1..], "%d,%d,%d", h, s, v);
    h = (h/360.0) * 2*3.1415; s=(s/100.0); v=(v/100.0);
    r=v+s*cos(h);
    g=v+s*cos(h+(3.1415*2.0/3.0));
    b=v+s*cos(h+(3.1415*4.0/3.0));
#define FOO(X) ((int)((X)<0.0?0:(X)>1.0?255:(int)((X)*255.0)))
    return ({FOO(r), FOO(g), FOO(b) });
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

  from = replace(from-" ", "gray", "grey");
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

#define MAX(X,Y) ((X)>(Y)?(X):(Y))
#define MAX3(X,Y,Z) MAX(MAX(X,Y),Z)

array rgb_to_hsv(array|int ri, int|void gi, int|void bi)
{
  float max, min;
  float r,g,b, delta;
  float h, s, v;

  if(arrayp(ri)) return rgb_to_hsv(@ri);
  r = (float)ri/255.0; g = (float)gi/255.0; b = (float)bi/255.0;
  max = MAX3(r,g,b);
  min = -(MAX3(-r,-g,-b));

  v = max;

  if(max != 0.0)
    s = (max - min)/max;
  else
    return ({ 0, 0, (int)(v*255) });

  delta = max-min;

  if(r==max) h = (g-b)/delta;
  else if(g==max) h = 2+(b-r)/delta;
  else if(b==max) h = 4+(r-g)/delta;
  h *= 60; // now in degrees.
  if(h<0) h+=360;
  return ({ (int)((h/360.0)*255), (int)(s*255), (int)(v*255) });
}

array hsv_to_rgb(array|int hv, int sv, int vv)
{
  if(arrayp(hv)) return hsv_to_rgb(@hv);
  float h, s, v;
  float r, g, b;
  h = (hv/256.0) * 2*3.1415; s=(sv/100.0); v=(vv/100.0);
  r=v+s*cos(h);
  g=v+s*cos(h+(3.1415*2.0/3.0));
  b=v+s*cos(h+(3.1415*4.0/3.0));
  return ({FOO(r), FOO(g), FOO(b) });
}

void create()
{
  array err;
  if(err=catch(colors = decode_value(Stdio.read_bytes("etc/rgb.dat"))))
    perror("Color subsystem: Failed to read RGB data from etc/rgb.dat.\n"+
	   err[0]);
  add_constant("parse_color", parse_color);
  add_constant("color_name", color_name);
}
