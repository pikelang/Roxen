// Color support for roxen. 

//string cvs_version = "$Id: color.pike,v 1.13 1998/02/10 18:36:01 per Exp $";

#include <stdio.h>

mapping (string:array(int)) colors = ([]);
mapping (string:string) html_32_colors =
([
  "black":"#000000", "green":"#008000", "silver":"#C0C0C0", "lime":"#00FF00",
  "gray":"#808080", "olive":"#808000", "white":"#FFFFFF","yellow":"#FFFF00",
  "maroon":"#800000", "navy":"#000080", "red":"#FF0000", "blue":"#0000FF",
  "purple":"#800080", "teal":"#008080", "fuchsia":"#FF00FF", "aqua":"#00FFFF",
]);

#define MAX(X,Y) ((X)>(Y)?(X):(Y))
#define MIN(X,Y) ((X)<(Y)?(X):(Y))
#define MAX3(X,Y,Z) MAX(MAX(X,Y),Z)

array rgb_to_hsv(array|int ri, int|void gi, int|void bi)
{
  float max, min;
  float r,g,b, delta;
  float h, s, v;

  if(arrayp(ri)) return rgb_to_hsv(@ri);
  if((ri==gi) && (gi==bi)) return ({ 0, 0, ri }); // greyscale..
  
  r = (float)ri/255.0; g = (float)gi/255.0; b = (float)bi/255.0;
  max = MAX3(r,g,b);
  min = -(MAX3(-r,-g,-b));

  v = max;

  if(max != 0.0)
    s = (max - min)/max;
  else
    return ({ -10, 0, (int)(v*255) });

  delta = max-min;

  if(r==max) h = (g-b)/delta;
  else if(g==max) h = 2+(b-r)/delta;
  else if(b==max) h = 4+(r-g)/delta;
  h *= 60; // now in degrees.
  if(h<0) h+=360;
  return ({ (int)((h/360.0)*255), (int)(s*255), (int)(v*255) });
}

array hsv_to_rgb(array|int hv, int|void sv, int|void vv)
{
  if(arrayp(hv)) return hsv_to_rgb(@hv);

  float h,sat,v;
  float r,g,b;
  h = (hv/255.0)*(360.0/60.0);
  sat = sv/255.0;
  v = vv/255.0;
     
  if(sat==0.0)
  {
    r = g = b = v;
  } else {
#define i floor(h)
#define f (h-i)
#define p (v * (1 - sat))
#define q (v * (1 - (sat * f)))
#define t (v * (1 - (sat * (1 -f))))
    switch((int)i)
    {
     case 6: // 360 degrees. Same as 0..
     case 0:	 r = v;	 g = t;	 b = p;	 break;
     case 1:	 r = q;	 g = v;	 b = p;	 break;
     case 2:	 r = p;  g = v;	 b = t;	 break;
     case 3:	 r = p;	 g = q;	 b = v;	 break;
     case 4:	 r = t;	 g = p;	 b = v;	 break;
     case 5:	 r = v;	 g = p;	 b = q;	 break;
    }
  }
#undef i
#undef f
#undef p
#undef q
#undef t

#define FOO(X) (int)(X*255)
  return ({FOO(r), FOO(g), FOO(b) });
}

array(int) parse_color(string from)
{
  int c;
  if(!from || !strlen(from)) return ({ 0,0,0 }); // Odd color...

  from = lower_case(from-" ");

  if(html_32_colors[from])  from = html_32_colors[from];
  else if(arrayp(colors[from])) return colors[from];

  // Is it #rrggbb?
  if(from[0]=='#')
  {
    c = (int)("0x"+from[1..]);
    if(strlen(from)>6)
      return ({ c>>16, (c>>8)&255, c&255 });
    return ({ (c>>8)<<4, ((c>>4)&15)<<4, (c&15)<<4 });
  } else if(from[0]=='@') {
    // Nope. What about @h,s,v? (h=degrees, 0 to 359, s and v = percent)
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
    // Nope. What about %c,m,t,k? (percent)
    int c,m,y,k;
    sscanf(from[1..], "%d,%d,%d,%d", c, m, y, k);
    int r=100, b=100, g=100;
    r-=c+k; g-=m+k; b-=y+k;
    if(r<0) r=0;
    if(g<0) g=0;
    if(b<0) b=0;
    return ({ (int)(r*2.55), (int)(g*2.55), (int)(b*2.55) });
  }

  // No luck. It might be a color on the form rrggbb (that is, no leading '#')
  if(c=(int)("0x"+from))
  {
    if(strlen(from)>5)
      return ({ c>>16, (c>>8)&255, c&255 });
    return ({ (c>>8)<<4, ((c>>4)&15)<<4, (c&15)<<4 });
  }

  from = replace(from-" ", "gray", "grey");

  // Perhaps it is a greyscale? (gray00 to gray99)
  if(sscanf(from, "grey%d", c))
    return ({ (c*255)/100, (c*255)/100, (c*255)/100, });

  if(sscanf(from, "light%s", from))
  {
    array c = rgb_to_hsv(parse_color(from));
    c[2] = -MAX(-(c[2]+50), -255);
    if(c[2]==255) c[1]=MAX(c[1]-20,0);
    return hsv_to_rgb(c);
  }

  if(sscanf(from, "dark%s", from))
  {
    array c = rgb_to_hsv(parse_color(from));
    c[2] = MAX(c[2]-50, 0);
    if(c[2]==0) c[1]=MIN(c[1]+20,255);
    return hsv_to_rgb(c);
  }

  if(sscanf(from, "neon%s", from))
  {
    array c = rgb_to_hsv(parse_color(from));
    c[1] = 255; c[2] = 255;
    return hsv_to_rgb(c);
  }

  // Lets call it black and be happy..... :-)
  return ({ 0,0,0 });
}

inline nomask static int ABS(int y) { return y<0?-y:y; }

// Mostly used for debug. Not really all that perfect..
string color_name(array (int) from)
{
  if(!arrayp(from) || sizeof(from)!=3) return "-";
  foreach(values(colors), mixed c)
    if(ABS(c[0]-from[0]) < 6 &&
       ABS(c[1]-from[1]) < 6 &&
       ABS(c[2]-from[2]) < 6)
      return search(colors,c);
  if(equal(parse_color("grey"+(((int)from[0]*100)/255)),from))
    return "grey"+(((int)from[0]*100)/255);
  return sprintf("#%02x%02x%02x", @from);
}

array(string) list_colors()
{
  return indices(colors);
}

void create()
{
  catch(colors = decode_value(read_bytes("etc/rgb.dat")));
  add_constant("hsv_to_rgb", hsv_to_rgb);
  add_constant("rgb_to_hsv", rgb_to_hsv);
  add_constant("parse_color", parse_color);
  add_constant("color_name", color_name);
  add_constant("list_colors", list_colors);
  add_constant("color", this_object());
}
