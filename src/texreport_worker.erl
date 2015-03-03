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
     {_,[[Home]]} = init:get_argument(home),
    Cmd = Home++"/ReportCraft/report dir="++Dirname++"  type=nogui",
    ets_report:update(Key, "working"),
    ets_report:info(ets:first(report)),
    case run(Cmd,Key) of
        {error,timeout} ->
            Msg="Причина: - timeout",
            lager:log(error, [{pid, self()}], "Failed for timeout"),
            del_error(Key),
            send_msg(error, Msg);
        {error, Status, _} ->
            Msg="Код ошибки: - "++ integer_to_list(Status),
            lager:log(error, [{pid, self()}], "Failed for reason --~s",[integer_to_list(Status)]),
            del_error(Key),
            send_msg(error, Msg);
        _ ->
            {_, FileList} = filedir(Dirname,Key),
            lager:log(notice, [{pid, self()}], "File ready for use --~s", [FileList]),
            ets_report:update(Key, "done"), %%Здесь меняется статус задания
            ets_report:info(ets:first(report)),
            ok
    end,
    %%test(Dirname),
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
    filelib:ensure_dir(Fdest++"/1"),
    file_utils:zip_dir("result.zip", Dirname),
    List = filelib:wildcard(Dirname++"/*.{pdf,zip}"),
    FileList = lists:map(fun(X) -> filename:basename(X) end,List),
    lists:map(fun(Z) -> file:copy(Dirname++"/"++Z,Fdest++"/"++Key++"-"++Z) end,FileList), 
    ListKeyFile = filelib:wildcard(Fdest++"/"++Key++"*.{pdf,zip}"),
    file_utils:del_dir(Dirname),%kill dir
    lists:map(fun(Y) -> ets:insert(pdflist,[{Key,Y}])
                        %%Msg="Отчёт - "++ filename:basename(Y) ++ " готов",
                        %%send_msg(info, Msg)
              end,ListKeyFile),
    Msg="Отчёт - "++ Key ++ " готов",
    send_msg(info, Msg),
    ets:match_delete(logtex, {Key,'_'}),
    {ok, FileList}.

run(Command, Key) ->
    Port = open_port({spawn, Command},
                     [{line, 160}, exit_status, stderr_to_stdout, in, binary]),
    run(Port, [], <<>>, Key).
run(Port, Lines, OldLine, Key) ->
    receive
        {Port, {data, Data}} ->
            case Data of
                {eol, Line} ->
                    ets:insert(logtex,{Key, Line}),
                    run(Port, [<<OldLine/binary, Line/binary>> | Lines], <<>>, Key);
                {noeol, Line} ->
                    ets:insert(logtex,{Key, Line}),
                    run(Port, Lines, <<OldLine/binary, Line/binary>>, Key)
            end;
        {Port, {exit_status, 0}} ->
            {ok, Lines};
        {Port, {exit_status, Status}} ->
            {error, Status, Lines}
    after
        86400000 ->
            {error, timeout}
    end.
    
%%%test(Dirname) ->
%%%    os:cmd("touch "++Dirname++"/1.pdf"),
%%%    ok.

send_msg(Type, Msg) ->
    {_,Str} =ws_handler:wr_to_json(Type, Type, binary_to_list(unicode:characters_to_binary(Msg))),
    Message = term_to_binary({messageSent,{Str}}),
    gproc:send({p, l, {pubsub,wsbroadcast}}, {self(), {pubsub,wsbroadcast}, Message}). 

del_error(Key) ->
    ets_report:update(Key, "error"),
    ets_report:info(ets:first(report)).
    %ets:match_delete(report, {report, '_', '_','_',Key,'_'}),
    %Cmd =  binary_to_list(unicode:characters_to_binary("$('#"++Key ++"').remove()")),
    %Message  = term_to_binary({eval,{Cmd}}),
    %gproc:send({p, l, {pubsub,wsbroadcast}}, {self(), {pubsub,wsbroadcast}, Message}).
