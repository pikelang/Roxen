/*
 * $Id: update.pike,v 1.37 2002/06/03 21:42:11 nilsson Exp $
 *
 * The Roxen Update Client (compatibility placeholder)
 * Copyright © 2000 - 2001, Roxen IS.
 *
 */

inherit "module";

constant module_name = "DEPRECATED: Roxen Update Client";

void start(int num, Configuration conf)
{
  werror("\n ***** Roxen Update Client has been removed from your server.\n");
  call_out( conf->disable_module, 0.5, "update#0" );
}

