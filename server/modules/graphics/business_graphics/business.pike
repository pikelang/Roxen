/* This is a roxen module. (c) Informationsvävarna AB 1997.
 * Resdistribution of this file is not permitted.
 * 
 * Draws diagrams pleasing to the eye.
 * 
 * Made by Peter Bortas <peter@infovav.se> and Henrik Wallin <hedda@infovav.se>
 * in October -97
 */

constant cvs_version = "$Id 3$";
constant thread_safe=0;

#include <module.h>
inherit "module";
inherit "roxenlib";
#include <roxen.h>
//#include "create_bars.pike";
#include "create_pie.pike";

#define SEP "\t"

mixed *register_module()
{
  return ({ 
    MODULE_PARSER|MODULE_LOCATION,
    "Business Graphics",
      ("Draws graphs that is pleasing to the eye."
       "<br>This module defines some tags,"
       "<pre>"
       "&lt;diagram&gt;: \n"
       "</pre>"
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

  return "";
}

string itag_yaxis(string tag, mapping m, mapping res)
{
  if(m->name)  res->yname = m->name;
  
  if(m->start) res->ystart = m->start;
  else         res->ystart = "foobar";

  if(m->stop)  res->ystop = m->stop;
  else         res->ystop = "foobar";

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

  if(m->form == "db" || m->form == "straight")
  {
    array lines = contents/linesep;
    array foo = ({});
    array bar = ({});
    
    foreach( lines, string entries )
    {
      foreach( filter( ({ entries/sep - ({""}) }), sizeof ), array item)
      {
	foreach( item, string gaz )
	  foo += ({ (int)gaz });
      }
      bar += ({ foo });
    }
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

  if(m->subtype)
    res->subtype = (string)m->subtype;

  if(res->type == "pie")
    res->subtype="pie";

  if(res->type == "bars")
    if(res->subtype!="line")
      res->subtype="box";

  if(res->type == "graph")
    res->subtype="line";
  
  if(res->type == "sumbars")
    if(res->subtype!="norm")
      res->subtype=0;         /* #%¤%& Hedda! Fixa ett riktigt namn! */

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
  
  if(m->labelsize) res->labelsize = (int)m->labelsize;
  else res->labelsize=16;

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
      
  if(m->fontsize) res->fontsize = (int)m->fontsize;
  else res->fontsize=32;

  if(m->legendfontsize) res->legendfontsize = (int)m->legendfontsize;
  else res->legendfontsize = 10;

  if(m->labelcolor) res->labelcolor = parse_color(m->labelcolor);
  else res->labelcolor=({0,0,0});
  
  if(m->axiscolor) res->axiscolor=parse_color(m->axiscolor);
  else res->axiscolor=({0,0,0});
  
  if(m->linewidth) res->linewidth=(float)m->linewidth;
  else res->linewidth=2.2;

  if(m->xsize) res->xsize = (int)m->xsize;
  else return syntax( "You must specify an xsize for the diagram" );
  if(m->xsize) res->ysize = (int)m->ysize;
  else return syntax( "You must specify an ysize for the diagram" );

  if(m->tone) res->tone = 1;
  else res->tone = 0;

  if(!res->xnames)
    if(res->xname) res->xnames = ({ res->xname });
    else res->xnames = ({ });
      
  if(!res->ynames)
    if(res->yname) res->ynames = ({ res->yname });
    else res->ynames = ({ });
      
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

mapping find_file(string f, object id)
{
  if (f[sizeof(f)-4..] == ".gif")
    f = f[..sizeof(f)-5];

  mapping res = decode_value(MIME.decode_base64(f));    

  /*
    perror("f-#data: %O\n", sizeof(res->data[0]));
    perror("f-data: %O\n", res->data[0]);
    perror("f-#xnames: %O\n", sizeof(res->xnames));
    perror("f-xnames: %O\n", res->xnames);
  */

  //strap
  res->labels=      ({"xstor", "ystor", "xenhet", "yenhet"});
  res->xminvalue=   0.1;
  res->yminvalue=   0;

  mapping(string:mixed) diagram_data;
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

		 "xminvalue": res->xminvalue,
		 "yminvalue": res->yminvalue,

		 "axcolor":   res->axiscolor,

		 "labels":         res->labels,
		 "labelsize":      res->labelsize,
		 "legendfontsize": res->legenfontsize,
		 "legend_texts":   res->legend_texts,
		 "labelcolor":     res->labelcolor,

		 "linewidth": res->linewidth,
		 "tone":      res->tone
  ]);

  /*
    if(res->type == "bars")
    diagram_data=(["type":"bars",
		   "textcolor":  fg,
		   "subtype":    "box",
		   "orient":     "vert",
		   "data":       data,
		   "fontsize":   res->fontsize,
		   "axcolor":    res->axiscolor,
		   "bgcolor":    bg,
		   "labelcolor": res->labelcolor,
		   "datacolors": datacolors,
		   "linewidth":  res->linewidth,
		   "xsize":      res->xsize,
		   "ysize":      res->ysize,
		   "xnames":     res->xnames,
		   "labels":     res->labels,
		   "legendfontsize": res->legendfontsize,
		   "legend_texts":   res->legend_texts, 
		   "labelsize":  res->labelsize,
		   "xminvalue":  res->xminvalue,
		   "yminvalue":  res->yminvalue
    ]);
  */

  /*
    if(res->type == "pie")
    diagram_data=(["type":      "pie",
		   "textcolor": res->fg,
		   "subtype":   "box",
		   "orient":    "vert",
		   "data":      res->data,
		   "fontsize":  res->fontsize,
		   "axcolor":   res->axiscolor,
		   "bgcolor":   res->bg,
		   "labelcolor":res->labelcolor,
		   "datacolors":res->colors,
		   "linewidth": res->linewidth,
		   "xsize":     res->xsize,
		   "ysize":     res->ysize,
		   "xnames":    res->xnames,
		   "labels":    ({"xstor", "ystor", "xenhet", "yenhet"}),
		   "legendfontsize":res->legenfontsize,
		   "legend_texts":({ "streck 1", "streck 2", "foo",
				     "bar gazonk foobar illalutta!", "lila",
				     "turkos" }),
		   "labelsize":res->labelsize,
		   "xminvalue":0.1,
		   "yminvalue":0,
		   "3Ddepth":res->dimensionsdepth,
		   "drawtype":res->dimensions,
		   "tone":0	   
    ]);
  */

  object(Image.image) img;

  //  img = create_bars(diagram_data)["image"];
  if(res->type = "pie")
    img = create_pie(diagram_data)["image"];

  /*
  if(res->type = "bars")
    img = create_bars(diagram_data)["image"];

  if(res->type = "graph")
    img = create_graph(diagram_data)["image"];

  if(res->type = "sumbars")
    img = create_sumbars(diagram_data)["image"];
  */

  img = img->map_closest(img->select_colors(254)+({res->bg}));

  perror("%O\n", res->xnames);
  perror("\n");

  return http_string_answer(img->togif(@res->bg), "image/gif");  
}
