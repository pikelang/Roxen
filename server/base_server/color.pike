// Color support for roxen. 

string cvs_version = "$Id: color.pike,v 1.1 1996/12/04 01:53:53 per Exp $";

mapping (string:array(int)) colors = ([]);

array(int) parse_color(string from)
{
  int c;
  if(!from || !strlen(from)) return ({ 0,0,0 });

  if(from[0]=='#')
  {
    c = (int)("0x"+from[1..]);
    if(strlen(from)>6)
      return ({ c>>16, (c>>8)&255, c&255 });
    return ({ (c>>8)<<4, ((c>>4)&15)<<4, (c&15)<<4 });
  }

  from = replace(lower_case(from)-" ", "gray", "grey");
  if(sscanf(from, "gray%d", c))
    return ({ (c*255)/100, (c*255)/100, (c*255)/100, });
  return colors[from]||({0,0,0});
}

void create()
{
  if(catch(colors = decode_value(read_bytes("etc/rgb.dat"))))
    perror("Color subsystem: Failed to read RGB data from etc/rgb.dat.\n");
  add_constant("parse_color", parse_color);
}
