//!NOMODULE
/* $Id: ldapsearch.pike,v 1.1 1999/04/24 16:41:04 js Exp $ */
/*


     Emulation of ldapsearch command
     v1.0, (c) hop@unibase.cz

*/

//#define DWRITE(X)	write(X)
#define DWRITE(X)

int main(int argc, array(string) argv) {

  object ld, rv;

	DWRITE(sprintf("argc: %d argv %O\n", argc, argv));

	if(argc < 5) {
	  write("\nUsage:\n       ldapsearch.pike <hostname> <basedn> <scope> <filter>\n");
	  write("                       scope: 0=base, 1=onelevel, 2=subtree\n");
	  write("                       Use \"\" for null values.\n");
	  return(1);
	}

	ld = Protocols.LDAP.client(argv[1]);
	ld->bind();
	ld->set_basedn(argv[2]);
	ld->set_scope((int)argv[3]);
	rv = ld->search(argv[4]);
	if(!objectp(rv))
	  write("Search failed. Error: " + ld->error_string() + "\n");
	else {
	  write("Search succeeded. Returned code: " + rv->error_string() + "\n");
	  write("       Number of entries: " + (string)rv->num_entries() + "\n");
	  for(int ix=1; ix<=rv->num_entries(); ix++)
	    write(sprintf("       %2d: %s\n", ix, (rv->fetch(ix)->dn)[0]));

	}
	ld->unbind();	



}
