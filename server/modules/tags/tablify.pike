// This is a roxen module. Copyright © 1996 - 1999, Idonex AB.

constant cvs_version = "$Id: tablify.pike,v 1.27 1999/08/05 19:59:20 nilsson Exp $";
constant thread_safe=1;
#include <module.h>
inherit "module";
inherit "wizard";

#define old_rxml_compat 1

mixed *register_module()
{
  return ({ 
    MODULE_PARSER,
    "Tablify", 
    "This tag generates tables.<p>"
    "<tt>&lt;tablify help&gt;&lt;/tablify&gt;</tt> gives help.\n\n<p>",
    0, 1, });
}

string html_nice_table(array subtitles, array table, mapping opt)
{
  string r = "",type;

  int m = (int)opt->modulo || 1;
  if(opt->nice || opt->nicer)
    r+="<table bgcolor=\""+(opt->bordercolor||"#000000")+"\" border=\"0\" "
       "cellspacing=\"0\" cellpadding=\"1\">\n"
       "<tr><td>\n"
       "<table border=\""+(opt->border||"0")+"\" cellspacing=\"0\" cellpadding=\"4\">\n";

  int cols=0;
  if (subtitles) {
    r += "<tr bgcolor=\""+(opt->titlebgcolor||"#112266")+"\">\n";
    foreach(subtitles, string s) {
      cols++;
      if(opt->nicer)
        r+="<th align=\"left\"><gtext nfont=\""+(opt->font||"lucida")+"\" scale=\""+
	   (opt->scale||"0.36")+"\" fg=\""+(opt->titlecolor||"white")+"\" bg=\""+
	   (opt->titlebgcolor||"#27215b")+"\""+(opt->noxml?"":" xml")+">"+s+"</gtext></th>";
      else
        r+="<th align=\"left\"><font color=\""+
	  (opt->titlecolor||"#ffffff")+"\">"+s+" &nbsp; </font></th>";
    }
    r += "</tr>\n";
  }

  for(int i = 0; i < sizeof(table); i++) {
    if(opt->nice || opt->nicer)
      r+="<tr bgcolor=\""+((i/m)%2?opt->evenbgcolor||"#ddeeff":opt->oddbgcolor||"#ffffff")+"\">";
    else
      r+="<tr>";

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
            (type=="economic-float"?((int)a[0]<0?"#ff0000":"#000000"):(opt->textcolor||"#000000"))+
            "\""+(opt->nicer?(" size=\""+(opt->size||"2")+
            "\" face=\""+(opt->face||"helvetica,arial")+"\">"):">");
          nofont="</font>";
	}

        //The right way<tm> is to preparse the whole column and find the longest string of
        //decimals and use that to calculate the maximum with of the decimal cell, insted
        //of just saying widht=30, which easily produces an ugly result.
        r+="<td align=\"right\"><table border=0 cellpadding=0 cellspacing=0><tr><td align=right>"+
          font+a[0]+nofont+"</td><td>"+font+"."+nofont+"</td><td align=\"left\" width=30>"+font+
          (sizeof(a)>1?a[1]:"0")+nofont;

        r += "</td></tr></table>";
	break;

      case "num":
      case "economic-int":
      case "int":
        string font="",nofont="";
        if(opt->nicer || type=="economic-int"){
          font="<font color=\""+
            (type=="economic-int"?((int)a[0]<0?"#ff0000":"#000000"):(opt->textcolor||"#000000"))+
            "\""+(opt->nicer?(" size=\""+(opt->size||"2")+
            "\" face=\""+(opt->face||"helvetica,arial")+"\">"):">");
          nofont="</font>";
	}

        r+="<td align=\"right\">"+font+(string)(int)round((float)s)+nofont;
	break;

      case "text":
      case "left":
      case "right":
      case "center":
      default:
        r += "<td align=\""+(type!="text"?type:(opt->cellalign||"left"))+"\" valign=\""+(opt->valign||"top")+"\">";
	if(opt->nicer) r += "<font color=\""+(opt->textcolor||"#000000")+"\" size=\""+(opt->size||"2")+
          "\" face=\""+(opt->face||"helvetica,arial")+"\">";
        r += s+(opt->nice||opt->nicer?"&nbsp;&nbsp;":"");
        if(opt->nicer) r+="</font>";
      }

      r += "</td>";
    }
    if(sizeof(table[i])<cols) r+="<td colspan=\""+(cols-sizeof(table[i]))+"\">&nbsp;</td>";
    r += "</tr>\n";
  }

  if(opt->nice || opt->nicer)
    return r+"</table></td></tr>\n</table>"+(opt->noxml?"<br>":"<br />")+"\n";

  m_delete(opt, "cellalign");
  m_delete(opt, "valign");
  return make_container("table",opt,r);
}

string container_fields(string name, mapping arg, string q, mapping m, mapping arg_list)
{
  arg_list->fields = q/(arg->separator||m->cellseparator||"\t");
  return "";
}

string tag_tablify(string tag, mapping m, string q, object id)
{
  array rows, res;
  string sep;

#if old_rxml_compat
  // RXML <1.4 compatibility stuff
  if(m->fgcolor0) {
    m->oddbgcolor=m->fgcolor0;
    m_delete(m, "fgcolor0");
    id->conf->api_functions()->old_rxml_warning[0](id, "tablify attribute fgcolor0","oddbgcolor");
  }
  if(m->fgcolor1) {
    m->evenbgcolor=m->fgcolor1;
    m_delete(m, "fgcolor1");
    id->conf->api_functions()->old_rxml_warning[0](id, "tablify attribute fgcolor1","evenbgcolor");
  }
  if(m->fgcolor) {
    m->textcolor=m->fgcolor;
    m_delete(m, "fgcolor");
    id->conf->api_functions()->old_rxml_warning[0](id, "tablify attribute fgcolor","textcolor");
  }
  if(m->rowalign) {
    m->cellalign=m->rowalign;
    m_delete(m, "rowalign");
    id->conf->api_functions()->old_rxml_warning[0](id, "tablify attribute rowalign","cellalign");
  }
  // When people have forgotten what bgcolor meant we can reuse it as evenbgcolor=oddbgcolor=m->bgcolor
  if(m->bgcolor) {
    m->bordercolor=m->bgcolor;
    m_delete(m, "bgcolor");
    id->conf->api_functions()->old_rxml_warning[0](id, "tablify attribute bgcolor","bordercolor");
  }
#endif

  if(m->help) return register_module()[2];

  mapping arg_list = ([]);
  q = parse_html(q, ([]), (["fields":container_fields]), m, arg_list);

  sep = m->rowseparator||"\n";
  m_delete(m,"rowseparator");

  rows = (q / sep) - ({""});

  sep = m->cellseparator||"\t";

  array title;
  if((m->nice||m->nicer) && (!m->notitle)) {
    title = rows[0]/sep;
    rows = rows[1..];
  }

  if(m->min)
    rows = rows[((int)m->min)..];
  if(m->max)
    rows = rows[..((int)m->max-1)];
  
  rows = Array.map(rows,lambda(string r, string s){return r/s;}, sep);

  return html_nice_table(title, rows, m + arg_list);
}

mapping query_container_callers()
{
  return ([ "tablify" : tag_tablify ]);
}

mapping query_tag_callers()
{
  return ([]);
}

