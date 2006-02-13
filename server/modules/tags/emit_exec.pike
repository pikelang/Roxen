// RXML Exec module.
//
// Created 20060210 by Marcus Wellhardh <wellhard@roxen.com> as a
// consultancy job for Randstad.

// $Id: emit_exec.pike,v 1.1 2006/02/13 13:40:16 wellhard Exp $

#include <module.h>
inherit "module";

//<locale-token project="sitebuilder">LOCALE</locale-token>
//<locale-token project="sitebuilder">DLOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("sitebuilder",X,Y)
#define DLOCALE(X,Y)    _DEF_LOCALE("sitebuilder",X,Y)

#ifndef manual
constant thread_safe = 1;

#include <config.h>

constant module_type = MODULE_PARSER;
LocaleString module_name = DLOCALE(0, "Tags: Exec emit plugin");
LocaleString module_doc  = DLOCALE(0, "This module calls an external application and "
				   "returns the result.");

void create()
{
  defvar("applications",
	 Variable.Mapping( ([]), 0,
			   "Available Applications",
			   "This list specifies which applications are available "
			   "for the emit#exec plugin. Specify a short name for "
			   "each application and the search path in the Value column."));
}

class TagEmitExec {
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "exec";

  mapping(string:RXML.Type) req_arg_types = ([
    "application"        : RXML.t_text(RXML.PEnt)
  ]);
  
  mapping(string:RXML.Type) opt_arg_types =([
    "loop-split"      : RXML.t_text(RXML.PXml),
    "entity-split"    : RXML.t_text(RXML.PXml),
    "value-split"     : RXML.t_text(RXML.PXml),
    "arguments"       : RXML.t_text(RXML.PXml),
    "raw-variable"    : RXML.t_text(RXML.PXml),
    "return-variable" : RXML.t_text(RXML.PXml),
  ]);
  
  array(mapping) get_dataset(mapping args, RequestID id)
  {
    mapping(string:string) get_entities(string s)
    {
      string value_split = (args["value-split"] || "=");
      mapping variables = ([]);
      foreach(s/(args["entity-split"] || "\n"), string entity)
      {
	array a = entity/value_split;
	if(sizeof(a) > 1)
	  variables[a[0]] = a[1..] * value_split;
      }
      return variables;
    };
    
    string path = query("applications")[args->application];
    if(!path)
      RXML.parse_error("Unknown application name: %O\n", args->application);
    
    array(string) command_args = ({ path });
    if(args->arguments && sizeof(args->arguments))
      command_args += Process.split_quoted_string(args->arguments);
    
    Stdio.File stdout = Stdio.File();
    string res = "";
    
    void got_data(int cb_id, string s)
    {
      res += s;
    };
    
    mapping modifiers = ([
      "stdout": stdout->pipe(),
    ]);
    stdout->set_read_callback(got_data);
    Process.create_process p;
    mixed err = catch {
      p = Process.create_process(command_args, modifiers);
    };
    if(err)
      RXML.run_error(describe_error(err));
    
    int ret_value = p->wait();

    array rows = ({});
    string loop_split = args["loop-split"];
    if(loop_split)
      foreach(res/loop_split, string row)
	rows += ({ get_entities(row) });
    else
      rows += ({ get_entities(res) });
      
    if(args["raw-variable"])
      RXML.user_set_var(args["raw-variable"], res);
    if(args["return-variable"])
      RXML.user_set_var(args["return-variable"], ret_value);
    
    return rows;
  }
}

#endif

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
  "emit#exec":#"<desc type='plugin'><p><short hide='hide'>

  Calls an external application and returns the result.</short>This
  plugin makes it possible to call an external application and
  retrieve the output written to stdout. To call an application it has
  to be specified in the <i>Available Applications</i> module
  variable. The result can be parsed and variables can be extracted by
  settting delimiter characters. The return value and the raw result
  from the application can be retreived with special variables.

  <note><p>All <xref href='emit.tag'/> attributes apply.</p></note>
</desc>

<ex-box><emit source='exec' application='uptime' raw-variable='var.raw'/>

<sscanf format='%*s load average: %f, %f, %f'
        variables='var.load-1,var.load-5,var.load-15'>&var.raw;</sscanf>

Load  1 min: &var.load-1;<br/>
Load  5 min: &var.load-5;<br/>
Load 15 min: &var.load-15;<br/></ex-box>

<attr name='application' value='string'>
  <p>A symbolic name of the application to execute. The path to the
  application is looked up in the <i>Available Applications</i>
  module variable. The application has to be defined in the list,
  an error will be generated otherwise.</p>
</attr>

<attr name='loop-split' value='string'>
  <p>This attribute defines the delimiter to use when the result is
  splitted to extract each loop step.</p>
</attr>

<attr name='entity-split' value='string' default='newline'>
  <p>This attribute defines the delimiter to use when each loop of
  the result is splitted to extract entities.</p>
</attr>

<attr name='value-split' value='string' default='='>
  <p>This attribute defines the delimiter to use when each entity of
  the result is splitted to extract the entiry name and its value.</p>
</attr>

<attr name='raw-variable' value='variablename'>
  <p>Define this attribute to a variable name to store the raw result
  from the application in this variable. The variable will also be
  available after the emit</p>
</attr>

<attr name='return-variable' value='variablename'>
  <p>Define this attribute to a variable name to store the return value 
  from the application in this variable. The variable will also be
  available after the emit</p>
</attr>

",
  ]);
#endif
