/*
 * $Id: rbl.pike,v 1.1 1998/09/17 19:38:43 grubba Exp $
 *
 * Support for RBL (Real-time Blackhole List).
 *
 * Henrik Grubbström 1998-09-17
 */

constant cvs_version="$Id: rbl.pike,v 1.1 1998/09/17 19:38:43 grubba Exp $";
constant thread_safe=1;

#define RBL_DEBUG

array register_module()
{
  return({ MODULE_PROVIDER,
	   "SMTP RBL support",
	   "Support for the Real-time Blackhole List.<br>\n"
	   "See <a href=\"http://maps.vix.com/rbl/\">"
	   "MAPS RBL</a> for more information.\n"
  });
}

array(string)|multiset(string)|string query_provides()
{
  return(< "smtp_filter" >);
}

void create()
{
  defvar("server", "rbl.maps.vix.com", "RBL server", TYPE_STRING,
	 "RBL server to use.<br>\n"
	 "Examples are <tt>rbl.maps.vix.com</tt> and "
	 "<tt>orbs.dorkslayers.com</tt>.");
}

/*
 * Globals
 */

object dns;

/*
 * Callback functions
 */

static void check_dns_result(string nodename, mapping dns_result,
			     function cb, mixed ... args)
{
  if (dns_result && sizeof(dns_result->an)) {
#ifdef RBL_DEBUG
    report_debug(sprintf("RBL: Access refused for %s\n"
			 "%O\n",
			 node_name, dns_result->an));
#endif /* RBL_DEBUG */
    cb(({ sprintf("RBL: Access refused for %s; see http://maps.vix.com/rbl/\n",
		  nodename) }), @args);
  }
  cb(0, @args);
}

/*
 * smtp_filter interface functions:
 */

void async_classify_connection(object con, mapping con_info,
			       function cb, mixed ... args)
{
  if (!dns) {
    dns = Protocols.DNS.async_client();
  }

  string nodename = reverse(con_info->remoteip/".")*"."+QUERY(server);

  dns->do_query(nodename, Protocols.DNS.C_IN, Protocols.DNS.T_A,
		check_dns_result, cb, @args);
}
