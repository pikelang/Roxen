/*
 * Version information
 */

constant __roxen_version__ = "2.0";
constant __roxen_build__ = "21";

#ifdef __NT__
constant real_version= "Roxen/"+__roxen_version__+"."+__roxen_build__+" NT";
#else
constant real_version= "Roxen/"+__roxen_version__+"."+__roxen_build__;
#endif
