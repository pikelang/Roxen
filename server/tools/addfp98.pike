/*
 * addfp98.pike
 *
 * Script to create a fake Apache configuration file for the FrontPage98
 * package.
 *
 * Script originally provided by Mike Knott <mknott@cybermedia-inc.com>
 * Minor modifications by Leif Stensson <leif@roxen.com>
 *
 * $Id$
 */

#!/usr/local/bin/pike
#define FP_BASE "/usr/local/frontpage"

import Getopt;
import Stdio;
import Process;

void create_dir(string dir)
{
  if(!file_stat(dir) && !mkdir(dir)) {
    perror("Can not create directory "+dir);
    exit(1);
  }
}


void main(int argc, array (string) argv)
{
  string login  = find_option(argv, "l", "login", 0, 0);
  string domain = find_option(argv, "d", "domain", 0, 0);
  string passwd = find_option(argv, "p", "passwd", 0, 0);
  string port   = find_option(argv, 0, "port", 0, "80");
  string d_root = find_option(argv, "r", "document-root", 0, 0);
  string data;

  if(!login || !domain || !d_root || !passwd)
  {
    werror("Syntax: addfp98.pike -d <domain> -l <login> -p <passwd> "
	   "-r <document-root> [--port=<port>]\n");
    exit(1);
  }
  write("Setting up Frontpage...\n");

  string fp_dir = FP_BASE + "/" + domain + ":" + port;
  create_dir(fp_dir);
  chmod(fp_dir, 0755);

  string conf_dir = fp_dir + "/conf";
  create_dir(conf_dir);
  chmod(conf_dir, 0755);
  
  data =
    "# -FrontPage- version=2.0\n"
    "DocumentRoot $D_ROOT$\n"
    "Port $PORT$\n"
    "ServerRoot $FP_DIR$\n"
    "<VirtualHost $DOMAIN$>\n"
    "ScriptAlias /cgi-bin/ $D_ROOT$/cgi-bin/ \n"
    "ScriptAlias /_vti_bin/_vti_adm/ $D_ROOT$/_vti_bin/_vti_adm/ \n"
    "ScriptAlias /_vti_bin/_vti_aut/ $D_ROOT$/_vti_bin/_vti_aut/ \n"
    "ScriptAlias /_vti_bin/ $D_ROOT$/_vti_bin/ \n"
    "</VirtualHost>\n";
  
  data = replace(data,
		 ({ "$LOGIN$", "$PORT$", "$DOMAIN$",
		    "$D_ROOT$", "$FP_DIR$" }),
		 ({ login, port, domain, d_root, fp_dir }));
  
  Stdio.File(fp_dir + "/srm.conf", "rwct")->write(data);
  if(!file_stat(conf_dir + "/srm.conf"))
    symlink("../srm.conf", conf_dir + "/srm.conf");
  cd(FP_BASE);
  data = replace("currentversion/bin/fpsrvadm.exe -o install -p $PORT$ -s "
		 "$FP_DIR$/srm.conf -u $LOGIN$ -pw $PASSWD$ -type apache "
		 //"-xUser $LOGIN$ -xGroup users "
		 "-multihost $DOMAIN$",
		 ({ "$LOGIN$", "$PASSWD$", "$PORT$", "$DOMAIN$",
		    "$D_ROOT$", "$FP_DIR$" }),
		 ({ login, passwd, port, domain, d_root, fp_dir }));
  //write(data + "\n");
  write(popen(data));
}
