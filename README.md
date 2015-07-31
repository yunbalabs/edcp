edcp
================

This project is an implementation of [Database Change Protocol (DCP)](https://github.com/couchbaselabs/dcp-documentation) in erlang.

### Settings
```erlang
{edcp, [
       {listen_port, 12121},                   %% producer listen port
       {producer_callback, edcp_example},      %% producer callback
       {consumer_callback, edcp_example},      %% consumer callback
       {consumer_reconnect_delay, 30},         %% auto reconnect in 30 seconds after connection lost
       {connection_timeout, 60000},            %% connection timeout 60 seconds
]}
```

### Usage example
You can find in [edcp_example.erl](src/edcp_example.erl).

```erlang
edcp_example:open_stream(["127.0.0.1", 12121], [1, 1, 0], undefined).
```