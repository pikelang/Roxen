/* This is a roxen module. (c) Idonex AB 1997.
 * Resdistribution of this file is not permitted.
 * 
 * Draws diagrams pleasing to the eye.
 * 
 * Made by Peter Bortas <peter@idonex.se> and Henrik Wallin <hedda@idonex.se>
 * in October 1997
 *
 * BUGS:
 * The use of background images is not reliable in this version.
 * Providing a center-value higher than available pices will render a
 *  broken image.
 * 
 */

constant cvs_version = "$Id: business.pike,v 1.33 1997/10/20 02:50:48 peter Exp $";
constant thread_safe=0;

#include <module.h>
#include <roxen.h>
inherit "module";
inherit "roxenlib";
import Array;
import Image;

#define SEP "\t"

mixed *register_module()
{
  return ({ 
    MODULE_PARSER|MODULE_LOCATION,
    "Business Graphics",
      ("Draws graphs that are pleasing to the eye.\n"
       "<p>This module defines a tag,\n"
       "<pre>"
       "\n&lt;diagram&gt; (container): <br>\n"
       "Draws different kinds of diagrams. <br>\n"
       "Defines the following attributes: <br>\n"
       " help            Displays this text.<br>\n"
       " type=           { sumbars | normsumbars | linechart | barchart | piechart | graph }\n"
       "                 Mandatory!"
       " background=     Takes the filename of a ppm image as input.\n"
       " width=          width of diagram-image in pixels. (Will not have any effect below 100.)\n"
       " height=         height of diagram-image in pixels. (Will not have any effect below 100.)\n"
       " fontsize=       height of text in pixels.\n"
       " legendfontsize= height of legend text in pixels. Uses fontsize if not defined\n"
       " 3D=             Render piecharts on top of a cylinder, \n"
       "                 takes the height in pixels of the cylinder as argument.\n"
       /* " tone         Do nasty stuff to the background.\n"
	  " Requires dark background to be visable.\n" */
       " You can also use regular &lt;img&gt; arguments. They will be passed\n"
       " on to the resulting &lt;img&gt; tag. "
       "Defines the following tags: \n"
       "\n&lt;xaxis&gt; and &lt;yaxis&gt; (tags)\n"
       "Attributes for the x and y axis.\n"
       /* " name=        Dunno what this does.\n" */
       " start=       Limit the start of the diagram at this quantity.\n"
       " stop=        Limit the end of the diagram at this quantity.\n"
       " quantity=    Name things represented in the diagram.\n"
       " units=       Name the unit.\n"
       "\n&lt;colors&gt; (container)\n"
       "Tab separated list of colors for the diagram.\n"
       " separator=   Use the specified string as separator instead of tab.\n"
       "\n&lt;legend&gt; (container)\n"
       "Tab separated list of strings for the legend.\n"
       " separator=   Use the specified string as separator instead of tab.\n"
       "\n&lt;xnames&gt; (container)\n"
       "Tab separated list of datanames for the diagram.\n"
       " separator=   Use the specified string as separator instead of tab.\n"
       "\n&lt;ynames&gt; (container)\n"
       "Tab separated list of dataname for the diagram.\n"
       " separator=   Use the specified string as separator instead of tab.\n"
       "\n&lt;data&gt; (container)  Mandatory!\n"
       "Tab- and newline- separated list of data-value for the diagram.\n"
       " separator=     Use the specified string as separator instead of tab.\n"
       " lineseparator= Use the specified string as lineseparator instead of tab.\n"
       " form=          Can be set to either row or column. Default is row.\n"
       " parse          Run the content of the tag through the RXML-parser before data extraction is done.\n"
       "</pre>"
       ), ({}), 1,
    });
}

void create()
{
  defvar("location", "/diagram/", "Mountpoint", TYPE_LOCATION|VAR_MORE,
	 "The URL-prefix for the diagrams.");
  defvar( "maxwidth", 800, "Maxwidth", TYPE_INT,
	  "Maximal width of the generated image.");
  defvar( "maxheight", 600, "Maxheight", TYPE_INT,
	  "Maximal height of the generated image.");
}

string itag_xaxis(string tag, mapping m, mapping res)
{
  if(m->name)  res->xname = m->name;  
  if(m->start) res->xstart = m->start;
  if(m->stop)  res->xstop = m->stop;
  if(m->quantity) res->xstor = m->quantity;
  if(m->unit) res->xunit = m->unit;

  return "";
}

string itag_yaxis(string tag, mapping m, mapping res)
{
  if(m->name)  res->yname = m->name;
  if(m->start) res->ystart = m->start;
  if(m->stop)  res->ystop = m->stop;
  if(m->quantity) res->ystor = m->quantity;
  if(m->unit) res->yunit = m->unit;

  return "";
}

/* Handle <xnames> and <ynames> */
string itag_names(string tag, mapping m, string contents,
		      mapping res)
{
  string sep=SEP;
  if(m->separator)
    sep=m->separator;
  
  if( contents-" " != "" )
  {
    if(tag=="xnames")
      res->xnames = contents/sep;
    else
      res->ynames = contents/sep;
  }

  return "";
}

/* Handle <xvalues> and <yvalues> */
string itag_values(string tag, mapping m, string contents,
		   mapping res)
{
  string sep=SEP;
  if(m->separator)
    sep=m->separator;
  
  if( contents-" " != "" )
  {
    if(tag=="xvalues")
      res->xvalues = contents/sep;
    else
      res->yvalues = contents/sep;
  }

  return "";
}

string itag_data(mapping tag, mapping m, string contents,
		 mapping res, object id)
{
  string sep=SEP;
  if(m->separator)
    sep=m->separator;

  string linesep="\n";
  if(m->lineseparator)
    linesep=m->lineseparator;

  if(m->parse)
    contents = parse_rxml( contents, id );

  contents = contents - " ";
  array lines = filter( contents/linesep, sizeof );
  array foo = ({});
  array bar = ({});
  int maxsize=0;
  
  foreach( lines, string entries )
  {
    foreach( filter( ({ entries/sep - ({""}) }), sizeof ), array item)
    {
      foreach( item, string gaz )
	foo += ({ gaz });
    }
    if (sizeof(foo)>maxsize)
      maxsize=sizeof(foo);
    bar += ({ foo });
    foo = ({});
  }
  
  if (m->form == "column")
  {
    for(int i=0; i<sizeof(bar); i++)
      if (sizeof(bar[i])<maxsize)
	bar[i]+=allocate(maxsize-sizeof(bar[i]));
    
    array bar2=allocate(maxsize);
    for(int i=0; i<maxsize; i++)
      bar2[i]=column(bar, i);
    res->data=bar2;
  } else
    res->data=bar;

  return "";
}

string itag_colors(mapping tag, mapping m, string contents,
		   mapping res)
{
  string sep=SEP;
  if(m->separator) sep=m->separator;
  
  res->colors = map(contents/sep, parse_color); 

  return "";
}

string itag_legendtext(mapping tag, mapping m, string contents,
		       mapping res)
{
  string sep=SEP;
  if(m->separator)
    sep=m->separator;
  
  res->legend_texts = contents/sep;

  return "";
}

string syntax( string error )
{
  return "<hr noshade><h3>Syntax error</h3>"
    + error
    + "<hr noshade>";
}

mapping url_cache = ([]);
string quote(string in)
{
  string option;
  if(option = url_cache[in]) return option;
  object g;
  if (sizeof(indices(g=Gz))) {
    option=MIME.encode_base64(g->deflate()->deflate(in), 1);
  } else {
    option=MIME.encode_base64(in, 1);
  }
  if(search(in,"/")!=-1) return url_cache[in]=option;
  string res="$";	// Illegal in BASE64
  for(int i=0; i<strlen(in); i++)
    switch(in[i])
    {
     case 'a'..'z':
     case 'A'..'Z':
     case '0'..'9':
     case '.': case ',': case '!':
      res += in[i..i];
      break;
     default:
      res += sprintf("%%%02x", in[i]);
    }
  if(strlen(res) < strlen(option)) return url_cache[in]=res;
  return url_cache[in]=option;
}

string tag_diagram(string tag, mapping m, string contents,
		   object id, object f, mapping defines)
{
  mapping res=([]);
  res->datacounter=0;
  if(m->help) return register_module()[2];

  if(m->type) res->type = m->type;
  else return syntax( "You must specify a type for your table" );

  if(m->background)
    res->image = combine_path( dirname(id->not_query), (string)m->background);

  /* Piechart */
  if(res->type[0..2] == "pie")
    res->type = "pie";

  /* Barchart */
  if(res->type[0..2] == "bar")
  {
    res->type = "bars";
    res->subtype = "box";
  }   

  /* Linechart */
  if(res->type[0..3] == "line")
  {
    res->type = "bars";
    res->subtype = "line";
  }   

  /* Normaliced sumbar */
  if(res->type[0..3] == "norm")
  {
    res->type = "sumbars";
    res->subtype = "norm";
  }   

  switch(res->type) {
   case "sumbars":
   case "bars":
   case "pie":
   case "graph":
     break;
   default:
     return syntax("\""+res->type+"\" is an unknown type of diagram\n");
  }

  if(m->subtype)
    res->subtype = (string)m->subtype;

  if(res->type == "pie")
    res->subtype="pie";
  else
    res->drawtype="linear";

  if(res->type == "bars")
    if(res->subtype!="line")
      res->subtype="box";

  if(res->type == "graph")
    res->subtype="line";
  
  if(res->type == "sumbars")
    if(res->subtype!="norm");

  parse_html(contents, ([]), ([ "data":itag_data ]), res, id );

  parse_html(contents,
	     ([ "xaxis":itag_xaxis,
		"yaxis":itag_yaxis ]),
	     ([ "xnames":itag_names,
		"ynames":itag_names,
		"xvalues":itag_values,
		"yvalues":itag_values,
		"colors":itag_colors,
		"legend":itag_legendtext ]), 
	     res );

  if( res->data == ({ }) )
    return "<hr noshade><h3>No data for the diagram</h3><hr noshade>";

  res->bg = parse_color(defines->bg || "#e0e0e0");
  res->fg = parse_color(defines->fg || "black");
  
  if(m->center) res->center = (int)m->center;

  if(m["3d"])
  {
    res->drawtype = "3D";
    if( lower_case(m["3d"])!="3d" )
      res->dimensionsdepth = (int)m["3d"];    
    else
      res->dimensionsdepth = 20;    
  }
  else 
    if(res->type=="pie") res->drawtype = "2D";
    else res->drawtype = "linear";
      
  if(m->orient && m->orient[0..3] == "vert")
    res->orientation = "vert";
  else res->orientation="hor";

  if(m->fontsize) res->fontsize = (int)m->fontsize;
  else res->fontsize=16;

  if(m->legendfontsize) res->legendfontsize = (int)m->legendfontsize;
  else res->legendfontsize = res->fontsize;

  if(m->labelsize) res->labelsize = (int)m->labelsize;
  else res->labelsize = res->fontsize;

  if(m->labelcolor) res->labelcolor = parse_color(m->labelcolor);
  else res->labelcolor=({0,0,0});
  
  if(m->linecolor) res->axcolor=parse_color(m->axcolor);
  else res->axcolor=({0,0,0});
  
  if(m->linewidth) res->linewidth=m->linewidth;
  else res->linewidth="2.2";

  if(m->rotate) res->rotate = m->rotate;

  if(m->grey) res->bw = 1;

  if(m->width) {
    if((int)m->width > query("maxwidth"))
      m->width  = (string)query("maxwidth");
    if((int)m->width < 100)
      m->width  = "100";
  } else if(!res->image)
    m->width = "350";

  if(m->height) {  
    if((int)m->height > query("maxheight"))
      m->height = (string)query("maxheight");
    if((int)m->height < 100)
      m->height = "100";
  } else if(!res->image)
    m->height = "250";

  if(!res->image)
  {
    if(m->width) res->xsize = (int)m->width;
    else         res->xsize = 400; // A better algo for this is coming.

    if(m->height) res->ysize = (int)m->height;
    else res->ysize = 300; // Dito.
  } else {
    if(m->width) res->xsize = (int)m->width;
    if(m->height) res->ysize = (int)m->height;
  }

  if(m->tone) res->tone = 1;

  if(!res->xnames)
    if(res->xname) res->xnames = ({ res->xname });
      
  if(!res->ynames)
    if(res->yname) res->ynames = ({ res->yname });

  if(m->gridwidth) res->gridwidth = m->gridwidth;
  if(m->vertgrid) res->vertgrid = 1;
  if(m->horgrid) res->horgrid = 1;

  m_delete( m, "size" );
  m_delete( m, "type" );
  m_delete( m, "3d" );
  m_delete( m, "templatefontsize" );
  m_delete( m, "fontsize" );
  m_delete( m, "tone" );
  m_delete( m, "background" );

  m->src = query("location") + quote(encode_value(res)) + ".gif";

  return(make_tag("img", m));
}

mapping query_container_callers()
{
  return ([ "diagram" : tag_diagram ]);
}

object PPM(string fname, object id)
{
  string q;
  q = roxen->try_get_file( fname, id);
  // q = Stdio.read_file((string)fname);
  //  q = Stdio.read_bytes(fname);
  //  if(!q) q = roxen->try_get_file( dirname(id->not_query)+fname, id);
  if(!q) perror("Diagram: Unknown PPM image '"+fname+"'\n");
  mixed g = Gz;
  if (g->inflate) {
    catch {
      q = g->inflate()->inflate(q);
    };
  }
  return image()->fromppm(q);
}


/* Thease two are just ugly kludges until encode_value gets fixed */
float floatify( string in )
{
  return (float)in;
}

array strange( array in )
{
  // encode_value does not support negative floats.
  array tmp2 = ({});
  foreach(in, array tmp)
  {
    tmp = Array.map( tmp, floatify );
    tmp2 += ({ tmp });
  }
  return tmp2;
}

  // encode_value does not support negative floats.
/*
  array tmp2 = ({});
  foreach(res->data, array tmp)
  {
    tmp = Array.map( tmp, floatify );
    tmp2 += ({ tmp });
  }
  res->data = tmp2;
*/

mapping find_file(string f, object id)
{
  program Bars  = (program)"create_bars";
  program Graph = (program)"create_graph";
  program Pie   = (program)"create_pie";
  object pie    = Pie();
  object bars   = Bars();
  object graph  = Graph();

  if (f[sizeof(f)-4..] == ".gif")
    f = f[..sizeof(f)-5];

  mapping res;

  if (sizeof(f)) {
    object g;
    if (f[0] == '$') {	// Illegal in BASE64
      f = f[1..];
    } else if (sizeof(indices(g=Gz))) {
      /* Catch here later */
      f = g->inflate()->inflate(MIME.decode_base64(f));
    } else if (sizeof(f)) {
      /* Catch here later */
      f = MIME.decode_base64(f);
    }
    res = decode_value(f);  
  } else
    perror( "Diagram: Fatal Error, f: %s\n", f );

  res->labels = ({ res->xstor, res->ystor, res->xunit, res->yunit });

  /* Kludge */
  res->data = strange( res->data );
  if(res->xvalues)
    res->xvalues = Array.map( res->xvalues, floatify );
  if(res->yvalues)
    res->yvalues = Array.map( res->yvalues, floatify );

  mapping(string:mixed) diagram_data;
  array back = res->bg;

  if(res->image)
  {
    m_delete( res, "bg" );
    res->image = PPM(res->image, id);
  }

  if(res->xstart > res->xstop) m_delete( res, "xstart" );
  if(res->ystart > res->ystop) m_delete( res, "ystart" );


  diagram_data=(["type":      res->type,
		 "subtype":   res->subtype,
		 "drawtype":  res->dimensions,
		 "3Ddepth":   res->dimensionsdepth,
		 "xsize":     res->xsize,
		 "ysize":     res->ysize,
		 "textcolor": res->fg,
		 "bgcolor":   res->bg,
		 "orient":    res->orientation,

		 "xminvalue": (float)res->xstart,
		 "xmaxvalue": (float)res->xstop,
		 "yminvalue": (float)res->ystart,
		 "ymaxvalue": (float)res->ystop,

		 "data":      res->data,
		 "datacolors":res->colors,
		 "fontsize":  res->fontsize,

		 "xnames":              res->xnames,
		 "values_for_xnames":   res->xvalues,
		 "ynames":              res->ynames,
		 "values_for_ynames":   res->yvalues,

		 "axcolor":   res->axcolor,

		 "gridwidth": res->gridwidth,
		 "vertgrid":  res->vertgrid,
		 "horgrid":   res->horgrid,

		 "labels":         res->labels,
		 "labelsize":      res->labelsize,
		 "legendfontsize": res->legendfontsize,
		 "legend_texts":   res->legend_texts,
		 "labelcolor":     res->labelcolor,

		 "linewidth": (float)res->linewidth,
		 "tone":      res->tone,
		 "center":    res->center,
		 "rotate":    res->rotate,
		 "image":     res->image,

		 "bw":       res->bw,
  ]);

  if(!res->xstart)  m_delete( diagram_data, "xminvalue" );
  if(!res->xstop)   m_delete( diagram_data, "xmaxvalue" );
  if(!res->ystart)  m_delete( diagram_data, "yminvalue" );
  if(!res->ystop)   m_delete( diagram_data, "ymaxvalue" );
  if(!res->bg)      m_delete( diagram_data, "bgcolor" );
  if(!res->rotate)  m_delete( diagram_data, "rotate" );

  object(Image.image) img;

  /* Check this */
  if(res->image)
    diagram_data["image"] = res->image;

  if(res->type == "pie")
    img = pie->create_pie(diagram_data)["image"];

  if(res->type == "bars")
    img = bars->create_bars(diagram_data)["image"];

  if(res->type == "graph")
    img = graph->create_graph(diagram_data)["image"];

  if(res->type == "sumbars")
    img = bars->create_bars(diagram_data)["image"];

  img = img->map_closest(img->select_colors(254)+({ back }));

  return http_string_answer(img->togif(@back), "image/gif");  
}
