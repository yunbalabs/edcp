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
-export([producer_ranch_config/0, producer_config/0, consumer_config/0]).

producer_ranch_config() ->
    {ok, App}  = application:get_application(?MODULE),
    Port = application:get_env(App, listen_port, 12121),

    [{port, Port}].

producer_config() ->
    {ok, App}  = application:get_application(?MODULE),
    CallbackMod = application:get_env(App, producer_callback, edcp_example),

    [{callback, CallbackMod}].

consumer_config() ->
    {ok, App}  = application:get_application(?MODULE),
    CallbackMod = application:get_env(App, consumer_callback, edcp_example),

    [{callback, CallbackMod}].