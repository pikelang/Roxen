// This is a roxen module. Copyright © 1996 - 2001, Roxen IS.

constant cvs_version = "$Id: tablify.pike,v 1.63 2001/03/08 14:35:48 per Exp $";
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
constant tagdoc=(["tablify":({ #"<desc cont='cont'><p><short>
 Transforms texts into tables.</short> No attributes required.
</p></desc>

<attr name='rowseparator' value='string' default='newline'><p>
 Defines the rowseparator.</p>
</attr>

<attr name='cellseparator' value='string' default='tab'><p>
 Defines the cellseparator.</p>
</attr>

<attr name='border' value='number'><p>
 Defines the width of the border. Default is 2 in nice and nicer
 modes. Otherwise undefined.</p>
</attr>

<attr name='cellspacing' value='number'><p>
 Defines the cellspacing attribute. Default is 0 in nice and nicer
 modes. Otherwise undefined.</p>
</attr>

<attr name=cellpadding value='number'><p>
 Defines the cellpadding attribute. Default is 4 in nice and nicer
 modes. Otherwise undefined.</p>
</attr>

<attr name='interactive-sort'><p>
 Makes it possible for the user to sort the table with respect to any
 column.</p>
</attr>

<attr name='sortcol' value='number'><p>
 Defines which column to sort the table with respect to. The leftmost
 column is number 1. Negative value indicate reverse sort order.</p>
</attr>

<attr name=min value='number'><p>
 Indicates which of the input rows should be the first to be
 displayed. The first row is number 1.</p>
</attr>

<attr name=max value='number'><p>
 Indicates which of the input rows should be the last to be
 displayed.</p>
</attr>

<attr name='negativecolor' value='color' default='#ff0000'><p>
 The color of negative values in economic fields.</p>
</attr>

<attr name='cellalign' value='left|center|right'><p>
 Defines how the cell contents should be align by default.</p>
</attr>

<attr name='cellvalign' value='top|middle|bottom'><p>
 Defines how the cell contents should be verically aligned.</p>
</attr>

<attr name='width' value='number'><p>
 Defines the width of the table.</p>

<ex>
<tablify cellseparator=','>
Country, Population
Sweden, 8 911 296
Denmark, 5 356 845
Norway, 4 438 547
Iceland, 272 512
Finland, 5 158 372
</tablify>
</ex>
</attr>

<h1>The 'nice' attribute</h1>

<attr name='nice'><p>
 Add some extra layout to the table. All attributes below only applies
 in nice or nicer mode.</p>
</attr>

<attr name='grid' value='number'><p>
 Draws a grid with the thickness given.</p>
</attr>

<attr name='notitle'><p>
 Don't add a title to each column.</p>
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
</attr>

<attr name='oddbgcolor' value='color' default='#ffffff'><p>
 The first background color.</p>
</attr>

<attr name='evenbgcolor' value='color' default='#ddeeff'><p>
 The second background color.</p>

<ex>
<tablify nice='' cellseparator=',' modulo='2'>
Country, Population
Sweden, 8 911 296
Denmark, 5 356 845
Norway, 4 438 547
Iceland, 272 512
Finland, 5 158 372
</tablify>
</ex>
</attr>

<h1>The 'nicer' attribute</h1>

<attr name='nicer'><p>
 Add some extra extra layout to the table. All attributes below only
 applies in nicer mode. Nicer requires the gtext module.</p>
</attr>

<attr name='noxml'><p>
 Don't terminate the gifs with slashes.</p>
</attr>

<attr name='font' value='text' default='lucida'><p>
 Gtext font to write the column titles with.</p>
</attr>

<attr name='scale' value='float' default='0.36'><p>
 Size of the gtext font to write the column titles with.</p>
</attr>

<attr name='textcolor' value='color' default='#000000'><p>
 The color of the text. This will also work with economic fields in
 any mode.</p>
</attr>

<attr name='size' value='number' default='2'><p>
 The size of the table text.</p>
</attr>

<attr name='font' value='string' default='helvetica,arial'><p>
 The font of the table text.</p>

<ex>
<tablify nicer='' cellseparator=',' font='andover' scale='1.0'>
Country, Population
Sweden, 8 911 296
Denmark, 5 356 845
Norway, 4 438 547
Iceland, 272 512
Finland, 5 158 372
</tablify>
</ex>

</attr>",

(["fields":#"<desc cont='cont'><p>
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




string encode_url(int col, int state, object stateobj, RequestID id){
  if(col==abs(state))
    state=-1*state;
  else
    state=col;

  string global_not_query=id->raw_url;
  sscanf(global_not_query, "%s?", global_not_query);

  return global_not_query+"?__state="+
    stateobj->uri_encode(state);
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
      r+="<tr bgcolor=\""+(opt->titlebgcolor||"#112266")+"\">\n";
    else
      r+="<tr>";
    foreach(subtitles, string s) {
      col++;
      r+="<th align=\"left\">"+(opt["interactive-sort"]?"<a href=\""+encode_url(col,opt->sortcol||0,opt->state,id)+"\">":"");
      if(opt->nicer)
        r+="<gtext nfont=\""+(opt->font||"lucida")+"\" scale=\""+
	   (opt->scale||"0.4")+"\" fgcolor=\""+(opt->titlecolor||"white")+"\" bgcolor=\""+
	   (opt->titlebgcolor||"#112266")+"\""+(opt->noxml?" noxml":"")+">"+s+"</gtext>";
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

  for(int i = 0; i < sizeof(table); i++) {
    if(opt->nice || opt->nicer)
      r+="<tr bgcolor=\""+((i/m)%2?opt->evenbgcolor||"#ddeeff":opt->oddbgcolor||"#ffffff")+"\"";
    else
      r+="<tr";
    r+=opt->cellvalign?" valign=\""+opt->cellvalign+"\">":">";

    for(int j = 0; j < sizeof(table[i]); j++) {
      mixed s = table[i][j];
      type=arrayp(opt->fields) && j<sizeof(opt->fields)?opt->fields[j]:"text";
      switch(type){

      case "economic-float":
      case "float":
	array a = s/".";
        string font="",nofont="";
        if(opt->nicer || type=="economic-float"){
          font="<font color=\""+
            (type=="economic-float"?((int)a[0]<0?(opt->negativecolor||"#ff0000"):(opt->textcolor||"#000000")):
              (opt->textcolor||"#000000"))+
            "\""+(opt->nicer?(" size=\""+(opt->size||"2")+
            "\" face=\""+(opt->face||"helvetica,arial")+"\">"):">");
          nofont="</font>";
	}

        //The right way<tm> is to preparse the whole column and find the longest string of
        //decimals and use that to calculate the maximum width of the decimal cell, insted
        //of just saying width=30, which easily produces an ugly result.
        r+="<td align=\"right\"><table border=\"0\" cellpadding=\"0\" cellspacing=\"0\"><tr><td align=\"right\">"+
          font+a[0]+nofont+"</td><td>"+font+"."+nofont+"</td><td align=\"left\" width=\"30\">"+font+
          (sizeof(a)>1?a[1]:"0")+nofont;

        r += "</td></tr></table>";
	break;

      case "economic-int":
      case "int":
        if(opt->nicer || type=="economic-int"){
          font="<font color=\""+
            (type=="economic-int"?((int)s<0?(opt->negativecolor||"#ff0000"):(opt->textcolor||"#000000")):
              (opt->textcolor||"#000000"))+
            "\""+(opt->nicer?(" size=\""+(opt->size||"2")+
            "\" face=\""+(opt->face||"helvetica,arial")+"\">"):">");
          nofont="</font>";
	}

        r+="<td align=\"right\">"+font+(string)(int)round((float)s)+nofont;
	break;

      case "num":
        type="right";
      case "text":
      case "left":
      case "right":
      case "center":
      default:
        r += "<td align=\""+(type!="text"?type:(opt->cellalign||"left"))+"\">";
	if(opt->nicer) r += "<font color=\""+(opt->textcolor||"#000000")+"\" size=\""+(opt->size||"2")+
          "\" face=\""+(opt->face||"helvetica,arial")+"\">";
        r += s+(opt->nice||opt->nicer?"&nbsp;&nbsp;":"");
        if(opt->nicer) r+="</font>";
      }

      r += "</td>";
    }
    if(sizeof(table[i])<id->misc->tmp_colmax) r+="<td colspan=\""+(id->misc->tmp_colmax-sizeof(table[i]))+"\">&nbsp;</td>";
    r += "</tr>\n";
  }

  m_delete(id->misc, "tmp_colmax");
  if(opt->nice || opt->nicer)
    return Roxen.parse_rxml(r,id)+"</table></td></tr>\n</table>\n";

  m_delete(opt, "cellalign");
  m_delete(opt, "cellvalign");
  m_delete(opt, "fields");
  m_delete(opt, "state");
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
  array rows, res;
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

  id->misc->tmp_colmax=0;
  rows = map(rows,lambda(string r, string s){
		    array t=r/s;
		    if(sizeof(t)>id->misc->tmp_colmax) id->misc->tmp_colmax=sizeof(t);
		    return t;
		  }, sep);

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
    int sortcol=abs((int)m->sortcol)-1,num=0;
    if(m->fields && sortcol+1<sizeof(m->fields)) {
      switch(m->fields[sortcol]) {
      case "num":
      case "int":
      case "economic-int":
      case "float":
      case "economic-float":
        rows = map(rows, lambda(array a, int c) { return ({ (float)a[c] })+a; }, sortcol);
        sortcol=0;
        num=1;
      }
    }
    sort(column(rows,sortcol),rows);
    if((int)m->sortcol<0)
      rows=reverse(rows);
    if(num)
      rows = map(rows, lambda(array a) { return a[1..]; });
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
