%%%-------------------------------------------------------------------
%%% @author zy
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 20. 七月 2015 2:21 PM
%%%-------------------------------------------------------------------
-module(edcp_consumer).
-author("zy").

-behaviour(gen_fsm).

-include("edcp_protocol.hrl").

%% API
-export([start_link/5]).

%% gen_fsm callbacks
-export([init/1,
    stream_request/2,
    snapshot/2,
    state_name/3,
    handle_event/3,
    handle_sync_event/4,
    handle_info/3,
    terminate/3,
    code_change/4]).

-callback handle_snapshot_item(
    Item::any(),
    ModState::term()) ->
    {ok, NewModState::term()} |
    {error, Reason::term()}.

-callback handle_stream_error(
    Error::any(),
    ModState::term()) ->
    ok.

-callback handle_stream_end(
    Flag::integer(),
    ModState::term()) ->
    ok.

-define(SERVER, ?MODULE).

-record(state, {
    socket :: any(),
    buffer :: binary(),
    timeout :: integer(),
    vbucket_uuid :: integer(),
    mod :: module(),
    mod_state :: term()}).

-compile([{parse_transform, lager_transform}]).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Creates a gen_fsm process which calls Module:init/1 to
%% initialize. To ensure a synchronized start-up procedure, this
%% function does not return until Module:init/1 has returned.
%%
%% @end
%%--------------------------------------------------------------------
-spec(start_link(
    Mod :: module(),
    ProducerAddress :: term(),
    RequestParameters :: term(),
    timeout(),
    ModState :: term()) ->
    {ok, pid()} | ignore | {error, Reason :: term()}).
start_link(CallbackMod, ProducerAddress, RequestParameters, Timeout, ModState) ->
    gen_fsm:start_link({local, ?SERVER}, ?MODULE,
        [ProducerAddress, RequestParameters, Timeout, {CallbackMod, ModState}],
        []).

%%%===================================================================
%%% gen_fsm callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a gen_fsm is started using gen_fsm:start/[3,4] or
%% gen_fsm:start_link/[3,4], this function is called by the new
%% process to initialize.
%%
%% @end
%%--------------------------------------------------------------------
-spec(init(Args :: term()) ->
    {ok, StateName :: atom(), StateData :: #state{}} |
    {ok, StateName :: atom(), StateData :: #state{}, timeout() | hibernate} |
    {stop, Reason :: term()} | ignore).
init([[Host, Port], [VBucketUUID, SeqNoStart, SeqNoEnd], Timeout, {CallbackMod, ModState}]) ->
    StreamRequestPacket = case ets:lookup(edcp_consumer_vbucket, VBucketUUID) of
                              [{_, StreamRequest}] ->
                                  StreamRequest2 = StreamRequest#edcp_stream_request{
                                      seqno_start = SeqNoStart, seqno_end = SeqNoEnd
                                  },
                                  ets:insert(edcp_consumer_vbucket, {VBucketUUID, StreamRequest2}),
                                  edcp_protocol:encode_stream_request(StreamRequest2);
                              [] ->
                                  DefaultStreamRequest = #edcp_stream_request{
                                      flags = ?Flag_Latest,
                                      vbucket_uuid = VBucketUUID,
                                      seqno_start = SeqNoStart, seqno_end = SeqNoEnd
                                  },
                                  ets:insert(edcp_consumer_vbucket, {VBucketUUID, DefaultStreamRequest}),
                                  edcp_protocol:encode_stream_request(DefaultStreamRequest)
                          end,
    case gen_tcp:connect(Host, Port, [binary, {packet, 0}]) of
        {ok, Socket} ->
            gen_tcp:send(Socket, StreamRequestPacket),

            lager:debug("consumer start with the request ~p", [StreamRequestPacket]),
            {ok, stream_request, #state{
                socket = Socket, buffer = <<>>,
                timeout = Timeout, vbucket_uuid = VBucketUUID,
                mod = CallbackMod, mod_state = ModState
            }, Timeout};
        Error ->
            {stop, Error}
    end.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% There should be one instance of this function for each possible
%% state name. Whenever a gen_fsm receives an event sent using
%% gen_fsm:send_event/2, the instance of this function with the same
%% name as the current state name StateName is called to handle
%% the event. It is also called if a timeout occurs.
%%
%% @end
%%--------------------------------------------------------------------
-spec(stream_request(Event :: term(), State :: #state{}) ->
    {next_state, NextStateName :: atom(), NextState :: #state{}} |
    {next_state, NextStateName :: atom(), NextState :: #state{},
        timeout() | hibernate} |
    {stop, Reason :: term(), NewState :: #state{}}).
stream_request(timeout, State) ->
    {stop, timeout, State}.

-spec(snapshot(Event :: term(), State :: #state{}) ->
    {next_state, NextStateName :: atom(), NextState :: #state{}} |
    {next_state, NextStateName :: atom(), NextState :: #state{},
        timeout() | hibernate} |
    {stop, Reason :: term(), NewState :: #state{}}).
snapshot(timeout, State) ->
    {stop, timeout, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% There should be one instance of this function for each possible
%% state name. Whenever a gen_fsm receives an event sent using
%% gen_fsm:sync_send_event/[2,3], the instance of this function with
%% the same name as the current state name StateName is called to
%% handle the event.
%%
%% @end
%%--------------------------------------------------------------------
-spec(state_name(Event :: term(), From :: {pid(), term()},
    State :: #state{}) ->
    {next_state, NextStateName :: atom(), NextState :: #state{}} |
    {next_state, NextStateName :: atom(), NextState :: #state{},
        timeout() | hibernate} |
    {reply, Reply, NextStateName :: atom(), NextState :: #state{}} |
    {reply, Reply, NextStateName :: atom(), NextState :: #state{},
        timeout() | hibernate} |
    {stop, Reason :: normal | term(), NewState :: #state{}} |
    {stop, Reason :: normal | term(), Reply :: term(),
        NewState :: #state{}}).
state_name(_Event, _From, State) ->
    Reply = ok,
    {reply, Reply, state_name, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a gen_fsm receives an event sent using
%% gen_fsm:send_all_state_event/2, this function is called to handle
%% the event.
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_event(Event :: term(), StateName :: atom(),
    StateData :: #state{}) ->
    {next_state, NextStateName :: atom(), NewStateData :: #state{}} |
    {next_state, NextStateName :: atom(), NewStateData :: #state{},
        timeout() | hibernate} |
    {stop, Reason :: term(), NewStateData :: #state{}}).
handle_event(_Event, StateName, State) ->
    {next_state, StateName, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a gen_fsm receives an event sent using
%% gen_fsm:sync_send_all_state_event/[2,3], this function is called
%% to handle the event.
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_sync_event(Event :: term(), From :: {pid(), Tag :: term()},
    StateName :: atom(), StateData :: term()) ->
    {reply, Reply :: term(), NextStateName :: atom(), NewStateData :: term()} |
    {reply, Reply :: term(), NextStateName :: atom(), NewStateData :: term(),
        timeout() | hibernate} |
    {next_state, NextStateName :: atom(), NewStateData :: term()} |
    {next_state, NextStateName :: atom(), NewStateData :: term(),
        timeout() | hibernate} |
    {stop, Reason :: term(), Reply :: term(), NewStateData :: term()} |
    {stop, Reason :: term(), NewStateData :: term()}).
handle_sync_event(_Event, _From, StateName, State) ->
    Reply = ok,
    {reply, Reply, StateName, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_fsm when it receives any
%% message other than a synchronous or asynchronous event
%% (or a system message).
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_info(Info :: term(), StateName :: atom(),
    StateData :: term()) ->
    {next_state, NextStateName :: atom(), NewStateData :: term()} |
    {next_state, NextStateName :: atom(), NewStateData :: term(),
        timeout() | hibernate} |
    {stop, Reason :: normal | term(), NewStateData :: term()}).
handle_info({tcp_closed, Socket}, stream_end, State = #state{socket = Socket}) ->
    gen_tcp:close(Socket),
    {stop, normal, State};
handle_info({tcp_closed, Socket}, _StateName, State = #state{socket = Socket}) ->
    gen_tcp:close(Socket),
    {stop, tcp_close, State};

handle_info({tcp, Socket, Data}, StateName, State = #state{socket = Socket, buffer = Buffer, timeout = Timeout}) ->
    NewData = << Buffer/binary, Data/binary >>,
    case edcp_protocol:decode(NewData) of
        {ok, Packets, Rest} ->
            case handle_packets(Packets, StateName, State) of
                {stream_end, State2} ->
                    gen_tcp:close(Socket),
                    {stop, normal, State2};
                {StateName2, State2} ->
                    {next_state, StateName2, State2#state{buffer = Rest}, Timeout}
            end;
        {error, invalid_data} ->
            lager:error("tcp receive invalid data ~p", [Buffer]),
            gen_tcp:close(Socket),
            {stop, invalid_data, StateName}
    end;

handle_info(_Info, StateName, State) ->
    {next_state, StateName, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_fsm when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_fsm terminates with
%% Reason. The return value is ignored.
%%
%% @end
%%--------------------------------------------------------------------
-spec(terminate(Reason :: normal | shutdown | {shutdown, term()}
| term(), StateName :: atom(), StateData :: term()) -> term()).
terminate(_Reason, StateName, _State) ->
    lager:debug("consumer terminate when ~p", [StateName]),
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @end
%%--------------------------------------------------------------------
-spec(code_change(OldVsn :: term() | {down, term()}, StateName :: atom(),
    StateData :: #state{}, Extra :: term()) ->
    {ok, NextStateName :: atom(), NewStateData :: #state{}}).
code_change(_OldVsn, StateName, State, _Extra) ->
    {ok, StateName, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
handle_packets([], StateName, State) ->
    {StateName, State};
handle_packets([Packet | Rest], StateName, State) ->
    {StateName2, State2} = handle_packet(Packet, StateName, State),
    handle_packets(Rest, StateName2, State2).

handle_packet(#edcp_packet{
    magic = ?Magic_Response, op_code = ?OP_StreamRequest, status = ?Status_NoError
}, stream_request, State) ->
    {snapshot, State};
handle_packet(#edcp_packet{
    magic = ?Magic_Response, op_code = ?OP_StreamRequest, status = ErrorCode
}, stream_request, State = #state{mod = Mod, mod_state = ModState}) ->
    Mod:handle_stream_error({request_error, ErrorCode}, ModState),
    {stream_end, State};

handle_packet(Packet = #edcp_packet{op_code = ?OP_SnapshotMarker}, snapshot, State = #state{vbucket_uuid = VBucketUUID}) ->
    #edcp_snapshot_marker{seqno_start = Start, seqno_end = End} = edcp_protocol:decode_snapshot_marker(Packet),
    [{VBucketUUID, StreamRequest}] = ets:lookup(edcp_consumer_vbucket, VBucketUUID),
    ets:insert(edcp_consumer_vbucket, {
        VBucketUUID, StreamRequest#edcp_stream_request{snapshot_start = Start, snapshot_end = End}
    }),
    {snapshot, State};

handle_packet(Packet = #edcp_packet{op_code = ?OP_Log}, snapshot, State = #state{mod = Mod, mod_state = ModState}) ->
    #edcp_log{seqno = SeqNo, log = Log} = edcp_protocol:decode_log(Packet),
    case Mod:handle_snapshot_item({SeqNo, Log}, ModState) of
        {ok, NewModState} ->
            {snapshot, State#state{mod_state = NewModState}};
        {error, Reason} ->
            Mod:handle_stream_error(Reason, ModState),
            {stream_end, State}
    end;
handle_packet(Packet = #edcp_packet{op_code = ?OP_StreamEnd}, snapshot, State = #state{
    mod = Mod, mod_state = ModState, vbucket_uuid = VBucketUUID
}) ->
    ets:delete(edcp_consumer_vbucket, VBucketUUID),

    Flag = edcp_protocol:decode_stream_end(Packet),
    Mod:handle_stream_end(Flag, ModState),

    {stream_end, State}.