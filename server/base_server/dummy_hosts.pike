/* Dummy host_lookup, used when NO_DNS is defined. */

string cvs_version = "$Id: dummy_hosts.pike,v 1.3 1998/01/21 21:34:18 grubba Exp $";
void create_host_name_lookup_processes() {}

string quick_host_to_ip(string h) { return h; }

void host_to_ip(string|void host, function|void callback, mixed ... args)
{
  return callback(0, @args);
}

void ip_to_host(string|void ipnumber, function|void callback, mixed ... args)
{
  return callback(ipnumber, @args);
}

