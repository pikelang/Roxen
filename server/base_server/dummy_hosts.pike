/* Dummy host_lookup, used when NO_DNS is defined. */

string cvs_version = "$Id: dummy_hosts.pike,v 1.2 1996/12/01 19:18:28 per Exp $";
void create_host_name_lookup_processes() {}

string quick_host_to_ip(string h) { return h; }

varargs void host_to_ip(string host, function callback, mixed ... args)
{
  return callback(0, @args);
}

varargs void ip_to_host(string ipnumber, function callback, mixed ... args)
{
  return callback(ipnumber, @args);
}

