//!NOMODULE
/* $Id: monitor.pike,v 1.1 1999/04/24 16:41:05 js Exp $ */
/*

     Returns LDAP Server status
     v1.0, (c) hop@unibase.cz

*/

//#define DWRITE(X)	write(X)
#define DWRITE(X)

#define LDAP_MONITOR_DN		"cn=monitor"
#define LDAP_MONITOR_SCOPE	0
#define LDAP_MONITOR_FILTER	"objectclass"

int main(int argc, array(string) argv) {

  object ld, rv;
  mapping m;


	if(argc < 2) {
	  write("\nUsage:\n       monitor.pike <hostname>\n");
	  write("                       Use \"\" for null values.\n");
	  return(1);
	}

	ld = Protocols.LDAP.client(argv[1]);
	ld->bind();
	ld->set_basedn(LDAP_MONITOR_DN);
	ld->set_scope(LDAP_MONITOR_SCOPE);
	rv = ld->search(LDAP_MONITOR_FILTER);
	if(!objectp(rv))
	  write("Search failed. Error: " + ld->error_string() + "\n");
	else {
	  write("Search succeeded. Returned code: " + rv->error_string() + "\n");
	  write("       Number of entries: " + (string)rv->num_entries() + "\n");
	  for(int ix=1; ix<=rv->num_entries(); ix++) {
	    m = rv->fetch(ix);
	    write("       -------------------------------\n");
	    write(sprintf("       %2d: %s\n", ix, m->dn[0]));
	    write("       -------------------------------\n");
	    write(sprintf("       %O\n", m));
	  }

	}
	ld->unbind();	

	return(0);

}
