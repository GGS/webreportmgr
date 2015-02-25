-module(poll).
-behavior(gen_server).

-export([start/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,terminate/2]).

start() ->
    gen_server:start_link({local,?MODULE}, ?MODULE, [], []).
   
init(_Args) ->
    Timer = erlang:send_after(1, self(), check),
    {ok, Timer}. %возвращаем агрегированный статус

handle_call(_Req,_From, _State) ->
    ok.

handle_cast(_Req, _State) ->
    ok.

handle_info(check, OldTimer) ->  %получаем pid of timer
    erlang:cancel_timer(OldTimer),
    exist().
   
terminate(shutdown, _State) -> 
    exit(whereis(?MODULE), ok). 

exist() ->
    [L1,L5,L10,_,_] = string:tokens(os:cmd("cat /proc/loadavg")," "),
    R = lists:filter(fun(X) -> X =/= nomatch  end, 
                     lists:map(fun(X) -> re:run(X, "cpu\\d.+",[{capture,all,list}]) 
                               end, string:tokens(os:cmd("cat /proc/stat"),"\n"))),
    T = lists:map(fun(X) -> {match, [Cpu]} = X, 
                            [Pu, User, Nice,Sys,Idle,Io,Irq,Sirq,Steal,Guest,Var1] = string:tokens(Cpu," "), 
                            Total = list_to_integer(User)+list_to_integer(Nice)+list_to_integer(Sys)+list_to_integer(Idle)+list_to_integer(Io)+list_to_integer(Irq)+list_to_integer(Sirq)+list_to_integer(Steal)+list_to_integer(Guest)+list_to_integer(Var1),
                            [Pu, Total, list_to_integer(Idle)] end, R),
    Stat =  term_to_binary({procs,T}),
    Lavg = term_to_binary({loadavg,[L1,L5,L10]}),
    gproc:send({p, l, {pubsub,wsbroadcast}}, {self(), {pubsub,wsbroadcast}, Stat}), 
    gproc:send({p, l, {pubsub,wsbroadcast}}, {self(), {pubsub,wsbroadcast}, Lavg}), 
    Timer = erlang:send_after(1000, self(), check), %перезапускаем таймер
    {noreply, Timer}.  
