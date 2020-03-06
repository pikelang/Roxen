// This is a roxen module. Copyright © 2011, Roxen IS.

#include <module.h>
inherit "module";

constant cvs_version = "$Id$";
constant thread_safe = 1;

constant module_type = MODULE_LOGGER;
constant module_name = "Memory logger";
constant module_doc  = 
  "<p>This module prints memory usage information in a log file. "
  "The log format contains the following columns:</p>"
  "<table>"
  "<tr><td>ARR:</td> <td>Array megabytes </td></tr>"
  "<tr><td>CLO:</td> <td>Call out megabytes </td></tr>"
  "<tr><td>CLA:</td> <td>Callable megabytes </td></tr>"
  "<tr><td>CLB:</td> <td>Callback megabytes </td></tr>"
  "<tr><td>FRM:</td> <td>Frame megabytes </td></tr>"
  "<tr><td>MAP:</td> <td>Mapping megabytes </td></tr>"
  "<tr><td>MUL:</td> <td>Multiset megabytes </td></tr>"
  "<tr><td>OBJ:</td> <td>Object megabytes </td></tr>"
  "<tr><td>PRO:</td> <td>Program megabytes </td></tr>"
  "<tr><td>STR:</td> <td>String megabytes </td></tr>"
  "<tr><td>TYP:</td> <td>Type megabytes </td></tr>"
  "<tr><td>TOT:</td> <td>Total pike megabytes </td></tr>"
  "<tr><td>COM:</td> <td>Consolidated compiler megabytes </td></tr>"
  "<tr><td>RUN:</td> <td>Consolidated run-time overhead megabytes </td></tr>"
  "<tr><td>GC:</td> <td>Consolidated gc overhead megabytes </td></tr>"
  "<tr><td>MAL:</td> <td>Total allocated megabytes (if available) </td></tr>"
  "<tr><td>USE:</td> <td>Total in use megabytes (if available) </td></tr>"
  "<tr><td>RES:</td> <td>Resident megabytes </td></tr>"
  "<tr><td>VIR:</td> <td>Virtual megabytes </td></tr>"
  "</table>"
  "<p><b>Note:</b> Other versions of this module may "
  "add or remove columns.</p>";

void create(Configuration c) 
{
  defvar("LogInterval", 60, "Log interval",
	 TYPE_INT,
	 "Log interval in seconds.");

  defvar("LogFile", "$LOGDIR/memory/MemoryLog.%y-%m-%d",
	 "Log file", TYPE_FILE,
	 "The log file. "
	 ""
	 "A file name. Some substitutions will be done:"
	 "<pre>"
	 "%y    Year  (e.g. '1997')\n"
	 "%m    Month (e.g. '08')\n"
	 "%d    Date  (e.g. '10' for the tenth)\n"
	 "%h    Hour  (e.g. '00')\n"
	 "%H    Hostname\n"
	 "</pre>");

  defvar("LogFileCompressor", "/bin/gzip",
	 "Compress log file", TYPE_STRING,
	 "Path to a program to compress log files, "
	 "e.g. <tt>/usr/bin/bzip2</tt> or <tt>/usr/bin/gzip</tt>. "
	 "<b>Note&nbsp;1:</b> The active log file is never compressed. "
	 "Log rotation needs to be used using the \"Log file\" "
	 "filename substitutions "
	 "(e.g. <tt>$LOGDIR/mysite/Log.%y-%m-%d</tt>). "
	 "<b>Note&nbsp;2:</b> Compression is limited to scanning files "
	 "with filename substitutions within a fixed directory (e.g. "
	 "<tt>$LOGDIR/mysite/Log.%y-%m-%d</tt>, "
	 "not <tt>$LOGDIR/mysite/%y/Log.%m-%d</tt>).");
  
}

void schedule()
{
  remove_call_out(log_memory);
  call_out(log_memory, query("LogInterval"));
}

function log_function;

void end_logger()
{
  if (mixed err = catch {
      if (roxen.LogFile logger =
	  log_function && function_object (log_function)) {
	logger->close();
      }
    }) report_error ("While stopping the logger: " + describe_backtrace (err));
  log_function = 0;
}

void init_log_file()
{
  end_logger();
  string logfile = query("LogFile");
  if(strlen(logfile))
    log_function = roxen.LogFile(logfile, query("LogFileCompressor"))->write;
}

void start() 
{
  init_log_file();
  schedule();
}

mapping rmem = ([]);
mapping pmem = ([]);

void log_memory()
{
  mapping lt = localtime(time());
  string t = sprintf("%0:2d:%0:2d:%0:2d", lt->hour, lt->min, lt->sec);
  rmem = Roxen.get_memusage();
  pmem = Debug.memory_usage();
  int pmem_tot = 
    pmem->array_bytes +
    pmem->call_out_bytes +
    pmem->callable_bytes +
    pmem->callback_bytes +
    pmem->pike_frame_bytes +
    pmem->mapping_bytes + 
    pmem->multiset_bytes + 
    pmem->object_bytes +
    pmem->program_bytes +
    pmem->string_bytes +
    pmem->pike_type_bytes;

  string res = 
    sprintf("%s "
	    "ARR: %:3d, CLO: %:2d, CLA: %:2d, "
	    "CLB: %:2d, FRM: %:2d, MAP: %:3d, "
	    "MUL: %:3d, OBJ: %:3d, PRO: %:3d, "
	    "STR: %:3d, TYP: %:3d, TOT: %:4d, "
	    "COM: %:3d, RUN: %:3d, GC: %:3d, "
	    "MAL: %:4d, USE: %:4d, "
	    "RES: %:4d, VIR: %:4d\n", 
	    t, 
	    pmem->array_bytes/1048576, 
	    pmem->call_out_bytes/1048576, 
	    pmem->callable_bytes/1048576, 

	    pmem->callback_bytes/1048576, 
	    pmem->pike_frame_bytes/1048576, 
	    pmem->mapping_bytes/1048576, 

	    pmem->multiset_bytes/1048576, 
	    pmem->object_bytes/1048576, 
	    pmem->program_bytes/1048576, 

	    pmem->string_bytes/1048576,
	    pmem->pike_type_bytes/1048576,
	    pmem_tot/1048576, 

	    (pmem->node_s_bytes +
	     pmem->supporter_marker_bytes)/1048576,
	    (pmem->catch_context_bytes +
	     pmem->pike_frame_bytes)/1048576,
	    (pmem->ba_mixed_frame_bytes +
	     pmem->destroy_called_mark_bytes +
	     pmem->gc_rec_frame_bytes +
	     pmem->marker_bytes +
	     pmem->mc_marker_bytes)/1048576,

	    pmem->malloc_block_bytes/1048576,
	    pmem->malloc_bytes/1048576,

	    rmem->resident/1024, 
	    rmem->virtual/1024);
  
  log_function(res);

  schedule();
}

ADT.Trie query_snmp_mib(array(int) base_oid, array(int) oid_suffix)
{
  return
    SNMP.SimpleMIB(base_oid, oid_suffix,
		   ({
		     UNDEFINED,
		     ({		// OS-level
		       UNDEFINED,
		       SNMP.Gauge(lambda() { return rmem->virtual; },
				  "virtmem"),
		       SNMP.Gauge(lambda() { return rmem->resident; },
				  "resmem"),
		     }), ({	// Lib C-level
		       UNDEFINED,
		       SNMP.Gauge(lambda() { return pmem->malloc_block_bytes || 0; },
				  "malloc_alloced_bytes"),
		       SNMP.Gauge(lambda() { return pmem->malloc_bytes || 0; },
				  "malloc_used_bytes"),
		     }), ({	// Pike-level
		       UNDEFINED,
		       ({	// Number of items.
			 UNDEFINED,
			 SNMP.Gauge(lambda() {
				      return pmem->num_pike_frames +
					pmem->num_catch_contexts;
				    },
				    "num_runtime_items"),
			 SNMP.Gauge(lambda() { return pmem->num_markers; },
				    "num_markers"),
			 SNMP.Gauge(lambda() { return pmem->num_arrays; },
				    "num_arrays"),
			 SNMP.Gauge(lambda() { return pmem->num_mappings; },
				    "num_mappings"),
			 SNMP.Gauge(lambda() { return pmem->num_multisets; },
				    "num_multisets"),
			 SNMP.Gauge(lambda() { return pmem->num_objects; },
				    "num_objects"),
			 SNMP.Gauge(lambda() { return pmem->num_programs; },
				    "num_programs"),
			 SNMP.Gauge(lambda() { return pmem->num_strings; },
				    "num_strings"),
			 SNMP.Gauge(lambda() { return pmem->num_pike_types; },
				    "num_types"),
			 SNMP.Gauge(lambda() { return pmem->num_call_outs; },
				    "num_call_outs"),
			 SNMP.Gauge(lambda() { return pmem->num_callables; },
				    "num_callables"),
			 SNMP.Gauge(lambda() { return pmem->num_callbacks; },
				    "num_callbacks"),
			 SNMP.Gauge(lambda() {
				      return pmem->num_node_ss +
					pmem->num_supporter_markers;
				    },
				    "num_compiler_items"),
			 SNMP.Gauge(lambda() {
				      return pmem->num_ba_mixed_frames +
					pmem->num_destroy_called_marks +
					pmem->num_gc_rec_frames +
					pmem->num_markers +
					pmem->num_mc_markers;
				    },
				    "num_gc_items"),
		       }), ({	// Number of bytes,
			 UNDEFINED,
			 SNMP.Gauge(lambda() {
				      return pmem->pike_frame_bytes +
					pmem->catch_context_bytes;
				    },
				    "runtime_item_bytes"),
			 SNMP.Gauge(lambda() { return pmem->marker_bytes; },
				    "marker_bytes"),
			 SNMP.Gauge(lambda() { return pmem->array_bytes; },
				    "array_bytes"),
			 SNMP.Gauge(lambda() { return pmem->mapping_bytes; },
				    "mapping_bytes"),
			 SNMP.Gauge(lambda() { return pmem->multiset_bytes; },
				    "multiset_bytes"),
			 SNMP.Gauge(lambda() { return pmem->object_bytes; },
				    "object_bytes"),
			 SNMP.Gauge(lambda() { return pmem->program_bytes; },
				    "program_bytes"),
			 SNMP.Gauge(lambda() { return pmem->string_bytes; },
				    "string_bytes"),
			 SNMP.Gauge(lambda() { return pmem->pike_type_bytes; },
				    "type_bytes"),
			 SNMP.Gauge(lambda() { return pmem->call_out_bytes; },
				    "call_out_bytes"),
			 SNMP.Gauge(lambda() { return pmem->callable_bytes; },
				    "callable_bytes"),
			 SNMP.Gauge(lambda() { return pmem->callback_bytes; },
				    "callback_bytes"),
			 SNMP.Gauge(lambda() {
				      return pmem->node_s_bytes +
					pmem->supporter_marker_bytes;
				    },
				    "compiler_item_bytes"),
			 SNMP.Gauge(lambda() {
				      return pmem->ba_mixed_frame_bytes +
					pmem->destroy_called_mark_bytes +
					pmem->gc_rec_frame_bytes +
					pmem->marker_bytes +
					pmem->mc_marker_bytes;
				    },
				    "gc_item_bytes"),
		       }),
		     }),
		   }));
}
