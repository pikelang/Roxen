#include <roxen.h>
#define LOCALE	LOW_LOCALE->config_interface


int __lt;
string describe_time(int t)
{
  int full;
  if(localtime(__lt)->yday != localtime(t)->yday)
  {
    __lt = t;
    full=1;
  }

  if(full)
    return capitalize(roxen->language(LOW_LOCALE->name,"date")(t));
  else
    return sprintf("%02d:%02d",localtime(t)->hour,localtime(t)->min);
}

string describe_interval(int i)
{
  switch(i)
  {
   case 0..50:       return LOW_LOCALE->seconds(i);
   case 51..3560:    return LOW_LOCALE->minutes(((i+20)/60));
   default:          return LOW_LOCALE->hours(((i+300)/3600));
  }
}

string describe_times(array (int) times)
{
  __lt=0;
  if(sizeof(times) < 6)
    return String.implode_nicely(map(times, describe_time), LOW_LOCALE->and);

  int d, every=1;
  int ot = times[0];
  foreach(times[1..], int t)
    if(d)
    {
      if(abs(t-ot-d)>(d/4))
      {
	every=0;
	break;
      }
      ot=t;
    } else
      d = t-ot;
  if(every && (times[-1]+d) >= time(1)-10)
    return (LOW_LOCALE->every +" "
	    +describe_interval(d)+" "+LOW_LOCALE->since+" "+
	    describe_time(times[0]));
  return String.implode_nicely(map(times[..4], describe_time)+({"..."})+
			map(times[sizeof(times)-3..], describe_time),
			LOCALE->and);
}

string fix_err(string s)
{
  sscanf(reverse(s), "%*[ \t\n]%s", s);
  s=reverse(s);
  if(s=="")
    return s;
  if(!(<'.','!','?'>)[s[-1]]) s+=".";
  return capitalize(s);
}

int last_time;
string describe_error(string err, array (int) times)
{
  int code, nt;
  array(string) codetext=({ LOCALE->notice, 
			    LOCALE->warning, 
			    LOCALE->error });
  
  if(sizeof(times)==1 && times[0]/60==last_time) nt=1;
  last_time=times[0]/60;
  sscanf(err, "%d,%s", code, err);
  return ("<table><tr><td valign=top><img src=/internal-roxen-err_"+code+".gif \n"
	  "alt="+codetext[code-1]+">"
	  "</td><td>"+(nt?"":describe_times(times)+"<br>")+
	  replace(fix_err(err),"\n","<br>\n")+"</table>");
}


string parse(object id)
{
  array report = indices(roxen->error_log), r2;

  last_time=0;
  r2 = map(values(roxen->error_log),lambda(array a){
     return id->variables->reverse_report?-a[-1]:a[0];
  });
  sort(r2,report);
  for(int i=0;i<sizeof(report);i++) 
     report[i] = describe_error(report[i], roxen->error_log[report[i]]);
  return "</dl>"+(sizeof(report)?(report*""):LOCALE->empty())+"<dl>";
}
