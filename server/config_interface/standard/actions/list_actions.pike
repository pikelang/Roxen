inherit "roxenlib";
#define LOCALE roxen->locale->get()->config_interface

string parse( RequestID id )
{
  string res = "";
  foreach( glob( "*.pike",
                 get_dir( dirname( __FILE__ ) ) ) ,
           string f )
  {
    mapping ac;
    if( ac = LOCALE["action_"+f-".pike"] )
    {
      res += "<p>"+ac->name+"<br>"+ac->doc;
    }
  }
  return res;
}
