#ifdef WEBSOCKET_DEBUG
#define WS_DEBUG werror
#else
#define WS_DEBUG(X...)
#endif /* WEBSOCKET_DEBUG */

inherit Protocols.WebSocket.Connection;

//! Callout for the keepalive we run automatically.
mixed ws_keepalive;

//! Set the number of seconds between pings we should send across the
//! wire. Set to 0 to disable.
int(0..) ws_ping_interval = 30;

//! The WebSocket close reason
Protocols.WebSocket.CLOSE_STATUS ws_close_reason;

//! Queue of messages to be processed in sequence by the handler threads.
Thread.Queue ws_msg_queue;

//! Track if we are scheduled to be handled or not.
int ws_in_handler_queue = 0;
Thread.Mutex ws_handler_mutex;

protected constant WS_OPEN_MSG = "WEBSOCKET_OPEN";
protected constant WS_CLOSE_MSG = "WEBSOCKET_CLOSE";

//! Reference to the @[RequestID] object that was upgraded to this
//! websocket.
RequestID id;

//! Object to handle websocket requests.
WebSocketAPI api;

//! Indicate that we should die.
int is_ended = 0;

protected void create(RequestID id, WebSocketAPI api, string|void data)
{
  this_program::id = id;
  this_program::api = api;
  ws_msg_queue = Thread.Queue();
  ws_handler_mutex = Thread.Mutex();
  onclose = ws_onclose;
  onmessage = ws_onmessage;

#if constant(Protocols.WebSocket.Extension)
  ::create(id->my_fd, id->file->parsed_websocket_extensions);
#else
  ::create(id->my_fd);
#endif
  // Disconnect the fd from the RequestID.
  id->my_fd = 0;

  if (data) {
    websocket_in(id, data);
  }

  // Inform the application that the WebSocket is now ready for use...
  ws_onopen(this);
}

protected void destroy()
{
  if (ws_keepalive) {
    remove_call_out(ws_keepalive);
  }

  if (id) {
    id->end();
  }
  id = 0;

  ws_msg_queue = UNDEFINED;
}

//! Called to end a socket instead of destructing it. This method will
//! ensure that there are no outstanding handler requests before
//! destructing it.
void end()
{
  is_ended = 1;

  object key = ws_handler_mutex->lock();

  if (!ws_in_handler_queue) {
    destruct(this);
  }

  key = 0;
}

//! Handler that processes the msg queue. This method should only be
//! executed by one handler at the time (per request object ofc) or
//! messages may arrive out-of-order to the application.
protected void ws_handle_queue()
{
  if (!ws_msg_queue->size()) return;

  string|Protocols.WebSocket.Frame msg = ws_msg_queue->read();
  if (api) {
    if (objectp(msg)) {
      // This is a WebSocket frame so let's process it.
      id->json_logger->log(([
                             "event": "WEBSOCKET_MESSAGE_BEGIN",
                             "callback": "websocket_message",
                           ]));
      api->websocket_message(this, msg);
      id->json_logger->log(([
                             "event": "WEBSOCKET_MESSAGE_END",
                             "callback": "websocket_message",
                           ]));
    } else if (msg == WS_OPEN_MSG) {
      // This is the first message so let's call the open callback
      id->json_logger->log(([
                             "event": "WEBSOCKET_MESSAGE_BEGIN",
                             "callback": "websocket_ready",
                           ]));
      api->websocket_ready(this);
      id->json_logger->log(([
                             "event": "WEBSOCKET_MESSAGE_END",
                             "callback": "websocket_ready",
                           ]));
    } else if (msg == WS_CLOSE_MSG) {
      id->json_logger->log(([
                             "event": "WEBSOCKET_MESSAGE_BEGIN",
                             "callback": "websocket_close",
                           ]));
      api->websocket_close(this, ws_close_reason);
      id->json_logger->log(([
                             "event": "WEBSOCKET_MESSAGE_END",
                             "callback": "websocket_close",
                           ]));
      id->end();
      return;
    }
  } else if (!is_ended) {
    id->json_logger->log(([
                           "event": "WEBSOCKET_API_HANDLER_GONE",
                         ]));
    id->end();
    is_ended++;
  }

  ws_in_handler_queue--;
  if (!is_ended && ws_msg_queue->size()) {
    ws_schedule_handling();
  } else if (is_ended) {
    destruct(this);
  }
}

//! Reschedule this request object for handling websocket messages in
//! queue.
protected void ws_schedule_handling()
{
  if (this && !is_ended && !ws_in_handler_queue) {
    object key = ws_handler_mutex->lock();
    if (!ws_in_handler_queue) {
      roxen.handle(ws_handle_queue);
      ws_in_handler_queue++;
    }
    key = 0;
  }
}

//! Runs the keep-alive ping over the websocket and reschedules
//! another one.
protected void ws_do_keepalive()
{
  // Only send the ping iff we have a ws_ping_interval set and a
  // valid, open connection.
  if (ws_ping_interval &&
      state == Protocols.WebSocket.Connection.OPEN) {
    ping();
  }

  if (ws_keepalive) ws_reschedule_keepalive();
}

//! Reschedule the keep-alive ping for a new time.
protected void ws_reschedule_keepalive()
{
  if (ws_keepalive) {
    remove_call_out(ws_keepalive);
  }

  // We always reschedule, even if ws_ping_interval is 0 so that if
  // the application changes the ping interval, we pick up on that
  // automagically.
  ws_keepalive = roxen.background_run(ws_ping_interval || 1, ws_do_keepalive);
}

//! Callback called when we receive a websocket message.
protected void ws_onmessage(Protocols.WebSocket.Frame frame, mixed id)
{
  ws_reschedule_keepalive();
  ws_msg_queue->write(frame);
  ws_schedule_handling();
  this_program::id->json_logger->log(([
                         "event" : "WEBSOCKET_MESSAGE_QUEUED",
                       ]));
}

//! Callback called when a CLOSE frame is received.
protected void ws_onclose(Protocols.WebSocket.CLOSE_STATUS reason, mixed id)
{
  WS_DEBUG("Connection closed.\n");
  ws_close_reason = reason;
  ws_msg_queue->write(WS_CLOSE_MSG);
  ws_schedule_handling();
  this_program::id->json_logger->log(([
                                       "event" : "WEBSOCKET_CLOSED_QUEUED",
                                     ]));
}

//! Overloaded to call @[ws_reschedule_keepalive()].
void send(Protocols.WebSocket.Frame frame)
{
  ws_reschedule_keepalive();
  ::send(frame);
}

//! Callback which is called after we've setup the WebSocket
//! connection to tell the application that the connection is ready
//! for use.
//! @note
//! This isn't registered as a callback in the WebSocket Connection
//! object as that doesn't really work. Instead, it is simply called
//! after the WebSocket connection object has been set up. This means
//! that this method will be called in the same handler thread as the
//! one that returned the upgrade_connection mapping.
protected void ws_onopen(this_program id)
{
  WS_DEBUG("WebSocket connection open and ready.\n");
  ws_msg_queue->write(WS_OPEN_MSG);
  this_program::id->json_logger->log(([
                         "event" : "WEBSOCKET_OPEN_QUEUED",
                       ]));
  ws_schedule_handling();
}

//! Close the websocket from our end. Once the connection is closed,
//! the @[websocket_close] callback will be triggered.
//!
//! @returns 1 if this isn't an open websocket connection.
public int websocket_close(void|Protocols.WebSocket.CLOSE_STATUS reason)
{
  if (state != Protocols.WebSocket.Connection.OPEN) {
    return 1;
  }

  id->json_logger->log(([
                         "event" : "WEBSOCKET_CLOSE_INITIATED",
                   ]));

  close(reason);
  return 0;
}
