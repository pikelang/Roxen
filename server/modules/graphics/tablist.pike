// This is a roxen module. Copyright © 1997-2000, Roxen IS.
// Makes a tab list like the one in the config interface.

constant cvs_version="$Id: tablist.pike,v 1.51 2001/03/07 13:40:46 kuntri Exp $";
constant thread_safe=1;

#include <module.h>
inherit "module";

constant module_type = MODULE_TAG;
constant module_name = "Tab list";
constant module_doc = 
#"Provides the <tt>&lt;tablist&gt;</tt> tag that is used to draw tab lists.
It requires the <i>GButton</i> module.";

/*
 * Functions
 */

TAGDOCUMENTATION
#ifdef manual
constant tagdoc=(["tablist":({ #"<desc cont='cont'><p><short>

Tablist is used in the Roxen products configurationinterfaces.</short>

</p></desc>

<p>
tablist använder gbutton.

För en gbutton behöver man två lager:

frame och mask.

Mask ska vara genomskinligt där knappen ska vara genomskinlig.
'frame' körs alltid i moden Multiply, och maskens grafikinnehåll visas
aldrig, det är bara masken på den som spelar roll.

Man kan även ha ett lager vid namn 'background', som då hamnar under
lagret 'frame' och texten. 


Så här blir det om man ser det som en hög lager:

 frame              mode = multiply
 text               mode = normal, mask = texten
 background         
 button-background  mode = normal, mask = lagret 'mask'
 page-background    mode = normal


Man kan även ange i taggen att man vill ha extra lager. De stoppas in
så här:

*extra-layers
 frame              mode = multiply
*extra-frame-layers mode = multiply
 text               mode = normal, mask = texten
 background         
*extra-background-layers
 button-background  mode = normal, mask = lagret ('mask' + *extra-mask-layers)
 page-background    mode = normal


Om man anger extra-left-layers och/eller extra-right layers stoppas de
sedan till vänster och höger om den bild som genereras av koden ovan.

 

För en tablist vill man förutom de två grundläggande lager som anges
ovan ha några till:

unselected  streck i underkanten
first left  streck till vänster
last right  streck till höger


Man kan även ha några fler olika lager.

Alla som heter 'first' stoppas bara dit om tabben som ska rendreras är
först i listan.

Alla som heter 'last' stoppas bara dit om tabben som ska rendreras är
sist i listan.

Alla som heter 'unselected' stoppas bara dit om tabben inte är vald.

Alla som heter 'selected' stoppas bara dit om tabben är vald.

Alla lager som inte har något annat namn än när det ska stoppas dit
stoppas dit i 'extra-layers' (se gbutton ovan). Alla som heter
\"* background\" stoppas dit i extra-background-layers. mask left och
right stoppas också i dito extra-*-layers.

Alla lager som man kan ha i en gbutton utan att själv ange extra-*- är
alltså:


background
frame
mask
left
right

first 
first background
first frame
first mask
first left
first right

last 
last background
last frame
last mask
last left
last right

selected 
selected background
selected frame
selected mask
selected left
selected right

unselected 
unselected background
unselected frame
unselected mask
unselected left
unselected right

first selected 
first selected background
first selected frame
first selected mask
first selected left
first selected right

first unselected 
first unselected background
first unselected frame
first unselected mask
first unselected left
first unselected right

last selected 
last selected background
last selected frame
last selected mask
last selected left
last selected right

last unselected 
last unselected background
last unselected frame
last unselected mask
last unselected left
last unselected right


> state={disabled,normal}

state={enabled,disabled} (fast allt som inte är \"disabled\" funkar)

> icon_src=...

icon-src=... (icon_src funkar fortfarande)

> icon_data=...

icon-data=... (icon_data funkar fortfarande)

> align_icon={left,right}

align-icon={left,center-before,center-after,right}

Dessutom finns vertikal justering, men det kräver tre horisontella
guides i ramfilen. (Allt blir horisontellt centrerat oavsett värdet
på align-icon.)

valign-icon={above,middle,below}

Förtydligande angående valign-icon: horisontell justering fungerar
förstås för valign-icon=middle (defaultvärdet), men för above eller
below så blir det automatiskt centrerat.

Jag hittade en gammal beskrivning:

<gbutton> specific args:

pagebgcolor=...
bgcolor=...
textstyle={condensed,normal}
width=...
align={left,right,center}
state={disabled,normal}
icon_src=...
icon_data=...
align_icon={left,right}
font=...
extra-layers=...
extra-left-layers=...
extra-right-layers=...
extra-background-layers=...
extra-mask-layers=...
extra-frame-layers=...

<tablist> inherits from gbutton, and also have:

selcolor=...
seltextcolor=...
textcolor=...
dimcolor=...

frame-image=...

<tab> inherits from tablist, and also have:
selected=...
alt=...



All 'normal' layers (without extra layer arguments specified:


A		B		C
''		''		''
'first'		'selected'	'background'
'last'		'unselected'	'mask'
				'frame'
				'left'
				'right'

All possible combinations of A, B and C are useful as layer names,
following the pattern \"[A ]B C\" (such as \"selected mask\" or \"first
selected left\" or \"selected\")


B and A specifies when the layer is used.

C specifies the position.

'' (such as 'first' or 'first selected') is inserted above all other
layers in the picture.

'background' is put below all other layers.

'mask' is used to specify which part of the image is transparent, the
part of the mask that is transparent is also transparent in the
finished picture.

'frame' alters the brightness of the picture (while maintaining the
color).


'left' is put to the left of the image, extending it's size
'right' is put to the right of the image, extending it's size.


<attr name='extra-layers' value='[''],[first|last],[selected|unselected],[background|mask|frame|left|right]'>
<p></p>
</attr>

<attr name='extra-left-layers' value='[''],[first|last],[selected|unselected],[background|mask|frame|left|right]'>
<p></p>
</attr>

<attr name='extra-right-layers' value='[''],[first|last],[selected|unselected],[background|mask|frame|left|right]'>
<p></p>
</attr>

<attr name='extra-background-layers' value='[''],[first|last],[selected|unselected],[background|mask|frame|left|right]'>
<p></p>
</attr>

<attr name='extra-mask-layers' value='[''],[first|last],[selected|unselected],[background|mask|frame|left|right]'>
<p></p>
</attr>

<attr name='extra-frame-layers' value='[''],[first|last],[selected|unselected],[background|mask|frame|left|right]'>
<p></p>
</attr>

<!-- <table>
<tr><td>A</td><td>B</td><td>C</td></tr>
<tr><td>''</td><td>''</td><td>''</td></tr>
<tr><td>'first'</td><td>'selected'</td><td>'background'</td></tr>
<tr><td>'last'</td><td>'unselected'</td><td>'mask'</td></tr>
<tr><td></td><td></td><td>'frame'</td></tr>
<tr><td></td><td></td><td>'left'</td></tr>
<tr><td></td><td></td><td>'right'</td></tr>
</table> -->


",
(["tab":#"<desc cont='cont'><p><short>
 Tab</short></p></desc>"]) }) ]);

#endif

void start(int num, Configuration conf)
{
  module_dependencies(conf, ({ "gbutton" }) );
}

void add_layers( mapping m, string lay )
{
  foreach( ({"","background-","mask-","frame-","left-","right-",
             "above-","below-" }), string s )
  {
    string ind="extra-"+s+"layers", l;
    if( strlen( s ) )
      l = lay+" "+(s-"-");
    else
      l = lay;
    if( m[ind] )
      m[ind]+=","+l;
    else
      m[ind] = l;
  }
}

class TagTablist {
  inherit RXML.Tag;
  constant name = "tablist";

  class TagTab {
    inherit RXML.Tag;
    constant name = "tab";

    class Frame {
      inherit RXML.Frame;

      array do_return(RequestID id) {
	string fimage;
	mapping d = id->misc->tablist_args;

	if(args["frame-image"])
	  fimage = Roxen.fix_relative( args["frame-image"], id );
	else if(d["frame-image"])
	  fimage = Roxen.fix_relative( d["frame-image"], id );
	else if(id->misc->defines["tab-frame-image"])
	  fimage = Roxen.fix_relative( id->misc->defines["tab-frame-image"], id );
	else
	  //  We need an absolute path or else gbutton will "fix" this according
	  //  to the path in the request...
	  fimage = "/internal-roxen-tabframe";
  
	mapping gbutton_args = d|args;

	gbutton_args["frame-image"] = fimage;

	if( args->selected  ) {
	  add_layers( gbutton_args, "selected" );
	  gbutton_args->bgcolor = args->selcolor || d->selcolor || "white";
	  gbutton_args->textcolor = (args->seltextcolor || d->seltextcolor ||
				     args->textcolor || d->textcolor ||
				     id->misc->defines->fgcolor ||
				     id->misc->defines->theme_fgcolor ||
				     "black");
	} else {
	  add_layers( gbutton_args, "unselected" );
	  gbutton_args->bgcolor =  args->dimcolor || d->dimcolor || "#003366";
	  gbutton_args->textcolor = (args->textcolor || d->textcolor || "white");
	}
	m_delete(gbutton_args, "selected");
	m_delete(gbutton_args, "dimcolor");
	m_delete(gbutton_args, "seltextcolor");
	m_delete(gbutton_args, "selcolor");
	m_delete(gbutton_args, "result");

	if (args->alt) {
	  gbutton_args->alt = args->alt;
	  m_delete(args, "alt");
	} else
	  gbutton_args->alt = "/" + content + "\\";

	id->misc->tablist_result += ({ ({gbutton_args,content}) });
	return 0;
      }
    }
  }

  RXML.TagSet internal = RXML.TagSet("TagTablist.internal", ({ TagTab() }) );

  class Frame {
    inherit RXML.Frame;
    RXML.TagSet additional_tags = internal;

    array do_enter(RequestID id) {
      id->misc->tablist_args = args;
      id->misc->tablist_result = ({});
    }

    array do_return(RequestID id) {
      array(array) result = id->misc->tablist_result;
      if(!sizeof(result))
	return 0;

      if( result[0][0]->selected )
	add_layers( result[0][0], "first selected" );
      else
	add_layers( result[0][0], "first unselected" );
      add_layers( result[0][0], "first" );
      if( result[-1][0]->selected )
	add_layers( result[-1][0], "last selected" );
      else
	add_layers( result[-1][0], "last unselected" );
      add_layers( result[-1][0], "last" );

      return map( result, lambda( array q ) {
			    return RXML.make_tag ("gbutton",q[0],q[1]);
			  } );
    }
  }
}
