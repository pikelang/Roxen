inherit Variable.Variable;
inherit "html";

// Locale macros
//<locale-token project="roxen_config"> LOCALE </locale-token>

#define LOCALE(X,Y)    \
  ([string](mixed)Locale.translate("roxen_config",roxenp()->locale->get(),X,Y))

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
//!   @elem int(1..9) everynth
//!   @elem int(0..7) day
//!     @int
//!       @value 0
//!         Day
//!       @value 1
//!         Sunday
//!       @value 2..7
//!         Rest of weekdays
//!     @endint
//!   @elem int(0.23) time
//! @endarray
array transform_from_form( string what, void|mapping vl )
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

private mapping next_or_same_day(mapping from, int day)
{
  if(from->wday==day) return from;
  return next_day(from, day);
}

private mapping next_day(mapping from, int day)
{
  from->hour = 0;
  if(from->wday<day) {
    from->wday = day;
    return from;
  }
  return localtime(mktime(from) + (7-from->wday)*3600*24 + day*3600*24);
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
  return localtime(mktime(from) + (24-from->hour)*3600 + delta + hour*3600);
}

int get_next( int last )
//! Get the next time that matches this schedule, starting with @[last].
//! If last is 0, time(1) will be used instead.
{
  array vals = query();
  if( !vals[0] )
    return -1;
  if( vals[0] == 1 )
    if( !last )
      return time(1);
    else
      return last + 3600 * vals[1];

  mapping m = localtime( last || time(1) );
  m->min = m->sec = 0;
  if( !last )
  {
    if( !vals[3] )
      return mktime( next_or_same_time( m, vals[4] ) );
    return mktime( next_or_same_time(
		     next_or_same_day( m, vals[3]-1 ),
		     vals[4], 7*24*3600 ) );
  }

  m->hour = 0;
  if(!vals[3])
    return mktime(m)+vals[2]*24*3600 + vals[4]*3600;
  for(int i; i<vals[2]; i++)
    m = next_day(m, vals[3]-1);
  return mktime(m) + vals[4]*3600;
}

string render_form( RequestID id, void|mapping additional_args )
{
  string res, inp1, inp2, inp3;

  res = "<table>"
    "<tr valign='top'><td><input name='" + path() + "' value='0' type='radio' " +
    checked(0,0) + " /></td><td>" + LOCALE(91, "Never") + "</td></tr>\n";

  inp1 = select(path()+"1", "123456789"/1 + "1011121314151617181920212223"/2, (string)query()[1]);

  res += "<tr valign='top'><td><input name='" + path() + "' value='1' type='radio' " +
    checked(0,1) + " /></td><td>" + sprintf( LOCALE(92, "Every %s hour(s)."), inp1) +
    "</td></tr>\n";

  inp1 = select(path()+"2", "123456789"/1, (string)query()[2]);
  inp2 = select(path()+"3", ({
    ({ "0", LOCALE(93, "Day") }),
    ({ "1", LOCALE(100, "Sunday") }),
    ({ "2", LOCALE(94, "Monday") }),
    ({ "3",  LOCALE(95, "Tuesday") }),
    ({ "4", LOCALE(96, "Wednesday") }),
    ({ "5", LOCALE(97, "Thursday") }),
    ({ "6", LOCALE(98, "Friday") }),
    ({ "7", LOCALE(99, "Saturday") }) }), (string)query()[3]);
  inp3 = select(path()+"4", "000102030405060708091011121314151617181920212223"/2,
		sprintf("%02d", query()[4]));

  res += "<tr valign='top'><td><input name='" + path() + "' value='2' type='radio' " +
    checked(0,2) + " /></td>\n<td>" +
    sprintf(LOCALE(101, "Every %s %s at %s o'clock."), inp1, inp2, inp3) +
    "</td></tr>\n</table>";

  return res;
}

string render_view( RequestID id, void|mapping additional_args )
{
  array res = query();
  switch(res[0]) {
    case 0:
      return LOCALE(91, "Never");
    case 1:
      return sprintf(LOCALE(108, "Every %d hour."), res[1]);
    case 2:
      string period = ({
	LOCALE(93, "Day"),
	LOCALE(94, "Monday"),
	LOCALE(95, "Tuesday"),
	LOCALE(96, "Wednesday"),
	LOCALE(97, "Thursday"),
	LOCALE(98, "Friday"),
	LOCALE(99, "Saturday"),
	LOCALE(100, "Sunday")
      })[query()[3]];

      return sprintf(LOCALE(109, "Every %d %s at %02d:00"), res[2], period, res[4]);
    default:
      return LOCALE(110, "Error in stored value.");
  }
}
