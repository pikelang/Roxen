/*
 * $Id$
 */

#include <roxen.h>
//<locale-token project="admin_tasks"> LOCALE </locale-token>
#define LOCALE(X,Y)  _STR_LOCALE("admin_tasks",X,Y)

constant action = "status";

string name= LOCALE(10, "List fonts");
string doc = LOCALE(11, "List all available fonts");


string versions(string font)
{
  array res=({ });
  array b = available_font_versions(font,32);
  if (!b || !sizeof(b))
    return "<b>"+LOCALE("dH","Not available.")+"</b>";
  array a = map(b,describe_font_type);
  mapping m = mkmapping(b,a);
  foreach(sort(indices(m)), string t)
    res += ({ m[t] });
  return String.implode_nicely(res);
}

mapping info;
string list_font(string font)
{
  string fn = replace(lower_case( font ), " ", "_" );

  string tmpl = #"
    {{ #name }}
      <h3 class='section{{^do_info}} no-margin-bottom{{/do_info}}'>{{ name }}
        <small>&ndash; {{ versions }}</small></h3>
    {{ /name }}
    {{ #do_info }}
      <table class='auto indent extra'>
        {{ #info }}
          <tr>
            <th>{{ key }}:</th>
            <td>{{ value }}
          </tr>
        {{ /info }}
      </table>
    {{ /do_info }}";

  mapping data = ([
    "name" : map(replace(font,"_"," ")/" ", capitalize)*" ",
    "versions" : versions(font),
    "info" : ({})
  ]);

  if (mapping m = info[fn]) {
    data->do_info = true;

    foreach( sort( indices( m ) - ({"name","versions"}) ), string i ) {
      if (intp(m[i]) || (stringp(m[i]) && sizeof(m[i]))) {
        data->info += ({ ([ "key" : i, "value" : (string)m[i] ]) });
      }
    }
  }

  Mustache m = Mustache();
  string res = m->render(tmpl, data);
  destruct(m);
  return res;
}

string font_loaders( )
{
  string res ="";
  foreach( roxen.fonts.font_handlers, FontHandler fl )
  {
    int nf =  sizeof( fl->available_fonts() );
    res += "<dl><dt>"+fl->name+" ("+nf
        +" font"+(nf==1?"":"s")+")</dt>"
        "<dd>"+fl->doc+"</dd></dl>";
  }
  return res;
}

string page_0(RequestID id)
{
  array fonts = roxen.fonts.available_fonts(1);
  array q = roxen.fonts.get_font_information();
  info = mkmapping( q->name, q );
  string res=("<input type='hidden' name='action' value='listfonts.pike'/>"
              "<input type='hidden' name='doit' value='indeed'/>\n"
              "<h2 class='no-margin-top'>" +
              LOCALE(58,"Available font loaders") + "</h2><p>"+
              font_loaders()+"<h3 class='section'>" +
                LOCALE("dI","All available fonts") + "</h3><p>");

  foreach(sort(fonts), string font) {
    res += list_font(font);
  }

  res += ("</p><hr class='section'><p>" + LOCALE(236,"Example text") + ": "
          "<input name=text size=46 value='" +
          LOCALE(237,"Jackdaws love my big sphinx of quartz.") +
          "'></p><hr class='section'>"
          "<table><tr><td>"
          "<cf-cancel href='?class=status&amp;&usr.set-wiz-id;'/></td>"
          "<td class='text-right'>"
          "<cf-next/></td></tr></table>");
  return res;
}

string page_1(RequestID id)
{
  string res="";
  mapping v  = id->real_variables;
  string txt = v->text && v->text[0];
  foreach(roxen.fonts.available_fonts(), string fn)
    res += Roxen.html_encode_string( fn )+":<br />\n"
      "<gtext fontsize=16 align='top' font='"+fn+"'>"+Roxen.html_encode_string(txt)+"</gtext><br>"
      "<gtext fontsize=32 align='top' font='"+fn+"'>"+Roxen.html_encode_string(lower_case(txt))+"</gtext><br>"
      "<gtext fontsize=48 align='top' font='"+fn+"'>"+Roxen.html_encode_string(upper_case(txt))+"</gtext><p>";
  return res+"<br /></p><p>\n<cf-ok/></p>";
}

mixed parse( RequestID id )
{
  if( id->variables->doit )
    return page_1( id );
  return page_0( id );
}
