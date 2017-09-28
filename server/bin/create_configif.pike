/*
 * $Id$
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

class Readline
{
  inherit Stdio.Readline;

  void trap_signal(int n)
  {
    werror("Interrupted, exit.\r\n");
    destruct(this_object());
    exit(1);
  }

  void destroy()
  {
    get_input_controller()->dumb = 0;
    ::destroy();
    signal(signum("SIGINT"));
  }

    private string safe_value(string r)
    {
	if(!r)
	{
	    /* C-d? */
	    werror("\nTerminal closed, exit.\n");
	    destruct(this_object());
	    exit(1);
	}
	
	return r;
    }
    
  string read(mixed ... args)
  {
    return safe_value(::read(@args));
  }

  string edit(mixed ... args)
  {
    return safe_value(::edit(@args));
  }
  
  void create(mixed ... args)
  {
    signal(signum("SIGINT"), trap_signal);
    ::create(@args);
  }
}

mapping(string:string) batch;

string read_string(Readline rl, string prompt,
		   string|void batch_symbol, string|void def)
{
  string res;
  if (batch && batch_symbol) {
    res = batch[batch_symbol] || def;
    if (res) return res;
  }

  res = rl->edit(def || "", prompt+" ", ({ "bold" }));
  if( def && !strlen(res-" ") )
    res = def;
  return res;
}

#if constant(Crypto.Password)
constant hash_password = Crypto.Password.hash;
#else
constant hash_password = Crypto.make_crypt_md5;
#endif

int main(int argc, array argv)
{
  Readline rl = Readline();
  string name = "Administration Interface";
  string user = "administrator";
  string password, configdir, port;
  string passwd2;

#if constant( SSL )
  string def_port = "https://*:"+(random(20000)+10000)+"/";
#else
  string def_port = "http://*:"+(random(20000)+10000)+"/";
#endif

  //werror("Argv: ({%{%O, %}})\n", argv);

  if(has_value(argv, "--help")) {
    write(#"
Creates and initializes a Roxen WebServer configuration
interface. Arguments:

 -d dir   The location of the configuration interface.
          Defaults to \"../configurations\".
 -a       Only create a new administration user.
          Useful when the administration password is lost.
 --help   Displays this text.
 --batch  Create a configuration interface in batch mode.
          The --batch argument should be followed by an optional
          list of value pairs, each pair representing the name
          of a question field and the value to be filled in.
          Available fields:
      server_name    The name of the server. Defaults to
                     \"Administration Interface\".
      server_url     The server url, e.g. \"http://*:1234/\".
                     Defaults to \"https://*:22202/\" in batch mode.
      user           The name of the administrator.
                     Defaults to \"administrator\".
      password       The administrator password.
                     NB: No default; if not specified, no
                     administration user will be created.
      ok             Require interactive user confirmation of the
                     above information with the value pair \"ok n\".

Example of batch installation with interactive password entry:

 ./create_configinterface --batch server_name Admin server_url \\
   http://*:8080/ ok y user admin

");
    return 0;
  }

  configdir =
   Getopt.find_option(argv, "d",({"config-dir","configuration-directory" }),
  	              ({ "ROXEN_CONFIGDIR", "CONFIGURATIONS" }),
                      "../configurations");
  int admin = has_value(argv, "-a");

//    werror("Admin mode: %O\n"
//  	 "Argv: ({%{%O, %}})\n", admin, argv);

  int batch_args = search(argv, "--batch");
  if(batch_args>=0)
    batch = (mapping)(argv[batch_args+1..]/2);

  if (batch) {
    if (!batch->server_url) {
      batch->server_url = "https://*:22202/";
    }
    if (batch["__semicolon_separated__"]) {
      // Used by Win32Installer.vbs:CreateConfigInterface().
      array(string) sections = batch["__semicolon_separated__"]/";";
      if (sizeof(sections) < 6) {
	error("Too few sections in __semicolon_separated__: %O.\n",
	      batch["__semicolon_separated__"]);
      }
      cd(sections[0]);				// SERVERDIR
      batch->server_name = sections[1];		// SERVER_NAME
      batch->server_url = sprintf("%s://*:%s/",
				  sections[2],	// SERVER_PROTOCOL
				  sections[3]);	// SERVER_PORT
      batch->user = sections[4];			// ADM_USER
      batch->password = sections[5..]*";";	// ADM_PASS1
    }
  }

  foreach( get_dir( configdir )||({}), string cf )
    catch 
    {
      if( cf[-1]!='~' &&
	  search( Stdio.read_file( configdir+"/"+cf ), 
                  "'config_filesystem#0'" ) != -1 )
      {
	string server_version = Stdio.read_file("VERSION");
	if(server_version)
	  Stdio.write_file(configdir+"/server_version","server-"+server_version);
        werror("   There is already an administration interface present in "
               "this\n   server. A new one will not be created.\n");
        if(!admin++) exit( 1 );
      }
    };
  if(admin==1) {
    werror("   No administration interface was found. A new one will be created.\n");
    admin = 0;
  }
  if(configdir[-1] != '/')
    configdir+="/";
  if(admin)
    write( "   Creating an administrator user.\n\n" );
  else
    write( "   Creating an administration interface server in\n"+
	   "   "+combine_path(getcwd(), configdir)+".\n");

  do
  {
    password = passwd2 = 0;
    
    if(!admin) 
    {
      write("\n");
      do {
	if (!sizeof(name)) name = "Administration Interface";
	name = read_string(rl, "Server name:", "server_name", name);
	if (batch) m_delete(batch, "server_name");
      } while (!sizeof(name));

      int port_ok;
      while( !port_ok )
      {
        string protocol = "https";
	string host, path;

        port = read_string(rl, "Port URL:", "server_url", def_port);
        if( port == def_port )
          ;
        else if( (int)port )
        {
          int ok;
          while( !ok )
          {
            switch( protocol = lower_case(read_string(rl, "Protocol:", "protocol", protocol)))
            {
             case "":
               protocol = "https";
             case "http":
             case "https":
               port = protocol+"://*:"+port+"/";
               ok=1;
               break;
             default:
               write("\n   Only http and https are supported for the "
                     "configuration interface.\n");
	       if (batch) m_delete(batch, "protocol");
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
             write("\n   Only http and https are supported for the "
                   "configuration interface.\n\n");
	     if (batch) m_delete(batch, "server_url");
             break;
          }
        }
      }
    }

    // NB: Don't create a user if batch mode and no password.
    if (!batch || batch->password) {
      do
      {
	user = read_string(rl, "Administrator user name:", "user", user);
	if (batch) m_delete(batch, "user");
      } while(((search(user, "/") != -1) || (search(user, "\\") != -1)) &&
	      write("User name may not contain slashes.\n"));

      do
      {
	if(passwd2 && password)
	  write("\n   Please select a password with one or more characters. "
		"You will\n   be asked to type the password twice for "
		"verification.\n\n");
	rl->get_input_controller()->dumb=1;
	password = read_string(rl, "Administrator password:", "password");
	passwd2 = read_string(rl, "Administrator password (again):", "password");
	rl->get_input_controller()->dumb=0;
	if(batch) m_delete(batch, "password");
	else
	  write("\n");
      } while(!strlen(password) || (password != passwd2));
    }

    if (!batch || has_prefix(lower_case(batch->ok || ""), "n")) {
      passwd2 = read_string(rl, "Are the settings above correct [Y/n]?", 0, "");
      if (has_prefix(lower_case(passwd2), "n")) {
	// Exit batch mode and retry interactively.
	batch = 0;
	continue;
      }
    }
    break;
  } while(1);

  if( !admin )
  {
    mkdirhier( configdir );
    string server_version = Stdio.read_file("VERSION");
    if(server_version)
      Stdio.write_file(configdir+"/server_version", "server-"+server_version);
    Stdio.write_file( configdir+replace( name, " ", "_" ),
                      replace(
#"
<!-- -*- html -*- -->
<?XML version=\"1.0\"?>
<roxen-config>

<region name='EnabledModules'>
  <var name='config_filesystem#0'> <int>1</int>  </var> <!-- Configration Filesystem -->
</region>

<region name='pikescript#0'>
  <var name='trusted'><int>1</int></var>
</region>

<region name='graphic_text#0'>
  <var name='colorparse'>        <int>1</int> </var>
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
  <var name='URLs'> <a> <str>$URL$#ip=;nobind=0;</str></a> </var>

  <var name='comment'>
    <str>Automatically created by create_configuration</str>
  </var>
  <var name='compat_level'>
    <str>5.2</str>
  </var>

  <var name='name'>
    <str>$NAME$</str>
  </var>
</region>

</roxen-config>",
 ({ "$NAME$", "$URL$" }),
 ({ name, port }) ));
    write("\n   Administration interface created.\n");
  }

  if (password) {
    string ufile=(configdir+"_configinterface/settings/" + user + "_uid");
    mkdirhier( ufile );
    Stdio.File( ufile, "wct", 0770 )
      ->write(
string_to_utf8(#"<?xml version=\"1.0\"  encoding=\"utf-8\"?>
<map>
  <str>permissions</str> : <a> <str>Everything</str> </a>
  <str>real_name</str>   : <str>Administrator</str>
  <str>password</str>    : <str>" + hash_password(password) + #"</str>
  <str>name</str>        : <str>" + user + #"</str>
</map>\n" ));

    write("\n   Administrator user \"" + user + "\" created.\n");
  } else {
    write(#"

   NOTE: No administration user has been created.
         To create an administration user later; run

           create_configinterface -a\n");
  }
}
