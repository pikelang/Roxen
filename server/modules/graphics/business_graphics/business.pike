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

string itag_xaxis(mapping tag, mapping m, mapping res)
{
  if(m->name)  res->xname = m->name;
  
  if(m->start) res->xstart = m->start;
  else         res->xstart = "foobar";

  if(m->stop)  res->xstop = m->stop;
  else         res->xstop = "foobar";

  return "";
}

string itag_yaxis(mapping tag, mapping m, mapping res)
{
  if(m->name)  res->yname = m->name;
  
  if(m->start) res->ystart = m->start;
  else         res->ystart = "foobar";

  if(m->stop)  res->ystop = m->stop;
  else         res->ystop = "foobar";

  return "";
}

/* Handle <xdatanames> and <ydatanames> */
string itag_datanames(mapping tag, mapping m, string contents,
		      mapping res)
{
  string sep="\t";
  if(m->separator)
    sep=m->sep;
  
  if(tag=="xdatanames")
    res->xdatanames = contents / sep;
  else
    res->ydatanames = contents / sep;

  return "";
}

string itag_data(mapping tag, mapping m, string contents,
		 mapping res)
{
  string sep="\t";
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
	  foo += ({ (float)gaz });
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
  string sep="\t";
  if(m->separator)
    sep=m->sep;
  
  if(m->colors)
    res->colors = map(m->colors/sep, parse_color); 
  else
    res->colors = ({ ({0,255,0}), ({255,255,0}), ({0,255,255}),
		     ({255,0,255}), ({0,255,0}), ({255,255,0}) });
  
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

  parse_html(contents,
	     ([ "xaxis":itag_xaxis,
		"yaxis":itag_yaxis ]),
	     ([ "datanames":itag_datanames,
		"data":itag_data,
		"colors":itag_colors]), res);

  res->bg = parse_color(defines->bg || "#e0e0e0");
  res->fg = parse_color(defines->fg || "black");

  if(m["3d"])
  {
    res->dimensions = "3D";
    perror("'"+m["3d"]+"'\n");
    if( lower_case(m["3d"])!="3d" )
      res->dimensionsdepth = (int)m["3d"];    
    else
      res->dimensionsdepth = 20;    
  }
  else 
    res->dimensions = "2D";

  if(m->xsize)
    res->xsize = (int)m->xsize;
  if(m->xsize)
    res->ysize = (int)m->ysize;

  if(m->type) res->type = m->type;
  else return syntax( "You must specify a type for your table" );

  m_delete( m, "ysize" );
  m_delete( m, "xsize" );
  m_delete( m, "size" );
  m_delete( m, "type" );
  m_delete( m, "3d" );

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
  array (int) bg = res->bg, fg = res->fg;

  res->colors = ({ ({0,255,0}), ({255,255,0}), ({0,255,255}),
		   ({255,0,255}), ({0,255,0}), ({255,255,0}) });
  array datacolors = res->colors;

  array data = /* res->data;*/
    ({ ({55, 40, 30 ,20, 10, 10, 10, 10, 5 }) });

  perror("f-data: %O\n", data);

  mapping(string:mixed) diagram_data;

  if(res->type == "bars")
    diagram_data=(["type":"bars",
		   "textcolor":fg,
		   "subtype":"box",
		   "orient":"vert",
		   "data":data,
		   "fontsize":32,
		   "axcolor":({0,0,0}),
		   "bgcolor" : bg,
		   "labelcolor":({0,0,0}),
		   "datacolors":datacolors,
		   "linewidth":2.2,
		   "xsize":res->xsize,
		   "ysize":res->ysize,
		   "xnames":({"jan", "feb", "mar", "apr", "maj", "jun"}),
		   "fontsize":16,
		   "labels":({"xstor", "ystor", "xenhet", "yenhet"}),
		   "legendfontsize":12,
		   "legend_texts":
		   ({ "streck 1", "streck 2", "foo", "bar gazonk foobar illalutta!" }),
		   "labelsize":12,
		   "xminvalue":0.1,
		   "yminvalue":0
    ]);
  
  if(res->type == "pie")
    diagram_data=(["type":"pie",
		   "textcolor":fg,
		   "subtype":"box",
		   "orient":"vert",
		   "data":data,
		   "fontsize":32,
		   "axcolor":({0,0,0}),
		   "bgcolor":bg,
		   "labelcolor":({0,0,0}),
		   "datacolors":datacolors,
		   "linewidth":2.2,
		   "xsize":res->xsize,
		   "ysize":res->ysize,
		   "xnames":({"jan", "feb", "mar", "apr", "maj", "jun",
			      "jul", "aug", "sep" }),
		   "fontsize":16,
		   "labels":({"xstor", "ystor", "xenhet", "yenhet"}),
		   "legendfontsize":12,
		   "legend_texts":({ "streck 1", "streck 2", "foo",
				     "bar gazonk foobar illalutta!", "lila",
				     "turkos" }),
		   "labelsize":12,
		   "xminvalue":0.1,
		   "yminvalue":0,
		   "3Ddepth":res->dimensionsdepth,
		   "drawtype":res->dimensions,
		   "tone":1	   
    ]);


  object(Image.image) img;

  //  img = create_bars(diagram_data)["image"];
  img = create_pie(diagram_data)["image"];
  img = img->map_closest(img->select_colors(254)+({bg}));

  //  perror("%O\n", bg);
  perror("\n");

  return http_string_answer(img->togif(@bg), "image/gif");  

  return 0;
}
