/* This is a roxen module. (c) Idonex AB 1997.
 * Resdistribution of this file is not permitted.
 * 
 * Draws diagrams pleasing to the eye.
 * 
 * Made by Peter Bortas <peter@idonex.se> and Henrik Wallin <hedda@idonex.se>
 * in October 1997
 */

/* TODO:
 *
 * Idag:
 * Skriv dok och skriv ut åt PetNo.
 * Se till att sumbars får jämnstora arrayer.
 *
 * Senare:
 * Prevent less that 100x100 in size.
 */

constant cvs_version = "$Id: business.pike,v 1.20 1997/10/15 12:28:42 peter Exp $";
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
      ("Draws graphs that is pleasing to the eye."
       "<br>This module defines some tags,"
       "<pre>"
       "&lt;diagram&gt; (container): \n"
       "Draws differet kinds of diagrams. \n"
       "Defines the following attributes: \n"
       " type=        { sumbars | normsumbars |linechart | barchart | piechart | graph }\n"
       " background=  Takes the filename of a ppm image is input.\n"
       " xsize=       width of diagram-image in pixels.\n"
       " ysize=       height of diagram-image in pixels.\n"
       " fontsize=    height if text in pixels.\n"
       " legendfontsize= height if legend text in pixels. Uses fontsize if not defined\n"
       " 3D=          Does a C00l 3D-effect on piecharts, takes the size in pixels of the 3Dtilt as argument.\n"
       /* " tone         Do nasty stuff to the background Requires dark background to be visable.\n" */
       "Defines the following tags: \n"
       "&lt;xaxis&gt; and &lt;yaxis&gt; (tags)"
       "Attributes for the x and y axis."
       " name=        Dunno what this does.\n"
       " start=       .\n"
       " stop=        .\n"       
       " quantity=    name.\n"
       " units=       name.\n"
       "&lt;colors&gt; (container)"
       "Tabseparated list of colors for the diagram."
       " separator=   Use the specifyed string as separator intead of tab.\n"
       "&lt;legend&gt; (container)"
       "Tabseparated list of strings for the legend."
       " separator=   Use the specifyed string as separator intead of tab.\n"
       "&lt;xdatanames&gt; (container) !!Name will probably change!!"
       "Tabseparated list of datanames for the diagram."
       " separator=   Use the specifyed string as separator intead of tab.\n"
       "&lt;xdatanames&gt; (container) !!Name will probably change!!"
       "Tabseparated list of dataname for the diagram."
       " separator=   Use the specifyed string as separator intead of tab.\n"
       "&lt;xdatanames&gt; (container) !!Name will probably change!!"
       "Tab- and newline- separated list of data-value for the diagram."
       " separator=      Use the specifyed string as separator intead of tab.\n"
       " lineseparator=  Use the specifyed string as lineseparator intead of tab.\n"
       "</pre>"
       "BUGS:<br><li>background does not work well.<br>"
       "<br><li>"
       ), ({}), 1,
    });
}

void create()
{
  defvar("location", "/diagram/", "Mountpoint", TYPE_LOCATION|VAR_MORE,
	 "The URL-prefix for the diagrams.");
}

string itag_xaxis(string tag, mapping m, mapping res)
{
  if(m->name)  res->xname = m->name;
  
  if(m->start) res->xstart = m->start;
  else         res->xstart = "foobar";

  if(m->stop)  res->xstop = m->stop;
  else         res->xstop = "foobar";

  if(m->quantity) res->xstor = m->quantity;
  else            res->xstor = "";

  if(m->unit) res->xunit = m->unit;
  else        res->xunit = "";

  return "";
}

string itag_yaxis(string tag, mapping m, mapping res)
{
  if(m->name)  res->yname = m->name;
  
  if(m->start) res->ystart = m->start;
  else         res->ystart = "foobar";

  if(m->stop)  res->ystop = m->stop;
  else         res->ystop = "foobar";

  if(m->quantity) res->ystor = m->quantity;
  else            res->ystor = "";

  if(m->unit) res->yunit = m->unit;
  else        res->yunit = "";

  return "";
}

/* Handle <xdatanames> and <ydatanames> */
string itag_datanames(string tag, mapping m, string contents,
		      mapping res)
{
  string sep=SEP;
  if(m->separator)
    sep=m->separator;
  
  if(tag=="xdatanames")
    res->xnames = contents / sep;
  else
    res->ynames = contents / sep;

  return "";
}

string itag_data(mapping tag, mapping m, string contents,
		 mapping res)
{
  string sep=SEP;
  if(m->separator)
    sep=m->separator;

  string linesep="\n";
  if(m->lineseparator)
    linesep=m->lineseparator;

  if( !m->form || m->form == "straight" )
  {
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
	  foo += ({ (float)gaz });
      }
      if (sizeof(bar)>maxsize)
	maxsize=sizeof(bar);
      bar += ({ foo });
      foo = ({});
    }

    //FIXME Här har Hedda hackat och fört in buggar
    if (m->form == "db")
      {
	for(int i=0; i<sizeof(bar); i++)
	  if (sizeof(bar[i])<maxsize)
	    bar+=allocate(maxsize-sizeof(bar[i]));
	
	array bar2=allocate(sizeof(bar));
	for(int i=0; i<sizeof(bar); i++)
	  bar2[i]=column(bar, i);
	res->data=bar2;
      }
    else
      res->data=bar;
  }

  return "";
}

string itag_colors(mapping tag, mapping m, string contents,
		   mapping res)
{
  string sep=SEP;
  if(m->separator)
    sep=m->separator;
  
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

string tag_diagram(string tag, mapping m, string contents,
		   object id, object f, mapping defines)
{
  mapping res=([]);
  res->datacounter=0;
  if(m->help) return register_module()[2];

  if(m->type) res->type = m->type;
  else return syntax( "You must specify a type for your table" );

  if(m->background)
    res->image = (string)m->background;

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
    if(res->subtype!="norm")
      res->subtype=0;         /* #%¤%& Hedda! Fixa ett riktigt namn! 
			        - Näe! /Hedda                         */

  parse_html(contents,
	     ([ "xaxis":itag_xaxis,
		"yaxis":itag_yaxis ]),
	     ([ "xdatanames":itag_datanames,
		"ydatanames":itag_datanames,
		"data":itag_data,
		"colors":itag_colors,
		"legend":itag_legendtext ]), res);

  if(!res->colors)
    res->colors = 0;

  res->bg = parse_color(defines->bg || "#e0e0e0");
  res->fg = parse_color(defines->fg || "black");
  
  if(m->center) res->center = (int)m->center;
  else res->center = 0;

  if(m["3d"])
  {
    res->drawtype = "3D";
    //    perror("'"+m["3d"]+"'\n");
    if( lower_case(m["3d"])!="3d" )
      res->dimensionsdepth = (int)m["3d"];    
    else
      res->dimensionsdepth = 20;    
  }
  else 
    if(res->type=="pie") res->drawtype = "2D";
    else res->drawtype = "linear";
      
  if(m->orientation && m->orientation[0..3] == "vert")
    res->orientation = "vert";
  else res->orientation="hor";

  if(m->fontsize) res->fontsize = (int)m->fontsize;
  else res->fontsize=32;

  if(m->legendfontsize) res->legendfontsize = (int)m->legendfontsize;
  else res->legendfontsize = res->fontsize;

  if(m->labelsize) res->labelsize = (int)m->labelsize;
  else res->labelsize = res->fontsize;

  if(m->labelcolor) res->labelcolor = parse_color(m->labelcolor);
  else res->labelcolor=({0,0,0});
  
  if(m->axiscolor) res->axiscolor=parse_color(m->axiscolor);
  else res->axiscolor=({0,0,0});
  
  if(m->linewidth) res->linewidth=(float)m->linewidth;
  else res->linewidth=2.2;

  if(!m->image)
  {
    if(m->xsize) res->xsize = (int)m->xsize;
    else res->xsize = 400;
    if(m->ysize) res->ysize = (int)m->ysize;
    else res->ysize = 300;
  }
  else
  {
    if(m->xsize) res->xsize = (int)m->xsize;
    if(m->ysize) res->ysize = (int)m->ysize;
  }

  if(m->tone) res->tone = 1;
  else res->tone = 0;

  if(!res->xnames)
    if(res->xname) res->xnames = ({ res->xname });
    else res->xnames = 0;
      
  if(!res->ynames)
    if(res->yname) res->ynames = ({ res->yname });
    else res->ynames = 0;
      
  m_delete( m, "ysize" );
  m_delete( m, "xsize" );
  m_delete( m, "size" );
  m_delete( m, "type" );
  m_delete( m, "3d" );
  m_delete( m, "templatefontsize" );
  m_delete( m, "fontsize" );
  m_delete( m, "tone" );

  m->src = query("location") + MIME.encode_base64(encode_value(res)) + ".gif";

  return(make_tag("img", m));
}

mapping query_container_callers()
{
  return ([ "diagram" : tag_diagram ]);
}

object PPM(string fname, object id)
{
  string q;
  //    roxen->try_get_file( dirname(id->not_query)+fname, id);
  q = Stdio.read_file((string)fname);
  //  q = Stdio.read_bytes(fname);
  //  if(!q) q = roxen->try_get_file( dirname(id->not_query)+fname, id);
  if(!q) perror("Unknown PPM image '"+fname+"'\n");
  mixed g = Gz;
  if (g->inflate) {
    catch {
      q = g->inflate()->inflate(q);
    };
  }
  return image()->fromppm(q);
}

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

  mapping res = decode_value(MIME.decode_base64(f));    

  perror("f-#data: %O\n", sizeof(res->data[0]));
  perror("f-data: %O\n", res->data);

  //strap
  res->labels=      ({ res->xstor, res->ystor, res->xunit, res->yunit });
  res->xminvalue=   0.1;
  res->yminvalue=   0;

  mapping(string:mixed) diagram_data;

  array back = res->bg;

  if(res->image)
  {
    res->bg = 0;
    perror( res->image +"\n" );
    res->image = PPM(res->image, id);
  }

  diagram_data=(["type":      res->type,
		 "subtype":   res->subtype,
		 "drawtype":  res->dimensions,
		 "3Ddepth":   res->dimensionsdepth,
		 "xsize":     res->xsize,
		 "ysize":     res->ysize,
		 "textcolor": res->fg,
		 "bgcolor":   res->bg,
		 "orient":    res->orientation,

		 "data":      res->data,
		 "datacolors":res->colors,
		 "fontsize":  res->fontsize,
		 "xnames":    res->xnames,
		 "ynames":    res->ynames,

		 "xminvalue": res->xminvalue,
		 "yminvalue": res->yminvalue,

		 "axcolor":   res->axiscolor,

		 "labels":         res->labels,
		 "labelsize":      res->labelsize,
		 "legendfontsize": res->legendfontsize,
		 "legend_texts":   res->legend_texts,
		 "labelcolor":     res->labelcolor,

		 "linewidth": res->linewidth,
		 "tone":      res->tone,
		 "center":    res->center,
		 "image":     res->image
  ]);
  

  object(Image.image) img;

  perror( res->orientation +"  " );
  perror( res->type +"  " );
  perror( res->subtype +"\n" );

  /* Säkerhetshål!! */
  if(res->image)
    diagram_data["image"] = PPM(res->image, id);

  if(res->type == "pie")
    img = pie->create_pie(diagram_data)["image"];

  if(res->type == "bars")
    img = bars->create_bars(diagram_data)["image"];

  if(res->type == "graph")
    img = graph->create_graph(diagram_data)["image"];

  if(res->type == "sumbars")
    img = bars->create_bars(diagram_data)["image"];

  img = img->map_closest(img->select_colors(254)+({ back }));

  //  perror("%O\n", res->xnames);
  perror("\n");

  return http_string_answer(img->togif(@back), "image/gif");  
}
