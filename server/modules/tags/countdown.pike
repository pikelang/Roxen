constant cvs_version="$Id: countdown.pike,v 1.11 1999/07/19 15:11:17 nilsson Exp $";
#include <module.h>
inherit "module";
inherit "roxenlib";

mapping set_to_julian_easter(int year) {
  int G = year % 19;
  int I = (19*G + 15) % 30;
  int J = (year + year/4 + I) % 7;
  int L = I - J;

  mapping easter=([]);

  easter->mon=3 + (L + 40)/44;
  easter->day=L + 28 - 31*(easter->mon/4);
  return easter;
}

mapping set_to_gregorian_easter(int year) {
  int G = year % 19;
  int C = year / 100;
  int H = (C - C/4 - (8*C+13)/25 + 19*G + 15) % 30;
  int I = H - (H/28)*(1 - (H/28)*(29/(H + 1))*((21 - G)/11));
  int J = (year + year/4 + I + 2 - C + C/4) % 7;
  int L = I - J;

  mapping easter=([]);

  easter->mon=3 + (L + 40)/44;
  easter->day=L + 28 - 31*(easter->mon/4);
  return easter;
}

array register_module()
{
  return ({ MODULE_PARSER, "Countdown",
	    "This module adds a new tag, when enabled, see "
	    "&lt;countdown help&gt; for usage information.",0,1 });
}

// :-) This code is not exactly conforming to the Roxen API, since it
// uses a rather private mapping the language object (which you are
// not even supposed to know the existence of). But I wanted some nice
// month->number code that did not depend on a static mapping.
// Currently, this means that you can enter the name of the month or day in
// your nativ language, if it is supported by roxen.
constant language = roxen->language;
int find_a_month(string which)
{
  which = lower_case(which);
  foreach(indices(roxen->languages), string lang)
    for(int i=1; i<13; i++)
      catch {
      if(which == lower_case(language(lang,"month")(i))[..strlen(which)])
	return i-1;
    };
  return 1;
}

int find_a_day(string which)
{
  which = lower_case(which);
  foreach(indices(roxen->languages), string lang)
    for(int i=1; i<8; i++)
      if(which == lower_case(language(lang,"day")(i))[..strlen(which)])
	return i;
  return 1;
}


string show_number(int n,mapping m)
{
  return number2string(n,m,language(m->lang,m->ordered?"ordered":"number"));
}

string describe_example(array a)
{
  return ("<b><font size=+1>"+a[0]+"</font></b><br>"
	  "<b>Source:</b> "+replace(a[1], ({ "<", ">", "&" }), 
				   ({ "&lt;", "&gt;", "&amp"}))
	  +"<br><b>Result:</b> "+a[1]+"<p>");
}

#define E(X,Y) ({ X, Y })

constant examples = 
({
  E("The age of something", "Per Hedbor is <countdown iso=1973-01-16 since display=years type=string> years old"),

  E("How many days are left to year 2000?", "There are <countdown event=year2000 display=days> days left until year 2000"),

  E("Which date is the first monday in January 1998?",
    "<countdown month=january day=monday year=1998 date display=when part=date type=ordered>"),

  E("Is this a Sunday?",
    "<if eval='<countdown day=sunday display=boolean>'>This is indeed a Sunday</if><else>Nope</else>."),

  E("On which day will the next christmas eve be?",
    "It will be a <countdown event=christmas_eve lang=en display=when date part=day type=string>"),

  E("How old Fredrik & Monica Hübinette's dog Sadie?",
    "She is <countdown iso=1998-03-29 prec=day since months display=combined> old or <countdown iso=1998-03-29 prec=day since display=dogyears> dog years."),
});

string describe_examples()
{
  return "</b><p>"+Array.map(examples, describe_example)*"";
}

string usage()
{
  return (#"<h1>The &lt;countdown&gt; tag.</h1>
This tag can count days, minutes, months, etc. from a specified date or time. It can also
give the time to or from a few special events. See below for a full list.
<p>
<b>Time:</b>
<table border=\"0\" cellpadding=\"0\" cellspacing=\"0\">
<tr valign=\"top\"><td>year = int</td><td><i>sets the year</i></td></tr>
<tr valign=\"top\"><td>month = int | month_name&nbsp;</td><td><i>sets the month</i></td></tr>
<tr valign=\"top\"><td>day = int | day_name</td><td><i>sets the weekday</i></td></tr>
<tr valign=\"top\"><td>mday = int</td><td><i>sets the day of the month</i></td></tr>
<tr valign=\"top\"><td>hour = int</td><td><i>sets the hour. Might be useful, perhaps..</i></td></tr>
<tr valign=\"top\"><td>minute = int</td><td><i>sets the minute.</i></td></tr>
<tr valign=\"top\"><td>second = int</td><td><i>sets the second.</i></td></tr>
<tr valign=\"top\"><td>iso = year-month-day</td>
  <td><i>Sets the year, month and day all at once (YYYY-MM-DD or YYYYMMDD)</i></td></tr>
<tr><td><br><b>Special events:</b></td>
<tr><td>easter</td></tr>\n
<tr><td>gregorian-easter</td></tr>\n
<tr><td>julian-easter</td></tr>\n
<tr><td>christmas</td></tr>\n
<tr><td>christmas-day</td></tr>\n
<tr><td>christmas-eve</td></tr>\n
<tr><td>year2000</td></tr>\n
<tr><td>y2k</td></tr>\n
<tr valign=\"top\"><td><br><b>Presentation:</b></tr></tr>
<tr valign=\"top\"><td>display = when</td><td><i>Shows when the time will occur.
  All arguments that are valid in a
  &lt;date&gt; tag can be used to modify the display</i></td></tr>
<tr valign=\"top\"><td>display = years</td><td><i>How many years until the time</i></td></tr>
<tr valign=\"top\"><td>display = months</td><td><i>How many months until the time</i></td></tr>
<tr valign=\"top\"><td>display = weeks</td><td><i>How many weeks until the time</i></td></tr>
<tr valign=\"top\"><td>display = days</td><td><i>How many days until the time</i></td></tr>
<tr valign=\"top\"><td>display = hours</td><td><i>How many hours until the time</i></td></tr>
<tr valign=\"top\"><td>display = minutes</td><td><i>How many minutes until the time</i></td></tr>
<tr valign=\"top\"><td>display = seconds</td><td><i>How many seconds until the time</i></td></tr>
<tr valign=\"top\"><td>display = combined</td><td><i>Shows an english text describing the time period.
  Example: 2 days, 1 hour and 5 seconds. You may use the 'prec' tag to limit how precise the description
  is. Also, you can use the 'month' tag if you want to see years/months/days instead of years/weeks/days.
</i></td></tr>
<tr valign=\"top\"><td>display = dogyears</td><td><i>How many dog-years until the time. (With one decimal)
  </i></td></tr>
<tr valign=\"top\"><td>display = boolean</td>
  <td><i>Return 1 or 0, depending on if the time is _now_ or not. The
  fuzziness of 'now' is decided by the \"prec\" option.</td></tr>
<tr valign=\"top\"><td>type=type, lang=language</td><td><i>As for 'date'. Useful values for type include
  string, number and ordered.</i></td></tr>
<tr valign=\"top\"><td>since</td><td><i>Negate the period of time (replace 'until' with 'since' in
  the above sentences to see why it is named 'since')</i></td></tr>
<tr valign=\"top\"><td>next</td><td><i>Always count down to the next event. &lt;countdown day=friday
  next&gt; says 6 on a friday as opposed to 0 without the next attribute.</i></td></tr>
<tr valign=\"top\"><td>prec</td><td><i>modifier for 'boolean' and 'combined'. Can be one of
  year, month, week, day, hour minute of second.</td></tr></table>
<p><b>Examples</b>"+describe_examples());
  
}


// This function should be fixed to support different languages.
// Possibly even implemented in the language module itself.
// Hubbe
string time_period(int t, int prec)
{
  int i;
  string *tmp=({});
  if(!t)
    return "zero seconds";

  i=t%60;
  if(i && prec<60) tmp=({i+ " second"+(i==1?"":"s") });

  t/=60;
  i=t&60;
  if(i && prec<3600) tmp=({i+ " minute"+(i==1?"":"s") })+tmp;

  t/=60;
  i=t%24;
  if(i && prec<3600*24) tmp=({i+ " hour"+(i==1?"":"s") })+tmp;

  t/=24;

  if(prec==3600*24*7) {
    if(i=t/365) tmp=({i+ " year"+(i==1?"":"s") });
    t-=365*i;
    if(i=t/7) tmp+=({i+ " week"+(i==1?"":"s") });
    t-=7*i;
    if(t) tmp+=({i+ " day"+(i==1?"":"s") });
    return String.implode_nicely(tmp);
  }

  float days_per_year = 365.242190; // Y28K safe
  float days_per_month = days_per_year/12;
  float s=(float)t;

  i=(int)(t%days_per_month);
  if(i && prec<(int)(3600*24*days_per_month)) tmp=({i+" day"+(i==1?"":"s") })+tmp;
  s=t/days_per_month;

  i=(int)(s%12);
  if(i && prec<(int)(3600*24*days_per_year)) tmp=({i+" month"+(i==1?"":"s") })+tmp;
  s=(s/12)*1.000664;

  if(i=(int)s) tmp=({i+" year"+(i==1?"":"s") })+tmp;

  return String.implode_nicely(tmp);
}

mapping clear_less_significant(mapping m, string from) {
  switch(from) {
  case "year":
    m->mon=0;
  case "mon":
    m->mday=1;
  case "day":
    m->hour=0;
  case "hour":
    m->min=0;
  case "min":
    m->sec=0;
    return m;
  }
}

int unset_from(mapping m, string from) {
  switch(from) {
  case "sec":
    if(m->minute) return 0;
  case "min":
    if(m->hour) return 0;
  case "hour":
    if(m->wday) return 0;
  case "wday":
    if(m->mday || m->iso) return 0;
  case "day":
    if(m->month || m->iso) return 0;
  case "mon":
    if(m->year || m->iso) return 0;
    return 1;
  }
}

int weekday_handler(int when, mapping time_args) {
  while((localtime(when)->wday) != (time_args->wday))
    when += 3600*24;
  if(!zero_type(time_args->mon) && localtime(when)->mon!=time_args->mon)
    return -1;
  if(!zero_type(time_args->year) && localtime(when)->year!=time_args->year)
    return -1;
  return when;
}

int old_RXML_compat=1;

string tag_countdown(string t, mapping m, object id)
{

  if(old_RXML_compat) {

    foreach( ({ 
      ({"min","minute"}),
      ({"sec","second"}),
      ({"age","since"}) }), array tmp)
      { if(m[tmp[0]]) { m[tmp[1]]=m[tmp[0]]; m_delete(m, tmp[0]); } }

    if(m->prec=="min") m->prec="minute";

    foreach(({"christmas_eve","christmas_day","christmas","year2000","easter"}), string tmp)
      if(m[tmp]) { m->event=tmp; m_delete(m, tmp); }

    if(m->nowp) {
      m->round="up";
      m->display="boolean";
    }

    if(!m->display) {
      foreach(({"seconds","minutes","hours","days","weeks","months","years",
		"dogyears","combined","when"}), string tmp) {
        if(m[tmp]) m->display=tmp;
        m_delete(m, tmp);
      }
    }

  }

  if(m->sec || m->prec=="second")
    CACHE(1);
  else
    CACHE(59);

  if(m->help) return usage();

  float days_per_year = 365.242190; // Y28K safe

  string tprec;
  int unix_now = time();
  mapping now = localtime(unix_now);
  mapping time_args = ([]);
  time_args->year=now->year;
  time_args->mon=now->mon;
  time_args->mday=now->mday;
  time_args->hour=now->hour;
  time_args->min=now->min;
  time_args->sec=now->sec;

  if(m->year) {
       time_args->year = ((int)m->year-1900);
       if(time_args->year < -1800)
	 time_args->year += 1900;
       tprec="year";
       time_args=clear_less_significant(time_args, "year");
  }
  if(m->iso) {
       if(sscanf(m->iso, "%d-%d-%d", 
		 time_args->year, time_args->mon, time_args->mday)==3 ||
          sscanf(m->iso, "%4d%2d%2d",
		 time_args->year, time_args->mon, time_args->mday)==3)
       {
         time_args=clear_less_significant(time_args, "day");
	 tprec="day";
	 time_args->mon--;
	 if(time_args->year>1900) time_args->year-=1900;
       }
  }
  if(m->month) {
       if(!(int)m->month) m->month = find_a_month(m->month)+1;
       tprec="month";
       time_args->mon = (int)m->month-1;
       if(time_args->mon!=now->mon) time_args=clear_less_significant(time_args, "mon");
  }
  if(m->day) {
       if(!(int)m->day) m->day = find_a_day(m->day);
       tprec="day";
       time_args->wday = (int)m->day-1;
       if(time_args->wday!=now->wday) time_args=clear_less_significant(time_args, "day");
  }
  if(m->mday) {
       tprec="day";
       time_args->mday = (int)m->mday;
       if(time_args->mday!=now->mday) time_args=clear_less_significant(time_args, "day");
  }
  if(m->hour) {
       tprec="hour";
       time_args->hour = (int)m->hour;
       if(time_args->hour!=now->hour) time_args=clear_less_significant(time_args, "hour");
  }
  if(m->minute) {
       tprec="minute";
       time_args->min = (int)m->minute;
       if(time_args->min!=now->min) time_args=clear_less_significant(time_args, "min");
  }
  if(m->second) {
       tprec="second";
       time_args->sec = (int)m->second;
  }

  if(time_args->mon < now->mon && unset_from(m,"mon")) time_args->year++;
  else if(time_args->mday < now->mday && unset_from(m,"day")) time_args->mon++;
  else if(time_args->hour < now->hour && unset_from(m,"hour")) time_args->mday++;
  else if(time_args->min < now->min && unset_from(m,"min")) time_args->hour++;
  else if(time_args->sec < now->sec && unset_from(m,"sec")) time_args->min++;

  if(m->event) {
    switch(m->event) {

    case "christmas-eve":
      time_args->mday=24;
      time_args->mon=11;
      tprec="day";
    break;

    case "christmas":
    case "christmas-day":
      time_args->mday=25;
      time_args->mon=11;
      tprec="day";
    break;

    case "year2000":
    case "y2k":
      time_args->year=100;
      time_args=clear_less_significant(time_args, "year");
      tprec="day";
    break;

    case "julian-easter":
      mapping easter=set_to_julian_easter(time_args->year+1900);
      if(easter->mon-1 < time_args->mon ||
              (easter->mon-1 == time_args->mon && easter->day < time_args->day))
        easter=set_to_julian_easter(++(time_args->year)+1900);
      time_args->mon=easter->mon-1;
      time_args->mday=easter->day;
      time_args=clear_less_significant(time_args, "day");
      tprec="day";
    break;

    case "easter":
    case "gregorian-easter":
      mapping easter=set_to_gregorian_easter(time_args->year+1900);
      if(easter->mon-1 < time_args->mon ||
               (easter->mon-1 == time_args->mon && easter->day < time_args->day))
        easter=set_to_gregorian_easter(++(time_args->year)+1900);
      time_args->mon=easter->mon-1;
      time_args->mday=easter->day;
      tprec="day";
    break;
    }
    m_delete(m,"event");
  }

  int prec;
  if(m->prec) tprec = m->prec;

  switch(tprec)
  {
   case "year": prec=(int)(3600*24*days_per_year); break;
   case "month": prec=(int)(3600*24*(days_per_year/12)); break;
   case "week": prec=3600*24*7; break;
   case "day": prec=3600*24; break;
   case "hour": prec=3600; break;
   case "minute": prec=60; break;
   default: prec=(int)m->prec?(int)m->prec:1;
  }

  int when;
  if(catch {
    when = mktime(time_args);
  })
    return "Invalid time.";

  if(!zero_type(time_args->wday)) {
    when=weekday_handler(when, time_args);
    if(when==-1) return "Invalid time.";
  }

  //FIXME: Clear less significant
  if((m->next) && when==unix_now) {
    if(m->month && unset_from(m,"mon")) time_args->year++;
    if(m->mday && unset_from(m,"day")) time_args->mon++;
    if(m->day && unset_from(m,"wday")) time_args->mday+=6;
    if(m->hour && unset_from(m,"hour")) time_args->mday++;
    if(m->minute && unset_from(m,"min")) time_args->hour++;
    if(m->second && unset_from(m,"sec")) time_args->sec++;
    if(catch {
      when = mktime(time_args);
    })
      return "Invalid time.";
    //if(!zero_type(time_args->wday)) {
    //  when=weekday_handler(when, time_args);
    //  if(when==-1) return "Invalid time.";
    //}
  }

  foreach(({"second","minute","hour","mday","day","month","year","iso","prec"}), string tmp) {
    m_delete(m, tmp);
  }

  int delay = when-unix_now;
  if(m->since) delay = -delay;

  if(m->round=="up") {
    delay=((delay/prec)+(delay?1:0))*prec;
    when=((when/prec)+(delay?1:0))*prec;
  }

  switch(m->display) {
    case "when":
    m->unix_time = (string)when;
    m_delete(m, "display");
    return make_tag("date", m);

    case "combined":
    delay-=delay%prec;
    return time_period(delay, prec);

    case "dogyears":
    return sprintf("%1.1f",(delay/(3600*24*days_per_year/7)));

    case "years":
    return  show_number((int)(delay/(3600*24*days_per_year)),m);

    case "months":
    return show_number((int)(delay/((3600*24*days_per_year)/12)),m);

    case "weeks":
    return  show_number(delay/(3600*24*7),m);

    case "days":
    return   show_number(delay/(3600*24),m);

    case "hours":
    return  show_number(delay/3600, m);

    case "minutes":
    return show_number(delay/60,m);

    case "seconds":
    return show_number(delay,m);

    case "boolean":
    return (string)((when/prec) == (mktime(now)/prec));

    case "debug":
      string ret="<pre>Debug.\n\ntime_args.\n";
      foreach(indices(time_args), string tmp)
        ret+=tmp+": "+time_args[tmp]+"\n";
      ret+="\nnow.\n";
      foreach(indices(now), string tmp)
        ret+=tmp+": "+now[tmp]+"\n";
      ret+="\nunix_now: "+unix_now+"\n    when: "+when+"\n   delay: "+delay+"\n\nLeft on arglist.\n";
      foreach(indices(m), string tmp)
        ret+=tmp+": "+m[tmp]+"\n";
      return ret+"</pre>\n";
  }

  //FIXME: L10N
  if(tprec) return delay/prec+" "+tprec+(delay/prec>1?"s":"");

  m->unix_time = (string)when;
  return "I don't think I understood that, but I think you want to count to "+
    make_tag("date",m)+" to which it is "+when+" seconds. Write &lt;countdown"
    " help&gt; to get an idea of what you ougt to write.";
}

mapping query_tag_callers()
{
  return ([ "countdown":tag_countdown, ]);
}
