// This is a roxen module. Copyright © 2004, Roxen IS.
//

#include <module.h>
inherit "module";

constant cvs_version = "$Id: kerberos.pike,v 1.1 2004/05/14 12:54:09 wellhard Exp $";
constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Tags: Support for kerberos authentication";
constant module_doc  = ("Adds a couple of tags to enable simple kerberos "
			"authentication.");
constant module_unique = 1;

Kerberos.Context ctx = Kerberos.Context();

class TagIfKerberosAuth {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "kerberos-auth";

  int eval(string user, RequestID id, mapping args)
  {
    if(!args->password)
      RXML.parse_error("No password attribute specified.\n");
    
    NOCACHE();

    return ctx->authenticate(user, args->password);
  }
}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
"if#kerberos-auth;":#"<desc type='plugin'><p><short>
 Returns true if the kerberos authentication is sucessful. The username is
 provided in the plugin attribute. Example:</p>

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
