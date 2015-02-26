-module(ws_handler).
-export([init/4, stream/3, info/3, terminate/2, message/2,wr_to_json/3]).

-define(WSKey,{pubsub,wsbroadcast}).

init(_Transport, Req, _Opts, _Active) ->
    {Username, Req2} =  cowboy_req:cookie(<<"username">>, Req),
    {_, Str} = wr_to_json("connected",Username, "Ok!"),
    {_, Message} = message("data",Str),
    Term  = term_to_binary({eval,{js:index()}}),
    self()!{binary, Term},
    gproc:reg({p, l, ?WSKey}),
    erlang:start_timer(1000, self(), Message),
    lager:log(notice, [{pid, self()}], "Connected --~s", [Username]),
    io:format("--Pid websocket open --~p ~n", [self()]),
    DateTime = cowboy_clock:rfc1123(),
    io:format("clock refresh timeout: ~s~n", [DateTime]),
    F_id = ets:first(report),
    if F_id =/= '$end_of_table' ->
            ets_report:info(ets:first(report),self());
       true ->
            ok
    end,
    {ok, Req2, undefined_state}.

stream({text, <<"PING", Name/binary>>}, Req, State) ->
    %%io:format("ping ~p received~n", [Name]),
    %%{reply, <<"pong">>, Req, State};
    {ok, Req, State};
stream({text, Data}, Req, State) ->
    io:format("--Receive --~p ~n", [Data]),
    Text = binary_to_list(Data), 
    {_, Message} = message("data",Text),
    io:format("--OOO text --~p~n",[Message]),
    gproc:send({p, l, ?WSKey}, {self(), ?WSKey, [Message]}),
    {ok, Req, State};
stream({binary, Data}, Req, State) -> 
    Cmsg = binary_to_term(Data),
    case  Cmsg of
        {messageSent,Text,Username,_} = Cmsg -> 
            {_, Str} = wr_to_json(messageReceived,Username, Text),
            lager:log(notice, [{pid, self()}], "--Receive --~p ~n", [Cmsg]),
            %%{_, Message} = message("data", Str),
            Term = term_to_binary({messageSent,{Str}}),
            gproc:send({p, l, {pubsub,wsbroadcast}}, {self(), {pubsub,wsbroadcast}, Term});
        {delReport,Key,_,_} = Cmsg -> 
            lager:log(notice, [{pid, self()}], "--Request for delete --~p ~n", [Cmsg]),
            ets_report:delete(Key);
        {delErr,Key,_,_} = Cmsg -> 
            lager:log(notice, [{pid, self()}], "--Request for delete error data --~p ~n", [Cmsg]),
            [{report,Dirname,_,_,_,_,_}] = ets:lookup(report,Key),
            file_utils:del_dir(Dirname),
            ets:match_delete(logtex, {Key,'_'}),
            ets_report:delete(Key);
        {viewLog,Key,_,_} = Cmsg -> 
            io:format("--Receive --~p ~n", [Cmsg]),
            ets_report:logtex(Key);
        _->
            ok
    end,
    {ok, Req, State}.

info(Info, Req, State) ->
    case Info of
        {_PID,?WSKey,Msg} ->
            {reply, {binary, Msg}, Req, State};
        {timeout, _Ref, Msg} ->
            {reply, {text, Msg}, Req, State};
        {dwnl, Msg} ->
            {_, Message} = message("data", Msg),
            {reply, {text, Message}, Req, State};
        {command, Msg} ->
            {_, Message} = message( "eval", Msg),
            {reply, {text, Message}, Req, State};
        {binary, Msg} ->
            {reply, {binary, Msg}, Req, State};
        _ ->
            {ok, Req, State}
    end.   
   
terminate(_Req, _State) ->
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
