%%%-------------------------------------------------------------------
%%% @author zy
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 17. 七月 2015 5:33 PM
%%%-------------------------------------------------------------------
-module(edcp_protocol).
-author("zy").

-include("edcp_protocol.hrl").

%% API
-export([
    encode_stream_request/1, encode_stream_end/1, encode_snapshot_marker/1, encode_log/1, encode/1,
    decode_stream_request/1, decode_stream_end/1, decode_snapshot_marker/1, decode_log/1, decode/1]).

encode_stream_request(#edcp_stream_request{
    flags = Flags,
    seqno_start = SeqnoStart, seqno_end = SeqnoEnd,
    vbucket_uuid = VBucketUUID,
    snapshot_start = SnapshotStart, snapshot_end = SnapshotEnd}) ->
    Extras = <<Flags:32, 0:32, SeqnoStart:64, SeqnoEnd:64, VBucketUUID:64, SnapshotStart:64, SnapshotEnd:64>>,
    encode(#edcp_packet{magic = ?Magic_Request, op_code = ?OP_StreamRequest, extras = Extras}).

encode_stream_end(Flag) when is_integer(Flag) ->
    encode(#edcp_packet{magic = ?Magic_Request, op_code = ?OP_StreamEnd, extras = <<Flag:32>>}).

encode_snapshot_marker(#edcp_snapshot_marker{
    type = Type,
    seqno_start = SeqnoStart, seqno_end = SeqnoEnd}) ->
    Extras = <<SeqnoStart:64, SeqnoEnd:64, Type:32>>,
    encode(#edcp_packet{magic = ?Magic_Request, op_code = ?OP_SnapshotMarker, extras = Extras}).

encode_log(#edcp_log{seqno = SeqNo, log = Log}) when is_integer(SeqNo) andalso is_binary(Log) ->
    Extras = <<SeqNo:64>>,
    encode(#edcp_packet{magic = ?Magic_Request, op_code = ?OP_Log, extras = Extras, value = Log}).

encode(Packet) when is_record(Packet, edcp_packet) ->
    Magic = Packet#edcp_packet.magic,
    Opcode = Packet#edcp_packet.op_code,
    KeySize = size(Packet#edcp_packet.key),
    Extras = Packet#edcp_packet.extras,
    ExtrasSize = size(Extras),
    DataType = Packet#edcp_packet.data_type,
    Status = Packet#edcp_packet.status,
    Body = <<Extras:ExtrasSize/binary, (Packet#edcp_packet.key)/binary, (Packet#edcp_packet.value)/binary>>,
    BodySize = size(Body),
    Opaque = Packet#edcp_packet.opaque,
    CAS = Packet#edcp_packet.cas,
    <<Magic:8, Opcode:8, KeySize:16, ExtrasSize:8, DataType:8, Status:16, BodySize:32, Opaque:32, CAS:64, Body:BodySize/binary>>.

decode_stream_request(#edcp_packet{magic = ?Magic_Request, op_code = ?OP_StreamRequest, extras = Extras, extras_size = 48}) ->
    <<Flags:32, 0:32, SeqnoStart:64, SeqnoEnd:64, VBucketUUID:64, SnapshotStart:64, SnapshotEnd:64>> = Extras,
    #edcp_stream_request{
        flags = Flags,
        seqno_start = SeqnoStart, seqno_end = SeqnoEnd,
        vbucket_uuid = VBucketUUID,
        snapshot_start = SnapshotStart, snapshot_end = SnapshotEnd}.

decode_stream_end(#edcp_packet{magic = ?Magic_Request, op_code = ?OP_StreamEnd, extras = <<Flag:32>>}) ->
    Flag.

decode_snapshot_marker(#edcp_packet{magic = ?Magic_Request, op_code = ?OP_SnapshotMarker, extras = Extras, extras_size = 20}) ->
    <<SeqnoStart:64, SeqnoEnd:64, Type:32>> = Extras,
    #edcp_snapshot_marker{type = Type, seqno_start = SeqnoStart, seqno_end = SeqnoEnd}.

decode_log(#edcp_packet{magic = ?Magic_Request, op_code = ?OP_Log, extras = Extras, value = Log}) ->
    <<SeqNo:64>> = Extras,
    #edcp_log{seqno = SeqNo, log = Log}.

decode(Buffer) ->
    decode(Buffer, []).

decode(Buffer, Packets) ->
    case decode_header(Buffer) of
        {error, not_enough} ->
            {ok, lists:reverse(Packets), Buffer};
        {error, _Error} ->
            {error, _Error};
        {ok, Packet, Rest} ->
            case decode_body(Rest, Packet) of
                {ok, Packet2, Rest2} ->
                    decode(Rest2, [Packet2 | Packets]);
                {error, not_enough} ->
                    {ok, lists:reverse(Packets), Buffer};
                {error, _Error} ->
                    {error, _Error}
            end
    end.

decode_header(<<Magic:8, Opcode:8, KeySize:16, ExtrasSize:8, DataType:8, Status:16, BodySize:32, Opaque:32, CAS:64, Rest/binary>>) ->
    Packet = #edcp_packet{
        magic = Magic,
        op_code = Opcode,
        data_type = DataType,
        status = Status,
        opaque = Opaque,
        cas = CAS,
        key_size = KeySize,
        extras_size = ExtrasSize,
        body_size = BodySize
    },
    {ok, Packet, Rest};
decode_header(Data) when byte_size(Data) < 24 ->
    {error, not_enough};
decode_header(_Data) ->
    {error, invalid_data}.

decode_body(Data, Packet = #edcp_packet{key_size = KeySize, extras_size = ExtrasSize, body_size = BodySize}) ->
    case Data of
        <<Body:BodySize/binary, Rest/binary>> ->
            case Body of
                <<Extras:ExtrasSize/binary, Key:KeySize/binary, Value/binary>> ->
                    {ok, Packet#edcp_packet{extras = Extras, key = Key, value = Value}, Rest};
                _ ->
                    {error, not_enough}
            end;
        _ ->
            {error, not_enough}
    end.