// This is a roxen module. Copyright © 2009, Roxen IS.
//

#include <module.h>
inherit "module";

constant cvs_version = "$Id$";
constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Tags: Support for Kerberos authentication";
constant module_doc  = ("Adds a couple of tags to enable simple Kerberos "
			"authentication.");
constant module_unique = 1;

#if constant(Kerberos.Context)
Kerberos.Context ctx;
string instantiate_msg;

class TagIfKerberosAuth {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "kerberos-auth";

  int eval(string user, RequestID id, mapping args)
  {
    if (!ctx)
      RXML.run_error("The Kerberos module is not active.\n");
    
    if(!args->password)
      RXML.parse_error("No password attribute specified.\n");
    
    NOCACHE();

    return ctx->authenticate(user, args->password);
  }
}

void start()
{
  if (mixed err = catch {
      //  This may throw an error if Kerberos support is included in Pike
      //  but a run-time error takes place.
      ctx = ctx || Kerberos.Context();
    }) {
    //  Save error message for status()
    instantiate_msg = "An error occurred when enabling the Kerberos module.\n";
#ifdef DEBUG
    werror("Kerberos.Context() instantiation error: %s\n",
	   describe_backtrace(err));
#endif
  }
}

string status()
{
  return (instantiate_msg ?
	  ("<font color='&usr.warncolor;'>" + instantiate_msg + "</font>") :
	  "");
}


#else /* !constant(Kerberos.Context) */

constant dont_dump_program = 1;

string status()
{
  return "<font color='&usr.warncolor;'>Kerberos not available in this Roxen.</font>";
}

#endif /* constant(Kerberos.Context) */

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
"if#kerberos-auth":#"<desc type='plugin'><p><short>
 Returns true if the Kerberos authentication is successful.</short>
 The username is provided in the plugin attribute.</p>

<ex-box>
<if kerberos-auth=\"username\" password=\"password\">
  <p>The user is authenticated.</p>
</if>
</ex-box>
</desc>

<attr name='password' value='string' required='required'><p>
 Specifies the password.</p>
</attr>",

    ]);
#endif
