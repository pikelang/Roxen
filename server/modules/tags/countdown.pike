// This is a roxen module. Copyright © 1997 - 2009, Roxen IS.
//

constant cvs_version="$Id$";
#include <module.h>
inherit "module";

constant thread_safe=1;
constant module_type = MODULE_TAG;
constant module_name = "Tags: Countdown";
constant module_doc  = "Provides the <tt>&lt;countdown&gt;</tt> tag, that "
"shows the time remaining until a certain date.";

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=(["countdown":#"<desc tag='tag'><p><short>
This tag can count days, minutes, months, etc. from a specified date
or time.</short> It can also give the time to or from a few special
events. See below for a full list.</p></desc>

<p>Time:</p>
<attr name='year' value='number'><p>Sets the year to count down to.</p></attr>
<attr name='month' value='number|month_name'><p>Sets the month to count down to. If given as a
  number January is 1.</p></attr>
<attr name='day' value='number|day_name'><p>Sets the weekday to count down to. If given as
  a number Sunday is 1.</p></attr>
<attr name='mday' value='number'><p>Sets the day of the month to count down to.</p></attr>
<attr name='hour' value='number'><p>Sets the hour to count down to.</p></attr>
<attr name='minute' value='number'><p>Sets the minute to count down to.</p></attr>
<attr name='second' value='number'><p>Sets the second to count down to.</p></attr>
<attr name='iso' value='year-month-day'><p>Sets the year, month and day to count down to.
  (YYYY-MM-DD, YYYYMMDD or YYYY-MMM-DD).</p>
<ex><countdown iso='2020-FEB-12'/></ex>
</attr>
<attr name='event' value='easter,gregorian-easter,julian-easter,christmas,christmas-day,christmas-eve'><p>
Sets the time of an event to count down to.</p></attr>

<attr name='years' value='number'><p>Add this number of years to the result.</p></attr>
<attr name='months' value='number'><p>Add this number of months to the result.</p></attr>
<attr name='weeks' value='number'><p>Add this number of weeks to the result.</p></attr>
<attr name='days' value='number'><p>Add this number of days to the result.</p></attr>
<attr name='hours' value='number'><p>Add this number of hours to the result.</p></attr>
<attr name='beats' value='number'><p>Add this number of beats to the result.</p></attr>
<attr name='minutes' value='number'><p>Add this number of minutes to the result.</p></attr>
<attr name='seconds' value='number'><p>Add this number of seconds to the result.</p></attr>
<attr name='now' value='year-month-day'><p>Sets the 'present' time, if other than really present time. (YYYY-MM-DD, YYYYMMDD or YYYY-MMM-DD)</p>

<ex><countdown now=\"1999-12-24\" year=\"2000\" display=\"days\"/></ex>
</attr>


<p>Presentation:</p>

<attr name='display' value='when|years|months|weeks|days|hours|beats|minutes|seconds|combined|dogyears|boolean'>

<list type='dl'>
<item name='display=when'><p>Shows when the time will occur. All arguments that are valid in
                         <xref href='date.tag' /> can be used to modify the display.</p></item>
<item name='display=years'><p>How many years until the time.</p></item>
<item name='display=months'><p>How many months until the time.</p></item>
<item name='display=weeks'><p>How many weeks until the time.</p></item>
<item name='display=days'><p>How many days until the time.</p></item>
<item name='display=hours'><p>How many hours until the time.</p><ex><countdown day='friday' display='hours'/></ex></item>
<item name='display=beats'><p>How many beats until the time.</p></item>
<item name='display=minutes'><p>How many minutes until the time.</p></item>
<item name='display=seconds'><p>How many seconds until the time.</p></item>
<item name='display=combined'><p>Shows an english text describing the time period.
                         Example: 2 days, 1 hour and 5 seconds. You may use the 'prec'
                         attribute to limit how precise the description is. Also, you can
                         use the 'month' attribute if you want to see years/months/days
                         instead of years/weeks/days.</p>

<ex>The world will go under in <countdown year='2038' display='combined' prec='day'/>.</ex></item>
<item name='display=dogyears'><p>How many dog-years until the time. (With one decimal)</p><ex><countdown years='2' display='dogyears'/></ex></item>
<item name='display=boolean'><p>Return true or false (1 or 0), depending on if the time is now or not. The fuzziness of 'now' is decided by the 'prec' option.</p>

<ex><b>Is this a Sunday?</b>
<define variable='var.test' preparse=''><countdown day='sunday' display='boolean'/></define>
<if variable='var.test = 1'>Yes, this is a Sunday.</if>
<else>No, it isn't.</else></ex>
</item>
</list>

</attr>

<attr name='type' value='type'><p>As for 'date'. Useful values for type include string, number and ordered.</p></attr>
<attr name='lang' value='langcodes'><p>The language in which the result should be written if the type is string.</p>

<ex>Heute ist es ungefähr <countdown event='christmas' display='months' type='string' lang='de'/> Monate bis Weinachten.</ex>
</attr>

<attr name='since'><p>Negate the period of time.</p>
<ex>
 I am <countdown iso='1980-06-28' since='' display='years' type='string'/> years old.</ex>
</attr>

<attr name='next'><p>Always count down to the next event.
<tag>countdown day='friday' next=''</tag> says 6 on a friday as opposed
to 0 without the next attribute.</p>

<ex>It is <countdown day='monday' next=''/> to monday.</ex>

</attr>
<attr name='prec' value='year|month|week|day|hour|minute|second'><p>Modifies the precision for 'boolean'- and 'combined'-arguments.</p></attr>"
		]);
#endif

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

void start( int num, Configuration conf )
{
  module_dependencies (conf, ({ "rxmltags" }));
}

array languages = roxen->list_languages();
constant language_low = roxen->language_low;
int find_a_month(string which)
{
  which = lower_case(which);
  foreach(languages, string lang)
    for(int i=1; i<13; i++)
      catch {
      if(which == lower_case(language_low(lang)->month(i))[..strlen(which)])
	return i-1;
    };
  return 1;
}

int find_a_day(string which)
{
  which = lower_case(which);
  foreach(languages, string lang)
    for(int i=1; i<8; i++)
      if(which == lower_case(language_low(lang)->day(i))[..strlen(which)])
	return i;
  return 1;
}

constant language=roxen->language;
string show_number(int n, mapping m, RequestID id)
{
  return Roxen.number2string(n, m, language(m->lang||id->misc->defines->pref_language,
					    m->ordered?"ordered":"number", id));
}

// This function should be fixed to support different languages.
// Possibly even implemented in the language module itself.
// Hubbe
string time_period(int t, int prec)
{
  int i;
  array(string) tmp=({});
  if(!t)
    return "zero seconds";

  i=t%60;
  if(i && prec<60) tmp=({i+ " second"+(i==1?"":"s") });

  t/=60;
  i=t%60;
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
  return when;
}

class TagCountdown {
  inherit RXML.Tag;
  constant name = "countdown";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      result = countdown(args, id);
      return 0;
    }
  }
}

string countdown(mapping m, RequestID id)
{
  if(m->sec || m->prec=="second")
    CACHE(1);
  else
    CACHE(59);

  float days_per_year = 365.242190; // Y28K safe

  string tprec;
  int unix_now = time(1);
  if(m->now) {
    mapping newnow=([]);
    if(sscanf(m->now, "%d-%d-%d",
    	 newnow->year, newnow->mon, newnow->mday)==3 ||
       sscanf(m->now, "%4d%2d%2d",
	 newnow->year, newnow->mon, newnow->mday)==3 ||
       sscanf(m->now, "%d-%s-%d",
         newnow->year, newnow->mon, newnow->mday) == 3)
       {
	 if (stringp(newnow->mon))
           newnow->mon = ([ "jan":  1, "feb":  2, "mar":  3, "apr":  4,
                     "may":  5, "jun":  6, "jul":  7, "aug":  8,
                     "sep":  9, "oct": 10, "nov": 11, "dec": 12 ])
	     [lower_case(sprintf("%s", newnow->mon))[0..2]];
         if (newnow->year>1900) newnow->year-=1900;
         newnow->mon--;
         if(catch {
           unix_now = mktime(newnow);
         })
           RXML.parse_error("Bad now argument.");
       }
  }
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
		 time_args->year, time_args->mon, time_args->mday)==3 ||
          sscanf(m->iso, "%d-%s-%d",
                 time_args->year, time_args->mon, time_args->mday) == 3)
	 {
	   if (stringp(time_args->mon))
           time_args->mon = ([ "jan":  1, "feb":  2, "mar":  3, "apr":  4,
                       "may":  5, "jun":  6, "jul":  7, "aug":  8,
                       "sep":  9, "oct": 10, "nov": 11, "dec": 12 ])
	     [lower_case(sprintf("%s", time_args->mon))[0..2]];
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
    switch(m_delete(m, "event")) {

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
      easter=set_to_gregorian_easter(time_args->year+1900);
      if(easter->mon-1 < time_args->mon ||
               (easter->mon-1 == time_args->mon && easter->day < time_args->day))
        easter=set_to_gregorian_easter(++(time_args->year)+1900);
      time_args->mon=easter->mon-1;
      time_args->mday=easter->day;
      tprec="day";
    break;
    }
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
   default: prec=(int)m->prec || 1;
  }

  int when;
  if(catch( when = mktime(time_args) ))
    RXML.run_error("Resulted in an invalid time.");

  if(!zero_type(time_args->wday)) {
    int wen=when;
    when=weekday_handler(when, time_args);
  }

  //FIXME: Clear less significant
  if(m->next && when==unix_now) {
    if(m->month && unset_from(m,"mon")) time_args->year++;
    if(m->mday && unset_from(m,"day")) time_args->mon++;
    if(m->day && unset_from(m,"wday")) time_args->mday+=6;
    if(m->hour && unset_from(m,"hour")) time_args->mday++;
    if(m->minute && unset_from(m,"min")) time_args->hour++;
    if(m->second && unset_from(m,"sec")) time_args->sec++;
    if(catch( when = mktime(time_args) ))
      RXML.run_error("Resulted in an invalid time.");
    //if(!zero_type(time_args->wday)) {
    //  when=weekday_handler(when, time_args);
    //}
    m_delete(m, "next");
  }

  foreach(({"second","minute","hour","mday","day","month","year","iso","prec"}), string tmp) {
    m_delete(m, tmp);
  }

  when+=Roxen.time_dequantifier(m);
  int delay = when-unix_now;
  if(m->since) delay = -delay;

  if(m->round=="up") {
    delay=((delay/prec)+(delay?1:0))*prec;
    when=((when/prec)+(delay?1:0))*prec;
  }

  switch(m_delete(m, "display")) {
    case "when":
    return Roxen.tagtime(when, m, id, language);

    case "combined":
    delay-=delay%prec;
    return time_period(delay, prec);

    case "dogyears":
    // FIXME: 7 per year the first two years, then 5 per year. Perhaps.
    return sprintf("%1.1f",(delay/(3600*24*days_per_year/7)));

    case "years":
    return  show_number((int)(delay/(3600*24*days_per_year)), m, id);

    case "months":
    return show_number((int)(delay/((3600*24*days_per_year)/12)), m, id);

    case "weeks":
    return  show_number(delay/(3600*24*7), m, id);

    case "days":
    return   show_number(delay/(3600*24), m, id);

    case "hours":
    return  show_number(delay/3600, m, id);

    case "beats":
    return "@"+show_number(delay/(3600*24/1000), m, id);

    case "minutes":
    return show_number(delay/60, m, id);

    case "seconds":
    return show_number(delay, m, id);

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

  return "I don't think I understood that, but I think you want to count to "+
    Roxen.tagtime(when, m, id, language)+" to which it is "+when+" seconds. Write &lt;countdown"
    " help&gt; to get an idea of what you ougt to write.";
}
