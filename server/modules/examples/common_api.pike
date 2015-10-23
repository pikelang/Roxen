// This is a roxen module. Copyright © 2000 - 2009, Roxen IS.

inherit "module";
// All roxen modules must inherit module.pike
#include <roxen.h>
// include roxen.h for locale specific stuff

// Some defines for the translation system
// 
//<locale-token project="mod_common_api">LOCALE</locale-token>
#define LOCALE(X,Y)	_DEF_LOCALE("mod_common_api",X,Y)
// end of the locale related stuff

constant cvs_version="$Id$";
//! This string (filtered to remove some ugly cvs id markup) shows up in
//! the roxen administration interface when handling module parameters in
//! developer mode (configured under "User Settings" below the Admin tab).
//! It will also serve as the basis for extracting version information of
//! the file in the inherit tree. Optional, but convenient, especially if
//! you use cvs for version control of your code.

LocaleString module_name = LOCALE(1,"Tamaroxchi");
//! The name that will show up in the module listings when adding modules
//! or viewing the modules of a virtual server. Keep it fairly informative
//! and unique, since this is the only means for identification of your
//! module in the most brief add module view mode.

constant module_type = MODULE_ZERO;
//! Module type (see server/etc/include/module.h). May be bitwise ored
//! (|) for hybrid modules. Hybrid modules must implement the required
//! API functions for all of the module types they are hybrids of.

LocaleString module_doc_locale = LOCALE(2,"This module does nothing, but its "
				  "inlined documentation gets imported "
				  "into the roxen programmer manual. "
				  "You really don't want to add this "
				  "module to your virtual server, promise!");
//! The documentation string that will end up in the administration
//! interface view of the module just below the module name. Also shows
//! up in the more verbose add module views.

constant module_unique = 1;
//! 0 to allow multiple instances of the module per virtual server,
//! 1 to allow at most one.

constant thread_safe = 0;
//! Tell Roxen that this module is thread safe. That is, there is no
//! request specific data in module global variables (such state is
//! better put in the <ref>RequestID</ref> object, preferably in the
//! <pi>id->misc</pi> mapping under some key unique to your module).
//!
//! If your module is not thread safe, setting this flag to zero (0) or
//! leaving it unset altogether will make roxen serialize accesses to
//! your module. This will hurt performance on a busy server. A value of
//! one (1) means your module is thread safe.

int itching = 0;
// Like this, see? We keep global state here, which is a really bad habit
// most of the time - hence the zero for thread_safe just above.

void create(Configuration|void conf)
//! In <pi>create()</pi>, you typically define your module's
//! configurable variables (using <ref>defvar()</ref>) and set data
//! about it using <ref>set_module_creator()</ref> and
//! <ref>set_module_url()</ref>. The configuration object of the
//! virtual server the module was initialized in is always passed,
//! except for the one occation when the file is compiled for the
//! first time, when the `conf' argument passed is 0. Se also
//! <ref>start</ref>.
{
  //report_debug("tamaroxchi(%O)\n", conf); // Ends up in the debug log
  set_module_creator("Johan Sundström <jhs@roxen.com>");
  set_module_url("https://jhs.user.roxen.com/examples/common_api.html");
}

mapping(LocaleString:function(RequestID:void)) query_action_buttons(RequestID id)
//! Optional callback for adding action buttons to the module's
//! administration settings page; convenient for triggering module
//! actions like flushing caches and the like.
//!
//! The indices of the returned mapping are the action descriptions that will
//! show up on each button (e g "flush cache"), and the corresponding values
//! are the callbacks for each button respectively. These functions may take
//! an optional RequestID argument, where this id object refers to the id
//! object in the admin interface sent with the request used to invoke the
//! action by the administrator.
{
  return ([ LOCALE(3,"Scratch me!") : scratch_me ]);
}

void scratch_me()
// No, this is not a common API function. :-)
{
  if(itching)
  {
    itching = 0;
    report_notice(LOCALE(4,"Aah, that's good.\n"));
  } else
    report_warning(LOCALE(5,"Ouch!\n"));
}

LocaleString info( Configuration conf )
//! Implementing this function in your module is optional.
//!
//! When present, it returns a string that describes the module.
//! When absent, Roxen will use element <ref>module_doc_locale</ref>. Unlike
//! module_doc_locale, though, this information is only shown when the module
//! is present in a virtual server, so it won't show up when adding
//! modules to a server.
{
  string mp = query_internal_location();
  
  return sprintf(LOCALE(6,"This string overrides the documentation string "
			"given in module_doc[_locale], but only once the "
			"module is added to a server. The module's internal "
			"mountpoint is found at <tt>%s</tt>"), mp );
}

LocaleString check_variable(string variable, mixed set_to)
//! Custom checks of configuration variable validities. (optional)
//!
//! Check admin interface variables for sanity.
//!
//! "variable" is the name of the variable we're checking,
//! "set_to" is the value being tested. A return value of zero (0)
//! means all was OK, a string is used as an error message that the
//! administrator will be prompted with when given a second shot at
//! getting it right.
{
  // find out what variable we're checking...
  if(variable=="variable1")
  {
    // find out if it's a value we'll accept... if so, then just return.
    if(set_to=="whatevervalueweaccept")
      return 0;
    else // if it's not, return an error message.
      return LOCALE(7,"Sorry, we don't accept that value.")+"\n";
  }
}

void start(int occasion, Configuration conf)
//! Set up shop / perform some action when saving variables. (optional)
//!
//! If occasion is 0, we're being called when starting up the module,
//! to perform whatever actions necessary before we are able to service
//! requests. This call is received when the virtual server the module
//! belongs to gets initialized, just after the module is successfully
//! added by the administrator or when reloading the module.
//!
//! This method is also called with occasion set to 2 whenever the
//! configuration is saved, as in when some module variable has changed
//! and the administrator clicked "save" in the admin interface. This
//! also happens just before calling <ref>stop()</ref> upon reloading
//! the module.
{
  report_notice(LOCALE(8,"Wow, I feel good!")+"\n");
}

void stop()
//! Close down shop. (optional)
//!
//! Tidy up before the module is terminated. This method is called
//! when the administrator drops the module, reloads the module or
//! when the server is being shut down.
{
  report_notice(LOCALE(9,"Guess that's what I get for all this itching. *sigh*")+"\n");
}

string status()
//! Tells some run-time status, statistics or similar to the curious
//! administrator. Implementing this function is optional.
//!
//! Returns a string of HTML that will be put in the admin interface
//! on the module's settings page just below the
//! <ref to=>documentation string</ref>.
{
  string how_much;
  itching += !random(3);

  switch(itching)
  {
    case 0: return LOCALE(10,"Feelin' fine.");
    case 1: how_much = LOCALE(11,"a bit"); break;
    case 2: how_much = LOCALE(12,"noticeably"); break;
    case 3: how_much = LOCALE(13,"quite a bit"); break;
    case 4: how_much = LOCALE(14,"really much"); break;
    case 5: how_much = LOCALE(15,"a lot"); break;
    case 6: how_much = LOCALE(16,"unbearably"); break;
    default: how_much = LOCALE(17,"more than any sane person could stand");
  }
  return sprintf(LOCALE(18,"I'm itching %s. Please scratch me!"), how_much);
}

mapping|int|Stdio.File find_internal(string file, RequestID id)
//! Internal magic location. May return a result mapping,
//! -1 for a directory indicator, an open file descriptor
//! or 0, signifying file not found / request not handled.
//! Similar to the MODULE_LOCATION <ref>find_file()</ref>
//! in most respects, except that the mountpoint is defined
//! by the virtual server, and mostly used for background
//! things where a URL doesn't show too much, such as when
//! generating background images and the like. To get the
//! internal mountpoint below which find_internal will handle
//! requests, use <ref>query_internal_location()</ref>.
{
  return Roxen.http_string_answer(status());
}
