// This is a roxen module. Copyright © 2001, Roxen IS.

#include <module.h>
inherit "module";

constant cvs_version = "$Id: emit_timerange.pike,v 1.1 2001/06/11 19:21:58 jhs Exp $";
constant thread_safe = 1;
constant module_uniq = 1;
constant module_type = MODULE_TAG;
constant module_name = "Tags: Timerange Emit Source";
constant module_doc  = "This module provides the emit source 'timerange'."
" NOTE! The exact look and workings of the TimeRange objects is subject to"
" change without notice - indeed, the look <i>will</i> change before it is"
" fully finished, without any backwards compatibility built-in; this code"
" is just the development version. When the TimeRange object has matured,"
" this disclaimer will of course be removed.";

#ifdef TIMERANGE_VALUE_DEBUG
#define DEBUG(X ...) report_debug( X )
#else
#define DEBUG(X ...)
#endif

static constant units = ({ "Year", "Month", "Week", "Day",
			   "Hour", "Minute", "Second" }),
	    calendars = ({ "ISO", "Gregorian", "Julian", "Coptic",
			   "Islamic", "Discordian", "unknown" }),
	 output_units = ({ "years", "months", "weeks", "days",
			   "hours", "minutes", "seconds", "unknown" }),
       scope_layout = ([ // Date related data:
			 "year"			: "year_no",
			 "year.day"		: "year_day",
			 "year.name"		: "year_name",
			 "year.is-leap-year"	: "p:leap_year", // predicate
			 "month"		: "month_no",
			 "month.day"		: "month_day",
			 "month.name"		: "month_name",
			 "month.short-name"	: "month_shortname",
			 "week"			: "week_no",
			 "week.day"		: "week_day",
			 "week.day.name"	: "week_day_name",
			 "week.day.short-name"	: "week_day_shortname",
			 "week.name"		: "week_name",
			 "day"			: "month_day",
			 // Time zone dependent data:
			 "hour"			: "hour_no",
			 "minute"		: "minute_no",
			 "second"		: "second_no",
			 "timezone"		: "tzname_iso",
			 "timezone.name"	: "tzname",
			 "timezone.iso-name"	: "tzname_iso",
			 "timezone.seconds-to-utc" : "utc_offset",
			 // Misc data:
			 "unix-time"		: "unix_time",
			 "julian-day"		: "julian_day" ]);

/* Possible future convenience expansion:
         format_...
	   iso_ymd_full   "2000-06-02 (Jun) -W22-5 (Fri)" [2]
           ymd            "2000-06-02"
           ymd_short      "20000602"
           ymd_xshort     "000602" [1]
           iso_week       "2000-W22"
           iso_week_short "2000W22"
           week           "2000-w22" [2]
           week_short     "2000w22" [2]
           month          "2000-06"
           month_short    "200006" [1]
           iso_time_full  "2000-06-02 (Jun) -W22-5 (Fri) 20:53:14 UTC+1" [2]
           ctime          "Fri Jun  2 20:53:14 2000\n" [2] [3]
           http           "Fri, 02 Jun 2000 20:53:14 GMT" [4]
           time           "2000-06-02 20:53:14"
           time_short     "20000602 20:53:14"
           time_xshort    "000602 20:53:14"
           mtime          "2000-06-02 20:53"
           xtime          "2000-06-02 20:53:14.123456"
           tod            "20:53:14"
           tod_short      "205314"
           todz           "20:53:14 CET"
           todz_iso       "20:53:14 UTC+1"
           xtod           "20:53:14.123456"
           mod            "20:53"

	[1] note conflict (think 1 February 2003)
	[2] language dependent
	[3] as from the libc function ctime()
	[4] as specified by the HTTP standard; not language or timezone dependant */

static mapping layout;
//! create() constructs this module-global recursive mapping,
//! with one mapping level for each dot-separated segment of the
//! indices of the scope_layout constant, sharing the its values.
//! Where collisions occur, such as "week" and "week.name", the
//! resulting mapping will turn out "week" : ([ "" : "week_no",
//! "day" : "week_day" ]).

void create(Configuration conf)
{
  DEBUG("%O->create(%O)\b", this_object(), conf);
  if(layout)
  {
    DEBUG("\b => layout already defined.\n");
    return;
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
      if(j == last)
	if(t2 = t1[index])
	  if(mappingp(t2))
	    t1[index] += ([ "" : vals[i] ]);
	  else
	    t1 += ([ index : vals[i],
		        "" : t2 ]);
	else
	  t1[index] = vals[i];
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
  DEBUG("\b => layout: %O.\n", layout);
}

//! Plays the role as both an RXML.Scope (for multi-indexable data
//! such as scope.year.is-leap-year and friends) and an RXML.Value for
//! the leaves of all such entities (as well as the one-dot variables,
//! for example scope.julian-day).
class TimeRangeValue(Calendar.TimeRange time, string type)
{
  //! Once we have the string pointing out the correct time object
  //! method, this method calls it from the @code{time@} object and
  //! returns the result, properly quoted.
  //! @param calendar_method
  //!   the name of a method in a @[Calendar.TimeRange] object,
  //!   possibly prefixed with the string @tt{"p:"@}, which signifies
  //!   that the function returns a boolean answer that in RXML should
  //!   return either of the strings @tt{"yes"@} or @tt{"no"@}.
  static string fetch_and_quote_value(string calendar_method,
				      RXML.Type want_type)
  {
    mixed result;
    if(sscanf(calendar_method, "p:%s", calendar_method))
      result = time[ calendar_method ]() ? "yes" : "no";
    else
      result = time[ calendar_method ]();
    result = want_type && want_type != RXML.t_text
	   ? want_type->encode( result )
	   : (string)result;
    DEBUG("\b => %O\n", result);
    return result;
  }

  //! Trickle down through the layout mapping, fetching whatever the
  //! scope × var variable name points at there. (Once the contents of
  //! the layout mapping is set in stone, the return type can safely
  //! be strictened up a bit ("string" instead of "mixed", perhaps).
  static mixed dig_out(string scope, string var)
  {
    mixed result = layout;
    foreach((scope/".")[1..] + ({ var }), string index)
      if(!(result = result[ index ]))
      {
	DEBUG("\b => ([])[0] (user gave incorrect variable name)\n");
	return ([])[0];
      }
    return result;
  }

  //! Called for each level towards the leaves, including the leaf itself
  mixed `[](string var, void|RXML.Context ctx,
	    void|string scope, void|RXML.Type want_type)
  {
    DEBUG("%O->`[](%O, %O, %O, %O)\b", this_object(), var, ctx, scope, want_type);
    mixed what;;
    if(!(what  = dig_out(scope, var)))
      return ([])[0]; // conserve zero_type
    if(!mappingp( what )) // if it's not a mapping, it's a calendar method name
      return fetch_and_quote_value([string]what, want_type);
    DEBUG("\b => %O\n", this_object());
    return this_object();
  }

  //! Called to dereference a TimeRangeValue object, for instance left behind by
  //! `[] or in the top-level mappings given by TagEmitTimeRange.
  mixed rxml_var_eval(RXML.Context ctx, string var,
		      string scope, void|RXML.Type want_type)
  {
    DEBUG("%O->rxml_var_eval(%O, %O, %O, %O)\b",
	  this_object(), ctx, var, scope, want_type);
    mixed what, result;
    if(!(what  = dig_out(scope, var)))
      return ([])[0]; // conserve zero_type
    if(mappingp( what ) && !(result = what[""])) // allows using a scope as a leaf
    { // this probably only occurs if the layout mapping is incorrectly set up:
      DEBUG("\b => ([])[0] (what:%O)\n", what);
      return ([])[0];
    }
    return fetch_and_quote_value(result || what, want_type);
  }

  //! called with 'O' and ([ "indent":2 ]) for <insert variables=full/>, which is
  //! probably a bug, n'est-ce pas? Shouldn't this be handled just as with the
  //! normal indexing, using `[] / rxml_var_eval (and possibly cast)?
  string _sprintf(int sprintf_type, mapping args)
  {
    switch( sprintf_type )
    {
      case 't': return sprintf("TimeRangeValue(%s)", type);
      case 'O':
      default:
	return sprintf("TimeRangeValue(%O)", time);
    }
  }
}

class TagEmitTimeRange
{
  inherit RXML.Tag;
  constant name = "emit", plugin_name = "timerange";
  mapping(string:RXML.Type) req_arg_types
			   = ([ "unit" : RXML.t_text(RXML.PEnt) ]);

  array get_dataset(mapping args, RequestID id)
  {
    // DEBUG("get_dataset(%O, %O)\b", args, id);
    string what = upper_case(m_delete(args, "calendar") || "ISO");
    string calendar = calendars[search(map(calendars, upper_case), what)];
    if(calendar == "unknown")
      RXML.parse_error(sprintf("Unknown calendar.\n"));
    Calendar cal = Calendar[ calendar ];

    what = m_delete(args, "unit"); // || "day"; (throw an error instead)
    string output_unit = output_units[search(output_units, what)];
    if(output_unit == "unknown")
      RXML.parse_error(what ? sprintf("Unknown unit %O.\n", what)
			    : "No unit attribute given.");

    Calendar.TimeRange from = get_date("from", args, cal),
			 to = get_date("to", args, cal), range;
    string range_type = m_delete(args, "inclusive") ? "range" : "distance";
    if(from <= to)
      range = from[range_type]( to );
    else
      range = to[range_type]( from );

    if(what = m_delete(args, "timezone"))
      range = range->set_timezone( what );
    if(what = m_delete(args, "language"))
      range = range->set_language( what );

    array dataset = range[ output_unit ]();
    if(from > to)
      dataset = reverse( dataset );

#ifdef FUTURE_INCOMPATIBILITY
    args -= <EMIT_ARGS>;
    if(sizeof( args ))
    {
      int i = sizeof( args );
      string error = "Unsupported attribute"
	           + (i == 1 ? "" : "s") + " ";
      error += String.implode_nicely(indices( args ));
      RXML.run_error( error );
    }
#endif

    output_unit = output_unit[..sizeof(output_unit)-2]; // lose plural "s"
    mixed r = map(dataset, scopify/*TimeRangeValue*/, output_unit);
    // DEBUG("\b => %O\n", r);
    return r;
  }
}

mapping scopify(Calendar.TimeRange time, string unit)
{
  TimeRangeValue value = TimeRangeValue(time, unit);
  return mkmapping(indices( layout ),
		   allocate(sizeof( layout ), value));
}

Calendar.TimeRange get_date(string name, mapping args, Calendar calendar)
{
  Calendar cal = calendar; // local copy
  Calendar.TimeRange date; // carries the result
  string what; // temporary data
  if(what = m_delete(args, name + "-timezone"))
    cal = cal->set_timezone( what );
  if(what = m_delete(args, name + "-language"))
    cal = cal->set_language( what );

  if(what = m_delete(args, name + "-time"))
    date = calendar->dwim_time( what );
  else if(what = m_delete(args, name + "-date"))
    date = calendar->dwim_day( what );
  else
  {
    what = name + "-year";
    if(zero_type( args[what] ))
      date = cal->Year();
    else
      date = cal->Year( m_delete(args, what) );
  }

  // we have a year; let's get more precise:
  foreach(units[1..], string current_unit)
  {
    string unit = lower_case( current_unit );
    what = m_delete(args, name + "-" + unit);
    if( what )
    {
      date = date[unit]( (int)what );
      DEBUG("unit: %O => %O (%d)\n", unit, what, (int)what);
    }
  }
  return date;
}
