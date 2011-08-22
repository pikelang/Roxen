// This is a roxen module. Copyright © 2011, Roxen IS.

#include <module.h>
inherit "module";

constant cvs_version = "";
constant thread_safe = 1;

constant module_type = MODULE_LOGGER;
constant module_name = "Memory logger";
constant module_doc  = "This module printes memory usage information "
                       "in a log file";

void create(Configuration c) 
{
  defvar("LogInterval", 60, "Log interval",
	 TYPE_INT,
	 "Log interval in second.");

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

void init_log_file()
{
  if(log_function)
  {
    // Free the old one.
    destruct(function_object(log_function));
    log_function = 0;
  }
  string logfile = query("LogFile");
  if(strlen(logfile))
    log_function = roxen.LogFile(logfile, query("LogFileCompressor"))->write;
}

void start() 
{
  init_log_file();
  schedule();
}

//    "array_bytes": 1134096,
//    "call_out_bytes": 2824,
//    "callable_bytes": 16304,
//    "callback_bytes": 6192,
//    "frame_bytes": 32720,
//    "mapping_bytes": 4975233,
//    "multiset_bytes": 295640,
//    "object_bytes": 2219868,
//    "program_bytes": 6468908,
//    "string_bytes": 16672652,

//    "num_arrays": 16388,
//    "num_call_outs": 45,
//    "num_callables": 255,
//    "num_callbacks": 4,
//    "num_frames": 55,
//    "num_mappings": 14880,
//    "num_multisets": 3495,
//    "num_objects": 18602,
//    "num_programs": 3002,
//    "num_strings": 87410,


void log_memory()
{
  mapping lt = localtime(time());
  string t = sprintf("%0:2d:%0:2d:%0:2d", lt->hour, lt->min, lt->sec);
  mapping rmem = Roxen.get_memusage();
  mapping pmem = Debug.memory_usage();
  int pmem_tot = 
    pmem->array_bytes +
    pmem->call_out_bytes +
    pmem->callable_bytes +
    pmem->callback_bytes +
    pmem->frame_bytes +
    pmem->mapping_bytes + 
    pmem->multiset_bytes + 
    pmem->object_bytes +
    pmem->program_bytes +
    pmem->string_bytes;

  string res = sprintf("%s "
	 "ARR: %:3d, CLO: %:2d, CLA: %:2d, "
	 "CLB: %:2d, FRM: %:2d, MAP: %:3d, "
	 "MUL: %:3d, OBJ: %:3d, PRO: %:3d, "
	 "STR: %:3d, TOT: %:4d, "
	 "RES: %:4d, VIR: %:4d\n", 
	 t, 
	 pmem->array_bytes/1048576, pmem->call_out_bytes/1048576, pmem->callable_bytes/1048576, 
	 pmem->callback_bytes/1048576, pmem->frame_bytes/1048576, pmem->mapping_bytes/1048576, 
	 pmem->multiset_bytes/1048576, pmem->object_bytes/1048576, pmem->program_bytes/1048576, 
	 pmem->string_bytes/1048576, pmem_tot/1048576, 
	 rmem->resident/1024, rmem->virtual/1024);
  log_function(res);

  schedule();
}
