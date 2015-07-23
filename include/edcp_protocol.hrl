%%%-------------------------------------------------------------------
%%% @author zy
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 17. 七月 2015 11:03 AM
%%%-------------------------------------------------------------------
-author("zy").

-define(Magic_Request,          16#80).
-define(Magic_Response,         16#81).

-define(OP_StreamRequest,       16#53).
-define(OP_SnapshotMarker,      16#56).
-define(OP_StreamEnd,           16#55).
-define(OP_Log,                 16#80).

-define(Flag_Takeover,          16#01).
-define(Flag_DiskOnly,          16#02).
-define(Flag_Latest,            16#04).

-define(Flag_OK,                16#00).
-define(Flag_Closed,            16#01).
-define(Flag_StateChanged,      16#02).
-define(Flag_Disconnected,      16#03).

-define(Status_NoError,         16#0000).
-define(Status_InternalError,   16#0084).

-define(SnapshotType_Memory,    16#01).
-define(SnapshotType_Disk,      16#02).
-define(SnapshotType_Checkpoint,16#04).
-define(SnapshotType_Ack,       16#08).

-record(edcp_packet, {
    magic = 16#00 :: integer(),
    op_code = 16#00 :: integer(),
    data_type = 16#00 :: integer(),
    status = 16#0000 :: integer(),
    opaque = 16#00000000 :: integer(),
    cas = 16#0000000000000000 :: integer(),
    extras = <<>> :: binary(),
    key = <<>> :: binary(),
    value = <<>> :: binary(),
    key_size = 16#0000 :: integer(),
    extras_size = 16#00 :: integer(),
    body_size = 16#00000000 :: integer()
}).

-record(edcp_stream_request, {
    flags = 16#00000000 :: integer(),
    seqno_start = 16#0000000000000000 :: integer(),
    seqno_end = 16#0000000000000000 :: integer(),
    vbucket_uuid = 16#0000000000000000 :: integer(),
    snapshot_start = 16#0000000000000000 :: integer(),
    snapshot_end = 16#0000000000000000 :: integer()
}).

-record(edcp_snapshot_marker, {
    type = 16#00000000 :: integer(),
    seqno_start = 16#0000000000000000 :: integer(),
    seqno_end = 16#0000000000000000 :: integer()
}).

-record(edcp_log, {
    seqno = 16#0000000000000000 :: integer(),
    timestamp = 16#00000000 :: integer(),
    cmd = <<>> :: binary()
}).