-module(edcp_app).

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).

%% ===================================================================
%% Application callbacks
%% ===================================================================

start(_StartType, _StartArgs) ->
    ets:new(edcp_consumer_vbucket, [set, public, named_table]),

    {ok, _} = ranch:start_listener(edcp, 10,
        ranch_tcp, edcp_config:producer_ranch_config(), edcp_producer, edcp_config:producer_config()),
    edcp_consumer_sup:start_link().

stop(_State) ->
    ets:delete(edcp_consumer_vbucket),
    ok.