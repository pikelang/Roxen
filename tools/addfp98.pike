/*
 * addfp98.pike
 *
 * Script to create a fake Apache configuration file for the FrontPage98
 * package.
 *
 * Script originally provided by Mike Knott <mknott@cybermedia-inc.com>
 *
 * $Id: addfp98.pike,v 1.1 1998/12/04 22:17:18 leif Exp $
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
    werror("Syntax: addfrontpage.pike -d <domain> -l <login> "
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
    popen("tar xvf /root/srm_template.tar");
    data = read_file("srm.conf");
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
