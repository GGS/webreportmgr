-module(texreport_worker).

-behaviour(task_queue).

-export([
        init/1,
        process_task/2,
        terminate/2,
        code_change/3
    ]).

-record(state, {}).

init(_Args) ->
    #state{}.

process_task({gen_report, Dirname, Key}, State) ->
    io:format("Dirname from worker--~p----Key---~p ~n",[Dirname,Key]),
    Cmd ="/home/DC/ggs/ReportCraft/report dir="++Dirname++" lang=RU type=nogui",
    ets_report:update(Key, "working"),
    ets_report:info(ets:first(report)),
    run(Cmd),
    %test(Dirname),
    {_, FileList} = filedir(Dirname,Key),
    ets_report:update(Key, "done"), %Здесь меняется статус задания
    ets_report:info(ets:first(report)),
    {ok, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
%%%===================================================================
%%% Internal functions
%%%===================================================================
filedir(Dirname, Key) ->
    {ok, CWD} = file:get_cwd(),
    Fdest = filename:join([CWD, "priv","pdf"]),
    List = filelib:wildcard(Dirname++"/*.{pdf,xls*}"),
    FileList = lists:map(fun(X) -> filename:basename(X) end,List),
    lists:map(fun(Z) -> file:copy(Dirname++"/"++Z,Fdest++"/"++Key++"-"++Z) end,FileList), 
    ListKeyFile = filelib:wildcard(Fdest++"/"++Key++"*.{pdf,xls*}"),
    directory:del_dir(Dirname),%kill dir
    lists:map(fun(Y) -> ets:insert(pdflist,[{Key,Y}]),
                        Msg="Отчёт - "++ filename:basename(Y) ++ " готов",
                        {_, Message} = ws_handler:message(unicode:characters_to_binary(Msg),"info"),
                        gproc:send({p, l, {pubsub,wsbroadcast}}, {self(), {pubsub,wsbroadcast}, Message}) 
              end,ListKeyFile),
    {ok, ListKeyFile}.

run(Command) ->
    Port = open_port({spawn, Command},
                     [{line, 160}, exit_status, stderr_to_stdout, in, binary]),
    run(Port, [], <<>>).
run(Port, Lines, OldLine) ->
    receive
        {Port, {data, Data}} ->
            case Data of
                {eol, Line} ->
                    %Pid! {dwnl, Line},
                    run(Port, [<<OldLine/binary, Line/binary>> | Lines], <<>>);
                {noeol, Line} ->
                    %Pid! {dwnl, Line},
                    run(Port, Lines, <<OldLine/binary, Line/binary>>)
            end;
        {Port, {exit_status, 0}} ->
            {ok, Lines};
        {Port, {exit_status, Status}} ->
            %Pid! {dwnl, Status},
            {error, Status, Lines}
    after
        600000 ->
            {error, timeout}
    end.
    
test(Dirname) ->
    os:cmd("touch "++Dirname++"/1.pdf"),
    ok.

