/*
 * $Id: create_configif.pike,v 1.21 2000/04/12 19:09:20 js Exp $
 *
 * Create an initial administration interface server.
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

  write( "Roxen 2.0 administration interface installation script\n");

  configdir =
   Getopt.find_option(argv, "d",({"config-dir","configuration-directory" }),
  	              ({ "ROXEN_CONFIGDIR", "CONFIGURATIONS" }),
                      "../configurations");
  int admin = has_value(argv, "-a");

  
  foreach( get_dir( configdir )||({}), string cf )
    catch 
    {
      if( cf[-1]!='~' &&
	  search( Stdio.read_file( configdir+"/"+cf ), 
                  "'config_filesystem#0'" ) != -1 )
      {
        werror("There is already an administration interface present in "
               "this server.\nNo new will be created\n");
        exit( 0 );
      }
    };
  if(configdir[-1] != '/')
    configdir+="/";
  if(admin)
    write( "Creating an administrator user.\n" );
  else
    write( "Creating an administration interface server in "+configdir+"\n");

  do
  {
    if(!admin) 
    {
      name = rl->read( "Server name [Administration Interface]: " );
      if( !strlen(name-" ") )
	name = "Administration Interface";

      int port_ok;
      while( !port_ok )
      {
        string protocol, host, path;

        port = rl->read( "Port URL ["+def_port+"]: ");
        if( !strlen(port-" ") )
          port = def_port;
        else if( (int)port )
        {
          int ok;
          while( !ok )
          {
            switch( protocol = lower_case(rl->read( "Protocol [http]: ")) )
            {
             case "":
               protocol = "http";
             case "http":
             case "https":
               port = protocol+"://*:"+port+"/";
               ok=1;
               break;
             default:
               write("Only http and https are supported for the "
                     "configuration interface\n");
               break;
            }
          }
        }

        if( sscanf( port, "%[^:]://%[^/]%s", protocol, host, path ) == 3)
        {
          if( path == "" )
            path = "/";
          switch( lower_case(protocol) )
          {
           case "http":
           case "https":
             // Verify hostname here...
             port = lower_case( protocol )+"://"+host+path;
             port_ok = 1;
             break;
           default:
             write("Only http and https are supported for the "
                   "configuration interface\n");
             break;
          }
        }
      }
    }

    do 
    {
      user = rl->read( "Administrator user name [administrator]: ");
    } while(((search(user, "/") != -1) || (search(user, "\\") != -1)) &&
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


  if( !admin )
  {
    string community_user, community_password, proxy_host="", proxy_port="80";
    string community_userpassword="";
    int use_update_system=0;
  
    write("Roxen 2.0 has a built-in update system. If enabled it will periodically\n");
    write("contact update servers at Roxen Internet Software over the Internet.\n");
    write("Do you want to enable this?\n");

    if(!(strlen( passwd2 = rl->read( "Ok? [y]: " ) ) && passwd2[0]=='n' ))
    {
      use_update_system=1;
      write("If you have a registered user identity at Roxen Community\n");
      write("(http://community.roxen.com), you may be able to access\n");
      write("additional material through the update system.\n");
      write("Press enter to skip this.\n");
      community_user=rl->read("Roxen Community Identity (your e-mail): ");
      if(sizeof(community_user))
      {
        do
        {
          rl->get_input_controller()->dumb=1;
          community_password = rl->read( "Roxen Community Password: ");
          passwd2 = rl->read( "Roxen Community Password (again): ");
          rl->get_input_controller()->dumb=0;
          write("\n");
          community_userpassword=community_user+":"+community_password;
        } while(!strlen(community_password) || (community_password != passwd2));
      
        if((strlen( passwd2 = rl->read("Do you want to access the update "
                                       "server through an HTTP proxy? [n]: "))
            && passwd2[0]!='n' ))
	{
	  proxy_host=rl->read("Proxy host: ");
	  if(sizeof(proxy_host))
	    proxy_port=rl->read("Proxy port: [80]");
	  if(!sizeof(proxy_port))
	    proxy_port="80";
	}
      }
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

<region name='update#0'>
  <var name='do_external_updates'> <int>$USE_UPDATE_SYSTEM$</int> </var>
  <var name='proxyport'>         <int>$PROXY_PORT$</int> </var>
  <var name='proxyserver'>       <str>$PROXY_HOST</str> </var>
  <var name='userpassword'>      <str>$COMMUNITY_USERPASSWORD$</str> </var>
</region>

<region name='contenttypes#0'>
  <var name='_priority'>         <int>0</int> </var>
  <var name='default'>           <str>application/octet-stream</str> </var>
  <var name='exts'><str># This will include the defaults from a file.
# Feel free to add to this, but do it after the #include line if
# you want to override any defaults

#include %3cetc/extensions%3e
tag text/html
xml text/html
rad text/html
ent text/html

</str></var>
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
 ({ "$NAME$", "$URL$", "$USE_UPDATE_SYSTEM$","$PROXY_PORT$",
    "$PROXY_HOST", "$COMMUNITY_USERPASSWORD$" }),
 ({ name, port, (string)use_update_system, proxy_port,
    proxy_host, community_userpassword }) ));
    write("Administration interface created\n");
  }

  string ufile=(configdir+"_configinterface/settings/" + user + "_uid");
  mkdirhier( ufile );
  Stdio.write_file(ufile,
string_to_utf8(#"<?XML version=\"1.0\"  encoding=\"UTF-8\"?>
<map>
  <str>permissions</str> : <a> <str>Everything</str> </a>
  <str>real_name</str>   : <str>Administration Interface Default User</str>
  <str>password</str>    : <str>" + crypt(password) + #"</str>
  <str>name</str>        : <str>" + user + "</str>\n</map>" ));

  write("Administrator user \"" + user + "\" created.\n");
}
