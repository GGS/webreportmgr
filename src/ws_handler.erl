-module(ws_handler).
%-behaviour(cowboy_websocket_handler).
-export([init/3]).
-export([websocket_init/3]).
-export([websocket_handle/3]).
-export([websocket_info/3]).
-export([websocket_terminate/3]).
-export([message/2]).
-export([wr_to_json/3]).
%-record(sentmsg, {msgatom, action, txt, user, time}).
-define(WSKey,{pubsub,wsbroadcast}).

init({tcp, http}, _Req, _Opts) ->
	{upgrade, protocol, cowboy_websocket}.

websocket_init(_Type, Req, _Opts) ->
    {Username, Req2} =  cowboy_req:cookie(<<"username">>, Req),
    {_, Str} = wr_to_json("connected",Username, "Ok!"),
    {_, Message} = message("data",Str),
    self()! {command, js:index()},
    gproc:reg({p, l, ?WSKey}),
    erlang:start_timer(1000, self(), Message),
    lager:log(notice, [{pid, self()}], "Connected --~s", [Username]),
    io:format("--Pid websocket open --~p ~n", [self()]),
    F_id = ets:first(report),
    if F_id =/= '$end_of_table' ->
            ets_report:info(ets:first(report),self());
       true ->
            ok
    end,
    %poll:start({self(), Link}),
    {ok, Req2, undefined_state}.


%Функция обработки входящего сообщение (реакция на клиентский запрос)
%
websocket_handle({text, Msg}, Req, State) ->
   
    if Msg == <<"PING">> ->
            {ok, Req, State}; 
       true ->
            io:format("--Receive --~p ~n", [Msg]),
            {ok, RegDir} = re:compile("[0-9][0-9][0-9]+"),
            case re:run(Msg, RegDir,[ global, {capture,[0], list}]) of  
                {match, [Link]}  ->
                    io:format("--Match --~p~n",[unicode:characters_to_list(Link)]),
                    ok;
                _ ->
                    io:format("--No match text --~n"),
                    failed,
                    Text = binary_to_list(Msg), 
                    io:format("--txt --~p~n",[Text]),
                    {_, Message} = message("data",Text),
                    io:format("--OOO text --~p~n",[Message]),
                    gproc:send({p, l, ?WSKey}, {self(), ?WSKey, [Message]})
            end,    
                     %{reply, {text, << Msg/binary >>}, Req, State};
            {ok, Req, State}
    end;

websocket_handle({binary, Msg}, Req, State) ->
    Cmsg = binary_to_term(Msg),
    case  Cmsg of
        {messageSent,Text,Username,_} = Cmsg -> 
            {_, Str} = wr_to_json(messageReceived,Username, Text),
            lager:log(notice, [{pid, self()}], "--Receive --~p ~n", [Cmsg]),
            {_, Message} = message("data", Str),
            gproc:send({p, l, {pubsub,wsbroadcast}}, {self(), {pubsub,wsbroadcast}, Message});
        {delReport,Key,_,_} = Cmsg -> 
            lager:log(notice, [{pid, self()}], "--Request for delete --~p ~n", [Cmsg]),
            ets_report:delete(Key);
        {viewLog,Key,_,_} = Cmsg -> 
            io:format("--Receive --~p ~n", [Cmsg]),
            ets_report:logtex(Key);
        _->
            ok
    end,
    {ok, Req, State};
   
websocket_handle(_Data, Req, State) ->
    io:format("--Data --~p~n",[_Data]),
    {ok, Req, State}.

%Обработка сообщений эрланга
%
websocket_info(Info, Req, State) ->
    case Info of
        {_PID,?WSKey,Msg} ->
            {reply, {text, Msg}, Req, State, hibernate};
        {timeout, _Ref, Msg} ->
            {reply, {text, Msg}, Req, State};
        {dwnl, Msg} ->
            {_, Message} = message("data", Msg),
            {reply, {text, Message}, Req, State};
        {command, Msg} ->
            {_, Message} = message( "eval", Msg),
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

message (Type, Data) ->
    Term = binary_to_list(term_to_binary(Data)),
    {ok, list_to_binary(io_lib:format("{~p:~p}",[Type,Term]))}.

wr_to_json(Event,Username,Text) ->
    {_,Time_event} = time_info(),
    Str =  unicode:characters_to_list(io_lib:format("{\"event\":\"~s\", \"name\":\"~s\",\"text\":\"~s\",\"time\":\"~s\"}",[Event, Username,  Text, Time_event])),
    io:format("Json is --~s~n",[Str]),
    {ok, Str}.
