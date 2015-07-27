%%%-------------------------------------------------------------------
%%% @author zy
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 16. 七月 2015 4:37 PM
%%%-------------------------------------------------------------------
-module(edcp_producer).
-author("zy").

-behaviour(ranch_protocol).

-include("edcp_protocol.hrl").

-export([start_link/4, push_item/2]).
-export([init/4]).

-callback stream_starting(
    VBucketUUID::integer(),
    SeqStart::integer(),
    SeqEnd::integer()) ->
    {ok, ModState::term()} |
    {error, Reason::term()}.

-callback stream_snapshot(
    SnapshotStart::integer(),
    SeqEnd::integer(),
    ModState::term()) ->
    {ok, ItemList::list(), NewModState::term()} |
    {hang, NewModState::term()} |
    {stop, NewModState::term()} |
    {error, Reason::term()}.

-callback stream_end(
    ModState::term()) ->
    ok.

-record(state, {
    socket :: any(),
    transport :: module(),
    mod :: module()}).

-compile([{parse_transform, lager_transform}]).

%%%===================================================================
%%% API
%%%===================================================================
start_link(Ref, Socket, Transport, Opts) ->
    Pid = spawn_link(?MODULE, init, [Ref, Socket, Transport, Opts]),
    {ok, Pid}.

push_item(Pid, Item) ->
    Pid ! {push_item, Item}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
init(Ref, Socket, Transport, [{callback, CallbackMod}]) ->
    ok = ranch:accept_ack(Ref),
    wait_request(<<>>, #state{socket=Socket, transport=Transport, mod = CallbackMod}).

wait_request(Buffer, State = #state{socket=Socket, transport=Transport}) ->
    case Transport:recv(Socket, 0, infinity) of
        {ok, Data} ->
            parse_request(<< Buffer/binary, Data/binary >>, State);
        {error, _} ->
            terminate(State)
    end.

parse_request(Buffer, State) ->
    case edcp_protocol:decode(Buffer) of
        {ok, Packets, Rest} ->
            case handle_packets(Packets, State) of
                {ok, State2} ->
                    wait_request(Rest, State2);
                {shutdown, _Reason, State2} ->
                    terminate(State2)
            end;
        {error, invalid_data} ->
            lager:error("tcp receive invalid data ~p", [Buffer]),
            terminate(State)
    end.

terminate(#state{socket=Socket, transport=Transport}) ->
    Transport:close(Socket),
    ok.

handle_packets([], State) ->
    {ok, State};
handle_packets([Packet | Rest], State) ->
    case handle_request(Packet, State) of
        {ok, State2} ->
            handle_packets(Rest, State2);
        {shutdown, Reason, State2} ->
            {shutdown, Reason, State2}
    end.

handle_request(Request = #edcp_packet{magic = ?Magic_Request, op_code = ?OP_StreamRequest},
    State = #state{socket=Socket, transport=Transport, mod = Mod}) ->
    #edcp_stream_request{
        vbucket_uuid = VBucketUUID,
        seqno_start = SeqStart, seqno_end = SeqEnd, snapshot_start = SnapshotStart
    } = edcp_protocol:decode_stream_request(Request),
    SeqStart2 = if
                    SnapshotStart > SeqStart -> SnapshotStart;
                    true -> SeqStart
                end,

    case Mod:stream_starting(VBucketUUID, SeqStart2, SeqEnd) of
        {ok, ModState} ->
            Transport:send(Socket, edcp_protocol:encode(#edcp_packet{
                magic = ?Magic_Response, op_code = ?OP_StreamRequest, status = ?Status_NoError
            })),

            case handle_snapshot(SeqStart2, SeqEnd, ModState, State) of
                {ok, NewModState} ->
                    Mod:stream_end(NewModState),
                    Transport:send(Socket, edcp_protocol:encode_stream_end(?Flag_OK)),
                    {ok, State};
                {error, {ErrorSnapshotStart, ErrorSnapshotEnd}, Reason} ->
                    lager:debug("snapshot ~p-~p failed ~p", [ErrorSnapshotStart, ErrorSnapshotEnd, Reason]),

                    Transport:send(Socket, edcp_protocol:encode_stream_end(?Flag_StateChanged)),
                    {ok, State};
                {tcp_error, {ErrorSnapshotStart, ErrorSnapshotEnd}, Reason} ->
                    lager:error("snapshot ~p-~p failed ~p", [ErrorSnapshotStart, ErrorSnapshotEnd, Reason]),
                    {shutdown, Reason, State}
            end;
        {error, Reason} ->
            lager:error("start stream failed ~p", [Reason]),

            Transport:send(Socket, edcp_protocol:encode(#edcp_packet{
                magic = ?Magic_Response, op_code = ?OP_StreamRequest, status = ?Status_InternalError
            })),
            {ok, State}
    end.

handle_snapshot(SnapshotStart, SeqEnd, _ModState, State) when SeqEnd =/= 0 andalso SnapshotStart > SeqEnd ->
    {ok, State};
handle_snapshot(SnapshotStart, SeqEnd, ModState, State = #state{mod = Mod}) ->
    case Mod:stream_snapshot(SnapshotStart, SeqEnd, ModState) of
        {ok, ItemList, NewModState} when length(ItemList) > 0 ->
            case send_snapshot(SnapshotStart, ItemList, State) of
                {ok, {SnapshotStart, SnapshotEnd}} ->
                    handle_snapshot(SnapshotEnd + 1, SeqEnd, NewModState, State);
                {error, {SnapshotStart, SnapshotEnd}, Reason} ->
                    {tcp_error, {SnapshotStart, SnapshotEnd}, Reason}
            end;
        {hang, NewModState} ->
            handle_mailbox(SnapshotStart, SeqEnd, NewModState, State);
        {stop, NewModState} ->
            {ok, NewModState};
        {error, Reason} ->
            {error, {SnapshotStart, SeqEnd}, Reason}
    end.

handle_mailbox(SnapshotStart, SeqEnd, NewModState, State) ->
    receive
        {push_item, {SeqNo, Log}} when SeqNo =< SnapshotStart ->
            case send_snapshot(SeqNo, [{SeqNo, Log}], State) of
                {ok, {_SnapshotStart2, SnapshotEnd2}} ->
                    handle_mailbox(SnapshotEnd2 + 1, SeqEnd, NewModState, State);
                {error, {SnapshotStart2, SnapshotEnd2}, Reason} ->
                    {tcp_error, {SnapshotStart2, SnapshotEnd2}, Reason}
            end;
        {push_item, _} ->
            {error, {SnapshotStart, SeqEnd}, seqno_mismatch};
        _ ->
            {ok, NewModState}
    end.

send_snapshot(SnapshotStart, ItemList, #state{socket=Socket, transport=Transport}) ->
    SnapshotEnd = SnapshotStart + length(ItemList) - 1,
    SnapshotMarker = edcp_protocol:encode_snapshot_marker(#edcp_snapshot_marker{
        type = ?SnapshotType_Memory,
        seqno_start = SnapshotStart,
        seqno_end = SnapshotEnd
    }),
    SnapshotList = serialize_snapshot_item(ItemList),
    case Transport:send(Socket, [SnapshotMarker | SnapshotList]) of
        ok -> {ok, {SnapshotStart, SnapshotEnd}};
        {error, Reason} -> {error, {SnapshotStart, SnapshotEnd}, Reason}
    end.

serialize_snapshot_item(Items) ->
    serialize_snapshot_item(Items, []).

serialize_snapshot_item([], SerializedList) ->
    lists:reverse(SerializedList);
serialize_snapshot_item([{SeqNo, Log} | Rest], SerializedList) ->
    Serialized = edcp_protocol:encode_log(#edcp_log{seqno = SeqNo, log = Log}),
    serialize_snapshot_item(Rest, [Serialized | SerializedList]).