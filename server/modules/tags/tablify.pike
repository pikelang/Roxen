// This is a roxen module. Copyright © 1996 - 2009, Roxen IS.

constant cvs_version = "$Id$";
constant thread_safe = 1;

#include <module.h>
inherit "module";

constant module_type = MODULE_TAG;
constant module_name = "Tags: Tablify";
constant module_doc  = 
#"This module provides the <tt>&lt;tablify&gt;</tt> tag that is used to
generate nice tables.";

TAGDOCUMENTATION
#ifdef manual
constant tagdoc=(["tablify":({ #"<desc type='cont'><p><short>
 Transforms texts into tables.</short> The default behavior is to use
 tabs as column delimiters and newlines as row delimiters. The values in the
 first row as assumed to be the title. Note in the example below how empty
 rows are ignored. As is shown in the last line a row does not need to be
 complete for tablify to work properly. These missing cells will get <ent>nbsp</ent>
 as content to force all cells to be drawn if borders are on, thus avoiding
 broken layout when, e.g. a dynamic variable happens to be empty. No attributes are
 required for tablify to work.</p>

<ex>
<tablify border='1'>
X	Y	Z
3	10	77

1	2	10
4	13	3
1	2
</tablify>
</ex>

 <p>Tablify also prescans the entire table to find the widest number of cells.</p>

<ex>
<tablify border='1'>
A	B
a	b
aa	bb
aaa	bbb	ops!
</tablify>
</ex>
</desc>

<attr name='rowseparator' value='string' default='newline'><p>
 Defines the character or string used to seperate the rows.</p>
</attr>

<attr name='cellseparator' value='string' default='tab'><p>
 Defines the character or string used to seperate the cells.</p>

<ex>
<tablify cellseparator=','>
Element, Mass
H, 1.00797
He, 4.0026
Li, 6.939
</tablify>
</ex>
</attr>

<attr name='intable'><p>
  If the intable attribute is set the tablify module will parse
  the indata as a table.</p>

<ex>
<tablify nice='1' intable='1'>
<table><tr><th>Element</th><th>Mass</th></tr>
<tr><td>H</td><td>1.00797</td></tr>
<tr><td>He</td><td>4.0026</td></tr>
<tr><td>Li</td><td>6.939</td></tr>
</table>
</tablify>
</ex>
</attr>

<attr name='notitle'><p>
 Don't add a title to the columns and treat the first row in the
 indata as real data instead.</p>
</attr>

<attr name='interactive-sort'><p>
 Makes it possible for the user to sort the table with respect to any
 column.</p>
</attr>

<attr name='sortcol' value='number'><p>
 Defines which column to sort the table with respect to. The leftmost
 column is number 1. Negative value indicate reverse sort order.</p>
</attr>

<attr name='min' value='number'><p>
 Decides which of the input rows should be the first one to be
 displayed. This can be used to skip unwanted rows in the beginning
 of the data. The first row after the heading is row number 1.</p>
</attr>

<attr name='max' value='number'><p>
 Decides which of the input rows should be the last one to be
 displayed. This can be used to limit the the output to a maximum
 number of rows.</p>
<ex>
<tablify min='2' max='4'>
Stuff
one
two
three
four
five
six
</tablify>
</ex>
</attr>

<attr name='negativecolor' value='color' default='#ff0000'><p>
 The color of negative values in economic fields.</p>
</attr>

<attr name='border' value='number'><p>
 Defines the width of the border. Default is 2 in nice and nicer
 modes. Otherwise undefined. The value is propagated into the
 resulting table tag if neither nice nor nicer is used.</p>
</attr>

<attr name='cellspacing' value='number'><p>
 Defines the cellspacing attribute. Default is 0 in nice and nicer
 modes. Otherwise undefined. The value is propagated into the
 resulting table tag if neither nice nor nicer is used.</p>
</attr>

<attr name='cellpadding' value='number'><p>
 Defines the cellpadding attribute. Default is 4 in nice and nicer
 modes. Otherwise undefined. The value is propagated into the
 resulting table tag if neither nice nor nicer is used.</p>
</attr>

<attr name='width' value='number'><p>
 Defines the width of the table.</p>
</attr>

<attr name='cellalign' value='left|center|right'><p>
 Defines how the cell contents should be align by default. The value is propagated into the
 resulting td tags if neither nice nor nicer is used.</p>
</attr>

<attr name='cellvalign' value='top|middle|bottom'><p>
 Defines how the cell contents should be verically aligned. The value is propagated into the
 resulting td tags if neither nice nor nicer is used.</p>
</attr>

<h1>The 'nice' attribute</h1>

<attr name='nice'><p>
 Add some extra layout to the table. More specifically it creates a bakcground
 table with another color and then colors all the cells in the inner table.
 All attributes below only applies in nice or nicer mode.</p>

<ex>
<tablify nice='1' cellseparator=','>
Element, Mass
H, 1.00797
He, 4.0026
Li, 6.939
</tablify>
</ex>

<ex>
<tablify nice='1' cellseparator=',' cellspacing='1'>
Element, Mass
H, 1.00797
He, 4.0026
Li, 6.939
</tablify>
</ex>
</attr>

<attr name='grid' value='number'><p>
 Draws a grid with the thickness given.</p>

<ex>
<tablify nice='1' grid='1'>
Element	Mass
H	1.00797
He	4.0026
Li	6.939
</tablify>
</ex>
</attr>

<attr name='bordercolor' value='color' default='#000000'><p>
 The color of the border.</p>
</attr>

<attr name='titlebgcolor' value='color' default='#112266'><p>
 The background color of the title.</p>
</attr>

<attr name='titlecolor' value='color' default='#ffffff'><p>
 The color of the title.</p>
</attr>

<attr name='modulo' value='number'><p>
 Defines how many rows in a row should have the same color.</p>

<ex>
<tablify nice='1' cellseparator=',' modulo='2'>
Element, Mass
H, 1.00797
He, 4.0026
Li, 6.939
Be, 9.0122
B, 10.811
</tablify>
</ex>
</attr>

<attr name='oddbgcolor' value='color' default='#ffffff'><p>
 The first background color.</p>
</attr>

<attr name='evenbgcolor' value='color' default='#ddeeff'><p>
 The second background color.</p>
</attr>

<h1>The 'nicer' attribute</h1>

<attr name='nicer'><p>
 Add some extra extra layout to the table. Compared with nice-mode it
 gtexts the column titles and adds a font-tag in all cells.
 All attributes below only applies in nicer mode. Nicer requires the
 gtext module.</p>

<ex>
<tablify nicer='1'>
Element	Mass
H	1.00797
He	4.0026
Li	6.939
</tablify>
</ex>
</attr>

<attr name='noxml'><p>
 Don't terminate the images with slashes, as required by XML.</p>
</attr>

<attr name='font' value='text' default='lucida'><p>
 The font gtext should use to write the column titles with.</p>

<ex>
<tablify nicer='1' cellseparator=', ' font='andover' fontsize='24'>
Element, Mass
H, 1.00797
He, 4.0026
Li, 6.939
</tablify>
</ex>
</attr>

<attr name='fontsize' value='int' default='13'><p>
 The size of the gtext font used to write the column titles with.</p>
</attr>

<attr name='scale' value='float'><p>
 Scales the gtext font used to write the column titles with.</p>
</attr>

<attr name='textcolor' value='color' default='#000000'><p>
 The color of the text. This will also work with economic fields in
 any mode.</p>
</attr>

<attr name='size' value='number' default='2'><p>
 The size of the table text.</p>
</attr>

<attr name='face' value='string' default='helvetica,arial'><p>
 The font of the table text, e.g. the value of the face attribute
 in the font tag that encloses every cell.</p>
</attr>",

(["fields":#"<desc type='cont'><p>
 The container 'fields' may be used inside the tablify container to
 describe the type of contents the fields in a column has. Available
 fields are:</p>

   <list type='ul'>
   <item><p>text (default)</p></item>
   <item><p>left</p></item>
   <item><p>center</p></item>
   <item><p>right</p></item>
   <item><p>num</p></item>
   <item><p>int</p></item>
   <item><p>economic-int</p></item>
   <item><p>float</p></item>
   <item><p>economic-float</p></item>
   </list>

   <p>All fields except text overrides the cellvalign attribute.</p>

<ex>
<tablify nice='nice'>
<fields separator=','>
text,center,right,float,economic-float,int,economic-int
</fields>
text	center	right	float	economic-float	int	economic-int
123.14	123.14	123.14	123.14	123.14	123.14	123.14
56.8	56.8	56.8	56.8	56.8	56.8	56.8
-2	-2	-2	-2	-2	-2	-2
</tablify>
</ex>
</desc>


<attr name='separator' value='string'><p>
 Defines the field type separator.</p>

 <p>The fields types are separated by</p>
  <list type='ol'>
  <item><p>The value given in the separator attribute to fields.</p></item>
  <item><p>The value given in the cellseparator attribute to tablify.</p></item>
  <item><p>Tab.</p></item>
  </list>
</attr>"
])
			    })
		]);
#endif


constant _tablify_args = ({
  "bordercolor",
  "cellalign",
  "cellseparator",
  "cellvalign",
  "evenbgcolor",
  "face",
  "fields",
  "font",
  "fontsize",
  "grid",
  "intable",
  "interactive-sort",
  "max",
  "min",
  "modulo",
  "negativecolor",
  "nice",
  "nicer",
  "notitle",
  "noxml",
  "oddbgcolor",
  "rowseparator",
  "scale",
  "size",
  "state",
  "sortcol",
  "textcolor",
  "titlebgcolor",
  "titlecolor",
});
constant tablify_args = mkmapping(_tablify_args, _tablify_args);


string encode_url(int col, int state, object stateobj, RequestID id){
  if(col==abs(state))
    state=-1*state;
  else
    state=col;

  return stateobj->encode_revisit_url (id, state);
}

string make_table(array subtitles, array table, mapping opt, RequestID id)
{
  string r = "",type;

  int m = (int)opt->modulo || 1;
  if(opt->nice || opt->nicer)
    r+="<table bgcolor=\""+(opt->bordercolor||"#000000")+"\" border=\"0\" "
       "cellspacing=\"0\" cellpadding=\""+(opt->border||"1")+"\""+
      (opt->width?" width=\""+opt->width+"\"":"")+">\n"
       "<tr><td>\n"
       "<table border=\""+(opt->grid||"0")+"\" cellspacing=\""+(opt->cellspacing||"0")+
       "\" cellpadding=\""+(opt->cellpadding||"4")+"\" width=\"100%\">\n";

  if (subtitles) {
    int col=0;
    if(opt->nice || opt->nicer)
      r += "<tr bgcolor=\"" + (opt->titlebgcolor||"#112266") + "\">\n";
    else
      r += "<tr>";

    foreach(subtitles, string s) {
      col++;
      r += "<th align=\"left\">" + (opt["interactive-sort"]?
				    "<a href=\""+encode_url(col,opt->sortcol||0,opt->state,id) +
				"\" id=\"nofollow-" + RXML.get_var("counter", "page") + "\">":"");
      if(opt->nicer) {
	mapping m = ([ "fgcolor":opt->titlecolor||"white",
		       "bgcolor":opt->titlebgcolor||"#112266",
		       "fontsize":opt->fontsize||"12" ]);
	if(opt->font) m->font = opt->font;
	if(opt->scale) m->scale = opt->scale;
	if(opt->noxml) m->noxml = "1";
	r += sprintf("<gtext%{ %s='%s'%}>%s</gtext>", (array)m, s);
      }
      else if(opt->nice)
        r+="<font color=\""+(opt->titlecolor||"#ffffff")+"\">"+s+"</font>";
      else
        r+=s;
      r+=(opt["interactive-sort"]?(abs(opt->sortcol||0)==col?"<img hspace=\"5\" src=\"internal-roxen-sort-"+
        (opt->sortcol<0?"asc":"desc")+"\" border=\"0\">":"")+
        "</a>":"")+"&nbsp;</th>";
    }
    if(col<id->misc->tmp_colmax) r+="<td colspan=\""+(id->misc->tmp_colmax-col)+"\">&nbsp;</td>";
    r += "</tr>\n";
  }

  opt->textcolor = opt->textcolor || "#000000";
  opt->negativecolor = opt->negativecolor || "#ff0000";
  opt->size = opt->size || "2";
  opt->face = opt->face || "helvetica,arial";
  opt->cellalign = opt->cellalign || "left";

  int i;
  foreach(table, array row) {
    if(opt->nice || opt->nicer)
      r += "<tr bgcolor=\"" +
	((i++/m)%2?opt->evenbgcolor||"#ddeeff":opt->oddbgcolor||"#ffffff") + "\"";
    else
      r += "<tr";

    r += opt->cellvalign?" valign=\""+opt->cellvalign+"\">":">";

    for(int j = 0; j < sizeof(row); j++) {
      mixed s = row[j];
      type = arrayp(opt->fields) && j<sizeof(opt->fields) ? opt->fields[j]:"text";
      string font="",nofont="";

      switch(type) {

      case "economic-float":
      case "float":
	array a = s/".";
        if(opt->nicer || type=="economic-float"){
          font = "<font color=\"" +
            (type=="economic-float" && (int)a[0]<0 ?
	     opt->negativecolor : opt->textcolor) +
            "\"" +
	    (opt->nicer?(" size=\"" + opt->size +
			 "\" face=\"" + opt->face +
			 "\">"):">");
          nofont = "</font>";
	}

        //The right way<tm> is to preparse the whole column and find the longest string of
        //decimals and use that to calculate the maximum width of the decimal cell, insted
        //of just saying width=30, which easily produces an ugly result.
        r += "<td align=\"right\"><table border=\"0\" cellpadding=\"0\" cellspacing=\"0\">"
	  "<tr><td align=\"right\">" +
          font + a[0] + nofont + "</td><td>" + font + "." + nofont +
	  "</td><td align=\"left\" width=\"30\">" + font +
          (sizeof(a)>1?a[1]:"0") + nofont;

        r += "</td></tr></table>";
	break;

      case "economic-int":
      case "int":
        if(opt->nicer || type=="economic-int") {
          font = "<font color=\"" +
            (type=="economic-int" && (int)s<0 ?
	     opt->negativecolor : opt->textcolor) +
            "\"" +
	    (opt->nicer?(" size=\"" + opt->size +
			 "\" face=\"" +
			 opt->face + "\">"):">");
          nofont = "</font>";
	}

        r += "<td align=\"right\">" + font + (string)(int)round((float)s) + nofont;
	break;

      case "num":
        type="right";
      case "text":
      case "left":
      case "right":
      case "center":
      default:
        r += "<td align=\"" + (type!="text"?type:opt->cellalign) + "\">";
	if(opt->nicer)
	  r += "<font color=\"" + opt->textcolor + "\" size=\"" + opt->size +
	    "\" face=\"" + opt->face + "\">";
        r += s + (opt->nice||opt->nicer?"&nbsp;&nbsp;":"");
        if(opt->nicer)
	  r += "</font>";
      }

      r += "</td>";
    }

    if(sizeof(row)<id->misc->tmp_colmax)
      r += "<td colspan=\"" + (id->misc->tmp_colmax-sizeof(row)) + "\">&nbsp;</td>";

    r += "</tr>\n";
  }

  m_delete(id->misc, "tmp_colmax");
  if(opt->nice || opt->nicer)
    return Roxen.parse_rxml(r+"</table></td></tr>\n</table>\n", id);

  opt -= tablify_args;
  return Roxen.make_container("table",opt,r);
}

string _fields(string name, mapping arg, string q, mapping m)
{
  m->fields = map(q/(arg->separator||m->cellseparator||"\t"),
		  lambda(string field) { return String.trim_all_whites(field); });
  return "";
}

string simpletag_tablify(string tag, mapping m, string q, RequestID id)
{
  array rows;
  string sep;

  q = parse_html(q, ([]), (["fields":_fields]), m);

  if(m->intable) {
    q=`-(q,"\n","\r","\t");
    m_delete(m, "rowseparator");
    m_delete(m, "cellseparator");
    if(!m->notitle) m+=(["notitle":1]);
    q=parse_html(q, ([]), (["table":lambda(string name, mapping arg, string q, mapping m) {
				      if(arg->border) m->border=arg->border;
				      if(arg->cellspacing) m->cellspacing=arg->cellspacing;
				      if(arg->cellpadding) m->cellpadding=arg->cellpadding;
				      return q;
				    },
			    "tr":lambda(string name, mapping arg, string q, mapping m) {
				   return q+"\n";
				 },
			    "td":lambda(string name, mapping arg, string q, mapping m) {
				   return q+"\t";
				 },
			    "th":lambda(string name, mapping arg, string q, mapping m) {
                                   if(m->notitle && m->notitle==1) m_delete(m, "notitle");
				   return q+"\t";
				 }
    ]), m);
    q = replace(q, "\t\n", "\n");
  }

  sep = m->rowseparator||"\n";
  m_delete(m,"rowseparator");

  rows = (q / sep) - ({""});

  sep = m->cellseparator||"\t";
  m_delete(m,"cellseparator");

  array title;
  if(!m->notitle && sizeof(rows)>1) {
    title = rows[0]/sep;
    rows = rows[1..];
  }

  int col_min = sizeof((rows + ({({})}))[0]);
  id->misc->tmp_colmax=0;
  rows = map(rows,lambda(string r, string s){
		    array t=r/s;
		    if(sizeof(t)>id->misc->tmp_colmax)
		      id->misc->tmp_colmax = sizeof(t);
		    if (sizeof(t) < col_min)
		      col_min = sizeof(t);
		    return t;
		  }, sep);

  if(!sizeof(rows)) return "";
  if(sizeof(rows[-1])==1 && !sizeof(String.trim_all_whites(rows[-1][0])))
    rows = rows[..sizeof(rows)-2];

  if(m["interactive-sort"]) {
    m->state=StateHandler.Page_state(id);
    m->state->register_consumer((m->name || "tb")+sizeof(rows));
    m->sortcol=(int)m->sortcol;
    if(id->real_variables->__state){
      m->state->uri_decode(id->real_variables->__state[0]);
      m->sortcol=m->state->get()||m->sortcol;
    }
  }

  if((int)m->sortcol) {
    int sortcol = abs((int)m->sortcol)-1;
    if (sortcol < col_min) {
      int num;
      if(m->fields && (sortcol+1 <= sizeof(m->fields))) {
	switch(m->fields[sortcol]) {
	case "num":
	case "int":
	case "economic-int":
	case "float":
	case "economic-float":
	  rows = map(rows,
		     lambda(array a, int c) {
		       return ({
			 (sizeof(a) > c) ? (float)a[c] : -1e99
		       }) + a;
		     }, sortcol);
	  sortcol=0;
	  num=1;
	}
      }
      sort(column(rows, sortcol), rows);
      if(num)
	rows = map(rows, lambda(array a) { return a[1..]; });
    }
    if((int)m->sortcol<0)
      rows=reverse(rows);
  }

  if(m->min || m->max) {
    m->min=m->min?(int)m->min-1:0;
    m->max=m->max?(int)m->max-1:sizeof(rows)-1;
    if(m->max < m->min) RXML.parse_error("Min attribute greater than the max attribute.");
    rows = rows[m->min..m->max];
    m_delete(m,"min");
    m_delete(m,"max");
  }

  return make_table(title, rows, m, id);
}
