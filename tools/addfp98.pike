/*
 * addfp98.pike
 *
 * Script to create a fake Apache configuration file for the FrontPage98
 * package.
 *
 * Script originally provided by Mike Knott <mknott@cybermedia-inc.com>
 *
 * $Id: addfp98.pike,v 1.3 1999/01/29 03:28:42 leif Exp $
 */

#!/usr/local/bin/pike
#define FP_BASE "/usr/local/frontpage/"
#define FP_DIR FP_BASE "roxen/"+domain2

import Getopt;
import Stdio;
import Process;


void main(int argc, array (string) argv)
{
  string login  = find_option(argv, "l", "login", 0, 0);
  string domain = find_option(argv, "d", "domain", 0, 0);
  string passwd = find_option(argv, "p", "passwd", 0, "frontpage");
  array user;
  string data, domain2;

  if(!login || !domain)
  {
    werror("Syntax: addfp98.pike -d <domain> -l <login> "
           "[--passwd=<pass>]\n");
    exit(1);
  }
  
  if(search(domain, "www."))
    domain2 = "www."+domain;
  else
    domain2 = domain;
  
    write("Setting up Frontpage...\n");
    mkdir(FP_DIR);
    chmod(FP_DIR, 0755);
    cd(FP_DIR);
    data =
        "# -FrontPage- version=2.0\n"
        "DocumentRoot /users/$login$/html\n"
        "Port $port$\n"
        "ServerRoot /usr/local/frontpage/cyberhosting/$domain$\n"
        "<VirtualHost $domain$>\n"
        "ScriptAlias /cgi-bin/ /users/$login$/html/cgi-bin/ \n"
        "ScriptAlias /_vti_bin/_vti_adm/ /users/$login$/html/_vti_bin/_vti_adm/ \n"
        "ScriptAlias /_vti_bin/_vti_aut/ /users/$login$/html/_vti_bin/_vti_aut/ \n"
        "ScriptAlias /_vti_bin/ /users/$login$/html/_vti_bin/ \n"
        "</VirtualHost>\n";
        
    data = replace(data, ({"$login$", "$port$", "$domain$", "$uid$"}),
                   ({login, "80", domain2, (string)user[2]}));
    rm("srm.conf");
    write_file("srm.conf", data);
    cd(FP_BASE);
    write(popen(sprintf("currentversion/bin/fpsrvadm.exe -o install -p 80 -s "
                        "/usr/local/frontpage/roxen/%s/srm.conf -u "
                        "%s -pw %s -type apache -xUser %s -xGroup users  "
                        "-multihost %s",
                        domain2,
                        login, passwd,
                        login, domain2)));
}
