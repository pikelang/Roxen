// $Id$

#if constant(roxenp)
inherit /*Variable*/.Variable;

//! This class implements a scheduler widget with three main states,
//! never index, index every n:th hour or index every n:th x-day at y
//! o'clock. In the "index every n:th hour" case the range is 1 to 23.
//! In the "index every n:th x-day at y o'clock" the n-range is
//! 1 to 9, the units are day and all the weekdays. The time range for
//! y is all hours in a day.

// Locale macros
//<locale-token project="roxen_config"> LOCALE </locale-token>

#define LOCALE(X,Y)    \
  ([string](mixed)Locale.translate("roxen_config",roxenp()->locale->get(),X,Y))

#else

// Test mode.

#define LOCALE(X, Y)	(Y)

array(int) val = ({ });

array(int) query()
{
  return val;
}

// Deterministic timezone...
#define localtime(X)	gmtime(X)

int main(int argc, array(string) argv)
{
  int successes;
  int failures;
  foreach(({
	    ({ ({ 0, 2, 1, 6, 3, 0, }),
	       // Disabled.
	       ({ 0, -1 }),
	    }),
	    ({ ({ 1, 2, 1, 6, 3, 0, }),
	       // Every other hour.
	       // 2022-06-22T14:11:43 (Wed)  ==>  2022-06-22T16:11:43 (Wed)
	       ({ 1655907103, 1655914303 }),
	    }),
	    ({ ({ 2, 2, 1, 6, 3, 0, }),
	       // Every Friday at 03:00.
	       // 2022-06-22T14:11:43 (Wed)  ==>  2022-06-24T03:00:00 (Fri)
	       ({ 1655907103, 1656039600 }),
	       // 2022-06-23T14:11:43 (Thu)  ==>  2022-06-24T03:00:00 (Fri)
	       ({ 1655993503, 1656039600 }),
	       // 2022-06-24T02:11:43 (Fri)  ==>  2022-06-24T03:00:00 (Fri)
	       ({ 1656036703, 1656039600 }),
	       // 2022-06-24T03:11:43 (Fri)  ==>  2022-07-01T03:00:00 (Fri)
	       ({ 1656040303, 1656644400 }),
	       // 2022-06-24T03:21:43 (Fri)  ==>  2022-07-01T03:00:00 (Fri)
	       ({ 1656040903, 1656644400 }),
	       // 2022-06-24T03:51:43 (Fri)  ==>  2022-07-01T03:00:00 (Fri)
	       ({ 1656042703, 1656644400 }),
	       // 2022-06-24T04:11:43 (Fri)  ==>  2022-07-01T03:00:00 (Fri)
	       ({ 1656043903, 1656644400 }),
	       // 2022-06-24T14:11:43 (Fri)  ==>  2022-07-01T03:00:00 (Fri)
	       ({ 1656079903, 1656644400 }),
	    }),
	    ({ ({ 2, 2, 1, 6, 3, 45, }),
	       // Every Friday at 03:45.
	       // 2022-06-22T14:11:43 (Wed)  ==>  2022-06-24T03:45:00 (Fri)
	       ({ 1655907103, 1656042300 }),
	       // 2022-06-23T14:11:43 (Thu)  ==>  2022-06-24T03:45:00 (Fri)
	       ({ 1655993503, 1656042300 }),
	       // 2022-06-24T02:11:43 (Fri)  ==>  2022-06-24T03:45:00 (Fri)
	       ({ 1656036703, 1656042300 }),
	       // 2022-06-24T03:11:43 (Fri)  ==>  2022-06-24T03:45:00 (Fri)
	       ({ 1656040303, 1656042300 }),
	       // 2022-06-24T03:21:43 (Fri)  ==>  2022-06-24T03:45:00 (Fri)
	       ({ 1656040903, 1656042300 }),
	       // 2022-06-24T03:51:43 (Fri)  ==>  2022-07-01T03:45:00 (Fri)
	       ({ 1656042703, 1656647100 }),
	       // 2022-06-24T04:11:43 (Fri)  ==>  2022-07-01T03:45:00 (Fri)
	       ({ 1656043903, 1656647100 }),
	       // 2022-06-24T14:11:43 (Fri)  ==>  2022-07-01T03:45:00 (Fri)
	       ({ 1656079903, 1656647100 }),
	    }),
	    ({ ({ 2, 1, 1, 0, 3, 0 }),	// PI-172 adjusted from 02:00 to 03:00
	       // Every day at 03:00.
	       // 2022-06-22T14:11:43 (Wed)  ==>  2022-06-23T03:00:00 (Thu)
	       ({ 1655907103, 1655953200 }),
	       // 2022-06-23T14:11:43 (Thu)  ==>  2022-06-24T03:00:00 (Fri)
	       ({ 1655993503, 1656039600 }),
	       // 2022-06-24T02:11:43 (Fri)  ==>  2022-06-24T03:00:00 (Fri)
	       ({ 1656036703, 1656039600 }),
	       // 2022-06-24T03:11:43 (Fri)  ==>  2022-06-25T03:00:00 (Sat)
	       ({ 1656040303, 1656126000 }),
	       // 2022-06-24T03:21:43 (Fri)  ==>  2022-06-25T03:00:00 (Sat)
	       ({ 1656040903, 1656126000 }), // Borken 2022-06-25T03:15:00
	       // 2022-06-24T03:51:43 (Fri)  ==>  2022-06-25T03:00:00 (Sat)
	       ({ 1656042703, 1656126000 }), // Borken 2022-06-25T03:45:00
	       // 2022-06-24T04:11:43 (Fri)  ==>  2022-06-25T03:00:00 (Sat)
	       ({ 1656043903, 1656126000 }),
	       // 2022-06-24T14:11:43 (Fri)  ==>  2022-06-25T03:00:00 (Sat)
	       ({ 1656079903, 1656126000 }),
	    }),
	  }), array(array(int)) test) {
    val = test[0];
    while(1) {
      foreach(test[1..], [int when, int expected]) {
	int got = get_next(when);
	if (got != expected) {
	  failures++;
	  werror("Test failed for %O\n"
		 "When: %d\n"
		 "%O\n"
		 "Expected: %d\n"
		 "%O\n"
		 "Got: %d\n"
		 "%O\n",
		 test,
		 when, localtime(when),
		 expected, localtime(expected),
		 got, localtime(got));
	} else {
	  successes++;
	}
      }
      if ((sizeof(val) > 5) && !val[5]) {
	// Redo in compat mode.
	val = val[..4];
	continue;
      }
      break;
    }
  }
  werror("Succeeded on %d, Failed on %d.\n", successes, failures);
  return !!failures;
}

#endif


protected string|function(:bool) link_enabled;
protected string|function(:int) link_last_run;

//! Link this schedule to another variable instance (providing a flag value)
//! or callback function (returning true/false) which answers whether this
//! schedule is active. Only needed when this schedule can become inactive
//! due to some external factor. Call @[get_link_enabled] to get the value
//! back.
//!
//! Part of the "Server Schedule" info box in the admin interface.
this_program set_link_enabled(string|function(:bool) _link_enabled)
{
  link_enabled = _link_enabled;
  return this;
}

//! Getter for the value set in @[set_link_enabled].
string|function(:bool) get_link_enabled()
{
  return link_enabled;
}

//! Link this schedule to another variable instance (providing a numeric
//! value) or callback function (returning an integer) which answers when
//! this schedule was last run. This helps the caller compute a more exact
//! time of the next run. Call @[get_link_last_run] to get the value back.
//!
//! Part of the "Server Schedule" info box in the admin interface.
this_program set_link_last_run(string|function(:int) _link_last_run)
{
  link_last_run = _link_last_run;
  return this;
}

//! Getter for the value set in @[set_link_last_run].
string|function(:int) get_link_last_run()
{
  return link_last_run;
}


#define VALS_SORT		0
#define VALS_REPEAT_HOURS	1
#define VALS_REPEAT_COUNT	2
#define VALS_DAY		3
#define VALS_HOUR		4
#define VALS_MINUTE		5

protected multiset(int(0..2)) valid_sorts = (< 0, 1, 2 >);

//! Transforms the form variables given in the @[vl] attribute
//! to the internal time representation as follows.
//!
//! @array
//!   @elem int(0..2) sort
//!     @int
//!       @value 0
//!         Never
//!       @value 1
//!         Every x hour
//!       @value 2
//!         Every x y at z
//!     @endint
//!
//!   @elem int(1..23) hour
//!     Number of hours between restarts.
//!
//!   @elem int(1..9) everynth
//!     Number of days or weeks to skip between restarts.
//!
//!   @elem int(0..7) day
//!     @int
//!       @value 0
//!         Day
//!       @value 1
//!         Sunday
//!       @value 2..7
//!         Rest of weekdays
//!     @endint
//!
//!   @elem int(0..23) time_hour
//!     Time at which to restart (hour).
//!
//!   @elem int(0..59)|void time_min
//!     Time at which to restart (minute).
//!     If not present at minute 0 (compat).
//! @endarray
array transform_from_form( string what, mapping vl )
{
  array res = query() + ({});
  if(sizeof(res) <= VALS_HOUR) {
    res = ({ 0, 2, 1, 6, 3, -1 });
  } else if (sizeof(res) <= VALS_MINUTE) {
    // Compat.
    res += ({ 0 });
  }

  res[VALS_SORT] = (int)what;
  for(int i=1; i <= VALS_MINUTE; i++) {
    res[i] = (int)vl[(string)i];
    res[i] = max( ({ 0, 1, 1, 0, 0, 0 })[i], res[i] );
    res[i] = min( ({ 2, 23, 9, 7, 23, 59 })[i], res[i] );
  }

  if (!res[VALS_MINUTE]) {
    // Compat.
    res = res[..VALS_HOUR];
  }

  return res;
}

#if constant(roxenp)
array verify_set_from_form(array val)
{
  if ((sizeof(val) >= VALS_SORT) &&
      !valid_sorts[val[VALS_SORT]]) {
    throw("Invalid operation mode.\n");
  }
  return ::verify_set_from_form(val);
}
#endif

protected int mktime(mapping m)
{
  int t = predef::mktime(m);
  if (m->timezone) {
    // Compensate for cases where predef::mktime() is broken.
    // Cf [WS-469].
    t += t - predef::mktime(localtime(t));
  }
  return t;
}

private mapping next_or_same_day(mapping from, int day, int hour, int minute)
{
  if(from->wday==day && from->hour<hour)
    return from;
  if(from->wday==day && from->hour == hour && from->min<minute)
    return from;
  return next_day(from, day);
}

private mapping next_day(mapping from, int day)
{
  int num_days = ((6 + day - from->wday) % 7) + 1;

  // NB: Use a time in the middle of the date to ensure that we
  //     don't miss the next day due to DST or similar.
  //     Adjust the hour back to 00 afterwards.
  from->hour = 12;
  mapping m = localtime(mktime(from) + num_days * 3600 * 24);
  m->hour = from->hour = 0;
  m->min = from->min = 0;
  return m;
}

private mapping next_or_same_time(mapping from, int hour, int minute,
				  void|int delta)
{
  if (from->hour == hour) {
    if (minute < 0) {
      return from;
    }
    if ((from->min - (from->min % 15)) == minute) {
      return from;
    }
  }
  return next_time(from, hour, minute, delta);
}

private mapping next_time(mapping from, int hour, int minute, void|int delta)
{
  if(from->hour<hour) {
    from->hour = hour;
    if (minute < 0) {
      from->min = 0;
    } else {
      from->min = minute;
    }
    return from;
  } else if ((from->hour == hour) && (from->min < minute)) {
    from->min = minute;
    return from;
  }
  from->min = minute;
  return localtime(mktime(from) + (24 - from->hour + hour)*3600 + delta);
}

int get_next( int last )
//! Get the next time that matches this schedule, starting from the
//! posix time @[last]. If last is 0, time(1) will be used instead.
//!
//! @returns
//!  When the next scheduled event is, represented by a posix time integer.
//!  Note that the returned time may already have occured, so all return
//!  values < time() essentially means go ahead and do it right away.
//!  Minutes and seconds are cleared in the return value, so if the scheduler
//!  is set to every day at 5 o'clock, and this method is called at 5:42 it
//!  will return the posix time representing 5:00, unless of course @[last]
//!  was set to a posix time >= 5:00.
//!  Returns @tt{-1@} if the schedule is disabled (@tt{"Never"@}).
{
  array vals = query();
  if (sizeof(vals) == VALS_MINUTE) {
    vals += ({ 0 });
  }
  if( !vals[VALS_SORT] )
    return -1;

  // Every n:th hour.
  if( vals[VALS_SORT] == 1 )
    if( !last )
      return time(1);
    else
      return last + 3600 * vals[VALS_REPEAT_HOURS];

  mapping m = localtime( last || time(1) );
  m->sec = 0;
  m->min -= (m->min % 15);
  if( !vals[VALS_DAY] ) {
    // Every n:th day at x.
    if (!last)
    {
      for(int i; i<vals[VALS_REPEAT_COUNT]; i++)
	m = next_or_same_time( m, vals[VALS_HOUR], vals[VALS_MINUTE] );
      return mktime(m);
    }
    else
    {
      for(int i; i<vals[VALS_REPEAT_COUNT]; i++)
	m = next_time( m, vals[VALS_HOUR], vals[VALS_MINUTE] );
      return mktime(m);
    }
  }

  // Every x-day at y.
  if (!last)
  {
    for(int i; i<vals[VALS_REPEAT_COUNT]; i++)
    {
      m = next_or_same_time( next_or_same_day( m, vals[VALS_DAY]-1,
					       vals[VALS_HOUR]+1,
					       vals[VALS_MINUTE] ),
			     vals[VALS_HOUR], vals[VALS_MINUTE], 6*24*3600 );
    }
  }
  else
  {
    for(int i; i<vals[VALS_REPEAT_COUNT]; i++)
    {
      m = next_or_same_time( next_or_same_day( m, vals[VALS_DAY]-1,
					       vals[VALS_HOUR],
					       vals[VALS_MINUTE] ),
			     vals[VALS_HOUR], vals[VALS_MINUTE], 6*24*3600 );
    }
  }
  return mktime(m);
}

#if constant(roxenp)

private string checked( int pos, int alt )
{
  if(alt==query()[pos])
    return " checked='checked'";
  return "";
}

string render_form( RequestID id, void|mapping additional_args )
{
  string res, inp1, inp2, inp3, inp4;
  array vals = query();
  if (sizeof(vals) == VALS_MINUTE) {
    vals += ({ 0 });
  }

  res = "<table>";

  if (valid_sorts[0]) {
    res +=
      "<tr valign='top'><td><input name='" + path() + "' value='0' type='radio' " +
      checked(0,0) + " /></td><td>" + LOCALE(482, "Never") + "</td></tr>\n";
  }

  if (valid_sorts[1]) {
    inp1 = HTML.select(path()+"1", "123456789"/1 + "1011121314151617181920212223"/2, (string)vals[VALS_REPEAT_HOURS]);

    res += "<tr valign='top'><td><input name='" + path() + "' value='1' type='radio' " +
      checked(0,1) + " /></td><td>" + sprintf( LOCALE(483, "Every %s hour(s)."), inp1) +
      "</td></tr>\n";
  }

  if (valid_sorts[2]) {
    inp1 = HTML.select(path()+"2", "123456789"/1, (string)vals[VALS_REPEAT_COUNT]);
    inp2 = HTML.select(path()+"3", ({
      ({ "0", LOCALE(484, "Day") }),
      ({ "1", LOCALE(485, "Sunday") }),
      ({ "2", LOCALE(486, "Monday") }),
      ({ "3", LOCALE(487, "Tuesday") }),
      ({ "4", LOCALE(488, "Wednesday") }),
      ({ "5", LOCALE(489, "Thursday") }),
      ({ "6", LOCALE(490, "Friday") }),
      ({ "7", LOCALE(491, "Saturday") }) }), (string)vals[VALS_DAY]);
    inp3 = HTML.select(path()+"4",
		       "000102030405060708091011121314151617181920212223"/2,
		       sprintf("%02d", vals[VALS_HOUR]));
    inp4 = HTML.select(path()+"5",
		       "00153045"/2,
		       sprintf("%02d", vals[VALS_MINUTE]));

    res += "<tr valign='top'><td><input name='" + path() + "' value='2' type='radio' " +
      checked(0,2) + " /></td>\n<td>" +
      sprintf(LOCALE(492, "Every %s %s at %s:%s o'clock."),
	      inp1, inp2, inp3, inp4) +
      "</td></tr>\n";
  }

  res += "</table>";

  return res;
}

string render_view( RequestID id, void|mapping additional_args )
{
  array res = query();
  if (sizeof(res) == VALS_MINUTE) {
    res += ({ 0 });
  }
  switch(res[VALS_SORT]) {
    case 0:
      return LOCALE(482, "Never");
    case 1:
      return sprintf(LOCALE(493, "Every %d hour."), res[VALS_REPEAT_HOURS]);
    case 2:
      string period = ({
	LOCALE(484, "Day"),
	LOCALE(485, "Sunday"),
	LOCALE(486, "Monday"),
	LOCALE(487, "Tuesday"),
	LOCALE(488, "Wednesday"),
	LOCALE(489, "Thursday"),
	LOCALE(490, "Friday"),
	LOCALE(491, "Saturday")
      })[res[VALS_DAY]];

      return sprintf(LOCALE(494, "Every %d %s at %02d:%02d"),
		     res[VALS_REPEAT_COUNT], period,
		     res[VALS_HOUR], res[VALS_MINUTE]);
    default:
      return LOCALE(495, "Error in stored value.");
  }
}

protected void create(array(int) default_value, void|int flags,
		      void|LocaleString std_name, void|LocaleString std_doc,
		      multiset(int(0..2))|void valid_sorts)
{
  if (valid_sorts) {
    this_program::valid_sorts &= valid_sorts;
    if (!sizeof(this_program::valid_sorts)) {
      error("Invalid set of operation modes for Schedule: %O\n", valid_sorts);
    }
  }
  if (sizeof(default_value||({})) &&
      !this_program::valid_sorts[default_value[VALS_SORT]]) {
    error("Invalid default mode for Schedule: %O\n", default_value[VALS_SORT]);
  }
  ::create(default_value, flags, std_name, std_doc);
}

#endif
