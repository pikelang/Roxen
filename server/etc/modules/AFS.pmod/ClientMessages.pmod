// $Id$

//
// ClientMessages.pmod
//
// List of standard message types the server sends to the clients.
//
//

//! Ping response message
constant pong = "pong";

//! May be sent in response to a poll request to indicate the poll interval.
constant poll = "poll";

//! Client Session Reset
//!
//! Sent by the server to indicate that the session is reset. This
//! means that the client can and should expect that any cached data
//! may be invalid and try to refresh all subscriptions needed and
//! flush as much state as possible.
//!
//! The message has no payload.
//!
//! Clients may choose to trust old data until new data is received
//! from the server, but must then be prepared to handle errors that
//! may arise from posting obsolete data to the server.
//!
//! This message is also sent to clients whenever new sessions are
//! created.
constant reset_session = "reset-session";

//! Error message with information about the error that occured.
//!
//! Clients must expect that any action may return an @[error] message
//! instead of their normal messages. The client can choose how it
//! wants to handle the error and in some cases, a simple
//! "retry-a-bit-later" strategy may be perfectly ok while other cases
//! requires user interaction to be rectified.
//!
//! The server will not send error messages for authentication
//! problems or invalid requests (missing parameters, non-existing
//! actions etc). In those cases, the client should expect an HTTP
//! error.
//!
//! The generic error message format is as follows:
//! @mapping
//!   @member string "action"
//!     The action that caused the error condition.
//!   @member string "error_code"
//!     A literal error code string that describes the general error
//!     condition.
//!
//!   @member string|int "message"
//!     A display string that describes the error in a "user friendly"
//!     manner. This string can be used to explain the error to the
//!     user.
//!
//!     If this member is an integer, the client should look up
//!     the string from it's localization table and use that string in
//!     its place.
//!
//!   @member mapping(string:string) args
//!     Parameters that can be substituted into the message string.
//! @endmapping
constant error = "error";
