// This is a roxen module. Copyright © 1996 - 2000, Idonex AB.
//

constant cvs_version="$Id: graphic_text.pike,v 1.206 2000/02/29 15:02:26 nilsson Exp $";

#include <module.h>
inherit "module";
inherit "roxenlib";


// ------------------- Module registration ---------------------

constant module_type   = MODULE_PARSER;
constant module_name   = "Graphics text";
constant module_doc    = "Generates graphical texts.";
constant thread_safe   = 1;

void create()
{
  defvar("colorparse", 1, "Parse tags for document colors", TYPE_FLAG,
	 "If set, parse the specified tags for document colors.");

  defvar("deflen", 300, "Default maximum text-length", TYPE_INT|VAR_MORE,
	 "The module will, per default, not try to render texts "
	 "longer than this. This is a safeguard for things like "
	 "&lt;gh1&gt;&lt;/gh&gt;, which would otherwise parse the"
	 " whole document. This can be overrided with maxlen=... in the "
	 "tag.");

  defvar("ext", 0, "Append .fmt (gif, jpeg etc) to all images",
	 TYPE_FLAG|VAR_MORE,
	 "Append .gif, .png, .gif etc to all images made by gtext. "
         "Normally this will only waste bandwidth");
}

TAGDOCUMENTATION;
#ifdef manual
constant gtextargs="";
constant tagdoc=(["gtext":"<desc cont></desc>"+gtextargs,
		  "gtext-id":"<desc tag></desc>"+gtextargs,
		  "anfang":"<desc cont></desc>"+gtextargs,
		  "gtext-url":"<desc cont></desc>"+gtextargs,
		  "gh":"<desc cont></desc>"+gtextargs,
		  "gh1":"<desc cont></desc>"+gtextargs,
		  "gh2":"<desc cont></desc>"+gtextargs,
		  "gh3":"<desc cont></desc>"+gtextargs,
		  "gh4":"<desc cont></desc>"+gtextargs,
		  "gh5":"<desc cont></desc>"+gtextargs,
		  "gh6":"<desc cont></desc>"+gtextargs]);
#endif


// -------------------- Image cache functions --------------------

roxen.ImageCache image_cache;

string status() {
  array s=image_cache->status();
  return sprintf("<b>Images in cache:</b> %d images<br>\n<b>Cache size:</b> %s",
		 s[0]/2, sizetostring(s[1]));
}

void start(int num, Configuration conf)
{
  image_cache = roxen.ImageCache( "gtext", draw_callback );
  roxen.dump( "etc/modules/GText.pmod" );
  if(query("colorparse")) module_dependencies(conf, ({ "wiretap" }) );
}

constant nbsp = iso88591["&nbsp;"];
constant replace_from = indices( iso88591 )+ ({"&ss;","&lt;","&gt;","&amp;",});
constant replace_to   = values( iso88591 ) + ({ nbsp, "<", ">", "&", });

#define simplify_text( from ) replace(from,replace_from,replace_to)

mixed draw_callback(mapping args, string text, RequestID id)
{
  array data;
  Image.Font font;
  Image.Image img;

  if( objectp( text ) )
  {
    if( !args->text )
      error("Failed miserably to find a text to draw. That's not"
	    " good.\n");
    id = (object)text;
    text = args->text;
  }

  if(!args->verbatim) // typographically correct...
  {
    text = replace(text, nbsp, " ");
    text = simplify_text( text );
    string res="",nspace="",cspace="";
    foreach(text/"\n", string line)
    {
      cspace="";
      nspace="";
      foreach(line/" ", string word)
      {
        string nonum;
        if(strlen(word) &&
           (nonum = replace(word,
                            ({"1","2","3","4","5","6","7","8","9","0","."}),
                            ({"","","","","","","","","","",""}))) == "") {
          cspace=nbsp+nbsp;
          if((strlen(word)-strlen(nonum)<strlen(word)/2) &&
             (upper_case(word) == word))
            word=((word/"")*nbsp);
        }
        else if(cspace!="")
          cspace=" ";

        res+=(nspace==cspace?nspace:" ")+word;

        if(cspace!="")
          nspace=cspace;
        else
          nspace=" ";
      }
      res+="\n";
    }
    text=replace(res[..strlen(res)-2], ({"!","?",": "}),({ nbsp+"!",nbsp+"?",nbsp+": "}));
    text=replace(replace(replace(text,({". ",". "+nbsp}),
                                 ({"\000","\001"})),".","."+nbsp+nbsp),
                 ({"\000","\001"}),({". ","."+nbsp}));
  }

  if( args->afont )
    font = resolve_font((args->afont||args->font)+" "+(args->font_size||32));
  else
  {
    int bold=0, italic=0;
    if(args->nfont) args->font = args->nfont;
    if(args->bold) bold=1;
    if(args->light) bold=-1;
    if(args->black) bold=2;
    if(args->italic) italic=1;
    font = get_font(args->font||"default",
                    (int)(args->font_size||args["font-size"])||32,
                    bold,
                    italic,
                    lower_case(args->talign||"left"),
                    (float)args->xpad,
                    (float)args->ypad);
  }
  if(!font)
    font = resolve_font(0);

  if (!font)
    error("gtext: No font (tried "+
          (args->afont||args->font||args->nfont)+ ")!\n");

  // Fonts and such are now initialized.
  img = GText.make_text_image(args, font, text, id);

  // Now we have the image in 'img'.

  if( !args->scroll && !args->fadein )
  {
    if(!args->notrans)
    {
      array (int) bgcolor = parse_color(args->bgcolor);
      Image.Image alpha;
      alpha = img->distancesq( @bgcolor );
      alpha->gamma( 8 );
      return ([ "img":img, "alpha":alpha ]);
    }
    return img;
  }

  if(args->fadein)
  {
    int amount=2, steps=10, delay=10, initialdelay=0, ox;
    string res = img->gif_begin();
    sscanf(args->fadein,"%d,%d,%d,%d", amount, steps, delay, initialdelay);
    if(initialdelay)
    {
      Image.Image foo=Image.Image(img->xsize(),img->ysize(),@parse_color(args->bgcolor));
      res += foo->gif_add(0,0,initialdelay);
    }
    for(int i = 0; i<(steps-1); i++)
    {
      Image.Image foo=img->clone();
      foo = foo->apply_matrix(GText.make_matrix(( (int)((steps-i)*amount))));
      res += foo->gif_add(0,0,delay);
    }
    res += img->gif_add(0,0,delay);
    res += img->gif_end();
    data = ({ res, ({ img->xsize(), img->ysize() }) });
  }
  else
  {
    int len=100, steps=30, delay=5, ox;
    string res = img->gif_begin() + img->gif_netscape_loop();
    sscanf(args->scroll, "%d,%d,%d", len, steps, delay);
    img=img->copy(0,0,(ox=img->xsize())+len-1,img->ysize()-1);
    img->paste(img, ox, 0);
    for(int i = 0; i<steps; i++)
    {
      int xp = i*ox/steps;
      res += img->copy(xp, 0, xp+len, img->ysize(),
                       @parse_color(args->bgcolor))->gif_add(0,0,delay);
    }
    res += img->gif_end();
    data = ({ res, ({ len, img->ysize() }) });
  }

  return
  ([
    "data":data[0],
    "meta":
    ([
      "xsize":data[1][0],
      "ysize":data[1][1],
      "type":(args->format?id->conf->type_from_filename("x."+args->format):"image/gif"),
    ])
  ]);
}

mapping find_internal(string f, RequestID id)
{
  if( strlen(f)>4 && query("ext") && f[-4]=='.') // Remove .ext
    f = f[..strlen(f)-5];
  if( strlen(f) && f[0]=='$' )
  {
    array id_text = f/"/";
    if( sizeof(id_text)==2 )
    {   // It's a gtext-id
      string second_key = roxen->argcache->store( (["":id_text[1]]) );
      return image_cache->http_file_answer( id_text[0][1..] +"$"+ second_key, id );
    }
  }
  return image_cache->http_file_answer( f, id );
}


// -------------- helpfunctions to gtext tags and containers -----------------

constant filearg=({"background","texture","alpha","magic-texture","magic-background","magic-alpha"});
constant textarg=({"afont",
		   "alpha",
		   "bevel",
		   "bgcolor",
		   "bgturbulence",
		   "black",
		   "bold",
		   "bshadow",
		   "chisel",
		   "crop",
		   "encoding",
		   "fadein",
		   "fgcolor",
		   "fs",
		   "font",
		   "font_size",
                   "format",
		   "ghost",
		   "glow",
		   "italic",
		   "light",
		   "mirrortile",
		   "move",
		   "narrow",
		   "nfont",
		   "notrans",
		   "opaque",
		   "outline",
		   "pressed",
		   "quant",
		   "rescale",
		   "rotate",
		   "scale",
		   "scolor",
		   "scroll",
		   "shadow",
		   "size",
		   "spacing",
		   "talign",
		   "tile",
		   "textbox",
		   "textbelow",
		   "textscale",
		   "verbatim",
		   "xpad",
		   "xsize",
		   "xspacing",
		   "ypad",
		   "ysize",
		   "yspacing"
});

constant theme=({"fgcolor","bgcolor","font"});

constant hreffilter=(["split":1,"magic":1,"noxml":1,"alt":1]);

mapping mk_gtext_arg(mapping arg, RequestID id) {

  mapping p=([]); //Picture rendering arguments.

  m_delete(arg,"src");
  m_delete(arg,"width");
  m_delete(arg,"height");

  foreach(filearg, string tmp)
    if(arg[tmp]) {
      p[tmp]=fix_relative(arg[tmp],id);
      m_delete(arg,tmp);
    }

  if(arg->border && search(arg->border,",")) {
    p->border=arg->border;
    m_delete(arg,"border");
  }

  foreach(textarg, string tmp)
    if(arg[tmp]) {
      p[tmp]=arg[tmp],id;
      m_delete(arg,tmp);
    }

  foreach(theme, string tmp)
    if( (id->misc->defines[tmp] || id->misc->defines["theme_"+tmp]) && !p[tmp])
      p[tmp]=id->misc->defines["theme_"+tmp] || id->misc->defines[tmp];

  if(id->misc->defines->nfont && !p->nfont) p->nfont=id->misc->gtext_nfont;
  if(id->misc->defines->afont && !p->afont) p->afont=id->misc->gtext_afont;
  if(id->misc->defines->bold && !p->bold) p->bold=id->misc->gtext_bold;
  if(id->misc->defines->italic && !p->italic) p->italic=id->misc->gtext_italic;
  if(id->misc->defines->black && !p->black) p->black=id->misc->gtext_black;
  if(id->misc->defines->narrow && !p->narrow) p->narrow=id->misc->gtext_narrow;

  return p;
}

string fix_text(string c, mapping m, RequestID id) {

  if(m->nowhitespace)
  {
    c=String.trim_all_whites(c);
    m_delete(m, "nowhitespace");
  }

  if(!m->noparse && !m->preparse)
    c = parse_rxml(c, id);
  else {
    m_delete(m, "noparse");
    m_delete(m, "preparse");
  }

  c=html_decode_string(c);

  if(m->maxlen) {
    c = c[..(((int)m->maxlen||QUERY(deflen))-1)];
    m_delete(m, "maxlen");
  }

  return c;
}


// ----------------- gtext tags and containers -------------------

string container_gtext_url(string t, mapping arg, string c, RequestID id) {
  c=fix_text(c,arg,id);
  mapping p=mk_gtext_arg(arg,id);
  if(arg->href && !p->fgcolor) p->fgcolor=id->misc->gtext_link||"#0000ff";
  string ext="";
  if(query("ext")) ext="."+(p->format || "gif");
  if(!arg->short)
    return query_internal_location()+image_cache->store( ({p,c}), id )+ext;
  return "+"+image_cache->store( ({p,c}), id )+ext;
}

string tag_gtext_id(string t, mapping arg, RequestID id) {
  mapping p=mk_gtext_arg(arg,id);
  if(arg->href && !p->fgcolor) p->fgcolor=id->misc->gtext_link||"#0000ff";
  if(!arg->short)
    return query_internal_location()+"$"+image_cache->store(p, id)+"/";
  return "+"+image_cache->store(p, id )+"/foo";
}

string container_gtext(string t, mapping arg, string c, RequestID id)
{
  if((c-" ")=="") return "";

  c=fix_text(c,arg,id);
  mapping p=mk_gtext_arg(arg,id);

  string ext="";
  if(query("ext")) ext="."+(p->format || "gif");

  string lp="%s", url="", ea="";

  int input=0;
  if(arg->submit)
  {
    input=1;
    m_delete(arg,"submit");
  }

  if(arg->href)
  {
    url = arg->href;
    lp = replace(make_tag("a",arg-hreffilter),"%","%%")+"%s</a>";
    if(!p->fgcolor) p->fgcolor=id->misc->gtext_link||"#0000ff";
    m_delete(arg, "href");
  }

  if(!arg->noxml) { arg["/"]="/"; m_delete(arg, "noxml"); }
  if(!arg->border) arg->border=arg->border||"0";

  if(arg->split)
  {
    string res="",split=arg->split;
    if(lower_case(split)=="split") split=" ";
    m_delete(arg,"split");
    c=replace(c, "\n", " ");
    int setalt=!arg->alt;
    foreach(c/split-({""}), string word)
    {
      string fn = image_cache->store( ({ p, word }),id );
      mapping size = image_cache->metadata( fn, id, 1 );
      if(setalt) arg->alt=word;
      arg->src=query_internal_location()+fn+ext;
      if( size )
      {
        arg->width  = (string)size->xsize;
        arg->height = (string)size->ysize;
      }
      res+=make_tag( "img", arg )+" ";
    }
    return sprintf(lp,res);
  }

  string num = image_cache->store( ({ p, c }), id );
  mapping size = image_cache->metadata( num, id, 1 );
  if(!arg->alt) arg->alt=replace(c,"\"","'");

  arg->src=query_internal_location()+num+ext;
  if(size) {
    arg->width=(string)size->xsize;
    arg->height=(string)size->ysize;
  }

  if(arg->magic)
  {
    string magic=replace(arg->magic,"'","`");
    m_delete(arg,"magic");

    if(p->bevel) p->pressed=1;

    foreach(glob("magic-*", indices(arg)), string q)
    {
      p[q[6..]]=arg[q];
      m_delete(arg, q);
    }

    if(!arg->fgcolor) p->fgcolor=id->misc->defines->theme_alink||
			id->misc->defines->alink||"#ff0000";

    string num2 = image_cache->store( ({ p, c }),id );
    size = image_cache->metadata( num2, id );
    if(size) {
      arg->width=(string)max(arg->xsize,size->xsize);
      arg->height=(string)max(arg->ysize,size->ysize);
    }

    if(!id->supports->images) return sprintf(lp,arg->alt);

    string sn="i"+id->misc->gtext_mi++;
    if(!id->supports->netscape_javascript) {
      return (!input)?
        ("<a "+ea+"href=\""+url+"\">"+make_tag("img",arg+(["name":sn]))+"</a>"):
        make_tag("input",arg+(["type":"image"]));
    }

    arg->name=sn;
    string res="\n<script>\n";
    if(!id->misc->gtext_magic_java) {
      res += "function i(ri,hi,txt)\n"
        "{\n"
        "  document.images[ri].src = hi.src;\n"
        "  setTimeout(\"top.window.status = '\"+txt+\"'\", 100);\n"
	"}\n";
    }
    id->misc->gtext_magic_java="yes";

    return
      res+
      " "+sn+"l = new Image("+arg->width+", "+arg->height+");"+sn+"l.src = \""+arg->src+"\";\n"
      " "+sn+"h = new Image("+arg->width+", "+arg->height+");"+sn+"h.src = \""+query_internal_location()+num2+ext+"\";\n"
      "</script>\n"+
      "<a "+ea+"href=\""+url+"\" "+
      (input?"onClick='document.forms[0].submit();' ":"")
      +"onMouseover=\"i('"+sn+"',"+sn+"h,'"+(magic=="magic"?url:magic)+"'); return true;\" "
      "onMouseout=\"top.window.status='';document.images['"+sn+"'].src = "+sn+"l.src;\">"
      +make_tag("img",arg)+"</a>";
  }

  if(input)
    return make_tag("input",arg+(["type":"image"]));

  return sprintf(lp,make_tag("img",arg));
}

array(string) container_gh(string t, mapping m, string c, RequestID id) {
  int i;
  if(sscanf(t, "%s%d", t, i)==2 && i>1)
    m->scale = (string)(1.0 / ((float)i*0.6));
  if(!m->valign) m->valign="top";
 return ({ "<p>"+container_gtext("",m,c,id)+"<br>" });
}

array(string) container_anfang(string t, mapping m, string c, RequestID id) {
  if(!m->align) m->align="left";
  return ({ "<br clear=\"left\">"+container_gtext("",m,c[0..0],id)+c[1..] });
}


// --------------- tag and container registration ----------------------

mapping query_tag_callers()
{
  return ([ "gtext-id":tag_gtext_id ]);
}

mapping query_container_callers()
{
  return ([ "anfang":container_anfang,
            "gtext-url":container_gtext_url, "gh":container_gh,
	    "gh1":container_gh, "gh2":container_gh,
	    "gh3":container_gh, "gh4":container_gh,
	    "gh5":container_gh, "gh6":container_gh,
	    "gtext":container_gtext ]);
}
