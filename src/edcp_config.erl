%%%-------------------------------------------------------------------
%%% @author zy
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 16. 七月 2015 4:41 PM
%%%-------------------------------------------------------------------
-module(edcp_config).
-author("zy").

%% API
-export([producer_ranch_config/0, producer_config/0, consumer_config/0, server_id_config/0]).

producer_ranch_config() ->
    {ok, App}  = application:get_application(?MODULE),
    Port = application:get_env(App, listen_port, 12121),

    [{port, Port}].

producer_config() ->
    {ok, App}  = application:get_application(?MODULE),
    CallbackMod = application:get_env(App, producer_callback, edcp_example),
    Timeout = application:get_env(App, connection_timeout, 60000),

    [{callback, CallbackMod}, {timeout, Timeout}].

consumer_config() ->
    {ok, App}  = application:get_application(?MODULE),
    CallbackMod = application:get_env(App, consumer_callback, edcp_example),
    ReconnectDelay = application:get_env(App, consumer_reconnect_delay, 30),
    Timeout = application:get_env(App, connection_timeout, 60000),

    [{callback, CallbackMod}, {reconnect_delay, ReconnectDelay}, {timeout, Timeout}].

server_id_config() ->
    {ok, App}  = application:get_application(?MODULE),
    ServerId = application:get_env(App, server_id, 0),

    [{server_id, ServerId}].