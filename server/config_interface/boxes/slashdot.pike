// <locale-token project="roxen_config">_</locale-token>
#include <roxen.h>
#define _(X,Y)	_DEF_LOCALE("roxen_config",X,Y)

inherit .Box.RDF;
constant box      = "small";
constant box_initial = 0;

constant host = "slashdot.org";
constant port = 80;
constant file = "/slashdot.rdf";

String box_name = _(361,"Slashdot headlines");
String box_doc  = _(362,"The headlines from Slashdot: "
		    "News for nerds, stuff that matters");
