inherit "roxenlib";
constant name= "Shut Roxen down";

constant doc = ("Roxen will <font size=+1 color=darkred><b>not</b></font> restart automatically if you select this action.");

mixed handle(object id, object mc)
{
  return http_redirect(roxen->config_url()+"(shutdown)/Actions/");
}
