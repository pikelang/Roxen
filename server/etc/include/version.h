// Version information
// $Id: version.h,v 1.434 2002/01/15 12:02:25 distmaker Exp $
// 
// Note that version information (major and minor) is also
// present in module.h.
constant __roxen_version__ = "2.4";
constant __roxen_build__ = "4";

#ifdef __NT__
constant real_version= "Roxen/"+__roxen_version__+"."+__roxen_build__+" NT";
#else
constant real_version= "Roxen/"+__roxen_version__+"."+__roxen_build__;
#endif
