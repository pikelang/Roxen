/*
 * name = "BG: diagram.h";
 * doc = "Business Graphics common things. You must upgrade this component to use newer versions of BG.";
 *
 * string cvs_version="$Id: diagram.h,v 1.4 1998/03/13 01:09:52 peter Exp $"
 */


#define max(i, j) (((i)>(j)) ? (i) : (j))
#define min(i, j) (((i)<(j)) ? (i) : (j))
#define abs(arg) ((arg)*(1-2*((arg)<0)))

#define PI 3.14159265358979
#define VOIDSYMBOL "\n"
#define SEP "\t"

constant LITET = 1.0e-38;
constant STORTLITET = 1.0e-30;
constant STORT = 1.0e30;

//#define BG_DEBUG 1
