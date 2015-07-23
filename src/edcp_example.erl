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
    open_stream/4,
    stream_starting/3, stream_snapshot/3, stream_end/1,
    handle_snapshot_item/2, handle_stream_error/2, handle_stream_end/2]).

-compile([{parse_transform, lager_transform}]).

%%%===================================================================
%%% API
%%%===================================================================
open_stream([Host, Port], [VBucketUUID, SeqNoStart, SeqNoEnd], Timeout, ModState) ->
    edcp_consumer_sup:start([Host, Port], [VBucketUUID, SeqNoStart, SeqNoEnd], Timeout, ModState).

%%%===================================================================
%%% edcp_producer callbacks
%%%===================================================================
stream_starting(VBucketUUID, SeqStart, SeqEnd) ->
    lager:debug("start stream with ~p ~p-~p", [VBucketUUID, SeqStart, SeqEnd]),

    SnapShotList = [{0, 10}, {11, 20}, {21, 33}],
    ModState = undefined,
    {ok, SnapShotList, ModState}.

stream_snapshot(SnapshotStart, SnapshotEnd, ModState) ->
    ItemList = lists:duplicate(SnapshotEnd - SnapshotStart + 1, {SnapshotStart, <<"log content">>}),
    {ok, ItemList, ModState}.

stream_end(_ModState) ->
    ok.

%%%===================================================================
%%% edcp_consumer callbacks
%%%===================================================================
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