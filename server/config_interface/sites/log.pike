inherit "../logutil.pike";
#include <config.h>
#include <roxen.h>
//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)

string parse(RequestID id)
{
  mapping log = id->misc->current_configuration->error_log;
  array report = indices(log), r2;

  last_time=0;
  r2 = map(values(log),lambda(array a){
     return id->variables->reversed?-a[-1]:a[0];
  });
  sort(r2,report);
  for(int i=0;i<min(sizeof(report),1000);i++) 
     report[i] = describe_error(report[i], log[report[i]],
				id->misc->cf_locale, 1);

  if( sizeof( report ) > 1000 )
    report[1000] =
      sprintf(LOCALE(467,"%d entries skipped. Present in log on disk"),
	      sizeof( report )-1000 );

  return (sizeof(report)?(report[..1000]*""):LOCALE(250, "Empty"));
}
