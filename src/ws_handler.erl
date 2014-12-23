-module(ws_handler).
%-behaviour(cowboy_websocket_handler).
-export([init/3]).
-export([websocket_init/3]).
-export([websocket_handle/3]).
-export([websocket_info/3]).
-export([websocket_terminate/3]).
-export([message/2]).

-define(WSKey,{pubsub,wsbroadcast}).

init({tcp, http}, _Req, _Opts) ->
	{upgrade, protocol, cowboy_websocket}.

websocket_init(_Type, Req, _Opts) ->
    {Username, Req2} =  cowboy_req:cookie(<<"username">>, Req),
    %{_,Time_event} = time_info(),
    Str= <<"{\"event\":\"connected\", \"name\":\"",Username/binary, "\",\"time\":\"",Username/binary,"\"}">>,
    gproc:reg({p, l, ?WSKey}),
    erlang:start_timer(1000, self(), Str),
    lager:log(notice, [{pid, self()}], "Connected --~s", [Username]),
    io:format("--Pid websocket open --~p ~n", [self()]),
    F_id = ets:first(report),
    if F_id =/= '$end_of_table' ->
            ets_report:info(ets:first(report),self());
       true ->
            ok
    end,
    %poll:start({self(), Link}),
    {ok, Req2, undefined_sate}.


%Функция обработки входящего сообщение (реакция на клиентский запрос)
%
websocket_handle({text, Msg}, Req, State) ->
    io:format("--Receive --~p ~n", [Msg]),
    {ok, RegDir} = re:compile("[0-9][0-9][0-9]+"),
    case re:run(Msg, RegDir,[ global, {capture,[0], list}]) of  
        {match, [Link]}  ->
            io:format("--Match --~p~n",[unicode:characters_to_list(Link)]),
            ets_report:delete(unicode:characters_to_list(Link)),
            ok;
_ ->
            io:format("--No match text --~n"),
            failed,
            gproc:send({p, l, ?WSKey}, {self(), ?WSKey, << Msg/binary >>})
    end,    
    
    {_, Text, _, _} = list_to_tuple(string:tokens(re:replace(Msg,"\"","",[global,{return, list}]),",")),         
    io:format("--txt --~p~n",[re:replace(Text, "text:","",[{return, list}])]),
                                        %{reply, {text, << Msg/binary >>}, Req, State};
    {ok, Req, State};

websocket_handle(_Data, Req, State) ->
    io:format("--Data --~p~n",[_Data]),
    {ok, Req, State}.

%Обработка сообщений эрланга
%
websocket_info(Info, Req, State) ->
    %io:format("--Pid erlang info --~p ~n", [self()]),
    case Info of
        {_PID,?WSKey,Msg} ->
            {reply, {text, Msg}, Req, State, hibernate};
        {timeout, _Ref, Msg} ->
                        %erlang:start_timer(10000, self(), Message),
            {reply, {text, Msg}, Req, State};
        {dwnl, Msg} ->
            {_, Message} = message(unicode:characters_to_binary(Msg),"info"),
            {reply, {text, Message}, Req, State};
        {command, Msg} ->
            {_, Message} = message(list_to_binary(Msg), "command"),
            {reply, {text, Message}, Req, State};
        _ ->
            {ok, Req, State}
    end.   
websocket_terminate(_Reason, _Req, _State) ->
    io:format("--Websocket closed --~p ~n", [self()]),
    ok.
time_info() ->
    {{_,_,_},{Hr,Min,Sec}} = calendar:now_to_local_time(now()),
    A = io_lib:format("~p:~p:~p", [Hr,Min,Sec]),
    {ok, A}.
message (Cyr_str, Command) ->
    {_,Time_event} = time_info(),
    %Cyr_str = unicode:characters_to_binary(Cyr_str),
    Tail_str = list_to_binary(string:concat(string:concat("\",\"time\":\"",Time_event),"\"}")),
    Head_str =list_to_binary(io_lib:format("{\"event\":~p, ~p:\"INFO\", \"text\":\"",[Command,Command])),
    %io:format("--Coding --~p ~n", [[Head_str,Cyr_str,Tail_str]]),
    {ok, [Head_str,Cyr_str,Tail_str]}.

