-module(edcp_consumer_sup).

-behaviour(supervisor2).

%% API
-export([start_link/0, start/4]).

%% Supervisor callbacks
-export([init/1]).

%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    supervisor2:start_link({local, ?MODULE}, ?MODULE, []).

start([Host, Port], [VBucketUUID, SeqNoStart, SeqNoEnd], Timeout, ModState) ->
    supervisor2:start_child(?MODULE, [[Host, Port], [VBucketUUID, SeqNoStart, SeqNoEnd], Timeout, ModState]).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init([]) ->
    [{callback, CallbackMod}, {reconnect_delay, ReconnectDelay}] = edcp_config:consumer_config(),

    RestartStrategy = simple_one_for_one,
    MaxRestarts = 1,
    MaxSecondsBetweenRestarts = ReconnectDelay,

    SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},

    Restart = {transient, ReconnectDelay},
    Shutdown = 2000,
    Type = worker,

    MonitorChild = {edcp_consumer, {edcp_consumer, start_link,
        [CallbackMod]},
        Restart, Shutdown, Type, [edcp_consumer]},

    {ok, {SupFlags, [MonitorChild]}}.

