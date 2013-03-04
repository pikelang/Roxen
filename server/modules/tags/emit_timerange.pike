// This is a roxen module. Copyright © 2001 - 2009, Roxen IS.

#include <module.h>
inherit "module";

//<locale-token project="mod_emit_timerange">LOCALE</locale-token>
//<locale-token project="mod_emit_timerange">SLOCALE</locale-token>
#define SLOCALE(X,Y)  _STR_LOCALE("mod_emit_timerange",X,Y)
#define LOCALE(X,Y)  _DEF_LOCALE("mod_emit_timerange",X,Y)
// end locale stuff

constant cvs_version = "$Id$";
constant thread_safe = 1;
constant module_uniq = 1;
constant module_type = MODULE_TAG;
constant module_name = "Tags: Calendar tools";
constant module_doc  = "This module provides the emit sources \"timerange\" and"
" \"timezones\" and the scope \"calendar\".";

#ifdef TIMERANGE_VALUE_DEBUG
#define DEBUG(X ...) report_debug( X )
#else
#define DEBUG(X ...)
#endif

// <emit source="timerange"
//   {from|to}-{date|time|{year/month/week/day/hour/minute/second}}="date/time specifier"
//   unit="{year/month/week/day/hour/minute/second}"
//   [calendar="{ISO/...}"]
// > &_.week.day.name; and so on from the look of the below scope_layout </emit>

protected constant units =        ({ "Year", "Month", "Week", "Day",
				     "Hour", "Minute", "Second" });
protected constant calendars =    ({ "ISO", "Gregorian", "Julian", "Coptic",
				     "Islamic", "Discordian", "unknown" });
protected constant output_units = ({ "years", "months", "weeks", "days",
				     "hours", "minutes", "seconds", "unknown"});
// output_unit_no is used for the comparing when using query attribute.
protected constant ouput_unit_no = ({ 3,6,0,9,12,15,18,0 });
protected constant scope_layout = ([ // Date related data:
  "ymd"			: "format_ymd",
  "ymd_short"		: "format_ymd_short",
  "date"		: "format_ymd",
  "year"		: "year_no",
  "year.day"		: "year_day",
  "year.name"		: "year_name",
  "year.is-leap-year"	: "p:leap_year", // predicate
  "month"		: "month_no",
  "months"		: "month_no:%02d",
  "month.day"		: "month_day",
  "month.days"		: "month_day:%02d",
  "month.name"		: "month_name",
  "month.short-name"	: "month_shortname",
  "month.number_of_days" : "number_of_days",
  "month.number-of-days" : "number_of_days",
  "week"		: "week_no",
  "weeks"		: "week_no:%02d",
  "week.day"		: "week_day",
  "week.day.name"	: "week_day_name",
  "week.day.short-name"	: "week_day_shortname",
  "week.name"		: "week_name",
  "day"			: "month_day",
  "days"		: "month_day:%02d",
  // Time zone dependent data:
  "time"		: "format_tod",
  "timestamp"		: "format_time",
  "hour"		: "hour_no",
  "hours"		: "hour_no:%02d",
  "minute"		: "minute_no",
  "minutes"		: "minute_no:%02d",
  "second"		: "second_no",
  "seconds"		: "second_no:%02d",
  "timezone"		: "tzname_iso",
  "timezone.name"	: "tzname",
  "timezone.iso-name"	: "tzname_iso",
  "timezone.seconds-to-utc" : "utc_offset",
  // Misc data:
  "unix-time"		: "unix_time",
  "julian-day"		: "julian_day",
  ""			: "format_nice",
  // Methods that index to a new timerange object:
  "next"		: "o:next",
  "next.second"		: "o:next_second",
  "next.minute"		: "o:next_minute",
  "next.hour"		: "o:next_hour",
  "next.day"		: "o:next_day",
  "next.week"		: "o:next_week",
  "next.month"		: "o:next_month",
  "next.year"		: "o:next_year",
  "prev"		: "o:prev",
  "prev.second"		: "o:prev_second",
  "prev.minute"		: "o:prev_minute",
  "prev.hour"		: "o:prev_hour",
  "prev.day"		: "o:prev_day",
  "prev.week"		: "o:prev_week",
  "prev.month"		: "o:prev_month",
  "prev.year"		: "o:prev_year",
  "this"		: "o:same",
  "this.second"		: "o:this_second",
  "this.minute"		: "o:this_minute",
  "this.hour"		: "o:this_hour",
  "this.day"		: "o:this_day",
  "this.week"		: "o:this_week",
  "this.month"		: "o:this_month",
  "this.year"		: "o:this_year",
  // Returns the current module default settings
  "default.calendar"	: "q:calendar",
  "default.timezone"	: "q:timezone",
  "default.timezone.region":"TZ:region",
  "default.timezone.detail":"TZ:detail",
  "default.language"	: "q:language",
]);
protected constant iso_weekdays = ([ "monday": 0, "tuesday": 1, "wednesday": 2,
				     "thirsday": 3, // sic
				     "thursday": 3, "friday": 4,"saturday": 5,
				     "sunday": 6]);
protected constant gregorian_weekdays = ([ "sunday": 0, "monday": 1,
					   "tuesday": 2, "wednesday": 3,
					   "thirsday": 4, // sic
					   "thursday": 4, "friday": 5,
					   "saturday": 6]);

protected mapping layout;
//! create() constructs this module-global recursive mapping,
//! with one mapping level for each dot-separated segment of the
//! indices of the scope_layout constant, sharing the its values.
//! Where collisions occur, such as "week" and "week.name", the
//! resulting mapping will turn out "week" : ([ "" : "week_no",
//! "day" : "week_day" ]).


//! A bunch of auto-generated methods that go from one TimeRange object to
//! another, to facilitate making navigation lists of various sorts et al.
Calendar.TimeRange prev(Calendar.TimeRange t) { return t->prev(); }
Calendar.TimeRange same(Calendar.TimeRange t) { return t; }
Calendar.TimeRange next(Calendar.TimeRange t) { return t->next(); }
function(Calendar.TimeRange:Calendar.TimeRange)
  prev_year,prev_month,prev_week,prev_day,prev_hour,prev_minute,prev_second,
  this_year,this_month,this_week,this_day,this_hour,this_minute,this_second,
  next_year,next_month,next_week,next_day,next_hour,next_minute,next_second;

function(Calendar.TimeRange:Calendar.TimeRange) get_prev_timerange(string Unit)
{ return lambda(Calendar.TimeRange t) { return t - Calendar[Unit]();}; }
function(Calendar.TimeRange:Calendar.TimeRange) get_this_timerange(string unit)
{
#if 0
  if(unit == "day")
    return lambda(Calendar.TimeRange t) { return t->day(1); };
#endif
  return lambda(Calendar.TimeRange t) { return t[unit](); };
}
function(Calendar.TimeRange:Calendar.TimeRange) get_next_timerange(string Unit)
{ return lambda(Calendar.TimeRange t) { return t + Calendar[Unit]();}; }

void create(Configuration conf)
{
  DEBUG("%O->create(%O)\b", this_object(), conf);
  if(layout)
  {
    DEBUG("\b => layout already defined.\n");
    return;
  }

  foreach(units, string Unit)
  {
    string unit = lower_case(Unit);
    this_object()["prev_"+unit] = get_prev_timerange(Unit);
    this_object()["this_"+unit] = get_this_timerange(unit);
    this_object()["next_"+unit] = get_next_timerange(Unit);
  }


  layout = ([]);
  array idx = indices( scope_layout ),
	vals = values( scope_layout );
  for(int i = 0; i < sizeof( scope_layout ); i++)
  {
    array split = idx[i] / ".";
    mapping t1 = layout, t2;
    int j, last = sizeof( split ) - 1;
    foreach(split, string index)
    {
      string|function value = vals[i];
      if(sscanf(value, "o:%s", value))
	value = [function]this_object()[value];
      if(j == last)
	if(t2 = t1[index])
	  if(mappingp(t2))
	    t1[index] += ([ "" : value ]);
	  else
	    t1 += ([ index : value,
		     "" : t2 ]);
	else
	  t1[index] = value;
      else
	if(t2 = t1[index])
	  if(mappingp(t2))
	    t1 = t2;
	  else
	    t1 = t1[index] = ([ "" : t2 ]);
	else
	  t1 = t1[index] = ([]);
      j++;
    }
  }

  int inited_from_scratch = 0;
  if(!calendar)
    inited_from_scratch = !!(calendar = Calendar.ISO_UTC);

  defvar("calendar", Variable.StringChoice("ISO", calendars-({"unknown"}), 0,
	 "Default calendar type", "When no other calendar type is given, the "
	 "rules of this calendar will be used. This also defines the calendar "
	 "used for the calendar scope."))->set_changed_callback(lambda(object c)
	 { calendar = calendar->set_calendar(c->query()); });

  // Could perhaps be done as a two-level widget for continent/region too using
  // sort(Array.uniq(column(map(Calendar.TZnames.zonenames(),`/,"/"),0))), but
  // where does UTC fit in that scheme? Nah, let's keep it simple instead:
  defvar("timezone", TZVariable("UTC", 0, "Default time zone",
	 "When no other time zone is given, this time zone will be used. "
	 "This also defines the time zone for the calendar scope. Some "
	 "examples of valid time zones include \"Europe/Stockholm\", \"UTC\", "
	 "\"UTC+3\" and \"UTC+10:30\"."))->set_changed_callback(lambda(object t)
	 {
	   calendar = calendar->set_timezone(t->query());
	   cached_calendars = ([]);
	 });

  array known_languages = filter(indices(Calendar.Language), is_supported);
  known_languages = sort(map(known_languages, wash_language_name));
  defvar("language", Variable.StringChoice("English", known_languages, 0,
					   "Default calendar language",
	 "When no other language is given, this language will be used. "
	 "This also defines the language for the calendar scope.\n"))
	 ->set_changed_callback(lambda(Variable.Variable language)
	 {
	   calendar = calendar->set_language(language->query());
	   cached_calendars = ([]);
	 });

  defvar ("db_name",
	  Variable.DatabaseChoice( " none", 0,
				   "Default database", #"\
<p>Default database to use with the \"query\" attribute. If set to
\"none\", the default database configured in the \"SQL tags\" module
is used.</p>")
	  ->set_configuration_pointer( my_configuration ) );

  if(inited_from_scratch)
  {
    calendar = Calendar[query("calendar")]
	     ->set_timezone(query("timezone"))
	     ->set_language(query("language"));
  }

  DEBUG("\b => layout: %O.\n", layout);
}

int is_supported(string class_name)
{ return sizeof(array_sscanf(class_name, "c%[^_]") * "") > 3; }

string wash_language_name(string class_name)
{ return String.capitalize(lower_case(class_name[1..])); }

int is_valid_timezone(string tzname)
{ return (Calendar.Timezone[tzname])? 1 : 0; }

class TZVariable
{
  inherit Variable.String;

  array(string) verify_set_from_form( mixed new )
  {
    if(is_valid_timezone( [string]new ))
      return ({ 0, [string]new - "\r" - "\n" });
    return ({ "Unknown timezone " + [string]new, query() });
  }
}

class TagIfIsValidTimezone
{
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "is-valid-timezone";

  int(0..1) eval(string tzname, RequestID id)
  {
    return is_valid_timezone(tzname);
  }
}

object calendar; // the default calendar

void start()
{
  query_tag_set()->prepare_context = set_entities;
}

string status()
{
  return sprintf("Calendar: %O<br />\n", calendar);
}

void set_entities(RXML.Context c)
{
  c->add_scope("calendar", TimeRangeValue(calendar->Second(time(1)),
					  "second", ""));
}

//! Plays the role as both an RXML.Scope (for multi-indexable data
//! such as scope.year.is-leap-year and friends) and an RXML.Value for
//! the leaves of all such entities (as well as the one-dot variables,
//! for example scope.julian-day).
class TimeRangeValue(Calendar.TimeRange time,	// the time object we represent
		     string type,		// its type ("second"..."year")
		     string parent_scope,       // e g "" or "calendar.next"
		     string|void lang           // e.g. "sv" the language...
		     )
{
  inherit RXML.Scope;

  constant is_RXML_encodable = 1;

  array(int|string) _encode()
  {
    array(int|string) a = ({ time->unix_time(), time->calendar()->calendar_name(),
			     type, time->timezone()->zoneid, parent_scope,
			     lang||query("language") });
    return a;
  }

  void _decode( array(int|string) a )
  {
    [int t, string cal_name, string type, string tz, parent_scope, lang] = a;
    time = Calendar[cal_name||"ISO"]["Second"](t);
    if(tz && sizeof(tz))
      time = time->set_timezone(tz);
    time->set_language(lang);
  }

  //! Once we have the string pointing out the correct time object
  //! method, this method calls it from the @[time] object and
  //! returns the result, properly quoted.
  //! @param calendar_method
  //!   the name of a method in a @[Calendar.TimeRange] object,
  //!   possibly prefixed with the string @tt{"p:"@}, which signifies
  //!   that the function returns a boolean answer that in RXML should
  //!   return either of the strings @tt{"yes"@} or @tt{"no"@}.
  protected string fetch_and_quote_value(string calendar_method,
					 RXML.Type want_type,
					 string|void parent_scope)
  {
    string result, format_string;
    if(sscanf(calendar_method, "TZ:%s", calendar_method))
    {
      result = query("timezone");
      if(calendar_method == "region")
	sscanf(result, "%[^-+/ ]", result);
      else if(has_value(result, "/"))
	sscanf(result, "%*s/%s", result);
    }
    else if(sscanf(calendar_method, "q:%s", calendar_method))
      result = query(calendar_method);
    else if(sscanf(calendar_method, "p:%s", calendar_method))
      result = time[ calendar_method ]() ? "yes" : "no";
    else if(sscanf(calendar_method, "%s:%s", calendar_method, format_string))
      result = sprintf(format_string, time[ calendar_method ]());
    else if(calendar_method == "number_of_days")
      result = (string)time->month()->number_of_days();
    else {
      result = (string)time[ calendar_method ]();
    }
    if(want_type && want_type != RXML.t_text)
      result = want_type->encode( result );
    DEBUG("\b => %O\n", result);
    return result;
  }

  //! Trickle down through the layout mapping, fetching whatever the
  //! scope × var variable name points at there. (Once the contents of
  //! the layout mapping is set in stone, the return type can safely
  //! be strictened up a bit ("string" instead of "mixed", perhaps).
  protected mixed dig_out(string scope, string|void var)
  {
    mixed result = layout;
    string reached;
    foreach((scope/".")[1..] + (var ? ({ var }) : ({})), string index)
      if(!mappingp(result))
	RXML.run_error(sprintf("Can't sub-index %O with %O.\n",
			       reached || "", index));
      else if(!(result = result[ index ]))
      {
	DEBUG("\b => ([])[0] (no such scope:%O%s)\n",
	      scope, (zero_type(var) ? "" : sprintf(", var:%O combo", var)));
	return ([])[0];
      }
      else
	reached = (reached ? reached + "." : "") + index;
    return result;
  }

  //! Called for each level towards the leaves, including the leaf itself.
  mixed `[](string var, void|RXML.Context ctx,
	    void|string scope, void|RXML.Type want_type)
  {
    DEBUG("%O->`[](var %O, ctx %O, scope %O, type %O)\b",
	  this_object(), var, ctx, scope, want_type);
    RequestID id = ctx->id; NOCACHE();

    // If we further down decide on creating a new TimeRangeValue, this will
    // be its parent_scope name; let's memorize instead of reconstruct it:
    string child_scope = scope;

    // Since we might have arrived at this object via a chain of parent objects,
    // e g "calendar.next.year.next.day" (which would entitle us a parent_scope
    // of "calendar.next.year.next"), we must cut off all the already processed
    // chunks who led the path here:
    if(scope == parent_scope)
      scope = (parent_scope / ".")[-1];
    else
      sscanf(scope, parent_scope + ".%s", scope);

    string|mapping|function what;
    if(!(what = dig_out(scope, var)))
      return ([])[0]; // conserve zero_type
    //report_debug("scope: %O, var: %O, what: %t\n", scope, var, what);
    if(functionp( what )) // it's a temporal method to render us a new TimeRange
    {
      //report_debug("was: %O became: %O\n", time, what(time));
      object result = TimeRangeValue(what(time), type, child_scope, lang);
      DEBUG("\b => new %O\n", result);
      return result;
    }
    if(what && stringp( what )) // it's a plain old Calendar method name
      return fetch_and_quote_value([string]what, want_type, scope);
    DEBUG("\b => same object\n",);
    return this_object();
  }

  //! Called to dereference the final leaf of a variable entity, i e var=="leaf"
  //! and scope=="node.[...].node" for the entity "&node.[...].node.leaf;". This
  //! step is however skipped when `[] returned an already quoted value rather
  //! than an object.
  mixed rxml_var_eval(RXML.Context ctx, string var,
		      string scope, void|RXML.Type want_type)
  {
    DEBUG("%O->rxml_var_eval(ctx %O, var %O, scope %O, type %O)\b",
	  this_object(), ctx, var, scope, want_type);
    RequestID id = ctx->id; NOCACHE();

    // If we further down decide on creating a new TimeRangeValue, this will
    // be its parent_scope name; let's memorize instead of reconstruct it:
    string child_scope = scope;

    // Just as in `[], we might have arrived via some parent. In the specific
    // case that we arrived via `[], and got called with the same parameters as
    // we were there (e g when resolving "&calendar.next.day;"; i e there was
    // nothing, "", to lookup in the new object).
    if(scope == parent_scope)
    {
      scope = var;
      var = "";
    }
    else // this typically happens for scope "calendar.default", var "timezone":
      sscanf(scope, parent_scope + ".%s", scope);

    mixed what, result;
    if(!(what  = dig_out(scope, var)))
    {
      DEBUG("\b => ([])[0] (what conserved)\n");
      return ([])[0]; // conserve zero_type
    }
    if(mappingp( what ) && !(result = what[""])) // may use this scope as a leaf
    { // this probably only occurs if the layout mapping is incorrectly set up:
      DEBUG("\b => ([])[0] (what:%O)\n", what);
      return ([])[0];
    }
    if (!result) result = what;

    if (functionp (result))
      return TimeRangeValue (result (time), type, child_scope, lang);

    return fetch_and_quote_value(result, want_type);
  }

  array(string) _indices(void|RXML.Context ctx, void|string scope_name)
  {
    DEBUG("%O->_indices(%s)\b", this_object(),
	  zero_type(ctx) ? "" : zero_type(scope_name) ?
	  sprintf("ctx: %O, no scope", ctx) :
	  sprintf("ctx: %O, scope %O", ctx, scope_name));
    mapping layout = scope_name ? dig_out(scope_name) : scope_layout;
    DEBUG("\b => %O", layout && indices(layout));
    return layout && indices(layout);
  }

  //! called with 'O' and ([ "indent":2 ]) for <insert variables=full/>, which
  //! is probably a bug, n'est-ce pas? Shouldn't this be handled just as with
  //! the normal indexing, using `[] / rxml_var_eval (and possibly cast)?
  string _sprintf(int|void sprintf_type, mapping|void args)
  {
    switch( sprintf_type )
    {
      case 't': return sprintf("TimeRangeValue(%s)", type);
      case 'O':
	return sprintf("TimeRangeValue(%O/%O)", time, parent_scope);
    }
  }
}

private mapping(string:Calendar.YMD) cached_calendars = ([]);

private constant uc_cal_lookup =
  mkmapping (map (calendars, upper_case), calendars);

Calendar.YMD get_calendar(string name)
{
  if(!name)
    return calendar;
  if (Calendar.YMD cal = cached_calendars[name])
    return cal;
  string uc_name = upper_case (name);
  if (Calendar.YMD cal = cached_calendars[uc_name])
    return cached_calendars[name] = cal;
  string wanted = uc_cal_lookup[uc_name];
  if(!wanted || wanted == "unknown")
    RXML.parse_error(sprintf("Unknown calendar %O.\n", name));
  return cached_calendars[wanted] = cached_calendars[uc_name] =
    Calendar[wanted]->set_timezone (query ("timezone"))
		    ->set_language (query ("language"));
}

class TagEmitTimeZones
{
  inherit RXML.Tag;
  constant name = "emit", plugin_name = "timezones";

  mapping(string:mapping(string : Calendar.TimeRange)) zones;

  protected void init()
  {
    refresh_zones(get_calendar(query("calendar"))->Second());
  }

  Calendar.TimeRange get_time_in_timezone(Calendar.TimeRange time,
					  string tzname, string region)
  {
    if (!zones) init();
    Calendar.TimeRange q = time->set_timezone(tzname),
		      ds = Calendar.Events.tzshift->next(q); // next (non|)dst
    if(ds && (!zones[region]->next_shift || (zones[region]->next_shift < ds)))
      zones[region]->next_shift = ds;
    return q;
  }

  void refresh_zones(Calendar.TimeRange time, string|void region)
  {
    if(!zones) zones = ([]);
    if(!region)
    {
      zones->UTC = ([]);
      for(int i=-24; i<=24; i++)
      {
	string offset = sprintf("UTC%+03d:%02d", i/2, i%2*30);
	zones->UTC[offset] = get_time_in_timezone(time, offset, "UTC");
      }
      foreach((array)Calendar.TZnames.zones, [region, array z])
      {
	zones[region] = ([]);
	foreach(z, string s)
	  zones[region][s] = get_time_in_timezone(time, region+"/"+s, region);
      }
    }
    else if(region != "UTC")
      foreach(Calendar.TZnames.zones[region], string z)
	zones[region][z] = get_time_in_timezone(time, region+"/"+z, region);
  }

  array get_dataset(mapping args, RequestID id)
  {
    if (!zones) init();
    NOCACHE();
    string region = m_delete(args, "region");
    if(!region)
      return map(sort(indices(zones)),
		 lambda(string region) { return ([ "name":region ]); });
    Calendar.YMD cal = get_calendar(m_delete(args, "calendar"));
    Calendar.TimeRange time, next_shift;
    if(!(time = get_date("", args, cal)))
      time = cal->Second();
    if(!zones[region])
      RXML.parse_error(sprintf("Unknown timezone region %O.\n", region));
    next_shift = zones[region] && zones[region]->next_shift;
    if(next_shift && time > next_shift)
      refresh_zones(time, region);
    return map(sort(indices(zones[region]) - ({ "next_shift" })),
	       lambda(string place)
	       {
		 return ([ "name" : place ]) +
		   scopify(zones[region][place], "second");
	       });
  }
}

class TagEmitTimeRange
{
  inherit RXML.Tag;
  constant name = "emit", plugin_name = "timerange";

  array get_dataset(mapping args, RequestID id)
  {
    // DEBUG("get_dataset(%O, %O)\b", args, id);
    string cal_type = args["calendar"];
    Calendar.YMD cal = get_calendar(m_delete(args, "calendar"));
    Calendar.TimeRange from, to, range;
    string what, output_unit;
    int compare_num, unit_no;
    if(what = m_delete(args, "unit"))
    {
      output_unit = output_units[search(output_units, what)];
      if(output_unit == "unknown")
	RXML.parse_error(sprintf("Unknown unit %O.\n", what));

      unit_no = search(output_units, what);
      compare_num = ouput_unit_no[unit_no];

      from = to = get_date("", args, cal);
      from = get_date("from", args, cal) || from || cal->Second();

      if((what = m_delete(args, "from-week-day")) && from)
      {
        what = lower_case(what);
	if(zero_type (gregorian_weekdays[what]))
          RXML.parse_error(sprintf("Unknown day: %O\n",what));
        int weekday = from->week_day();

	int weekday_needed;
        if(cal_type != "ISO" && query("calendar") != "ISO") {
	  weekday_needed = gregorian_weekdays[what]+1;
	}
        else
	  weekday_needed = iso_weekdays[what]+1;

	int change_to;
        if (weekday < weekday_needed)
          change_to = 7 - (weekday_needed - weekday);
        else if(weekday > weekday_needed)
	  change_to = weekday - weekday_needed;
	if (change_to > 0)
          from = from - change_to;
      }

      to = get_date("to", args, cal) || to || from;

      if(what = m_delete(args, "to-week-day")){
	what = lower_case(what);
	if(zero_type (gregorian_weekdays[what]))
	  RXML.parse_error(sprintf("Unknown day: %O\n",what));
	int weekday = to->week_day();

	int weekday_needed;
	if(cal_type != "ISO" && query("calendar") != "ISO") {
	  weekday_needed = gregorian_weekdays[what]+1;
	} else
	  weekday_needed = iso_weekdays[what]+1;

	int change_to;
	if (weekday < weekday_needed)
	  change_to = weekday_needed - weekday;
	else if(weekday > weekday_needed)
	  change_to = 7 - (weekday - weekday_needed);
	if (change_to > 0)// && upper_case(to->week_day_name()) != upper_case(what) - NOT NEEDED
	{
	  if(to == to->calendar()->Year())
	    to = to->calendar()->Day() + change_to;
	  else
	    to += change_to;
	}
      }

#if 0
      // The following repetitons of the from-week-day and to-week-day
      // blocks look very bogus. I don't know if they're intended to
      // have some kind of effect, but in reality they won't since the
      // indices are already deleted from the args mapping by now. /mast

      if((what = m_delete(args, "from-week-day")) && from)
			{
        what = lower_case(what);
	if(zero_type (gregorian_weekdays[what]))
          RXML.parse_error(sprintf("Unknown day: %O\n",what));
        int weekday_needed, change_to;
        int weekday = from->week_day();

        if(calendar != "ISO")
	  weekday_needed = gregorian_weekdays[what]+1;
        else
	  weekday_needed = iso_weekdays[what]+1;
        if (weekday < weekday_needed)
          change_to = 7 - (weekday_needed - weekday);
        else if(weekday > weekday_needed)
          change_to = weekday - weekday_needed;
        if (change_to > 0)
          from = from - change_to;
      }

      if((what = m_delete(args, "to-week-day")))
      {
	what = lower_case(what);
	if(zero_type (gregorian_weekdays[what]))
	  RXML.parse_error(sprintf("Unknown day: %O\n",what));
	int change_to = 0, weekday_needed = 0;
	int weekday = to->week_day();
	if(calendar != "ISO")
	  weekday_needed = gregorian_weekdays[what]+1;
	else
	  weekday_needed = iso_weekdays[what]+1;

	if (weekday < weekday_needed)
	  change_to = weekday_needed - weekday;
	else if(weekday > weekday_needed)
	  change_to = 7 - (weekday - weekday_needed);
	if (change_to > 0)
	  if(to == to->calendar()->Year())
	    to = to->calendar()->Day() + change_to;
	  else
	    to += change_to;
      }
#endif

      string range_type = m_delete(args, "inclusive") ? "range" : "distance";
      if(from <= to)
	range = from[range_type]( to );
      else
	range = to[range_type]( from );
    }
    else
      range = get_date("", args, cal) || cal->Second();

    string lang;
    if(what = m_delete(args, "output-timezone"))
      range = range->set_timezone( what );

    if(what = m_delete(args, "language")) {
      range = range->set_language( what );
      lang = what;
    }

    array(Calendar.TimeRange) dataset;
    if(output_unit)
    {
      dataset = range[output_unit](); // e g: r->hours() or r->days()
      output_unit = output_unit[..sizeof(output_unit)-2]; // lose plural "s"
    }
    else
    {
      dataset = ({ range }); // no unit, from and to given: do a single pass
      output_unit = "second";
    }

    if(from > to)
      dataset = reverse( dataset );

    array(Calendar.TimeRange | mapping | array) dset = ({});
    array(string) sqlindexes;

    if(args["query"]){
      string sqlquery = m_delete(args,"query");
      string use_date = m_delete(args,"compare-date");
      if(!use_date)
        RXML.run_error("No argument compare-date. The compare-date attribute "
                       "is needed together with the attribute query!\n");

      string host = m_delete(args,"host");
      //werror(sprintf("QUERY : %O HOST: %O\n",sqlquery,host));

      array(mapping) rs = db_query(sqlquery, host);
      if(sizeof(rs) > 0)
      {
        sqlindexes = indices(rs[0]);
        foreach(dataset,Calendar.TimeRange testing)
        {
	  int i = 0;
	  int test = 1;

	  foreach(rs,mapping rsrow)
	  {
            if(testing->format_time()[..compare_num] == rsrow[use_date])
            {
	      dset += ({({testing, rsrow})});
	      test = 0;
	    }
            i++;
          }

	  if(test == 1)
	    dset += ({testing});
	} //End foreach
      }
    }// End if we have a SQL query

    // Start Eriks stuff, july 8 2004
    string plugin;
    RoxenModule provider;
    if(plugin = m_delete(args, "plugin")) {
      array(RoxenModule) data_providers = id->conf->get_providers("timerange-plugin");
      foreach(data_providers, RoxenModule prov) {
	if(prov->supplies_plugin_name && prov->supplies_plugin_name(plugin)) {
	  provider = prov;
	  break;
	}
      }
      if(provider) {
	// Here we retrieve the data...
	string compare_column = provider->get_column_name();
	array(mapping(string:mixed)) provider_data = provider->get_dataset(args, range, id);
        foreach(dataset,Calendar.TimeRange test_date)
        {
	  int i = 0;
	  int test = 1;

	  foreach(provider_data, mapping pro_data)
	  {
            if(pro_data[compare_column]->overlaps(test_date) )
            {
	      dset += ({ ({ test_date, pro_data }) });
	      test = 0;
	    }
            i++;
          }

	  if(test == 1)
	    dset += ({test_date});
	} //End foreach

      } else {
	RXML.run_error(sprintf("<emit#timerange> plugin %O does not exist.\n", plugin));
      }
    }
    // End Eriks stuff, july 8 2004

  array(mapping) res;

  if(sizeof(dset) > 0){
    res = ({});
    for(int i = 0;i<sizeof(dset);i++)
      {
        if(arrayp(dset[i]))
          {
            //werror(sprintf("dset[%O][0]: %O\n",i,dset[i][0]));
            res += ({ scopify(dset[i][0], output_unit, 0, lang) + dset[i][1] });
            //werror(sprintf("dset[%O][1]: %O\n",i,dset[i..]));
          }
        else
          res += ({ scopify(dset[i], output_unit, 0, lang) });
      }
  }
  else
    res = map(dataset, scopify, output_unit, 0, lang);
  // DEBUG("\b => %O\n", res);
  return res;
  }
}

mapping scopify(Calendar.TimeRange time, string unit, string|void parent_scope, string|void lang)
{
  TimeRangeValue value = TimeRangeValue(time, unit, parent_scope || "", lang);
  return mkmapping(indices( layout ),
		   allocate(sizeof( layout ), value));
}

Calendar.TimeRange get_date(string name, mapping args, Calendar.YMD calendar)
{
  if(name != "")
    name = name + "-";
  Calendar.YMD cal = calendar; // local copy
  Calendar.TimeRange date; // carries the result
  string what; // temporary data
  if(what = m_delete(args, name + "timezone"))
    cal = cal->set_timezone( what );
  if(args[name + "language"])
    cal = cal->set_language( args[name + "language"] );
  if(name != "")
    what = m_delete(args, name + "language");

  int(0..1) succeeded = 1;
  if(what = m_delete(args, name + "time"))
  {
    if(catch(date = cal->dwim_time( what )))
      if(catch(date = cal->dwim_day( what )) || !date)
	RXML.run_error(sprintf("Illegal %stime %O.\n", name, what));
      else
	date = date->second();
  }
  else if(what = m_delete(args, name + "date"))
  {
    if(catch(date = cal->dwim_day( what )))
      RXML.run_error(sprintf("Illegal %sdate %O.\n", name, what));
  }
  else if(what = m_delete(args, name + "year"))
    date = cal->Year( (int)what );
  else
    succeeded = !(date = cal->Year());

  // we have at least a year; let's get more precise:
  foreach(units[1..], string current_unit)
  {
    string unit = lower_case( current_unit );
    if(what = m_delete(args, name + unit))
    {
      succeeded = 1;
      date = date[unit]( (int)what );
      DEBUG("unit: %O => %O (%d)\n", unit, what, (int)what);
    }
  }
  return succeeded && date->set_timezone(calendar->timezone())
			  ->set_language(calendar->language());
}

protected RoxenModule rxml_sql_module;

array(mapping) db_query(string q,string db_name)
{
  Sql.Sql con;
  string default_db = query ("db_name");

  if (db_name || default_db == " none") {
    // Either got an explicit db, in which case get_rxml_sql_con is
    // used to check access, or has no default db, in which case
    // get_rxml_sql_con uses the default one configured in the sqltag
    // module.

    if (!rxml_sql_module) {
      rxml_sql_module = my_configuration()->get_provider ("rxml_sql");
      if (!rxml_sql_module)
	RXML.run_error ("Couldn't connect to SQL server: "
			"The \"SQL Tags\" module is required.\n");
    }

    con = rxml_sql_module->get_rxml_sql_con (db_name);
  }

  else {
    // Use the database configured in the module. In this case we skip
    // the access check made by get_rxml_sql_con.
    mixed err = catch {
	con = DBManager.get (db_name || default_db, my_configuration());
      };
    if (err || !con)
      RXML.run_error (err ? describe_error (err) :
		      "Couldn't connect to SQL server.\n");
  }

  array(mapping(string:mixed)) result;
  if( mixed err = catch(result = con->query(q)) )
    RXML.run_error ("Query failed: " + describe_error (err));
  return result;
}

//! @ignore

#define DOC_SCOPE(SCOPE_NAME)  \
  "&"##SCOPE_NAME + ".year;":"<desc type='entity'><p>"\
  "  Returns the year i.e. 2003</p></desc>",\
  "&"##SCOPE_NAME + ".year.day;":"<desc type='entity'><p>"\
  "  Returns the day day of the year for date,"\
  "  in the range 1 to 366</p></desc>",\
  "&"##SCOPE_NAME + ".year.name;":"<desc type='entity'><p>"\
  "  Returns the year number i.e. 2003</p></desc>",\
  "&"##SCOPE_NAME + ".year.is-leap-year;":"<desc type='entity'><p>"\
  "    Returns TRUE or FALSE</p></desc>",\
  "&"##SCOPE_NAME + ".month;":"<desc type='entity'><p>"\
  "    Returns the month number i.e. 3 for march</p></desc>",\
  "&"##SCOPE_NAME + ".month.day;":"<desc type='entity'><p>"\
  "    Returns the day number in the month</p></desc>",\
  "&"##SCOPE_NAME + ".month.number_of_days;":"<desc type='entity'><p>"\
  "    Returns the number of days there is in a month.</p></desc>",\
  "&"##SCOPE_NAME + ".month.name;":"<desc type='entity'><p>"\
  "    Month name. Language dependent.</p></desc>",\
  "&"##SCOPE_NAME + ".month.short-name;":"<desc type='entity'><p>"\
  "  Month short name. Language dependent.</p></desc>",\
  "&"##SCOPE_NAME + ".month.number-of-days;":"<desc type='entity'><p>"\
  "    Integervalue of how many days the month contains. <ent>_.month.number_of_days</ent>"\
  "    will also work due to backward compatibility.</p></desc>",\
  "&"##SCOPE_NAME + ".week;":"<desc type='entity'><p>"\
  "    Returns the week number. Language dependent</p></desc>",\
  "&"##SCOPE_NAME + ".weeks;":"<desc type='entity'><p>"\
  "    Returns the week number. Zero padded. Language dependent</p></desc>",\
  "&"##SCOPE_NAME + ".week.day;":"<desc type='entity'><p>"\
  "    Returns the week day number. 1 for monday if it is ISO"\
  "    1 for sunday if it is Gregorian. ISO is default if Gregorian"\
  "    is not specified for the <att>calendar</att>."\
  "    Language dependent</p></desc>",\
  "&"##SCOPE_NAME + ".week.day.name;":"<desc type='entity'><p>"\
  "    Returns the name of the day. I.e. monday."\
  "    Language dependent</p></desc>",\
  "&"##SCOPE_NAME + ".week.day.short-name;":"<desc type='entity'><p>"\
  "    Returns the name of the day. I.e. mo for monday."\
  "    Language dependent</p></desc>",\
  "&"##SCOPE_NAME + ".week.name;":"<desc type='entity'><p>"\
  "    the name of the week. I.e. w5 for week number 5 that year.</p></desc>",\
  "&"##SCOPE_NAME + ".day;":"<desc type='entity'><p>Same as <ent>_.month.day</ent>"\
  "       </p></desc>",\
  "&"##SCOPE_NAME + ".days;":"<desc type='entity'><p>Same as <ent>_.month.days</ent>"\
  "        </p></desc>",\
  "&"##SCOPE_NAME + ".ymd;":"<desc type='entity'><p>"\
  "    Returns a date formated like YYYY-MM-DD (ISO date)</p></desc>",\
  "&"##SCOPE_NAME + ".ymd_short;":"<desc type='entity'><p>"\
  "    Returns a date formated YYYYMMDD (ISO)</p></desc>",\
  "&"##SCOPE_NAME + ".time;":"<desc type='entity'><p>"\
  "    Returns time formated hh:mm:ss (ISO)</p></desc>",\
  "&"##SCOPE_NAME + ".timestamp;":"<desc type='entity'><p>"\
  "    Returns a date and time timestamp formated YYYY-MM-DD hh:mm:ss</p></desc>",\
  "&"##SCOPE_NAME + ".hour;":"<desc type='entity'><p>"\
  "    Returns the hour. (Time zone dependent data)</p></desc>",\
  "&"##SCOPE_NAME + ".hours;":"<desc type='entity'><p>"\
  "    Returns the hour zero padded. (Time zone dependent data)</p></desc>",\
  "&"##SCOPE_NAME + ".minute;":"<desc type='entity'><p>"\
  "    Returns minutes, integer value, i.e. 5"\
  "    (Time zone dependent data)</p></desc>",\
  "&"##SCOPE_NAME + ".minutes;":"<desc type='entity'><p>"\
  "    Returns minutes, zero padded, i.e. 05"\
  "    (Time zone dependent data)</p></desc>",\
  "&"##SCOPE_NAME + ".second;":"<desc type='entity'><p>"\
  "    Returns seconds. (Time zone dependent data)</p></desc>",\
  "&"##SCOPE_NAME + ".seconds;":"<desc type='entity'><p>"\
  "Returns seconds, zero padded. (Time zone dependent data)</p></desc>",\
  "&"##SCOPE_NAME + ".timezone;":"<desc type='entity'><p>"\
  "    Returns the timezone iso name.(Time zone dependent data</p></desc>",\
  "&"##SCOPE_NAME + ".timezone.name;":"<desc type='entity'><p>"\
  "    Returns the name of the time zone.</p></desc>",\
  "&"##SCOPE_NAME + ".timezone.iso-name;":"<desc type='entity'><p>"\
  "    Returns the ISO name of the timezone</p></desc>",\
  "&"##SCOPE_NAME + ".timezone.seconds-to-utc;":"<desc type='entity'><p>"\
  "    The offset to UTC in seconds. (Time zone dependent data)</p></desc>",\
  "&"##SCOPE_NAME + ".unix-time;":"<desc type='entity'><p>"\
  "    Returns seconds since 1:st of january 1970 01:00:00</p>"\
  "    <p>Time zone dependent data</p></desc>",\
  "&"##SCOPE_NAME + ".julian-day;":"<desc type='entity'><p>"\
  "    Returns the Julian day number since the Julian calendar started.</p></desc>",\
  "&"##SCOPE_NAME + ".next.something;":"<desc type='entity'><p>"\
  "    Returns date compared to the current date. This will display a"\
  "    new date that is next to the current date.</p></desc>",\
  "&"##SCOPE_NAME + ".next.second;":"<desc type='entity'><p>"\
  "    Returns the next date the next second.</p></desc>",\
  "&"##SCOPE_NAME + ".next.minute;":"<desc type='entity'><p>"\
  "    Returns the next date the next minute.</p></desc>",\
  "&"##SCOPE_NAME + ".next.hour;":"<desc type='entity'><p>"\
  "    Returns the next date the next hour.</p></desc>",\
  "&"##SCOPE_NAME + ".next.day;":"<desc type='entity'><p>"\
  "    Returns the next date the next day.</p></desc>",\
  "&"##SCOPE_NAME + ".next.week;":"<desc type='entity'><p>"\
  "    Returns the next date the next week.</p></desc>",\
  "&"##SCOPE_NAME + ".next.month;":"<desc type='entity'><p>"\
  "    Returns the next date the next month.</p></desc>",\
  "&"##SCOPE_NAME + ".next.year;":"<desc type='entity'><p>"\
  "    Returns the next date the next year.</p></desc>",\
  "&"##SCOPE_NAME + ".prev.something;":"<desc type='entity'><p>"\
  "    Returns date compared to the current date. This will display a"\
  "    new date that is previous to the current date.</p></desc>",\
  "&"##SCOPE_NAME + ".prev.second;":"<desc type='entity'><p>"\
  "    Returns the previous date the previous second.</p></desc>",\
  "&"##SCOPE_NAME + ".prev.minute;":"<desc type='entity'><p>"\
  "    Returns the previous date the previous minute.</p></desc>",\
  "&"##SCOPE_NAME + ".prev.hour;":"<desc type='entity'><p>"\
  "    Returns the previous date the previous hour.</p></desc>",\
  "&"##SCOPE_NAME + ".prev.day;":"<desc type='entity'><p>"\
  "    Returns the previous date the previous day.</p></desc>",\
  "&"##SCOPE_NAME + ".prev.week;":"<desc type='entity'><p>"\
  "    Returns the previous date the previous week.</p></desc>",\
  "&"##SCOPE_NAME + ".prev.month;":"<desc type='entity'><p>"\
  "    Returns the previous date the previous month.</p></desc>",\
  "&"##SCOPE_NAME + ".prev.year;":"<desc type='entity'><p>"\
  "    Returns the previous date the previous year.</p></desc>",\
  "&"##SCOPE_NAME + ".this.something;":"<desc type='entity'><p>"\
  "    </p></desc>",\
  "&"##SCOPE_NAME + ".this.second;":"<desc type='entity'><p>"\
  "    Returns the this date this second.</p></desc>",\
  "&"##SCOPE_NAME + ".this.minute;":"<desc type='entity'><p>"\
  "    Returns the this date this minute.</p></desc>",\
  "&"##SCOPE_NAME + ".this.hour;":"<desc type='entity'><p>"\
  "    Returns the this date this hour.</p></desc>",\
  "&"##SCOPE_NAME + ".this.day;":"<desc type='entity'><p>"\
  "    Returns the this date this day.</p></desc>",\
  "&"##SCOPE_NAME + ".this.week;":"<desc type='entity'><p>"\
  "    Returns the this date the this week.</p></desc>",\
  "&"##SCOPE_NAME + ".this.month;":"<desc type='entity'><p>"\
  "    Returns the this date this month.</p></desc>",\
  "&"##SCOPE_NAME + ".this.year;":"<desc type='entity'><p>"\
  "    Returns the this date this year.</p></desc>",\
  "&"##SCOPE_NAME + ".default.something;":"<desc type='entity'><p>"\
  "    Returns the this modules settings.</p></desc>",\
  "&"##SCOPE_NAME + ".default.calendar;":"<desc type='entity'><p>"\
  "    Returns the this modules default calendar. I.e. \"ISO\", \"Gregorian\" etc.</p></desc>",\
  "&"##SCOPE_NAME + ".default.timezone;":"<desc type='entity'><p>"\
  "    Returns the this modules default timezone.</p></desc>",\
  "&"##SCOPE_NAME + ".default.timezone.region;":"<desc type='entity'><p>"\
  "    Returns the this modules default timezone region. I.e. Europe if the"\
  "    timezone is Europe/Stockholm</p></desc>",\
  "&"##SCOPE_NAME + ".default.timezone.detail;":"<desc type='entity'><p>"\
  "    Returns the this modules default timezone specific part. I.e. Stockholm if"\
  "    the timezone is Europe/Stockholm</p></desc>",\
  "&"##SCOPE_NAME + ".default.language;":"<desc type='entity'><p>"\
  "    Returns the this modules default language.</p></desc>"


TAGDOCUMENTATION;
constant tagdoc = ([
  "&calendar;":#"<desc type='scope'><p><short hide='hide'>
    This scope contains date variables.</short> This scope contains the
    dates variables, and also some possibility to calculate dates, e.g.
    when you want to know the next month or the previous day.
   </p></desc>",

  DOC_SCOPE("calendar"),

  "emit#timerange": ({ #"<desc type='plugin'>
  <p>This tag emits over a timerange
  between two dates (from i.e. from-date and to-date -attributes). 
  The purpose is also that you might have a Resultset from i.e. a
  database (but the goal is that   it should work with other resultsets
  why not from an ldap search?) and each
  row in the database result will also contain corresponding dates.
  But if there is no result row from the database query that match one
  day the variables from the Resultset will be empty.
  </p>
  <p>
  This tag is very useful for application that needs a calendar functionality.
  </p>
  <note><p>In Gregorian calendar, first day of the week is Sunday.</p></note>
  <note><p>All <xref href='emit.tag'>emit</xref> attributes apply.</p></note>

  </desc>

  <attr name='unit' value='years|months|weeks|days|hours|minutes|seconds' required='required'>
  <p>years - loop over years<br />
     days - will result in a loop over days<br />
     etc.
  </p>
  </attr>

  <attr name='calendar' value='ISO|Gregorian|Julian|Coptic|Islamic|Discordian' default='ISO'>
    <p>The type of calendar that is recieved from the to-* and from-* attributes and will
       also reflect the values that you get.</p>
    <p>These are not case sensitive values.</p>
  </attr>

  <attr name='from-date' value='YYYY-MM-DD'>
    <p>
      The date that the emit starts at (i.e. '2002-06-21' - which was 
      midsummer eve in Sweden that year)
    </p>
  </attr>

  <attr name='from-year' value='YYYY'>
    <p>
      Start the emit from this year. Used with all the unit types.
    </p>
  </attr>

  <attr name='from-time' value='HH:MM:SS'>
    <p>
      Two digits for hours, minutes and seconds - separated by colon. Useful when the
      value of unit is hours, minutes or seconds. But it might also influence when
      used with the <att>query</att> attribute.
    </p>
  </attr>

  <attr name='to-date' value='YYYY-MM-DD'>
    <p>
      The date (i.e. '2002-06-21' - which was midsummer eve in Sweden that year)
    </p>
  </attr>

  <attr name='to-year' value='YYYY'>
    <p>
      Emit to this year. Used with all the unit types.
    </p>
  </attr>

  <attr name='to-time' value='HH:MM:SS'>
    <p>
      Two digits for hours, minutes and seconds - separated by colon. 
      Useful when the value of unit is hours, minutes or seconds.
      But it might also have impact when used with the query attribute.
    </p>
  </attr>

  <attr name='from-week-day' value='monday|tuesday|wednesday|thursday|friday|saturday|sunday'>
   <p>Alter the startdate to nearest weekday of the choice which means
      that if you declare in <att>from-date</att> 2002-07-25 which is a
      tuesday the startdate will become
      2002-07-24 when from-week-day='monday'. So far this is supported by ISO, 
      Gregorian and Julian calendar.</p>
  </attr>

  <attr name='to-week-day' value='monday|tuesday|wednesday|thursday|friday|saturday|sunday'>
    <p>Alter the <att>to-date</att> to neareast weekday this day or after
       this day depending on where the weekday is. So far this is supported
       by ISO, Gregorian and Julian calendar.</p>
  </attr>

  <attr name='inclusive' value='empty'>
    <p>Affects the <i>to-*</i> attributes so that the <att>to-date</att> 
       will be included
       in the result. See examples below.</p>
  </attr>

  <attr name='query'>
    <p>A sql select query. <i>Must</i> be accompanied by a
       <att>compare-date</att> attribute otherwise it will throw an error.
       The attribute can for now only compare date in
       the ISO date format se <att>compare-date</att> for the ISO format.
    </p>
  </attr>

  <attr name='compare-date' value='sql-column-name'>
    <p>A column - or alias name for a column in the sql select query.
       The value of the column must be of the ISO format corresponding
       to the <att>unit</att> attribute asked for.
    </p>
    <p>
    <xtable>
      <row>
        <h>unit</h> <h>format</h>
      </row>
      <row>
        <c><p> years  </p></c>
        <c><p> YYYY</p></c>
      </row>
      <row>
        <c><p> months </p></c>
        <c><p> YYYY-MM</p></c>
      </row>
      <row>
        <c><p> weeks  </p></c>
        <c><p> has none (for now)</p></c>
      </row>
      <row>
        <c><p> days   </p></c>
        <c><p> YYYY-MM-DD</p></c>
      </row>
      <row>
        <c><p> hours  </p></c>
        <c><p> YYYY-MM-DD HH</p></c>
      </row>
      <row>
        <c><p> minutes</p></c>
        <c><p> YYYY-MM-DD HH:mm</p></c>
      </row>
      <row>
        <c><p> seconds</p></c>
        <c><p> YYYY-MM-DD HH:mm:ss</p></c>
      </row>
    </xtable>
    </p>
    <p>This attribute is <i>mandatory if the <att>query</att>
       attribute exists</i>.
       This attribute does nothing if the query attribute doesn't exists.
    </p>
  </attr>

  <attr name='host' value='db-host-name'>
    <p>
      A databas host name, found under DBs in Administration
      Interface. Used together with <att>query</att> attribute. See
      <tag>emit source=\"sql\"</tag> for further information.
    </p>
    <p>
      The \"SQL tags\" module must be loaded for this to work, and the
      \"Allowed databases\" setting in it is used to restrict database
      access.
    </p>
  </attr>

  <attr name='language' value='langcode'>
    <p>
      The language code to use:
    </p>
    <p>
      cat (for catala)<br />
      hrv (for croatian)<br />
      <!-- ces (for czech)-->
      nld (for dutch)<br />
      eng (for english)<br />
      fin (for finnish)<br />
      fra (for french)<br />
      deu (for german)<br />
      hun (for hungarian)<br />
      ita (for italian)<br />
      <!-- jpn (for japanese)-->
      <!-- mri (for maori)-->
      nor (for norwegian)<br />
      pol (for polish)<br />
      por (for portuguese)<br />
      <!-- rus (for russian) -->
      srp (for serbian)<br />
      slv (for slovenian)<br />
      spa (for spanish)<br />
      swe (for swedish)
    </p>
  </attr>

  <ex>
    <emit source='timerange' unit='hours' 
      from-time='08:00:00' to-time='12:00:00' inclusive='1'>
      <div>&_.hour;:&_.minute;:&_.second;</div>
    </emit>
  </ex>
  <ex>
    <emit source='timerange' unit='days'
      from-date='2002-11-23' to-date='2002-12-25' 
      from-week-day='monday' calendar='ISO' to-week-day='sunday' inclusive='1'>
      <if variable='_.week.day is 7'>
        <font color='red'>
          <if sizeof='_.day is 1'>0</if>&_.day;
        </font>
        <br />
      </if>
      <else>
        <if sizeof='_.day is 1'>0</if>&_.day;
      </else>
    </emit>
  </ex>
  <p>Database system this example uses: MySQL</p>
  <p>Database name: mydb </p>
  <p>   Table name: calendar_src:</p>
  <xtable>
    <row>
      <h>name</h> <h>type</h>
    </row>
    <row>
      <c><p> id  </p></c>
      <c><p>INT PRIMARY KEY</p></c>
    </row>
    <row>
      <c><p> start_date  </p></c>
      <c><p> DATETIME </p></c>
    </row>
    <row>
      <c><p> end_date  </p></c>
      <c><p> DATETIME </p></c>
    </row>
    <row>
      <c><p> day_event  </p></c>
      <c><p> TEXT </p></c>
    </row>
  </xtable>
  <ex-box>
    <table border='1'>
      <tr>
        <emit source='timerange'
          unit='days' calendar='ISO'
          from-date='2003-03-01'
          to-date='2003-03-31'
          from-week-day='monday'
          to-week-day='sunday'
          inclusive=''
          query='SELECT day_event,
                 DATE_FORMAT(start_date,\"%Y-%m-%d\") as comp_date
                 FROM calendar_src
                 WHERE start_date &gt; \"2003-03-01 00:00:00\"
                   AND start_date &lt; \"2003-04-01 00:00:00:\"
                 ORDER BY start_date'
          compare-date='comp_date'
          host='mydb'>

          <if variable='_.ymd_short is &var.ymd_short_old;' not=''>
            <![CDATA[</td>]]>
          </if>
          <if variable='_.week.day is 1' 
              match='&_.ymd_short; != &var.ymd_short_old;'>
            <if variable='_.counter &gt; 1'>
              <![CDATA[
              </tr>
              <tr>]]>
            </if>
            <td width='30' valign='top'>
              <div>&_.week;</div>
            </td>
            <![CDATA[<td width='100' valign='top'>]]>
            <div align='right'>&_.month.day;</div>
            <div>&_.day_event;</div>
          </if>
          <else>
            <set variable='var.cal-day-width'
              value='{$working-day-column-width}'/>
            <if variable='_.ymd_short is &var.ymd_short_old;' not=''>
              <![CDATA[<td width='100' valign='top'>]]>
              <if variable='_.week.day is 7'>
                <div align='right' style='color: red'>
                  &_.month.day;
                </div>
              </if>
              <else>
                <div align='right'>&_.month.day;</div>
              </else>
            </if>
            <div>&_.day_event;</div>
          </else>
          <set variable='var.ymd_short_old' from='_.ymd_short'/>
        </emit>
      </tr>
    </table>
  </ex-box>
  <p>The code above does not work in a XML- or XSLT-file
    unless modified to conform to XML. To accomplish that
    &lt;xsl:text disable-output-escaping='yes'&gt;
    &lt;![CDATA[&lt;td&gt;]]&gt;
    &lt;/xsl:text&gt; will solve that. Or it could be placed
    in a RXML-variable: &lt;set variable='var.start_td'
    value='&amp;lt;td&amp;gt;'/&gt; and used:
    &amp;var.start_td:none; see documentation: Encoding,
    under Variables, Scopes &amp; Entities
    </p>
  ", ([ DOC_SCOPE("_") ])
 })
]);

//! @endignore
