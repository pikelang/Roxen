/*
 * Version information
 */

constant __roxen_version__ = "2.0";
constant __roxen_build__ = "9";

#ifdef __NT__
string real_version= "Roxen/"+__roxen_version__+"."+__roxen_build__+" NT";
#else
string real_version= "Roxen/"+__roxen_version__+"."+__roxen_build__;
#endif
