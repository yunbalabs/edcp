-module(edcp_consumer_sup).

-behaviour(supervisor).

%% API
-export([start_link/0, start/4]).

%% Supervisor callbacks
-export([init/1]).

%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

start([Host, Port], [VBucketUUID, SeqNoStart, SeqNoEnd], Timeout, ModState) ->
    supervisor:start_child(?MODULE, [[Host, Port], [VBucketUUID, SeqNoStart, SeqNoEnd], Timeout, ModState]).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init([]) ->
    RestartStrategy = simple_one_for_one,
    MaxRestarts = 1000,
    MaxSecondsBetweenRestarts = 3600,

    SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},

    Restart = temporary,
    Shutdown = 2000,
    Type = worker,

    [{callback, CallbackMod}] = edcp_config:consumer_config(),

    MonitorChild = {edcp_consumer, {edcp_consumer, start_link,
        [CallbackMod]},
        Restart, Shutdown, Type, [edcp_consumer]},

    {ok, {SupFlags, [MonitorChild]}}.

