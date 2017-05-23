// Locale stuff.
// <locale-token project="roxen_config"> _ </locale-token>

#include <roxen.h>
#define _(X,Y)	_DEF_LOCALE("roxen_config",X,Y)

constant box      = "large";
constant box_initial = 1;

constant box_position = -1;

LocaleString box_name = _(365,"Welcome message");
LocaleString box_doc  = _(366,"Roxen welcome message and news");

string parse( RequestID id )
{
  // Ok. I am lazy. This could be optimized. :-)
  return #"<eval><insert file=\"welcome.txt\" /></eval>";
}
