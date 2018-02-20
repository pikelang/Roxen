/* This is a roxen module. Copyright © 1999 - 2009, Roxen IS.
 *
 * Draws diagrams pleasing to the eye.
 *
 * Made by Peter Bortas <peter@roxen.com> and Henrik Wallin <hedda@roxen.com>
 * in October 1997
 */

#include <module.h>
#include <roxen.h>

inherit "module";

constant cvs_version = "$Id$";
constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Graphics: Business graphics";
constant module_doc  = 
#"Provides the <tt>&lt;diagram&gt;</tt> tag that draws bar charts, line charts,
pie charts or graphs.";

#define VOIDSYMBOL "\n"
#define SEP "\t"

#ifdef BG_DEBUG
mapping bg_timers = ([]);
#endif

//FIXME (Not always VOID!?!)
#define VOIDCODE \
  do { voidsep = m->voidseparator||m->voidsep||res->voidsep||"VOID"; } while(0)

int loaded;


roxen.ImageCache image_cache;
function verify_font;

void start(int num, object configuration)
{
  if (!loaded) loaded = 1; 
  image_cache = roxen.ImageCache( "diagram", draw_callback );
  verify_font = roxen->fonts->verify_font;
}

void stop()
{
  /* Reload Pie, Bars and Graph */
  //This is not needed since Graphics.Graph is used
#ifdef MODULE_DEBUG
  mapping progs = master()->programs;
  foreach(glob(combine_path(__FILE__,"../*"), indices(progs)),
          string to_delete)
    m_delete(progs, to_delete);
#endif
  destruct(image_cache);
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

string status() {
  array s=image_cache->status();
  return sprintf("<b>Images in cache:</b> %d images<br />\n<b>Cache size:</b> %s",
		 s[0], Roxen.sizetostring(s[1]));
}

mapping(string:function) query_action_buttons() {
  return ([ "Clear Cache":flush_cache ]);
}

void flush_cache() {
  image_cache->flush();
}

string itag_xaxis(string tag, mapping m, mapping res, object id)
{
#ifdef BG_DEBUG
  bg_timers->xaxis = gauge {
#endif
  int l=query("maxstringlength")-1;

  if(!m->noparse)
    foreach(indices(m), string attr)
      m[attr] = Roxen.parse_rxml( m[attr], id );

  res->xaxisfont = verify_font( m->font || m->nfont || res->xaxisfont,
				res->labelsize );

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

string itag_yaxis(string tag, mapping m, mapping res, object id)
{
#ifdef BG_DEBUG
  bg_timers->yaxis = gauge {
#endif
  int l=query("maxstringlength")-1;

  if(!m->noparse)
    foreach(indices(m), string attr)
      m[attr] = Roxen.parse_rxml( m[attr], id );

  res->yaxisfont = verify_font( m->font || m->nfont || res->yaxisfont,
				res->labelsize );

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
    contents = Roxen.parse_rxml( contents, id );

  string sep = m->separator || SEP;

  string voidsep;
  VOIDCODE;

  array foo;

  if( contents-" " != "" )
  {
    if(tag=="xnames")
    {
      res->xnamesfont = verify_font( m->font || m->nfont || res->xnamesfont,
				     res->fontsize );

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

      res->ynamesfont = verify_font( m->font || m->nfont || res->ynamesfont,
				     res->fontsize );
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
    contents = Roxen.parse_rxml( contents, id );

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
    contents = Roxen.parse_rxml( contents, id );

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
    contents = Roxen.parse_rxml( contents, id );

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
    contents = Roxen.parse_rxml( contents, id );

  string sep = m->separator || SEP;

  res->legendfont = verify_font( m->font || m->nfont || res->legendfont,
				 res->legendfontsize );

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
  object o=Crypto.SHA1();
  string data=encode_value(in);
  o->update(data);
  string out=replace(http_encode_string(MIME.encode_base64(o->digest(),1)),
		     "/", "$");
*/

constant _diagram_args =
({ "xgridspace", "ygridspace", "horgrid", "size", "type", "3d", "do3d",
   "templatefontsize", "fontsize", "tone", "background","colorbg", "subtype",
   "dimensions", "dimensionsdepth", "xsize", "ysize", "fg", "bg",
   "orientation", "xstart", "xstop", "ystart", "ystop", "data", "colors",
   "xnames", "xvalues", "ynames", "yvalues", "axcolor", "gridcolor",
   "gridwidth", "vertgrid", "labels", "labelsize", "legendfontsize",
   "legendfont",
   "legend_texts", "labelcolor", "axwidth", "linewidth", "center",
   "rotate", "image", "bw", "eng", "neng", "xmin", "ymin", "turn", "notrans",
   "colortable_cache", "tonedbox", "name","color-scheme" });
mapping diagram_args = mkmapping(_diagram_args,_diagram_args);

constant _shuffle_args =
({ "dimensions", "dimensionsdepth", "ygridspace", "xgridspace",
   "xstart", "xstop", "ystart", "ystop", "colors", "autocolors","xvalues", "yvalues",
   "axwidth", "xstor", "ystor", "xunit", "yunit", "fg", "bg", "voidsep" });
mapping shuffle_args = mkmapping( _shuffle_args, _shuffle_args );

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
    res->namecolor=parse_color(m->namecolor||id->misc->defines->fgcolor);
    if(m->namefont)
      res->namefont = verify_font( m->namefont, res->namesize );
  }

  res->voidsep = m->voidseparator || m->voidsep;

  res->fontsize       = (int)m->fontsize || 16;
  res->legendfontsize = (int)m->legendfontsize || res->fontsize;
  res->labelsize      = (int)m->labelsize || res->fontsize;

  res->font = verify_font( m->font || m->nfont, res->fontsize );

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

  if (m->notrans) {
    res->colorbg=parse_color(m->bgcolor||m->colorbg||id->misc->defines->bgcolor||"white");
    m_delete(m, "bgcolor");
    res->notrans=1;
  }

  res->drawtype="linear";

  //Allow shortened names for some reason:
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
     res->subtype = "box";  //Not needed, I think
     m_delete( res, "drawtype" );
     break;
     case "line": 
       res->type = "line";
       break;
  case "norm":
    res->type = "norm";
    break;
   case "grap":
     res->type = "graph";
     res->subtype = "line";
     break;
   case "sumb":
     res->type = "sumbars";
     break;
   default:
     return syntax("\""+res->type+"\" is an FIX unknown type of diagram\n");
  }

  if(string val = (m["do3d"] || m["3d"]))
  {
    res->drawtype = "3D";
    if( (!m["3d"] || lower_case(m["3d"])!="3d") &&
	(!m["do3d"] || lower_case(m["do3d"])!="do3d") )
      res->dimensionsdepth = (int)val;
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

  res->bg = parse_color(m->bgcolor || id->misc->defines->bgcolor || "white");
  res->fg = parse_color(m->textcolor || id->misc->defines->fgcolor || "black");

  switch((string)(m["color-scheme"]||"")) {
  case "1":
    res->autocolors = allocate(sizeof(res->data));
#define NUM_AUTOCOLORS 8
    for(int i=0; i<sizeof(res->autocolors); i++)
      res->autocolors[i]=Colors.hsv_to_rgb((int)(256.0/(NUM_AUTOCOLORS+1) * (i%NUM_AUTOCOLORS)) ,255, 255 - (int)(((float)(i/NUM_AUTOCOLORS) / (float)(sizeof(res->autocolors)/NUM_AUTOCOLORS)) * 160) );
    break;
  }

  if(m->center) res->center = (int)m->center;
  if(m->eng) res->eng=1;
  if(m->neng) res->neng=1;

  res->quant          = (int)m->quant || (m->tonedbox?128:32);
#if constant(Image.GIF) && constant(Image.GIF.encode)
  res->format         = m->format || "gif";
#else
  res->format         = m->format || "jpg";
#endif
  res->encoding       = m->encoding || "iso-8859-1";

  if(m->labelcolor) res->labelcolor=parse_color(m->labelcolor || id->misc->defines->fgcolor || "black");
  res->axcolor   = parse_color(m->axcolor || id->misc->defines->fgcolor || "black");
  res->gridcolor = parse_color(m->gridcolor || id->misc->defines->fgcolor || "black");
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
  else if(res->autocolors)  res->datacolors = res->autocolors;
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

  int timeout = Roxen.timeout_dequantifier(m);

  m->src = query_absolute_internal_location(id) +
    image_cache->store( res, id, timeout )+ext;

  if( mapping size = image_cache->metadata( m, id, 1, timeout ) )
  {
    // image in cache (1 above prevents generation on-the-fly)
    m->width = size->xsize;
    m->height = size->ysize;
  }

  int xml=1;
  if(m->noxml) {
    m_delete(m, "noxml");
    xml=0;
  }

#ifdef BG_DEBUG
  if(id->prestate->debug)
    return(sprintf("<pre>Timers: %O\n</pre>", bg_timers) + make_tag("img", m, xml));
#endif

  return Roxen.make_tag("img", m - ({ "format" }), xml);
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
    return Roxen.http_string_answer( sprintf("<pre>%O\n", args) );

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
      args->image=get_font(0, 24, 0, 0,"left", 0.0, 0.0);
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

  foreach( ({ "font", "namefont", "legendfont", "xaxisfont", "yaxisfont",
	      "xnamesfont", "ynamesfont" }), string font)
    if(args[font]) args[font] = get_font(args[font], 32, 0, 0, "left", 0.0, 0.0);

  Image.Image img;
  
#ifdef BG_DEBUG
  bg_timers->drawing = gauge {
#endif

  switch(args->type) {
   case "pie":
     img = Graphics.Graph.pie(args);
     break;
   case "bars":
     img = Graphics.Graph.bars(args);
     break;
   case "sumbars":
     img = Graphics.Graph.sumbars(args);
     break;
   case "norm":
     img = Graphics.Graph.norm(args);
     break;
   case "line":
     img = Graphics.Graph.line(args);
     break;
   case "graph":
     img = Graphics.Graph.graph(args);
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
    report_debug("Timers: %O\n", bg_timers);
#endif

  if (!args->notrans)
    {
      Image.Image alpha;
      if (args->bgcolor)
	{
	  //Make an alpha-image with everything in
	  //bgcolor black and the rest white.
	  alpha=Image.Image(img->xsize(), img->ysize(), @args->bgcolor);
	  alpha=((img-alpha)+(alpha-img));
	  alpha=alpha->threshold(4);
	  }
      else
	alpha=img->threshold(4);
      return ([ "img":img, "alpha": alpha]);

    }
  return img;
}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
"diagram":({ #"<desc type='cont'><p><short>
 The <tag>diagram</tag> tag is used to draw pie, bar, or line charts
 as well as graphs.</short> It is quite complex with six internal
 tags. It is possible to pass attributes, such as the alt attribute, 
 to the resulting tag by including them in the diagram tag.</p>
</desc>

<attr name='do3d' value='number'><p>
 Draws a pie-chart on top of a cylinder, takes the height in pixels of the
 cylinder as argument.</p>
 </attr>

 <attr name='background' value='path'><p>
 Use an image as background. Valid types are gif-, jpeg- or pnm-images.</p>
 </attr>

 <attr name='bgcolor' value='color'><p>
 Set the background color to use for anti-aliasing.</p>
 </attr>

 <attr name='center' value='number'><p>
 Centers a pie chart around the <i>n</i>th slice.</p>
 </attr>

 <attr name='eng'><p>
 Write numbers in engineering fashion, i.e like 1.2M.</p>
 </attr>

 <attr name='font' value='font'><p>
 Use this font. Can be overridden in the <tag>legend</tag>,
 <tag>xaxis</tag>, <tag>yaxis</tag> and <tag>names</tag> tags.</p>
 </attr>

 <attr name='fontsize' value='number'><p>
 Height of the text in pixels.</p>
 </attr>

 <attr name='height' value='number'><p>
 Height of the diagram in pixels. Will not have effect below 100.</p>
 </attr>

 <attr name='horgrid'><p>
 Draw a horizontal grid.</p>
 </attr>

 <attr name='labelcolor' value='color'><p>
 Sets the color for the labels of the axis.</p>
 </attr>

 <attr name='legendfontsize' value='number'><p>
 Height of the legend text. <att>fontsize</att> is used if this is
 undefined.</p>
 </attr>

 <attr name='name' value='string'><p>
 Write a name at the top of the diagram.</p>
 </attr>

 <attr name='namecolor' value='color' default='textcolor'><p>
 Set the color of the name, by default set by the <att>textcolor</att>
 attribute.</p>
 </attr>

 <attr name='namefont' value='font'><p>
 Set the font for the diagram name.</p>
 </attr>

 <attr name='namesize' value='number'><p>
 Sets the height of the name, by default <att>fontsize</att>.</p>
 </attr>

 <attr name='neng'><p>
 As eng, but 0.1-1.0 is written as 0.xxx.</p>
 </attr>

 <attr name='notrans'><p>
 Make bgcolor opaque.</p>
 </attr>

 <attr name='rotate' value='degree'><p>
 Rotate a pie chart this much.</p>
 </attr>

 <attr name='textcolor'><p>
 Set the color for all text.</p>
 </attr>

 <attr name='tonedbox' value='color1,color2,color3,color4'><p>
 Create a background shading between the colors assigned to each of the
 four corners.</p>
 </attr>

 <attr name='quant' value='number'><p>
 The number of colors that the result image should have. Default is 128 if
 tonedbox is used and 32 otherwise.</p>
 </attr>

 <attr name='turn'><p>
 Turn the diagram 90 degrees. Useful when printing large diagrams.</p>
 </attr>

 <attr name='type' value='sumbars|normsum|line|bar|pie|graph' required='required'><p>
  The type of diagram. This attribute is required.</p>
 </attr>

 <attr name='vertgrid'><p>
 Draw vertical grid lines.</p>
 </attr>

 <attr name='voidsep' value='string'><p>
 Change the string that means no such value, by default 'VOID'.</p>
 </attr>

 <attr name='width' value='number' required='required'><p>
 Set the width of the diagram in pixels. Values below 100 will not take effect.  This attribute is required.</p>
 </attr>

 <attr name='xgridspace' value='number'><p>
 Set the space between two vertical grid lines. The unit is the same as
 for the data.</p>
 </attr>

 <attr name='ygridspace'><p>
 Set the space between two horizontal grid lines. The unit is the same
 as for the data.</p>
 </attr>

 <p>Regular <tag>img</tag> arguments will be passed on to the generated
 <tag>img</tag> tag.</p>

<h1>Timeout</h1>

<p>The generated image will by default never expire, but
in some circumstances it may be pertinent to limit the
time the image and its associated data is kept. Its
possible to set an (advisory) timeout on the image data
using the following attributes.</p>

<attr name='unix-time' value='number'><p>
Set the base expiry time to this absolute time.</p><p>
If left out, the other attributes are relative to current time.</p>
</attr>

<attr name='years' value='number'><p>
Add this number of years to the time this entry is valid.</p>
</attr>

<attr name='months' value='number'><p>
Add this number of months to the time this entry is valid.</p>
</attr>

<attr name='weeks' value='number'><p>
Add this number of weeks to the time this entry is valid.</p>
</attr>

<attr name='days' value='number'><p>
Add this number of days to the time this entry is valid.</p>
</attr>

<attr name='hours' value='number'><p>
Add this number of hours to the time this entry is valid.</p>
</attr>

<attr name='beats' value='number'><p>
Add this number of beats to the time this entry is valid.</p>
</attr>

<attr name='minutes' value='number'><p>
Add this number of minutes to the time this entry is valid.</p>
</attr>

<attr name='seconds' value='number'><p>
Add this number of seconds to the time this entry is valid.</p>
</attr>",

//-------------------------------------------------------------------------

	     ([


"data":#"<desc type='cont'><p><short>
 This tag contains the data the diagram is to visualize </short> It is
 required that the data is presented to the tag in a tabular or
 newline separated form.</p>
</desc>

 <attr name='form' value='column|row'><p>
  How to interpret the tabular data, by default row.</p>
  </attr>

 <attr name='lineseparator' value='string'><p>
 Use the specified string as lineseparator instead of newline.</p>
 </attr>

 <attr name='noparse'><p>
 Do not parse the contents by the RXML parser, before data extraction is done.</p>
 </attr>

 <attr name='separator' value='string'><p>
 Set the separator between elements, by default tab.</p>
 </attr>

 <attr name='xnames' value='number'><p>
 If given, treat the first row or column as names for the data to
 come. If <att>xnames</att> is set to a number N, N lines or columns
 are used. The name will be written along the pie slice or under the
 bar.</p>
 </attr>

 <attr name='xnamesvert'><p>
 Write the <att>xnames</att> vertically.</p>
 </attr>",

//-----------------------------------------------------------------------

	       "colors":#"<desc type='cont'><p><short>
 This tag sets the colors for different pie slices, bars or
 lines.</short> The colors are presented to the tag in a tab separated
 list.</p>
</desc>

 <attr name='separator' value='string'><p>
 Set the separator between colors, by default tab.</p>
 </attr>",

//------------------------------------------------------------------------

	       "legend":#"<desc type='cont'><p><short>
 A separate legend with description of the different pie slices, bars
 or lines.</short>The titles are presented to the tag in a tab
 separated list.</p>
</desc>

 <attr name='separator' value='string'><p>
 Set the separator between legends, by default tab.</p>
 </attr>",

//-------------------------------------------------------------------------

	       "xaxis":#"<desc tag='tag'><p><short>
 Used for specifying the quantity and unit of the x-axis, as well as
 its scale, in a graph.</short> The <tag>yaxis</tag> tag uses the same
 attributes.</p>
</desc>

 <attr name='start' value='float'><p>
 Limit the start of the diagram at this value. If set to <i>min</i> the
 axis starts at the lowest value in the data.</p>
 </attr>

 <attr name='stop' value='float'><p>
 Limit the end of the diagram at this value.</p>
 </attr>

 <attr name='quantity' value='string'><p>
 Set the name of the quantity of this axis.</p>
 </attr>

 <attr name='unit' value='string'><p>
 Set the name of the unit of this axis.</p>
 </attr>",

//------------------------------------------------------------------------

	       "yaxis":#"<desc tag='tag'><p><short>
 Used for specifying the quantity and unit of the y-axis, as well as
 its scale, in a graph or line chart.</short>Se the <tag>xaxis</tag>
 tag for a complete list of attributes.</p>
</desc>",

//------------------------------------------------------------------------

	       "xnames":#"<desc type='cont'><p><short>
 Separate tag that can be used to give names to put along the pie
 slices or under the bars.</short> The datanames are presented to the
 tag as a tab separated list. This tag is useful when the diagram is
 dynamically created. The <tag>ynames</tag> tag uses the same
 attributes.</p>
</desc>

 <attr name='separator' value='string' default='tab'><p>
 Set the separator between names, by default tab.</p>
 </attr>

 <attr name='orient' value='vert|horiz'><p>
 How to write names, vertically or horizontally.</p>
 </attr>",

//-------------------------------------------------------------------------

"ynames":#"<desc type='cont'><p><short>
 Separate tag that can be used to give names to put along the pie
 slices or under the bars.</short> The datanames are presented to the
 tag as a tab separated list. This tag is useful when the diagram is
 dynamically created. See the <tag>xnames</tag> tag for a complete
 list of attributes.</p>

<p>Some examples:</p>

 <ex>
  <diagram type='pie' width='200' height='200'  name='Population'
  tonedbox='lightblue,lightblue,white,white'>
    <data separator=','>5305048,5137269,4399993,8865051</data>
    <legend separator=','>Denmark,Finland,Norway,Sweden</legend>
 </diagram>
 </ex>

 <ex>
 <diagram type='bar' width='200' height='250' name='Population'
 horgrid='' tonedbox='lightblue,lightblue,white,white'>
   <data xnamesvert='' xnames='' separator=','>
     Denmark,Finland,Norway,Sweden
     5305048,5137269,4399993,8865051
   </data>
 </diagram>
 </ex>

 <ex>
 <diagram type='bar' width='200' height='250'
 name='Age structure' horgrid=''
 tonedbox='lightblue,lightblue,white,white'>
   <data xnamesvert='' xnames='' form='column'
   separator=','>
     Denmark,951175,3556339,797534
     Finland,966593,3424107,746569
     Norway,857952,2846030,696011
     Sweden,1654180,5660410,1550461
   </data>
   <legend separator=','>
     0-14,15-64,65-
   </legend>
 </diagram>
 </ex>

 <ex>
 <diagram type='sumbar' width='200' height='250'
 name='Land Use' horgrid=''
 tonedbox='lightblue,lightblue,white,white'>
   <data xnamesvert='' xnames='' form='column'
   separator=','>
     Denmark,27300,4200,10500
     Finland,24400,231800,48800
     Norway,9240,83160,215600
     Sweden,32880,279480,102750
   </data>
   <legend separator=','>
     Arable,Forests,Other
   </legend>
   <yaxis quantity='area'/>
   <yaxis unit='km^2'/>
 </diagram>
 </ex>

 <ex>
 <diagram type='normsumbar' width='200' height='250'
 name='Land Use' horgrid=''
 tonedbox='lightblue,lightblue,white,white'>
   <data xnamesvert='' xnames='' form='column'
   separator=','>
     Denmark,27300,4200,10500
     Finland,24400,231800,48800
     Norway,9240,83160,215600
     Sweden,32880,279480,102750
   </data>
   <legend separator=','>
     Arable,Forests,Other
   </legend>
   <yaxis quantity='%'/>
 </diagram>
 </ex>

 <ex>
 <diagram type='line' width='200' height='250'
 name='Exchange Rates' horgrid=''
 tonedbox='lightblue,lightblue,white,white'>
   <data form='row' separator=','
   xnamesvert='' xnames=''>
     1992,1993,1994,1995,1996
     0.166,0.154,0.157,0.179,0.172
     0.223,0.175,0.191,0.229,0.218
     0.161,0.141,0.142,0.158,0.155
     0.172,0.128,0.130,0.149,0.140</data>
   <yaxis start='0.09' stop='0.25'/>
   <legend separator=','>
     Danish kroner (DKr),
     Markkaa (FMk),
     Norwegian kronor (NKr),
     Swedish kronor (SKr)
   </legend>
   <xaxis quantity='year'/>
   <yaxis quantity='US$'/>
 </diagram>
 </ex>
</desc>"
	     ])

}),

    ]);
#endif
