/*
 * Version information
 */

// Note that version information (major and minor) is also
// present in module.h.
constant __roxen_version__ = "2.1";
constant __roxen_build__ = "95";

#ifdef __NT__
constant real_version= "Roxen/"+__roxen_version__+"."+__roxen_build__+" NT";
#else
constant real_version= "Roxen/"+__roxen_version__+"."+__roxen_build__;
#endif
