//
// WebSocket example module.
//

#include <module.h>

inherit "module";

constant thread_safe = 1;

constant module_type = MODULE_LOCATION;
constant module_name = "WebSockets: Example module";
constant module_doc =
  "This module provides a dummy WebSocket (RFC 6455) service.";
constant module_unique = 0;

protected void create()
{
  defvar("location", "/websocket_example/", "Mount point",
	 TYPE_LOCATION|VAR_INITIAL|VAR_NO_DEFAULT,
	 "Where the module will be mounted in the site's virtual "
	 "file system.");
}

void start(int ignored, Configuration conf)
{
  // We depend on the websocket protocol module.
  module_dependencies(conf, ({ "websocket" }));
}

string query_name()
{
  return sprintf("Example module mounted on %s",
		 query_location());
}

mapping(string:mixed)|int(0..0) find_file(string path, RequestID id)
{
  werror("find_file(%O, %O) called. Method: %O\n", path, id, id->method);
  if (id->method != "WebSocketOpen") return 0;
  if (path != "") return 0;
  return Roxen.upgrade_to_websocket(this, 0);
}

inherit WebSocketAPI;

int websocket_ready(WebSocket ws)
{
  werror("%O ready. Pending: %d\n", ws->id, ws->id->ws_msg_pending);
}

int websocket_close(WebSocket ws, Protocols.WebSocket.CLOSE_STATUS reason)
{
  werror("%O was closed. Pending: %d\n", ws->id, ws->id->ws_msg_pending);
  return 0;
}

mapping(string:mixed)|int(0..0) websocket_message(WebSocket ws,
						  Protocols.WebSocket.Frame frame)
{
  sscanf(frame->text, "%d %d", int ws_id, int cnt);

  if (ws->id->misc->ws_id && ws->id->misc->ws_id != ws_id) {
    werror("Wrong WebSocket ID! Expected %d and got %d\n",
	   ws->id->misc->ws_id, ws_id);
    return 0;
  }

  if (ws->id->misc->ws_cnt >= cnt) {
    werror("Messages out of order. Last cnt %d, got %d\n",
	   ws->id->misc->ws_cnt, cnt);
    return 0;
  }

  ws->id->misc->ws_id = ws_id;
  ws->id->misc->ws_cnt = cnt;

  if (!random(10)) {
    // Close a random connection
    // id->websocket_close();
  }
}
