/*
 * name = "BG: diagram.h";
 * doc = "Business Graphics common things. You must upgrade this component to use newer versions of BG.";
 *
 * string cvs_version="$Id: diagram.h,v 1.6 1998/11/04 20:13:42 peter Exp $";
 */


#define max(i, j) (((i)>(j)) ? (i) : (j))
#define min(i, j) (((i)<(j)) ? (i) : (j))
#define abs(arg) ((arg)*(1-2*((arg)<0)))

#define PI 3.14159265358979
#define VOIDSYMBOL "\n"
#define SEP "\t"
#define UNICODE(TEXT,ENCODING) Locale.Charset.decoder(ENCODING)->feed(TEXT)->drain()

constant LITET = 1.0e-38;
constant STORTLITET = 1.0e-30;
constant STORT = 1.0e30;

#define GETFONT(WHATFONT) object notext=resolve_font(diagram_data->WHATFONT||diagram_data->font);
					    
//#define BG_DEBUG 1
