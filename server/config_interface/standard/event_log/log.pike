inherit "../logutil.pike";
#include <config.h>
#include <roxen.h>
#define LOCALE	LOW_LOCALE->config_interface


string parse(object id)
{
  mapping log = roxen->error_log;
  array report = indices(log), r2;

  last_time=0;
  r2 = map(values(log),lambda(array a){
     return id->variables->reversed?-a[-1]:a[0];
  });
  sort(r2,report);
  for(int i=0;i<sizeof(report);i++) 
     report[i] = describe_error(report[i], log[report[i]],
				id->misc->cf_locale, 2);
  return "</dl>"+(sizeof(report)?(report*""):LOCALE->empty)+"<dl>";
}
