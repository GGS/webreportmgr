-module(print_stat).


-export([init/0]).
-export([update/1]).
-export([total_stat/0]).
-export([close_tables/0]).

init() ->
    case ets:info(statReport) of
        undefined -> ets:new(statReport,[bag,named_table, 
                                         {write_concurrency,true},
                                         {read_concurrency,true}]);
        _Else -> ok
    end,
    dets:open_file(statReportDisk, [{type, bag},{file,"statReport"}]),
    ets:from_dets(statReport,statReportDisk).

%% @doc Составление списка пользователей и подсчёт числа заданий и времени на них
%% затраченного.  

total_stat() ->
    init(),
    List = ets:foldl((fun ({_,_,_,User,_}, Sum) -> 
                       Cond= lists:member(User, Sum), 
                       if Cond == false -> 
                               [User|Sum]; 
                          true-> Sum 
                       end 
                       end), [], statReport),
    Res = lists:map(fun(H) -> 
                      Sum = lists:foldl(fun(Key,[Sum_t,Count_t]) ->
                                                [X,Y] = lists:foldl(fun([Bt,Et],[Sum,Count]) ->
                                                                    [Et-Bt+Sum,Count+1] 
                                                            end, [0,0], ets:match(statReport, {Key,'$1','$2',H,'_'})),
                                                [Sum_t+X,Count_t+Y]
                                        end, [0,0], lists:foldl((fun([Key], Acc) -> Cond= lists:member(Key, Acc), if Cond == false -> [Key|Acc]; true-> Acc end  end),[], ets:match(statReport,{'$1','_','_',H,'_'}))), %% уникальный ключ для юзера
                      {H, Sum}
              end,List),
    %%io:format("~p~n",[Res]),
    close_tables(),
    Res.

update(Key) ->
    init(),
    [[Bt, Et, User, Rn]] = ets:match(report, {report,'$1', '_','$2', '$4','$3',Key,'_'}),
    ets:insert(statReport,[{Key, Bt,Et,User,Rn}]),
    dets:insert(statReportDisk,[{Key, Bt,Et,User,Rn}]),
    close_tables().

close_tables() ->
case ets:info(statReport) of
		undefined -> ram_empty;
		_ElseClearRam -> ets:delete(statReport)
	end,
	case dets:info(statReportDisk) of
		{error,_Reason} -> disk_closed;
		_ElseCloseDisk -> _Res = dets:close(statReportDisk), done
	end.

    
%%ets:select(statReport,[{{'_','$1','$2','$3','_'},[{'=<', '$2', 63596985345},{'==','$3', "ggs"}],['$$']}]).y
