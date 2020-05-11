// $Id$

inherit Variable.Variable;

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
//!   @elem int(0..23) time
//!     Time at which to restart.
//! @endarray
array transform_from_form( string what, mapping vl )
{
  array res = query() + ({});
  if(sizeof(res)!=5)
    res = ({ 0, 2, 1, 6, 3 });

  res[0] = (int)what;
  for(int i=1; i<5; i++) {
    res[i] = (int)vl[(string)i];
    res[i] = max( ({ 0, 1, 1, 0, 0 })[i], res[i] );
    res[i] = min( ({ 2, 23, 9, 7, 23 })[i], res[i] );
  }

  return res;
}

private string checked( int pos, int alt )
{
  if(alt==query()[pos])
    return " checked='checked'";
  return "";
}

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

private mapping next_or_same_day(mapping from, int day, int hour)
{
  if(from->wday==day && from->hour<hour)
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
  return m;
}

private mapping next_or_same_time(mapping from, int hour, void|int delta)
{
  if(from->hour==hour) return from;
  return next_time(from, hour, delta);
}

private mapping next_time(mapping from, int hour, void|int delta)
{
  if(from->hour<hour) {
    from->hour = hour;
    return from;
  }
  return localtime(mktime(from) + (24 - from->hour + hour)*3600 + delta);
}

int get_next( int last )
//! Get the next time that matches this schedule, starting from the
//! posix time @[last]. If last is 0, time(1) will be used instead.
//!
//! @returns
//!  When the next scheduled event is, represented by a posix time integer.
//!  Note that the returnes time may already have occured, so all return
//!  values < time() essentially means go ahead and do it right away.
//!  Minutes and seconds are cleared in the return value, so if the scheduler
//!  is set to every day at 5 o'clock, and this method is called at 5:42 it
//!  will return the posix time representing 5:00, unless of course @[last]
//!  was set to a posix time >= 5:00.
//!  Returns @tt{-1@} if the schedule is disabled (@tt{"Never"@}).
{
  array vals = query();
  if( !vals[0] )
    return -1;

  // Every n:th hour.
  if( vals[0] == 1 )
    if( !last )
      return time(1);
    else
      return last + 3600 * vals[1];

  mapping m = localtime( last || time(1) );
  m->min = m->sec = 0;
  if( !vals[3] ) {
    // Every n:th day at x.
    if (!last)
    {
      for(int i; i<vals[2]; i++)
	m = next_or_same_time( m, vals[4] );
      return mktime(m);
    }
    else
    {
      for(int i; i<vals[2]; i++)
	m = next_time( m, vals[4] );
      return mktime(m);
    }
  }

  // Every x-day at y.
  if (!last)
  {
    for(int i; i<vals[2]; i++)
    {
      m = next_or_same_time( next_or_same_day( m, vals[3]-1, vals[4]+1 ),
			     vals[4], 6*24*3600 );
    }
  }
  else
  {
    for(int i; i<vals[2]; i++)
    {
      m = next_or_same_time( next_or_same_day( m, vals[3]-1, vals[4] ),
			     vals[4], 6*24*3600 );
    }
  }
  return mktime(m);
}

string render_form( RequestID id, void|mapping additional_args )
{
  string res, inp1, inp2, inp3;

  res = "<table>"
    "<tr valign='top'><td><input name='" + path() + "' value='0' type='radio' " +
    checked(0,0) + " /></td><td>" + LOCALE(482, "Never") + "</td></tr>\n";

  inp1 = HTML.select(path()+"1", "123456789"/1 + "1011121314151617181920212223"/2, (string)query()[1]);

  res += "<tr valign='top'><td><input name='" + path() + "' value='1' type='radio' " +
    checked(0,1) + " /></td><td>" + sprintf( LOCALE(483, "Every %s hour(s)."), inp1) +
    "</td></tr>\n";

  inp1 = HTML.select(path()+"2", "123456789"/1, (string)query()[2]);
  inp2 = HTML.select(path()+"3", ({
    ({ "0", LOCALE(484, "Day") }),
    ({ "1", LOCALE(485, "Sunday") }),
    ({ "2", LOCALE(486, "Monday") }),
    ({ "3",  LOCALE(487, "Tuesday") }),
    ({ "4", LOCALE(488, "Wednesday") }),
    ({ "5", LOCALE(489, "Thursday") }),
    ({ "6", LOCALE(490, "Friday") }),
    ({ "7", LOCALE(491, "Saturday") }) }), (string)query()[3]);
  inp3 = HTML.select(path()+"4", "000102030405060708091011121314151617181920212223"/2,
		sprintf("%02d", query()[4]));

  res += "<tr valign='top'><td><input name='" + path() + "' value='2' type='radio' " +
    checked(0,2) + " /></td>\n<td>" +
    sprintf(LOCALE(492, "Every %s %s at %s o'clock."), inp1, inp2, inp3) +
    "</td></tr>\n</table>";

  return res;
}

string render_view( RequestID id, void|mapping additional_args )
{
  array res = query();
  switch(res[0]) {
    case 0:
      return LOCALE(482, "Never");
    case 1:
      return sprintf(LOCALE(493, "Every %d hour."), res[1]);
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
      })[query()[3]];

      return sprintf(LOCALE(494, "Every %d %s at %02d:00"), res[2], period, res[4]);
    default:
      return LOCALE(495, "Error in stored value.");
  }
}
