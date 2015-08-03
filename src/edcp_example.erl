%%%-------------------------------------------------------------------
%%% @author zy
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 21. 七月 2015 2:19 PM
%%%-------------------------------------------------------------------
-module(edcp_example).
-author("zy").

-behaviour(edcp_producer).
-behaviour(edcp_consumer).

-include("edcp_protocol.hrl").

-export([
    open_stream/3,
    stream_starting/3, stream_snapshot/3, stream_end/1, stream_info/2,
    handle_snapshot_marker/3, handle_snapshot_item/2, handle_stream_error/2, handle_stream_end/2]).

-compile([{parse_transform, lager_transform}]).

%%%===================================================================
%%% API
%%%===================================================================
open_stream([Host, Port], [VBucketUUID, SeqNoStart, SeqNoEnd], ModState) ->
    edcp_consumer_sup:start([Host, Port], [VBucketUUID, SeqNoStart, SeqNoEnd], ModState).

%%%===================================================================
%%% edcp_producer callbacks
%%%===================================================================
stream_starting(VBucketUUID, SeqStart, SeqEnd) ->
    lager:debug("start stream with ~p ~p-~p", [VBucketUUID, SeqStart, SeqEnd]),

    Queue = queue:new(),
    Queue2 = queue:in({1, <<"log content 1">>}, Queue),
    Queue3 = queue:in({2, <<"log content 2">>}, Queue2),
    Queue4 = queue:in({3, <<"log content 3">>}, Queue3),
    Queue5 = queue:in({4, <<"log content 4">>}, Queue4),
    ModState = Queue5,

    self() ! {newitem, {5, <<"new log">>}},
    {ok, ModState}.

stream_snapshot(SnapshotStart, 0, Queue) ->
    case get_snapshots(SnapshotStart, 2, Queue) of
        {[], Queue2} ->
            {hang, Queue2};
        {SnapShot, Queue2} ->
            {ok, SnapShot, Queue2}
    end;
stream_snapshot(SnapshotStart, SeqEnd, Queue) when SeqEnd >= SnapshotStart ->
    SnapshotLen = if
                      SeqEnd - SnapshotStart > 1 -> 2;
                      true -> SeqEnd - SnapshotStart + 1
                  end,
    case get_snapshots(SnapshotStart, SnapshotLen, Queue) of
        {[], Queue2} ->
            {hang, Queue2};
        {SnapShot, Queue2} ->
            {ok, SnapShot, Queue2}
    end.

stream_end(_ModState) ->
    ok.

stream_info({newitem, {SeqNo, Log}}, ModState) ->
    edcp_producer:push_item(self(), {SeqNo, Log}),
    erlang:send_after(2000, self(), {newitem, {SeqNo + 1, Log}}),
    {ok, ModState}.

%%%===================================================================
%%% edcp_consumer callbacks
%%%===================================================================
handle_snapshot_marker(_SnapshotStart, _SnapshotEnd, ModState) ->
    {ok, ModState}.

handle_snapshot_item(Item = {_SeqNo, _Log}, ModState) ->
    lager:debug("receive ~p", [Item]),
    {ok, ModState}.

handle_stream_error(Error, _ModState) ->
    lager:debug("stream error ~p", [Error]),
    ok.

handle_stream_end(?Flag_OK, _ModState) ->
    lager:debug("stream end normally"),
    ok;
handle_stream_end(ErrorFlag, _ModState) ->
    lager:error("stream end with error ~p", [ErrorFlag]),
    ok.

%%%===================================================================
%%% Internal functions
%%%===================================================================
get_snapshots(StartNum, Len, Queue) ->
    get_snapshots(StartNum, Len, Queue, []).

get_snapshots(_StartNum, 0, Queue, SnapShot) ->
    {lists:reverse(SnapShot), Queue};
get_snapshots(StartNum, Len, Queue, SnapShot) ->
    case queue:out(Queue) of
        {empty, Queue} ->
            {lists:reverse(SnapShot), Queue};
        {{value, {StartNum, Log}}, Queue2} ->
            get_snapshots(StartNum + 1, Len - 1, Queue2, [{StartNum, Log} | SnapShot]);
        {{value, _Item}, Queue2} ->
            get_snapshots(StartNum, Len, Queue2, SnapShot)
    end.