/* This is a roxen module. Copyright © 1999 - 2000, Roxen IS.
 *
 * Draws diagrams pleasing to the eye.
 *
 * Made by Peter Bortas <peter@roxen.com> and Henrik Wallin <hedda@roxen.com>
 * in October 1997
 */

#include <module.h>
#include <roxen.h>

inherit "module";
inherit "roxenlib";

constant cvs_version = "$Id: business.pike,v 1.128 2000/05/11 10:16:07 per Exp $";
constant thread_safe = 1;
constant module_type = MODULE_PARSER|MODULE_LOCATION;
constant module_name = "Business graphics";
constant module_doc  = 
#"Provides the <tt>&lt;diagram&gt;</tt> tag that draws bar charts, line charts,
pie charts or graphs.";

#define VOIDSYMBOL "\n"
#define SEP "\t"

function create_pie, create_bars, create_graph;

#ifdef BG_DEBUG
mapping bg_timers = ([]);
#endif

//FIXME (Inte alltid VOID!
#define VOIDCODE \
  do { voidsep = m->voidseparator||m->voidsep||res->voidsep||"VOID"; } while(0)

int loaded;



roxen.ImageCache image_cache;

void start(int num, object configuration)
{
  if (!loaded) {
    loaded = 1;
    create_pie   = ((program)"create_pie")()->create_pie;
    roxen->dump( (combine_path( __FILE__, "../" ) + "create_pie.pike")
                 -(getcwd()+"/") );
    create_bars  = ((program)"create_bars")()->create_bars;
    roxen->dump( (combine_path( __FILE__, "../" ) + "create_bars.pike")
                 -(getcwd()+"/"));
    create_graph = ((program)"create_graph")()->create_graph;
    roxen->dump( (combine_path( __FILE__, "../" ) + "create_graph.pike")
                 -(getcwd()+"/"));
  }
  image_cache = roxen.ImageCache( "diagram", draw_callback );
}

void stop()
{
  /* Reload Pie, Bars and Graph */
#ifdef MODULE_DEBUG
  mapping progs = master()->programs;
  foreach(glob(combine_path(__FILE__,"../*"), indices(progs)),
          string to_delete)
    m_delete(progs, to_delete);
#endif
}

void create()
{
  defvar( "maxwidth", 3000, "Limits:Max width", TYPE_INT,
	  "Maximal width of the generated image." );
  defvar( "maxheight", 1000, "Limits:Max height", TYPE_INT,
	  "Maximal height of the generated image." );
  defvar( "maxstringlength", 60, "Limits:Max string length", TYPE_INT,
	  "Maximal length of each text label used in the diagram." );
  defvar( "ext", 1, "Append format to generated images",
	  TYPE_FLAG|VAR_MORE, 
	  "Append the image format (.gif, .png, .gif, etc) to the generated "
	  "images. This is not necessary, but might seem nicer.");
}

string itag_xaxis(string tag, mapping m, mapping res)
{
#ifdef BG_DEBUG
  bg_timers->xaxis = gauge {
#endif
  int l=query("maxstringlength")-1;

  res->xaxisfont = m->font || m->nfont || res->xaxisfont;

  if(m->name) res->xname = m->name[..l];
  if(m->start)
    if (lower_case(m->start[0..2])=="min")
      res->xmin=1;
    else
      res->xstart = (float)m->start;
  if(m->stop) res->xstop = (float)m->stop;
  if(m->quantity) res->xstor = m->quantity[..l];
  if(m->unit) res->xunit = m->unit[..l];
#ifdef BG_DEBUG
  };
#endif

  return "";
}

string itag_yaxis(string tag, mapping m, mapping res)
{
#ifdef BG_DEBUG
  bg_timers->yaxis = gauge {
#endif
  int l=query("maxstringlength")-1;

  res->yaxisfont = m->font || m->nfont || res->yaxisfont;

  if(m->name) res->yname = m->name[..l];
  if(m->start)
    if (lower_case(m->start[0..2])=="min")
      res->ymin=1;
    else
      res->ystart = (float)m->start;
  if(m->stop) res->ystop = (float)m->stop;
  if(m->quantity) res->ystor = m->quantity[..l];
  if(m->unit) res->yunit = m->unit[..l];
#ifdef BG_DEBUG
  };
#endif

  return "";
}

/* Handle <xnames> and <ynames> */
string itag_names(string tag, mapping m, string contents,
		      mapping res, object id)
{
#ifdef BG_DEBUG
  bg_timers->names += gauge {
#endif
  int l=query("maxstringlength")-1;

  if(!m->noparse)
    contents = parse_rxml( contents, id );

  string sep = m->separator || SEP;

  string voidsep;
  VOIDCODE;

  array foo;

  if( contents-" " != "" )
  {
    if(tag=="xnames")
    {
      res->xnamesfont = m->font || m->nfont || res->xnamesfont;

      foo=res->xnames = contents/sep;
      if(m->orient)
	if (m->orient[0..3] == "vert")
	  res->orientation = "vert";
	else
	  res->orientation="hor";
    }
    else
    {
      foo=res->ynames = contents/sep;

      res->ynamesfont = m->font || m->nfont || res->ynamesfont;
    }
  }
  else
     return "";

  for(int i=0; i<sizeof(foo); i++)
    if (voidsep==foo[i])
      foo[i]=" ";
    else
      foo[i]=foo[i][..l];
#ifdef BG_DEBUG
  };
#endif

  return "";
}

float|string floatify( string in , string voidsep )
{
  if (voidsep==in)
    return VOIDSYMBOL;
  else
    return (float)in;
}

/* Handle <xvalues> and <yvalues> */
string itag_values(string tag, mapping m, string contents,
		   mapping res, object id)
{
#ifdef BG_DEBUG
  bg_timers->values += gauge {
#endif

  string voidsep;
  VOIDCODE;

  if(!m->noparse)
    contents = parse_rxml( contents, id );

  string sep = m->separator || SEP;

  if( contents-" " != "" )
  {
    if(tag=="xvalues")
      res->xvalues = Array.map( contents/sep, floatify, voidsep );
    else
      res->yvalues = Array.map( contents/sep, floatify, voidsep );
  }
#ifdef BG_DEBUG
  };
#endif

  return "";
}

string itag_data(mapping tag, mapping m, string contents,
		 mapping res, object id)
{
#ifdef BG_DEBUG
  bg_timers->data += gauge {
#endif

  string voidsep;
  VOIDCODE;

  string sep = m->separator || SEP;

  if (sep=="")
    sep=SEP;

  string linesep = m->lineseparator || "\n";

  if (linesep=="")
    linesep="\n";

  if(!m->noparse)
    contents = parse_rxml( contents, id );

  if ((sep!="\t")&&(linesep!="\t"))
    contents = contents - "\t";

  array lines = contents/linesep-({""});
  array foo = ({});
  array bar = ({});
  int maxsize=0;

  if (sizeof(lines)==0)
  {
    res->data=({});
    return 0;
  }

#ifdef BG_DEBUG
  bg_timers->data_foo = gauge {
#endif

  bar=allocate(sizeof(lines));
  int gaba=sizeof(lines);

  for(int j=0; j<gaba; j++)
  {
    foo=lines[j]/sep - ({""});
    foo=replace(foo, voidsep, VOIDSYMBOL);
    if (sizeof(foo)>maxsize)
      maxsize=sizeof(foo);
    bar[j] = foo;
  }
#ifdef BG_DEBUG
  };
#endif

  if (sizeof(bar[0])==0)
  {
    res->data=({});
    return 0;
  }

#ifdef BG_DEBUG
  bg_timers->data_bar = gauge {
#endif
  if (m->form)
    if (m->form[0..2] == "col")
      {
	for(int i=0; i<sizeof(bar); i++)
	  if (sizeof(bar[i])<maxsize)
	    bar[i]+=allocate(maxsize-sizeof(bar[i]));
	
	array bar2=allocate(maxsize);
	for(int i=0; i<maxsize; i++)
	  bar2[i]=column(bar, i);
	res->data=bar2;
      }
    else
      res->data=bar;
  else
    res->data=bar;
#ifdef BG_DEBUG
  };
#endif

  if (m->xnames)
    if (!(int)(m->xnames))
      m->xnames=1;
    else
      m->xnames=(int)(m->xnames);

  if ((m->xnames)&&(sizeof(res->data)>m->xnames))
  {
    res->xnames=res->data[..m->xnames-1];
    int j=sizeof(res->xnames[0]);
    mixed foo=allocate(j);
    for(int i=0; i<j; i++)
      foo[i]=(column(res->xnames, i)-({VOIDSYMBOL}))*" ";
    res->xnames=foo;
    res->data=res->data[m->xnames..];
  }

  if (m->xnamesvert)
    res->orientation = "vert";

#ifdef BG_DEBUG
  bg_timers->data_gaz = gauge {
#endif
    mixed b;
    mixed c;

  bar=res->data;
  int basonk=sizeof(bar);
  for(int i=0; i<basonk; i++)
    {
      c=bar[i];
      int k=sizeof(c);
      for(int j=0; j<k; j++)
	if ((b=c[j])!=VOIDSYMBOL)
	  c[j]=(float)(b);
    }
  res->data=bar;
#ifdef BG_DEBUG
  };
#endif
#ifdef BG_DEBUG
  };
#endif

  return 0;
}

string itag_colors(mapping tag, mapping m, string contents,
		   mapping res, object id)
{
  if(!m->noparse)
    contents = parse_rxml( contents, id );

  string sep = m->separator || SEP;

  res->colors = map(contents/sep, parse_color);

  return "";
}

string itag_legendtext(mapping tag, mapping m, string contents,
		       mapping res, object id)
{
  int maxlen = query("maxstringlength")-1;

  string voidsep;
  VOIDCODE;

  if(!m->noparse)
    contents = parse_rxml( contents, id );

  string sep = m->separator || SEP;

  res->legendfont = m->font || m->nfont || res->legendfont;

  res->legend_texts = contents/sep;

  array foo = res->legend_texts;

  for(int i=0; i<sizeof(foo); i++)
    if (voidsep == foo[i])
      foo[i]=" ";
    else
      foo[i]=foo[i][..maxlen];

  return "";
}

string syntax( string error )
{
  return "<hr noshade><font size=+1><b>Syntax error</b></font>&nbsp;&nbsp;"
         "(&lt;<b>diagram help</b>&gt;&lt;/<b>diagram</b>&gt; gives help)<p>"
    + error
    + "<hr noshade>";
}

//mapping(string:mapping) cache = ([]);
mapping(string:object) palette_cache = ([]);
int datacounter = 0;


//FIXME: Put back some hash on the URL. Easily done by putting the hash
//in the metadata.
/* Old hashcode:
  object o=Crypto.sha();
  string data=encode_value(in);
  o->update(data);
  string out=replace(http_encode_string(MIME.encode_base64(o->digest(),1)),
		     "/", "$");
*/

constant _diagram_args =
({ "xgridspace", "ygridspace", "horgrid", "size", "type", "3d",
   "templatefontsize", "fontsize", "tone", "background","colorbg", "subtype",
   "dimensions", "dimensionsdepth", "xsize", "ysize", "fg", "bg",
   "orientation", "xstart", "xstop", "ystart", "ystop", "data", "colors",
   "xnames", "xvalues", "ynames", "yvalues", "axcolor", "gridcolor",
   "gridwidth", "vertgrid", "labels", "labelsize", "legendfontsize",
   "legendfont",
   "legend_texts", "labelcolor", "axwidth", "linewidth", "center",
   "rotate", "image", "bw", "eng", "neng", "xmin", "ymin", "turn", "notrans",
   "colortable_cache"});
constant diagram_args = mkmapping(_diagram_args,_diagram_args);

constant _shuffle_args =
({ "dimensions", "dimensionsdepth", "ygridspace", "xgridspace",
   "xstart", "xstop", "ystart", "ystop", "colors", "xvalues", "yvalues",
   "axwidth", "xstor", "ystor", "xunit", "yunit", "fg", "bg", "voidsep" });
constant shuffle_args = mkmapping( _shuffle_args, _shuffle_args );

string container_diagram(string tag, mapping m, string contents,
		   object id, object f)
{
  int l=query("maxstringlength")-1;
  contents=replace(contents, "\r\n", "\n");
  contents=replace(contents, "\r", "\n");

#ifdef BG_DEBUG
  bg_timers->names = 0;
  bg_timers->values = 0;
  bg_timers->data = 0;
#endif

  mapping(string:mixed) res=([]);

#ifdef BG_DEBUG
  bg_timers->all = gauge {
#endif

  if(m->colortable_cache) res->colortable_cache=m->colortable_cache;
  if(m->type) res->type = m->type;
  else return syntax("You must specify a type for your table.<br>"
		     "Valid types are: "
		     "<b>sumbars</b>, "
		     "<b>normsumbars</b>, "
		     "<b>linechart</b>, "
		     "<b>barchart</b>, "
		     "<b>piechart</b> and "
		     "<b>graph</b>");

  if(m->background)
    res->background =
      combine_path( dirname(id->not_query), (string)m->background);

  if (m->name)
  {
    res->name=m->name[..l];
    if (m->namesize)
      res->namesize=(int)m->namesize;
    if (m->namecolor)
      res->namecolor=parse_color(m->namecolor);
    else
      res->namecolor=parse_color(id->misc->defines->fg);
  }

  res->voidsep = m->voidseparator || m->voidsep;

  res->font = m->font || m->nfont;

  if(m->namefont)
    res->namefont=m->namefont;

  if (m->tunedbox)
    m->tonedbox=m->tunedbox;
  if(m->tonedbox) {
    array a = m->tonedbox/",";
    if(sizeof(a) != 4)
      return syntax("tonedbox must have a comma separated list of 4 colors.");
    res->tonedbox = map(a, parse_color);
  }
  else if (m->colorbg)
    res->colorbg=parse_color(m->colorbg);

  if ((m->bgcolor)&&(m->notrans))
  {
    res->colorbg=parse_color(m->bgcolor);
    m_delete(m, "bgcolor");
  }
  else
    if (m->notrans)
      res->colorbg=parse_color("white");

  res->drawtype="linear";

  switch(res->type[0..3]) {
   case "pie":
   case "piec":
     res->type = "pie";
     res->subtype="pie";
     res->drawtype = "2D";
     break;
   case "bar":
   case "bars":
   case "barc":
     res->type = "bars";
     res->subtype = "box";
     m_delete( res, "drawtype" );
     break;
   case "line":
     res->type = "bars";
     res->subtype = "line";
     break;
   case "norm":
     res->type = "sumbars";
     res->subtype = "norm";
     break;
   case "grap":
     res->type = "graph";
     res->subtype = "line";
     break;
   case "sumb":
     res->type = "sumbars";
     //res->subtype = "";
     break;
   default:
     return syntax("\""+res->type+"\" is an FIX unknown type of diagram\n");
  }

  if(m["3d"])
  {
    res->drawtype = "3D";
    if( lower_case(m["3d"])!="3d" )
      res->dimensionsdepth = (int)m["3d"];
    else
      res->dimensionsdepth = 20;
  }

  parse_html(contents,
	     ([ "xaxis":itag_xaxis,
	        "yaxis":itag_yaxis ]),
	     ([ "data":itag_data,
		"xnames":itag_names,
		"ynames":itag_names,
		"xvalues":itag_values,
		"yvalues":itag_values,
		"colors":itag_colors,
		"legend":itag_legendtext ]),
	     res, id );

  if ( !res->data || !sizeof(res->data))
    return syntax("No data for the diagram");

  res->bg = parse_color(m->bgcolor || id->misc->defines->bg || "white");
  res->fg = parse_color(m->textcolor || id->misc->defines->fg || "black");

  if(m->center) res->center = (int)m->center;
  if(m->eng) res->eng=1;
  if(m->neng) res->neng=1;

  res->format         = (int)m->format || "gif";
  res->encoding       = m->encoding || "iso-8859-1";
  res->fontsize       = (int)m->fontsize || 16;
  res->legendfontsize = (int)m->legendfontsize || res->fontsize;
  res->labelsize      = (int)m->labelsize || res->fontsize;

  if(m->labelcolor) res->labelcolor=parse_color(m->labelcolor || id->misc->defines->fg);
  res->axcolor   = parse_color(m->axcolor || id->misc->defines->fg);
  res->gridcolor = parse_color(m->gridcolor || id->misc->defines->fg);
  res->linewidth = m->linewidth || "2.2";
  res->axwidth   = m->axwidth || "2.2";

  if(m->rotate) res->rotate = m->rotate;
  if(m->grey) res->bw = 1;

  if(m->width) {
    if((int)m->width > query("maxwidth"))
      m->width  = (string)query("maxwidth");
    if((int)m->width < 100)
      m->width  = "100";
  } else if(!res->background)
    m->width = "350";

  if(m->height) {
    if((int)m->height > query("maxheight"))
      m->height = (string)query("maxheight");
    if((int)m->height < 100)
      m->height = "100";
  } else if(!res->background)
    m->height = "250";

  if(!res->background)
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

  if(m->xgridspace) res->xgridspace = (int)m->xgridspace;
  if(m->ygridspace) res->ygridspace = (int)m->ygridspace;

  if (m->turn) res->turn=1;

  m -= diagram_args;

  // Start of res-cleaning
  res->textcolor = res->fg;
  res->bgcolor = res->bg;

  m_delete( res, "voidsep" );

  if (res->xstop)
    if(res->xstart > res->xstop) m_delete( res, "xstart" );

  if (res->ystop)
    if(res->ystart > res->ystop) m_delete( res, "ystart" );

  res->labels = ({ res->xstor, res->ystor, res->xunit, res->yunit });

  if(res->dimensions) res->drawtype = res->dimensions;
  if(res->dimensionsdepth) res["3Ddepth"] = res->dimensionsdepth;
  if(res->ygridspace)  res->yspace = res->ygridspace;
  if(res->xgridspace)  res->xspace = res->xgridspace;
  if(res->orientation) res->orient = res->orientation;
  if((int)res->xstart)  res->xminvalue  = (float)res->xstart;
  if((int)res->xstop)   res->xmaxvalue  = (float)res->xstop;
  if(res->ystart)  res->yminvalue  = (float)res->ystart;
  if(res->ystop)   res->ymaxvalue  = (float)res->ystop;
  if(res->colors)  res->datacolors = res->colors;
  if(res->xvalues) res->values_for_xnames = res->xvalues;
  if(res->yvalues) res->values_for_ynames = res->yvalues;
  if((int)res->linewidth) res->graphlinewidth = (float)res->linewidth;
  else m_delete( res, "linewidth" );
  if((int)res->axwidth) res->linewidth  = (float)res->axwidth;

  res -= shuffle_args;

  if ((res->name)&&(!m->alt))
    m->alt=res->name;

  if (res->turn)
  {
    int t;
    t=m->width;
    m->width=m->height;
    m->height=t;
  }
#ifdef BG_DEBUG
  };
#endif

  string ext = "";
  if(query("ext")) ext="."+res->format;

  m->src = query_internal_location() + image_cache->store( res,id )+ext;

  if( mapping size = image_cache->metadata( m, id, 1 ) )
  {
    // image in cache (1 above prevents generation on-the-fly)
    m->width = size->xsize;
    m->height = size->ysize;
  }

  if(m->noxml)
    m_delete(m, "noxml");
  else
    m["/"]="/";

#ifdef BG_DEBUG
  if(id->prestate->debug)
    return(sprintf("<pre>Timers: %O\n</pre>", bg_timers) + make_tag("img", m));
#endif

  return make_tag("img", m);
}

int|object PPM(string fname, object id)
{
  return roxen->load_image( fname, id );
}

mapping find_internal(string f, object id)
{
  if( strlen(f)>4 && query("ext") && f[-4]=='.') // Remove .ext
    f = f[..strlen(f)-5];
  return image_cache->http_file_answer( f, id );
}

mixed draw_callback(mapping args, object id)
{
  if(id->prestate->debug)
    return http_string_answer( sprintf("<pre>%O\n", args) );

  array back=0;
  if (args->bgcolor)
    back = args->bgcolor;

  if(args->background)
  {
    m_delete( args, "bgcolor" );
    args->image = PPM(args->background, id);

    /* Image was not found or broken */
    if(args->image == 1)
    {
      args->image=get_font(0, 24, 0, 0,"left", 0, 0);
      if (!(args->image))
	throw(({"Missing font or similar error!\n", backtrace() }));
      args->image=args->image->
	write("The file was", "not found ",
	      "or was not a","jpeg-, gif- or","pnm-picture.");
    }
  } else if(args->tonedbox) {
    m_delete( args, "bgcolor" );
    args->image = Image.Image(args->xsize, args->ysize)->
      tuned_box(0, 0, args->xsize, args->ysize, args->tonedbox);
  }
  else if (args->colorbg)
  {
    back=0; //args->bgcolor;
    m_delete( args, "bgcolor" );
    args->image = Image.Image(args->xsize, args->ysize, @args->colorbg);
  }

  Image.Image img;

#ifdef BG_DEBUG
  bg_timers->drawing = gauge {
#endif

  switch(args->type) {
   case "pie":
     img = create_pie(args)["image"];
     break;
   case "bars":
   case "sumbars":
     img = create_bars(args)["image"];
     break;
   case "graph":
     img = create_graph(args)["image"];
     break;
  }
#ifdef BG_DEBUG
  };
  if (args->bg_timers)
    bg_timers+=args->bg_timers;
#endif
  if (args->turn)
    img=img->rotate_ccw();
	
#ifdef BG_DEBUG
  if(id->prestate->debug)
    werror("Timers: %O\n", bg_timers);
#endif

  return img;
}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
"diagram":({ #"<desc cont><short hide>
 The <diagram> tag is used to draw pie, bar, or line charts as well as
 graphs. </short>The <tag>diagram</tag> tag is used to draw pie, bar,
 or line charts as well as graphs. It is quite complex with six
 internal tags. </desc>

<attr name='3d' value='number'>
 Draws a pie-chart on top of a cylinder, takes the height in pixels of the
 cylinder as argument.
 </attr>

 <attr name='background' value='path'>
 Use an image as background. Valid types are gif-, jpeg- or pnm-images.
 </attr>

 <attr name='bgcolor' value='color'>
 Set the background color to use for anti-aliasing.
 </attr>

 <attr name='center' value='number'>
 Centers a pie chart around the <i>n</i>th slice.
 </attr>

 <attr name='eng'>
 Write numbers in engineering fashion, i.e like 1.2M.
 </attr>

 <attr name='font' value='font'>
 Use this font. Can be overridden in the <tag>legend</tag>,
 <tag>xaxis</tag>, <tag>yaxis</tag> and <tag>names</tag> tags.
 </attr>

 <attr name='fontsize' value='number'>
 Height of the text in pixels.
 </attr>

 <attr name='height' value='number'>
 Height of the diagram in pixels. Will not have effect below 100.
 </attr>

 <attr name='horgrid'>
 Draw a horizontal grid.
 </attr>

 <attr name='labelcolor' value='color'>
 Sets the color for the labels of the axis.
 </attr>

 <attr name='legendfontsize' value='number'>
 Height of the legend text. <att>fontsize</att> is used if this is undefined.
 </attr>

 <attr name='name' value='string'>
 Write a name at the top of the diagram.
 </attr>

 <attr name='namecolor' value='color'>
 Set the color of the name, by default <att>textcolor</att>.
 </attr>

 <attr name='namefont' value='font'>
 Set the font for the diagram name.
 </attr>

 <attr name='namesize' value='number'>
 Sets the height of the name, by default <att>fontsize</att>.
 </attr>

 <attr name='neng'>
 As eng, but 0.1-1.0 is written as 0.xxx.
 </attr>

 <attr name='notrans'>
 Make bgcolor opaque.
 </attr>

 <attr name='rotate' value='degree'>
 Rotate a pie chart this much.
 </attr>

 <attr name='textcolor'>
 Set the color for all text.
 </attr>

 <attr name='tonedbox' value='color1,color2,color3,color4'>
 Create a background shading between the colors assigned to each of the
 four corners.
 </attr>

 <attr name='turn'>
 Turn the diagram 90 degrees. Useful when printing large diagrams.
 </attr>

 <attr name='type' value='sumbars|normsum|line|bar|pie|graph'>
  The type of diagram. This attribute is required.
 </attr>

 <attr name='vertgrid'>
 Draw vertical grid lines.
 </attr>

 <attr name='voidsep' value='string'>
 Change the string that means no such value, by default 'VOID'.
 </attr>

 <attr name='width' value='number'>
 Set the width of the diagram in pixels. Values below 100 will not take effect.  This attribute is required.
 </attr>

 <attr name='xgridspace' value='number'>
 Set the space between two vertical grid lines. The unit is the same as
 for the data.
 </attr>

 <attr name='ygridspace'>
 Set the space between two horizontal grid lines. The unit is the same
 as for the data.
 </attr>

 <p>Regular <tag>img</tag> arguments will be passed on to the generated
 <tag>img</tag> tag.</p>",



	     (["data":#"<desc cont><short>This tag contains the data the diagram is to visualize </short> It is required that the data is presented to the tag in a tabular or newline separated form.</desc>

 <attr name='form' value='column|row'>
  How to interpret the tabular data, by default row.
  </attr>

 <attr name='lineseparator' value='string'>
 Use the specified string as lineseparator instead of newline.
 </attr>

 <attr name='noparse'>
 Do not parse the contents by the RXML parser, before data extraction is done.
 </attr>

 <attr name='separator' value='string'>
 Set the separator between elements, by default tab.
 </attr>

 <attr name='xnames' value='number'>
 If given, treat the first row or column as names for the data to
 come. If <att>xnames</att> is set to a number N, N lines or columns
 are used. The name will be written along the pie slice or under the
 bar.
 </attr>

 <attr name='xnamesvert'>
 Write the <att>xnames</att> vertically.
 </attr>",


	       "colors":#"<desc cont><short>This tag sets the colors for different pie slices, bars or lines.</short> The colors are presented to the tag in a tab separated list.</desc>

 <attr name='separator' value='string'>
 Set the separator between colors, by default tab.
 </attr>",

	       "legend":#"<desc cont><short>A separate legend with description of the different pie slices, bars or lines.</short>The titles are presented to the tag in a tab separated list.</desc>

 <attr name='separator' value='string'>
 Set the separator between legends, by default tab.
 </attr>",

	       "xaxis":#"<desc tag><short>Used for specifying the quantity and unit of the x-axis, as well as its scale, in a graph.</short> The <tag>yaxis</tag> tag uses the same attributes.</desc>

 <attr name='start' value='float'>
 Limit the start of the diagram at this value. If set to <i>min</i> the
 axis starts at the lowest value in the data.
 </attr>

 <attr name='stop' value='float'>
 Limit the end of the diagram at this value.
 </attr>

 <attr name='quantity' value='string'>
 Set the name of the quantity of this axis.
 </attr>

 <attr name='unit' value='string'>
 Set the name of the unit of this axis.
 </attr>",

	       "yaxis":#"<desc tag><short>
 Used for specifying the quantity and unit of the y-axis, as well as
 its scale, in a graph or line chart.</short>Se the <tag>xaxis</tag>
 tag for a complete list of attributes.</desc>",

	       "xnames":#"<desc cont><short>
 Separate tag that can be used to give names to put along the pie
 slices or under the bars.</short> The datanames are presented to the
 tag as a tab separated list. This tag is useful when the diagram is
 dynamically created. The <tag>ynames</tag> tag uses the same
 attributes.</desc>

 <attr name='separator' value='string'>
 Set the separator between names, by default tab.
 </attr>

 <attr name='orient' value='vert|horiz'>
 How to write names, vertically or horizontally.
 </attr>",

"ynames":#"<desc cont><short>
 Separate tag that can be used to give names to put along the pie
 slices or under the bars.</short> The datanames are presented to the
 tag as a tab separated list. This tag is useful when the diagram is
 dynamically created. See the <tag>xnames</tag> tag for a complete list of
 attributes.</desc>"
	     ])

}),

    ]);
#endif
