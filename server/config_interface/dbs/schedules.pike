#include <config_interface.h>
#include <config.h>
#include <roxen.h>
//<locale-token project="roxen_config">_</locale-token>
#define _(X,Y)	_STR_LOCALE("roxen_config",X,Y)

mapping|string parse( RequestID id )
{
  Sql.Sql db = connect_to_my_mysql(0, "roxen");

  if (id->variables["ok.x"]) {
    mixed err = catch {
	foreach(db->query("SELECT id FROM db_schedules")->id,
		string schedule) {
	  string var;
	  if ((var = id->variables["period-" + schedule])) {
	    array(string) segments = var/":";
	    int period;
	    int offset;
	    if (sizeof(segments) == 2) {
	      period = (int)segments[0];
	      offset = (int)segments[1] +
		(int)id->variables["time-" + schedule];
	      int generations = (int)id->variables["generations-" + schedule];
	      string method = id->variables["method-" + schedule];
	      string dir = id->variables["directories-" + schedule];
	      db->query("UPDATE db_schedules "
			"   SET period = %d, "
			"       offset = %d, "
			"       generations = %d, "
			"       method = %s, "
			"       dir = %s "
			" WHERE id = %s",
			period, offset, generations, method, dir, schedule);
	    } else {
	      db->query("UPDATE db_schedules "
			"   SET period = 0 "
			" WHERE id = %s",
			schedule);
	    }
	    DBManager.start_backup_timer((int)schedule, period, offset);
	  }
	}
      };
    if (err) master()->handle_error(err);
  }

  string res =
    "<h3>" + _(0, "Backup schedules") + ":</h3>\n"
    "<table width='100%'>\n"
    "<tr><th align='left'>" + _(0, "Schedule") +
    "</th><th align='left'>" + _(0, "Period") +
    "</th><th align='left'>" + _(0, "Time") +
    "</th><th align='left'>" + _(0, "Generations") +
    "</th><th align='left'>" + _(0, "Method") +
    "</th></tr>\n";

  foreach(db->query("SELECT id, schedule, period, offset, dir, "
		    "       generations, method "
		    "  FROM db_schedules "
		    " ORDER BY id ASC"), mapping(string:string) schedule) {
    int period = (int)schedule->period;
    int offset = (int)schedule->offset;
    if (period) offset %= period;
    int day = offset/86400;
    int hour = (offset/3600)%24;
    res += "<tr><td><b>" + Roxen.html_encode_string(schedule->schedule) +
      "</b></td>\n"
      "<td><default name='period-" + schedule->id + "' value='" +
      (schedule->period?(schedule->period + ":" + (day*86400)):"") +
      "'><select name='period-" + schedule->id + "'>\n"
      "<option value=''>" + _(0, "Never") + "</option>\n";
    foreach(_(0, "Sundays,Mondays,Tuesdays,Wednesdays,Thursdays,"
	      "Fridays,Saturdays")/","; int dayno; string day) {
      res += sprintf("<option value='%d:%d'>%s</option>\n",
		     86400*7, (((dayno + 3)%7)*86400),
		     Roxen.html_encode_string(day));
    }
#ifdef YES_I_KNOW_WHAT_I_AM_DOING
    res += "<option value='60:0'>Every minute</option>\n"
      "<option value='3600:0'>" + _(0, "Every Hour") + "</option>\n";
#endif
    res +=
      "<option value='86400:0'>" + _(0, "Every Day") + "</option>\n"
      "</select></default></td>\n"
      "<td>" + _(0, "At") +
      " <default name='time-" + schedule->id + "' value='" +
      hour*3600 + "'>"
      "<select name='time-" + schedule->id + "'>\n";
    int i;
    for (i = 0; i < 24; i++) {
      res += sprintf("<option value='%d'>%02d:00</option>\n", i*3600, i);
    }
    res += "</select></default></td>\n"
      "<td><default name='generations-" + schedule->id + "' "
      "value='" + schedule->generations +
      "'><select name='generations-" + schedule->id + "'>\n"
      "<option value='0'>" + _(0, "Unlimited") + "</option>\n"
      "<option value='1'>1</option>\n"
      "<option value='2'>2</option>\n"
      "<option value='3'>3</option>\n"
      "<option value='4'>4</option>\n"
      "<option value='5'>5</option>\n"
      "<option value='10'>10</option>\n"
      "</select></default></td>\n"
      "<td><default name='method-" + schedule->id +
      "' value='" + schedule->method + "'>"
      "<select name='method-" + schedule->id + "'>\n"
      "<option value='mysqldump'>" + _(0, "MySQLDump (recommended)") + "</option>\n"
      "<option value='backup'>" + _(0, "Backup (internal databases only)") + "</option>\n"
      "</select></default></td>\n"
      "</tr>\n"
      "<tr><td>&nbsp;</td><td colspan='3'>" +
      _(0, "Backup directory") +
      ": <input size='60%' name='directory-" + schedule->id +
      "' type='string' value='" + Roxen.html_encode_string(schedule->dir||"") +
      "' /></td><td>&nbsp;</td></tr>\n";
    if (schedule->id == "1") {
      res += "<tr><td>&nbsp;</td><td colspan='3'>" +
	_(0, "Note: This schedule is also used to schedule backups for "
	  "Roxen's internal databases.") +
	"</td><td>&nbsp;</td></tr>\n";
    }
  }

  res += "<tr><td>"
    "<submit-gbutton2 name='ok'>"+_(201,"OK")+"</submit-gbutton2></td>\n"
    "<td align='right' colspan='4'><cf-cancel href=''/></td></tr>\n";
    "</table>\n";

  return Roxen.http_string_answer(res);
}
