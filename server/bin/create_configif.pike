/*
 * $Id: create_configif.pike,v 1.7 2000/03/07 18:56:46 grubba Exp $
 *
 * Create an initial configuration interface server.
 */

int mkdirhier(string from)
{
  string a, b;
  array f;

  f=(from/"/");
  b="";

  foreach(f[0..sizeof(f)-2], a)
  {
    mkdir(b+a);
    b+=a+"/";
  }
}


int main(int argc, array argv)
{
  Stdio.Readline rl = Stdio.Readline();
  string name, user, password, configdir, port;
  string passwd2;

  rl->redisplay( 1 );

#if constant( SSL3 )
  string def_port = "https://*:"+(random(20000)+10000)+"/";
#else
  string def_port = "http://*:"+(random(20000)+10000)+"/";
#endif

  write( "Roxen 2.0 configuration interface installation script\n");

  configdir =
   Getopt.find_option(argv, "d",({"config-dir","configuration-directory" }),
  	              ({ "ROXEN_CONFIGDIR", "CONFIGURATIONS" }),
                      "../configurations");
  int admin = has_value(argv, "-a");

  if(configdir[-1] != '/')
    configdir+="/";
  if(admin)
    write( "Creating an administrator user.\n" );
  else
    write( "Creating a configuration interface server in "+configdir+"\n");

  do
  {
    if(!admin) {
      name = rl->read( "Server name [Configuration Interface]: " );
      if( !strlen(name-" ") )
	name = "Configuration Interface";

      port = rl->read( "Port ["+def_port+"]: ");
      if( !strlen(port-" ") )
	port = def_port;
    }

    do {
      user = rl->read( "Administrator user name [administrator]: ");
    } while(((search(user, "/") != -1) || (search(user, "\\"))) &&
	    write("User name may not contain slashes.\n"));
    if( !strlen(user-" ") )
      user = "administrator";

    do
    {
      rl->get_input_controller()->dumb=1;
      password = rl->read( "Administrator Password: ");
      passwd2 = rl->read( "Administrator Password (again): ");
      rl->get_input_controller()->dumb=0;
      write("\n");
    } while(!strlen(password) || (password != passwd2));
  } while( strlen( passwd2 = rl->read( "Ok? [y]: " ) ) && passwd2[0]=='n' );

  string ufile=(configdir+"_configinterface/settings/" + user + "_uid");
  mkdirhier( ufile );
  Stdio.write_file(ufile,
string_to_utf8(#"<?XML version=\"1.0\"  encoding=\"UTF-8\"?>
<map>
  <str>permissions</str> : <a> <str>Everything</str> </a>
  <str>real_name</str>   : <str>Configuration Interface Default User</str>
  <str>password</str>    : <str>" + crypt(password) + #"
  <str>name</str>        : <str>" + user + "\n</map>" ));

  if(admin)
  {
    write("Administrator user \"" + user + "\" created.");
    return 0;
  }

  mkdirhier( configdir );
  Stdio.write_file( configdir+replace( name, " ", "_" ),
replace(
#"
<!-- -*- html -*- -->
<?XML version=\"1.0\"?>

<region name='EnabledModules'>
  <var name='config_filesystem#0'> <int>1</int>  </var> <!-- Configration Filesystem -->
</region>

<region name='pikescript#0'>
  <var name='trusted'><int>1</int></var>
</region>

<region name='spider#0'>
  <var name='Domain'> <str></str> </var>
  <var name='MyWorldLocation'><str></str></var>
  <var name='URLs'> <a> <str>$URL$</str></a> </var>

  <var name='comment'>
    <str>Automatically created by create_configuration</str>
  </var>

  <var name='name'>
    <str>$NAME$</str>
  </var>
</region>",
 ({ "$NAME$", "$URL$" }),
 ({ name, port }) ));
  write("Configuration interface created\n");

}
