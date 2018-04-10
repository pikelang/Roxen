// Version information
// 
// Note that version information (major and minor) is also
// present in module.h and in the roxen.version test in
// ../test/tests/rxml/RoxenTest_BaseRXML.xml .
constant roxen_ver = "6.1";
constant roxen_build = "240";

#if !constant(roxen_release)
constant roxen_release = "-git";
#endif /* !constant(roxen_release) */

#ifdef __NT__
constant real_version= "Roxen/"+roxen_ver+"."+roxen_build+" NT"+roxen_release;
#else
constant real_version= "Roxen/"+roxen_ver+"."+roxen_build+roxen_release;
#endif

/* Compat for code that includes this file. (The reason for replacing
 * these two is that pike 7.8 and later reserves all identifiers
 * beginning and ending with "__".) */
#define __roxen_version__ roxen_ver
#define __roxen_build__ roxen_build
