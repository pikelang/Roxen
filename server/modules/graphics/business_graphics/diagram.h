// This file is part of business graphics. Copyright © 1998 - 2000, Roxen IS.
// $Id: diagram.h,v 1.9 2000/09/15 02:10:33 nilsson Exp $

#define PI 3.14159265358979
#define VOIDSYMBOL "\n"
#define SEP "\t"
#define UNICODE(TEXT,ENCODING) Locale.Charset.decoder(ENCODING)->feed(TEXT)->drain()

constant LITET = 1.0e-38;
constant STORTLITET = 1.0e-30;
constant STORT = 1.0e30;

#define GETFONT(WHATFONT) object notext=resolve_font(diagram_data->WHATFONT||diagram_data->font);
