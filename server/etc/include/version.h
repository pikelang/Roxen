/*
 * Version information
 */

constant __roxen_version__ = "1.4";
constant __roxen_build__ = "0";

#ifdef __NT__
string real_version= "Roxen Challenger/"+__roxen_version__+"."+__roxen_build__+" NT";
#else
string real_version= "Roxen Challenger/"+__roxen_version__+"."+__roxen_build__;
#endif

