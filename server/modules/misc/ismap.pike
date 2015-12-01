// This is a roxen module. Copyright © 1996 - 2009, Roxen IS.

// ISMAP image map support. Quite over-complex, really.  An example is
// the support for index images, and chromatic distances.

constant cvs_version = "$Id$";

#include <module.h>
inherit "module";

void create()
{
  defvar("extension", "map", "Mapfile extension", TYPE_STRING,
	 "All files ending with this extension will be parsed as map-files.");
}

constant module_type = MODULE_FILE_EXTENSION;
constant module_name = "ISMAP image-maps";
constant module_doc  = "Internal support for server side image-maps, including a quite "
  "odd color-per-url imagemap method";

inline int sqr(int a) { return a*a; }

int parse_color(string col, int multi)
{
  int r,g,b;
  if(!multi) 
    return (int)col;

  if(!sscanf(col, "#%2x%2x%2x", r, g, b))
    if(!sscanf(col, "(%d,%d,%d)", r, g, b))
      if(!sscanf(col, "%d,%d,%d", r, g, b))
	return 0;
  
  return r*256*256 + g*256 + b;
}

mapping find_colors(array lines, int color)
{
  string s, url;
  int col1, col2;
  int sr, sg, sb, er, eg, eb;
  string bc, c;

  mapping res=([ "ranges":({}), ]);

  for(int i=0; i<sizeof(lines); i++)
  {
    int sw;
    if(lower_case(lines[i][0..5])=="color:")
    {
      
      sscanf(lines[i], "%*s:%s", s);
      if(sscanf(s, "%s-%s:%s", bc, c, url)==3)
      {
	col1=parse_color(bc, color);
	col2=parse_color(c, color);

	if(color)
	{
	  sr=(col1/(256*256))&255;
	  sg=(col1/256)&255;
	  sb=col1&255;
	
	  er=(col2/(256*256))&255;
	  eg=(col2/256)&255;
	  eb=col2&255;
	} else {
	  if(col1>col2)
	  {
	    sw=col1;
	    col1=col2;
	    col2=sw;
	    res["ranges"] += ({ ({ col1, col2, url }) });
	    continue;
	  }
	}
	if(sr>er)
	{
	  sw=sr; 
	  sr=er; 
	  er=sw;
	}

	if(sg>eg)
	{
	  sw=sg; 
	  sg=eg; 
	  eg=sw;
	}

	if(sb>eb)
	{
	  sw=sb; 
	  sb=eb; 
	  eb=sw;
	}
	res["ranges"] += ({ ({ ({ sr, sg, sb }), ({ er, eg, eb }), url }) });
      } else if(sscanf(s, "%s:%s", bc, url)) {
	res[parse_color(bc, color)]=url;
      }
    }
  }
  return res;
}

#define TYPE_RECTANGLE	0
#define TYPE_CIRCLE	1
#define TYPE_DEFAULT	2
#define TYPE_POINT      3
#define TYPE_POLY       4
#define TYPE_NCSA_CIRCLE    5
#define TYPE_VOID           6

#define TYPE_IMAGE       256
#define TYPE_IMAGE_COLOR 512

#define TYPE_PPM_IMAGE (TYPE_IMAGE|TYPE_IMAGE_COLOR)
#define TYPE_PGM_IMAGE TYPE_IMAGE

array parse_roxen_map_line(string line)
{
  string Url;
  int x, y, x1, y1, r;

  string tmp;
  line = (replace(line, "\t", "")/" " - ({""})) * "";
  if(sscanf(line, "%*s(%s", tmp))
    line="("+tmp;

  if (sscanf( line, "(%d,%d)-(%d,%d)%s", x, y, x1, y1, Url ) == 5)
    return ({ ({ TYPE_RECTANGLE, Url, x, y, x1, y1 }) });
  else if (sscanf( line, "(%d,%d),%d%s", x, y, r, Url ) == 4)
    return ({ ({ TYPE_CIRCLE, Url, x, y, r }) });
  else if (sscanf(line, "(%d,%d)%s", x, y, Url) == 3)
    return  ({ ({ TYPE_POINT, ({ x, y, Url }) }) });
  return ({0});
}

array parse_cern_map_line(string line)
{
  string Url;
  int x, y, x1, y1, r;

  line = (replace(line, "\t", "")/" " - ({""})) * "";
  
  switch(line[0..3])
  {
   case "rect":
    if (sscanf( line, "%*s (%d,%d) (%d,%d) %s", x, y, x1, y1, Url ) == 5)
      return ({ ({ TYPE_RECTANGLE, Url, x, y, x1, y1 }) });
    break;
   
   case "circ":
    if (sscanf( line, "%*s (%d,%d) %d %s", x, y, r, Url) == 4)
      return ({ ({ TYPE_CIRCLE, Url, x, y, r }) });
    break;
    
   case "poly":
    mixed poly = ({});
    sscanf(line, "%*s %s", line);
    while(sscanf(line, "(%d,%d) %s", x, y, line) == 3)
      poly += ({ ({ x, y }) });

    return  ({ ({ TYPE_POLY, line, poly }) });
    break;

   default:
    if (sscanf(line, "point (%d,%d) %s", x, y, Url) == 3)
      return ({ ({ TYPE_POINT, ({ x, y, Url }) }) });
  }
  return ({0});
}

array parse_ncsa_map_line(string line)
{
  string Url;
  int x, y, x1, y1;

  line = (replace(line, "\t", "")/" " - ({""})) * "";

  switch(line[0..3])
  {
   case "rect":
    if (sscanf( line, "%*s %s %d,%d %d,%d", Url, x, y, x1, y1 ) == 5)
      return ({ ({ TYPE_RECTANGLE, Url, x, y, x1, y1 }) });
    
   case "circ":
    if (sscanf( line, "%*s %s %d,%d %d,%d", Url, x, y, x1, y1) == 5)
      return  ({ ({ TYPE_NCSA_CIRCLE, Url,  ({ ({ x, y }), ({ x1, y1 }) }) 
		    }) });
   case "poin":
    if (sscanf(line, "%*s %s %d,%d", Url, x, y) == 3)
      return ({ ({ TYPE_POINT, ({ x, y, Url }) }) });

   case "poly":
    if (sscanf(line, "%*s %s %d,%d %s", Url, x, y, line) == 4)
    {
      mixed poly = ({ ({x, y}) });
      
      while(sscanf(line, "%d,%d %s", x, y, line) == 3)
	poly += ({ ({ x, y }) });

      if(sscanf(line, "%d,%d", x, y) == 2)
	poly += ({ ({ x, y }) });
      
      return ({ ({ TYPE_POLY, Url, poly }) });
    }
  }
  return ({0});
 }


array compress_coordinate_list(array from)
{
  string def;
  array points=allocate(0, "array(int|string)"),
         result=allocate(sizeof(from), "string|array(int|string|array)");
  int p;
  
  def=from[0];
 
  from -= ({ 0, ({ 0 }), def });
  
  for(int i = 0; i < sizeof(from); i++)
  {
    if(from[i][0] == TYPE_POINT) 
      points += ({from[i][1]});
    else 
      result[++p] = from[i];
  }
  if(sizeof(points)) 
    result[++p]=({ TYPE_POINT, points });
  result[0]=stringp(def) ? def : 0;
  return result[0..p];
}

mixed parse_map_file( object o )
{
  mixed coordinate_list, tmp1;
  string data, line, Url;
  data = o->read(0x7ffffff);
  o->close("rw");
  destruct(o);
  coordinate_list = ({ 0 });
  
  foreach(replace(replace(data, "\r", "\n"), "\\\n", " ") / "\n", line)
  {
    string cmd;
    line = (replace(line, "\t", " ")/" " - ({""}))*" ";
    if (!strlen(line) || (line[0] == '#'))
      continue;
    
    if(line[0]==' ')
      line = line[1..strlen(line)-1];
    
    cmd = lower_case((line/" ")[0] || "");

    if(lower_case((line/":")[0] || "") == "default" && 
       sscanf(line, cmd+":%s", Url))
      coordinate_list[0] = replace(Url, ({" ", "\t"}), ({"",""}));
    else if(strlen(cmd) > 2)
      switch(cmd[0..2])
      {
       case "def":
	if(sscanf(line, cmd+" %s", Url ))
	  coordinate_list[0] = replace(Url, ({" ", "\t"}), ({"",""}));
	break;

       case "voi": 
	if(sscanf(line, cmd+" %s", Url ))
	  coordinate_list += 
	    ({ ({ TYPE_VOID, replace(Url, ({" ", "\t"}), ({"",""})) }) });
	break;


       case "cir": case "rec": case "pol": case "poi":
	if(sscanf(line, "%*s(%*s"))
	  coordinate_list += parse_cern_map_line(line);
	else
	  coordinate_list += parse_ncsa_map_line(line);
	break;
	
       case "ppm": case "pgm":
	if (sscanf( line, "ppm:%s", tmp1 ))
	  coordinate_list += 
	    ({ ({ TYPE_PPM_IMAGE,(replace(tmp1, "\t", "")/" " - ({""})) * "", 
		  find_colors(replace(data, ({" ", "\t"}), ({"",""}))/"\n", 1)
		  }) });
	else if (sscanf( line, "pgm:%s", tmp1 ))
	  ({ ({ TYPE_PGM_IMAGE, tmp1, 
		find_colors(replace(data, ({" ", "\t"}), ({"",""}))/"\n", 0)
		}) });
	break;

       case "col:":
	break;
      
       default:
	coordinate_list += parse_roxen_map_line(line);
      }
  }
  return compress_coordinate_list(coordinate_list);
}



mixed do_color_match(string file, mapping cols, int x, int y, int color)
{
  object f;
  string s, tmp;
  int xs, ys, eol;
  int r, g, b, i, grey;


  if(!file_stat(file))
    return 0;

  if(!(f=open(file, "r")))
    return 0;
  f->seek(3);
  s=f->read(200);
  eol=3;
  while(s[0] == '#')
  {
    sscanf(s, "%s\n%s", tmp, s);
    eol += strlen(tmp)+1;
    tmp="";
  }
  
  sscanf(s, "%d%*[ \t\r\n]%d%*[ \t\r\n]%s", xs, ys, tmp);
  sscanf(tmp, "%*s\n%s", tmp);
  eol += strlen(s) - strlen(tmp);
  
  f->seek(eol);
  if(x > xs || y > ys)
    return 0;
  
  f->seek(eol + x*(color?3:1) + y*xs*(color?3:1));
  
  if(color)
  {
    s=f->read(3);
    r=s[0];
    g=s[1];
    b=s[2];
    grey=(r+g*2+b)/4;
  } else {
    r=g=b=grey=f->read(1)[0];
  }

  if(cols[r*256*256 + g*256 + b])
    return cols[r*256*256 + g*256 + b];
  if(cols[grey])
    return cols[grey];
  
  for(i=0; i<sizeof(cols["ranges"]); i++)
  {
    if(arrayp(cols["ranges"][i][0])) /* Color color.. */
    {
      array (int) col1, col2;
      col1=cols["ranges"][i][0];
      col2=cols["ranges"][i][1];
      if(r>=col1[0] && g>=col1[1] && b>=col1[2] 
	 && r<=col2[0] && g<=col2[1] && b<=col2[2])
	return cols["ranges"][i][2];
    } else {			/* Greyscale color */
      if(grey >= cols["ranges"][i][0] && grey <= cols["ranges"][i][1])
	return cols["ranges"][i][2];
    }
  }
  return 0;
}

#define X 0
#define Y 1
int ncsa_circle(mixed coords, int x, int y)
{
  int radius1, radius2;
  
  radius1 = ((coords[0][Y] - coords[1][Y]) * 
	     (coords[0][Y] -
	      coords[1][Y])) + ((coords[0][X] - coords[1][X]) * 
				(coords[0][X] -
				 coords[1][X]));
  radius2 = ((coords[0][Y] - y) * (coords[0][Y] - y)) +
    ((coords[0][X] - x) * (coords[0][X] - x));
  return (radius2 <= radius1);
}


/* Polygon routine written by Henrik P Johnson <hpj@one.se> */
int polygon(mixed points, int tx, int ty)
{
  int i, j, l, c=0;
  int x,y;

  l=sizeof(points);
  
  y=points[l-1][Y];

  if ((y>=ty)!=(points[0][Y]>=ty)) {
    x=points[l-1][X];
    if ((j=(x>=tx))==(points[0][X]>=tx)) {
      if (j)
        c++;
    } else {
      c+=(x-(y-ty)*(points[0][X]-x)/(points[0][Y]-y))>=tx;
    }
  }
  
  for ((y=points[0][Y]),i=1;i<l;y=points[i][Y],i++) {
    if (y>=ty) {
      while ((i<l)&&(points[i][Y]>=ty))
        i++;
      if(i>=l)
        break;
      if((j=(points[i-1][X]>=tx))==(points[i][X]>=tx)) {
        if(j)
          c++;
      } else {
        c+=(points[i-1][X]-(points[i-1][Y]-ty)*
            (points[i][X]-points[i-1][X])/(points[i][Y]-points[i-1][Y]))>=tx;
      }
    } else {
      while ((i<l)&&(points[i][Y]<ty))
        i++;
      if(i>=l)
        break;
      if((j=(points[i-1][X]>=tx))==(points[i][X]>=tx)) {
        if (j)
          c++;
      } else {
        c+=(points[i-1][X]-(points[i-1][Y]-ty)*
            (points[i][X]-points[i-1][X])/(points[i][Y]-points[i-1][Y]))>=tx;
      }
    }
  }
  return c&1;
}
#undef Y
#undef X

/* Find the URL for the coordinate (x,y) in the file (map_file_name) */
string map_get_filename( int x, int y, string map_file_name, object o,
			 object conf)
{
  string cache_name = "mapfile:" +conf->name;
  array(int) s = (array(int))o->stat();
  array in_cache;
  array coordinate_list;

  if((in_cache=cache_lookup(cache_name, map_file_name))
     && (s[3] == in_cache[0]))
  {
    coordinate_list=in_cache[1];
  } else {
    cache_set(cache_name, map_file_name, ({ s[3],(in_cache=parse_map_file(o))}));
    coordinate_list=in_cache;
  }

  for (int c=1; c<sizeof(coordinate_list); c++)
  {
    if(x == -1 && y == -1)
    {
      if(coordinate_list[c][0] == TYPE_VOID)
	return coordinate_list[c][1];
    } else {
      if(coordinate_list[c][0] == TYPE_POINT)
      {
	int maxd=1000000, closest=-1, dist;
	array (array (int|string)) points;
	points=coordinate_list[c][1];
	/* In the list of points find the closest... */
	for(int i=0; i<sizeof(points); i++)
	{
	  dist=sqrt(sqr(x-points[i][0]) + sqr(y-points[i][1]));
	  if(dist < maxd)
	  {
	    maxd=dist;
	    closest=i;
	  }
	}
	if(closest >= 0)
	  return points[closest][2];
      } 
      if((coordinate_list[c][0] == TYPE_RECTANGLE 
	  && x >= coordinate_list[c][2] && y >= coordinate_list[c][3]
	  && x <= coordinate_list[c][4] && y <= coordinate_list[c][5])
	 || (coordinate_list[c][0] == TYPE_CIRCLE
	     && (sqrt(sqr(x-coordinate_list[c][2])+
		      sqr(y-coordinate_list[c][3]))
		 <= coordinate_list[c][4]))
	 || (coordinate_list[c][0] == TYPE_NCSA_CIRCLE
	     && ncsa_circle(coordinate_list[c][2], x, y))
	 || (coordinate_list[c][0] == TYPE_POLY
	     && polygon(coordinate_list[c][2], x, y)))   
	return coordinate_list[c][1];
      if(coordinate_list[c][0] & TYPE_IMAGE)
      {
	string u;
	u=do_color_match(coordinate_list[c][1], coordinate_list[c][2], x, y,
			 coordinate_list[c][0]&TYPE_IMAGE_COLOR);

	if(u) return u;
      }
    }
  }
  if(x == -1 && y == -1)
    return 0;
  return coordinate_list[0];
}

array(string) query_file_extensions()
{
  return ({ query("extension") });
}

int req;

mapping thevoid()
{
#ifdef NSERIOUS
  return Roxen.http_string_answer("<html><head><title>The Void!</title></head>"
				  "<body bgcolor='#000000' text='#ff0000'>"
				  "<h1 align='center'>The Void!</h1>"
				  "<h2>You come to the void if you fall out of a "
				  "room, and have nowhere to go.  If you give the "
				  "command 'church' you will be transported "
				  "there. <br />"
				  "Castle of Incanus."
				  "<ul>No obvious exits.</ul>"
				  "A nun (saintly).<br />"
				  "A unicorn horn.<br />"
				  "A rope tied to horn.<br />"
				  "A unicorn.<br />"
				  "A rope.<br />"
				  "</h2></body></html>");
#else
  return 0;
#endif
} 


mapping|string handle_file_extension(Stdio.File file, string ext, RequestID id)
{
  int x=-1, y=-1;
  string map_file_name;

  if(id->query)
    sscanf(id->query, "%d,%d", x, y);

  if(!id->supports->images)
    x = y = -1;
  
  req++;

  map_file_name=map_get_filename(x, y, id->not_query, file, id->conf);
  destruct(file);
  if(stringp(map_file_name) && strlen(map_file_name))
  {
    string varname, rest, pre;
    if(sscanf(" "+map_file_name+" ", "%s$%[a-zA-Z_]%s",pre, varname, rest)==3)
    {
      map_file_name = (pre + 
		       Roxen.http_encode_invalids(id->variables[varname]
						  ||id->state[varname]||"")
		       + rest) - " ";
    }
    if((strlen(map_file_name)>6 && 
	(map_file_name[3]==':' || map_file_name[4]==':' || 
	 map_file_name[5]==':' || map_file_name[6]==':') ||
	map_file_name[0]=='/'))
      return Roxen.http_redirect(map_file_name, id);
    return Roxen.http_redirect(dirname(id->not_query)+"/"+ map_file_name, id);
  }
  return thevoid();
}

string status() 
{
  return ("Mapfile requests: "+req+"\n<br />");
}
