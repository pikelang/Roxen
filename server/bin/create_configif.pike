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

  write( "Roxen 1.4 configuration interface installation script\n");

  configdir =
   Getopt.find_option(argv, "d",({"config-dir","configuration-directory" }),
  	              ({ "ROXEN_CONFIGDIR", "CONFIGURATIONS" }),
                      "../configurations");

  if(reverse(configdir)[0] != '/')
    configdir+="/";
  write( "Creating a configuration interface server in "+configdir+"\n");

  do
  {
    name = rl->read( "Server name [Configuration Interface]: " );
    if( !strlen(name-" ") )
      name = "Configuration Interface";

    port = rl->read( "Port ["+def_port+"]: ");
    if( !strlen(port-" ") )
      port = def_port;

    user = rl->read( "Administrator Username [administrator]: ");
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

  mapping user =
  ([
    "permissions":({"Everything"}),
    "name":user,
    "password":crypt( password ),
    "real_name":"Configuration Interface Default User",
  ]);

  string ufile=(".config_settings/"+replace(configdir,({ ".", "/" }),({"","-"}))+
                "/settings/"+user->name+"_uid");
  mkdirhier( ufile );
  Stdio.write_file( ufile, encode_value( user ) );

  mkdirhier( configdir );
  Stdio.write_file( configdir+replace( name, " ", "_" ),
replace(
#"
<!-- -*- html -*- -->
<?XML version=\"1.0\"?>

<region name='EnabledModules'>
  <var name='config_filesystem#0'> <int>1</int>  </var> <!-- Configration Filesystem -->
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
