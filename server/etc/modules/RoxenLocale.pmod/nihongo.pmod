#charset iso-2022

/*
 * $Id: nihongo.pmod,v 1.3 2000/03/14 02:22:11 per Exp $
 *
 * Roxen locale support -- $(BF|K\8l(B (nihongo (Japanese))
 *
 * Henrik Grubbström 1999-03-14
 */

inherit RoxenLocale.standard;
constant name="$(BF|K\8l(B";
constant language = "$(B$2$s$4(B";
constant user = "$(B%f!<%6(B";
constant latin1_name = "nihongo";
constant encoding = "iso-2022-jp";
constant reply_encoding = "utf-8";

class _base_server {
  inherit standard::_base_server;	// Fallback.

  string translate_cache_class( string what )
  {
    switch(what)
    {
     case "modules":      return "$(B%b%8%e!<%k(B";
     case "fonts":        return "$(B3h;zBN(B";
     case "file":         return "$(B%U%!%$%k(B";
     case "stat_cache":   return "$(B%U%!%$%k(B""$(B%9%F%$%?%9(B";
     case "hosts":        return "DNS";
    }
    return what;
  }
  string anonymous_user() { return("$(BL$>\(B"); }
};

class _config_interface
{
  inherit standard::_config_interface;
  // config/low_describers.pike
  constant font_test_string =("$(B$$$m$O$K$[$X$H(B"
			      "$(B$A$j$L$k$r(B"
			      "$(B$o$+$h$?$l$=(B"
			      "$(B$D$M$J$i$`(B"
			      "$(B$&$p$N$*$/$d$^(B"
			      "$(B$1$U$3$($F(B"
			      "$(B$"$5$-$f$a$K$7(B"
			      "$(B$q$R$b$;$9(B");
  string module_hint() {
    return "($(B%"%I%*%s%b%8%e!<%k(B)";
  }
  string font_hint() {
    return "($(B;zBN(B)";
  }
  string location_hint() {
    return "($(B%P!<%A%c%k%U%!%$%k%M!<%`(B)";
  }
  string file_hint() {
    return "($(B%U%!%$%k%M!<%`(B)";
  }
  string dir_hint() {
    return "($(B?ML>O?(B)";
  }
  string float_hint() {
    return "($(B<B?t(B)";
  }
  string int_hint() {
    return "($(B@0?t(B)";
  }
  string stringlist_hint() {
    return "($(BKg5s(B)";
  }
  string intlist_hint() {
    return "($(BKg5s@0?t(B)";
  }
  string floatlist_hint() {
    return "($(BKg5s<B?t(B)";
  }
  string dirlist_hint() {
    return "($(BKg5s?ML>O?(B)";
  }
  string password_hint() {
    return "($(B%Q%9%o!<%I(B)";
  }

  string color() {
    return "$(B?'(B";
  }

  string lines( int n ) {
    return _whatevers( "$(BNs(B", n );
  }
  // config/describers.pike
  string maintenance() {
    return "$(B;Y;}(B";
  }

  string status_info() {
    return("<b>$(B8=>u(B</b>");
  }
  // base_server/mainconfig.pike
  string roxen_challenger_maintenance() {
    return("Roxen $(B7P1D(B");
  }
  string continue_elipsis() {
    return("$(BB8CV(B...");
  }
  string add_module() {
    return "$(BIU$1$k(B" "$(B%"%I%*%s%b%8%e!<%k(B";
  }

  string administration_interface() {
    return("$(B%3%s%U%#%0%l!<%7%g%s(B "
           "$(B%f!<%6%$%s%?%U%'!<%9(B");
  }
  string admin_logged_on(string who, string from) {
    return("$(B1?1D<T(B "+who+" $(B%m%0%$%s(B  " + from + " $(B$+$i(B.\n");
  }
  string roxen_server_config() {
    return("Roxen"
           "$(B%5!<%P(B"
           "$(B%3%s%U%#%0%l!<%7%g%s(B"
           "$(B%f!<%6%$%s%?%U%'!<%9(B");
  }
  string button_newconfig() {
    return("$(BIU$1$k(B" "$(B%5!<%P(B");
  }
  string button_addmodule() {
    return("$(BIU$1$k(B" "$(B%"%I%*%s%b%8%e!<%k(B");
  }
  string button_delete() {
    return("$(B>C$9(B" "$(B%"%I%*%s%b%8%e!<%k(B");
  }
  string button_newmodulecopy() {
    return("$(BI{(B" "$(B%"%I%*%s%b%8%e!<%k(B");
  }
  string button_refresh() {
    return("$(B%j%U%l%C%7%e(B" "$(B%"%I%*%s%b%8%e!<%k(B");
  }
  string button_delete_server() {
    return("$(B>C$9(B" "$(B%5!<%P(B");
  }
  string button_foldall() {
    return("$(B@^$jJV$9(B" "$(BI4HL(B");
  }
  string button_unfoldmodified() {
    return("$(B9-$2$k(B" "$(BJQMF(B");
  }
  string button_unfoldlevel() {
    return("$(B9-$2$k(B" "");
  }
  string button_unfoldall() {
    return("$(B9-$2$k(B" "$(BI4HL(B");
  }
  string button_zapcache() {
    return("$(B6u$1$k%"%I%*%s%b%8%e!<%k1#$7>l=j(B");
  }
  string button_morevars() {
    return("$(BB?!9%;%C%F%#%s%0(B");
  }
  string button_nomorevars() {
    return("$(B67$7$F%;%C%F%#%s%0(B");
  }
  string button_save() {
    return("$(B%;!<%V(B");
  }
  string button_shutdown() {
    return("$(B%7%c%C%H%@%&%s(B");
  }


  constant language = language;
  constant user = "$(B%(%s%I%f!<%6(B";
  constant upgrade = "$(B>e$j:d(B";
  constant ports = " $(B%]!<%H(B";
  constant save = "$(B%;!<%V(B";
  constant actions = "$(B9TF0(B";
  constant clear_log = "$(B@Z$jJ'$&:nIh(B";
  constant create_new_site = " $(B<yN)%5%$%H(B";
  constant create_user = "$(B<yN)%f!<%6(B";
  constant debug_info  = "$(B%G%P%0%$%s%U%)(B";
  constant delete = " $(B>C$9(B";
  constant delete_user = " $(B>C$9%f!<%6(B";
  constant empty = "$(B6u=j(B";
  constant error = "$(B1[EY(B";
  constant eventlog = "$(B%(%Y%s%H$N:nIh(B";
  constant globals = "$(B%0%m!<%P%k(B";
  constant home = "$(B$*Bp(B";
  constant configiftab = "$(B%3%s%U%#%0%l!<%7%g%s%$%s%?%U%'!<%9(B";
  constant manual = "$(B<h@b(B";
  constant modules = "$(B%"%I%*%s%b%8%e!<%k(B";
  constant normal =  "$(BJ?>o(B";
  constant notice = "$(BCmL\(B";
  constant restart = "$(B:FH/B-(B";
  constant reverse = "$(B5U$5(B";
  constant settings= "$(B%3%s%U%#%0%l!<%7%g%s(B";
  constant usersettings= "$(B%3%s%U%#%0%l!<%7%g%s(B";
  constant shutdown = "$(B%7%c%C%H%@%&%s(B";
  constant site_name = "$(B%5%$%HB0L>(B";
  constant site_pre_text = "";
  constant sites   = "$(B%5%$%H(B";
  constant users = "$(B%f!<%6!<%:(B";
  constant welcome = "$(B$h$&$3$=(B";
  constant with_teplate = "$(BCr7?(B";
  constant site_type = "$(B%5%$%HCr7?(B";
  constant site_name_doc =
#"The name of the configuration must contain characters
other than space and tab, it should not end with
~, and it must not be 'CVS', 'Global Variables' or
'global variables', nor the name of an existing
configuration, and the character '/' cannot be
used";
  constant status = "$(B6a67(B";
  constant warning = "$(B7Y9p(B";
};


// Global useful words etc.
constant ok = "$(B85>d(B";
constant cancel = "$(B<h$j>C$9(B";
constant yes = "$(B$O$$(B";
constant no  = "$(BH](B";
constant and = "$(B$H(B";
constant or = "";
constant every = "$(B>e$2$:(B";
constant since = "$(BMh(B";
constant next = "$(B<!>r(B";
constant previous = "$(B@h(B";

string seconds(int n)
{
  return _whatevers("$(BIC(B",n);
}

string minutes(int n)
{
  return _whatevers("$(BJ,(B",n);
}

string hours(int n)
{
  return _whatevers("$(B;~(B",n);
}

string days(int n)
{
  return _whatevers("$(BF|(B",n);
}

string module_doc_string(mixed module, string var, int long)
{
  return (::module_doc_string(module,var,long) ||
	  RoxenLocale.standard.module_doc_string( module, var, long ));
}
