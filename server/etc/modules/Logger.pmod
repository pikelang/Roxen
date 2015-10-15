//! Your average base class for loggers. This one outputs by default
//! to stderr using the Roxen werror() method.
class BaseLogger {
  object parent_logger;
  mapping defaults = ([
    "level" : INFO,
  ]);

  enum {
    TRACE = 10,
    DBG = 20,
    INFO = 30,
    WARN = 40,
    ERROR = 50,
    FATAL = 60
  };

  int default_log_level = INFO;

  //! Override to allow early bailout in @[log()] if noone is
  //! listening. @[log()] will bail out if this method returns 0.
  int should_log() {
    if (parent_logger)
      return parent_logger->should_log();

    return 1;
  }

  //! Send the actual log to listeners.
  //! Override this method to change where log is sent and how it is encoded.
  protected void do_log(mapping data) {
    if (!data->level) {
      data = data | ([]); // Make sure we don't modify the original mapping!
      data->level = default_log_level;
    }

    string res = Standards.JSON.encode(data);
  }

  //! Override this method to implement custom merging of data into
  //! messages.
  //!
  //! The default logic is to just merge the default
  //! mapping into the message. If more dynamic defaults (such as
  //! current time etc) is needed, overriding this method is your best
  //! bet.
  protected mapping merge_defaults(mapping msg) {
    return defaults | msg;
  }

  //! Log an entry using this logger.
  //!
  //! If data is a string, it will be converted into a mapping using
  //! the key "msg" for the message.
  //!
  //! Overriding this method should not be needed.
  void log(mapping|string data) {
    // Check for early bailout
    if (!should_log()) {
      return;
    }

    if (stringp(data)) {
      data = ([ "msg" : data ]);
    }

    mapping log_entry = merge_defaults(data);
    if (parent_logger && functionp(parent_logger->log)) {
      parent_logger->log(log_entry);
    } else {
      do_log(log_entry);
    }
  }

  //! Default parameter mapping and a parent logger object.
  //!
  //! The @[parent_logger] object is used to pass any log messages
  //! injected into this logger up the chain. By default, this logger
  //! does not log at it's own level if a parent logger is given. Instead,
  //! it will simply add its defaults and pass the complete log entry up
  //! to the parent which is then responsible for handling the actual logging.
  void create(void|mapping|function defaults, void|object parent_logger) {
    this_program::defaults = defaults || ([]);
    this_program::parent_logger = parent_logger;
  }

  this_program child(void|mapping|function defaults) {
    this_program new_logger = object_program(this)(defaults, this);
    return new_logger;
  }
}

// Output to all listeners on a Unix socket somewhere.
//
// Note: Any object using this class should have unbind_all() called
// before the end of its life cycle to avoid leaving socket files on
// disk. destroy() will also take care of this, but isn't always
// called on cleanup.
class SocketLogger {
  inherit Logger.BaseLogger;

  multiset(object) listeners = (<>);
  array(object) ports;
  mapping(string:object) ports_by_path = ([]);

  class LogClient {
    Stdio.File sock;
    Stdio.Buffer output = Stdio.Buffer(4096);

    // Write data to the log buffer (output) and set up the write
    // callback, which will add the data to the actual stream.
    int write(string|Stdio.Buffer data) {
      if (stringp(data)) {
	data = Stdio.Buffer(data);
      }

      output->add(data);
      sock->set_write_callback(write_cb);
    }

    protected int write_cb(mixed self, Stdio.Buffer buff) {
      int res = 0;

      // Assuming we have data in this Logger's output buffer, we add
      // that output buffer to the socket buffer and create a new
      // buffer for future messages to this logger.
      if (sizeof(output)) {
	buff->add(output);
	res = sizeof(output);
	output->clear();
	// output = Stdio.Buffer(4096);
      }

      if (!sizeof(buff)) {
	sock->set_write_callback(0);
      }

      return res;
    }

    // Clean up when closed
    protected void close_cb(mixed self) {
      listeners[self] = 0;
      object f = self->sock;
      f->set_nonblocking(0,0,0);
      f->set_id(0);
      f->close();

      destruct(f);
    }

    protected void read_cb(mixed self, Stdio.Buffer buf) {
      // Dummy method - we don't care what the client is saying.
      // This is needed to ensure our close_cb is called properly when the client disconnects.
      buf->clear();
    }

    void create(Stdio.File f) {
      sock = f;
      f->set_id(this);
      f->set_buffer_mode(Stdio.Buffer(1024), Stdio.Buffer(4096)); // Arbitrary buffer length - may need to be adjusted.
      f->set_nonblocking(read_cb, 0, close_cb);
    }
  };

  int should_log() {
    // If noone is listening there is no point in doing any work.
    return sizeof(listeners);
  }

  void do_log(mapping entry) {
    string res = Standards.JSON.encode(entry);
    Stdio.Buffer tmp = Stdio.Buffer(res);
    tmp->add("\n"); // Add a newline so that the reciever can parse data based on lines.
    sizeof(listeners) && indices(listeners)->write(tmp);
  }

  void accept_cb(object port) {
    object l = port->accept();
    l = LogClient(l);
    listeners[l] = 1;
  }

  array get_bound_ports() {
    return indices(ports_by_path);
  }

  // Binds a port for the specified socket path
  object bind(string socket_path) {
    if (ports_by_path[socket_path]) {
      werror("Port already bound for logger!\n");
      return UNDEFINED;
    }

    Stdio.Port port = Stdio.Port();
    port->set_id(port);
    if (search(socket_path, ":") == -1) {
      // No port specified - assume UNIX socket
      int res = port->bind_unix(socket_path, accept_cb);
      if (!res) {
	werror("Failed to bind socket path %O for configuration logger.\n", socket_path);
	return UNDEFINED;
      } else {
	ports_by_path[socket_path] = port;
	return port;
      }
    } else {
      sscanf(socket_path, "%s:%d", string ip, int tcp_port);
      switch(ip||"") {
      case "":
      case "*":
	ip = "::";
      default:
      }

      int res = port->bind(tcp_port, accept_cb, ip, 1);
      if (res != 1) {
	werror("Failed to bind log port!\n%s\n", strerror(port->errno()));
      } else {
	ports_by_path[socket_path] = port;
	return port;
      }
    }
  }

  // Unbinds the specified path or port object. Returns 1 on success and 0 on failure.
  int unbind(string|object socket) {
    if (stringp(socket)) {
      socket = ports_by_path[socket];
    }

    if (!objectp(socket)) {
      werror("Invalid log socket used in unbind request.\n");
      return 0;
    }

    foreach(ports_by_path; string path; Stdio.Port p) {
      if (p == socket) {
	p->close();
	if (Stdio.exist(path)) {
	  if (!rm(path)) {
	    werror("Failed to remove log socket %s\n", path);
	  }
	}
	m_delete(ports_by_path, path);
	destruct(p);
	return 1;
      }
    }

    return 0;
  }

  // Unbind all bound sockets by this logger
  void unbind_all() {
    foreach(ports_by_path; string path; object port) {
      unbind(port);
    }
  }

  void create(void|mapping defaults, void|object parent_logger, void|string socket_path) {
    ::create(defaults, parent_logger);

    if (socket_path) {
      bind(socket_path);
    }
  }

  void destroy() {
    unbind_all();
  }
}

class MainLogger {
  inherit Logger.SocketLogger;

  mapping merge_defaults(mapping msg) {
    mapping tmp = ([
      "time" : time(),
    ]);

    return ::merge_defaults(msg) | tmp;
  }

  void create() {
    ::create(0,0,"*:7702");
  }
}
