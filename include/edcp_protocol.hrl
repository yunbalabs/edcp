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
    magic = 16#00,
    op_code = 16#00,
    data_type = 16#00,
    status = 16#0000,
    opaque = 16#00000000,
    cas = 16#0000000000000000,
    extras = <<>>,
    key = <<>>,
    value = <<>>,
    key_size = 16#0000,
    extras_size = 16#00,
    body_size = 16#00000000
}).

-record(edcp_stream_request, {
    flags = 16#00000000,
    seqno_start = 16#0000000000000000,
    seqno_end = 16#0000000000000000,
    vbucket_uuid = 16#0000000000000000,
    snapshot_start = 16#0000000000000000,
    snapshot_end = 16#0000000000000000
}).

-record(edcp_snapshot_marker, {
    type = 16#00000000,
    seqno_start = 16#0000000000000000,
    seqno_end = 16#0000000000000000
}).

-record(edcp_log, {
    seqno = 16#0000000000000000,
    timestamp = 16#00000000,
    cmd = <<>>
}).