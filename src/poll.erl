-module(poll).
-behavior(gen_server).

-export([start/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,terminate/2]).

start() ->
    gen_server:start_link({local,?MODULE}, ?MODULE, [], []).
   
init(_Args) ->
    Timer = erlang:send_after(1, self(), check),
    Initcount = calendar:datetime_to_gregorian_seconds(calendar:now_to_local_time(now())),
    {ok, {Timer, Initcount}}. %возвращаем агрегированный статус

handle_call(_Req,_From, _State) ->
    ok.

handle_cast(_Req, _State) ->
    ok.

handle_info(check, {OldTimer, Initcount }) ->  %получаем pid of timer
    erlang:cancel_timer(OldTimer),
    exist(Initcount).
   
terminate(shutdown, _State) -> 
    exit(whereis(?MODULE), ok). 

exist(Initcount) ->
    Cond = erlang:whereis(task_queue_manager),
    if Cond == undefined ->
            lager:log(error, [{pid, self()}], "Task_queue manager is down "),
            send_msg(error, "Task_queue manager is down"),
            task_queue:start(texreport_worker, [], [{workers_num, 4},{unique_tasks, false}]),
            send_msg(info, "Task_queue manager is UP, reload all task");
       true ->
            true
    end,
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
    {M0,{M1,M2,M3}} = calendar:seconds_to_daystime(calendar:datetime_to_gregorian_seconds(calendar:now_to_local_time(now()))-Initcount),
    Uptime = term_to_binary({uptime,[integer_to_list(M0),M1,M2,M3]}),
    gproc:send({p, l, {pubsub,wsbroadcast}}, {self(), {pubsub,wsbroadcast}, Stat}), 
    gproc:send({p, l, {pubsub,wsbroadcast}}, {self(), {pubsub,wsbroadcast}, Lavg}),
    gproc:send({p, l, {pubsub,wsbroadcast}}, {self(), {pubsub,wsbroadcast}, Uptime}),
    Timer = erlang:send_after(1000, self(), check), %перезапускаем таймер
    %%io:format("~p~p~p~p~n",[M0,M1,M2,M3]),
    {noreply, {Timer,Initcount}}.  

send_msg(Type, Msg) ->
    {_,Str} =ws_handler:wr_to_json(Type, Type, binary_to_list(unicode:characters_to_binary(Msg))),
    Message = term_to_binary({messageSent,{Str}}),
    gproc:send({p, l, {pubsub,wsbroadcast}}, {self(), {pubsub,wsbroadcast}, Message}). 
