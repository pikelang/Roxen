// <locale-token project="roxen_config">_</locale-token>
#include <roxen.h>
#define _(X,Y)	_DEF_LOCALE("roxen_config",X,Y)

inherit .Box.RDF;
constant host = "www.ars-technica.com";
constant port = 80;
constant file = "/etc/rdf/ars.rdf";

constant box      = "small";
constant box_initial = 0;

String box_name = _(0,"ArsTechnica headlines");
String box_doc  = _(0,"The headlines from ArsTechnica: "
		    "the pc enthusiast's resource");

