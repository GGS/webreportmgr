-module(reportstat_handler).

%% Standard callbacks.
-export([init/3]).
-export([content_types_provided/2]).
-export([terminate/3]).

%% Custom callbacks.
-export([to_text/2]).
-export([to_json/2]).

init(_Type, _Req, []) ->
	{upgrade, protocol, cowboy_rest}.

content_types_provided(Req, State) ->
    
    {[
      {<<"text/plain">>, to_text},
      {<<"application/json">>, to_json}
     ], Req, State}.

to_text(Req, State) ->
    Res = print_stat:total_stat(),
    Body= lists:map(fun({X,[Y,Z]})-> io_lib:format("User: ~s  TotalTime:~s TotalReports: ~s~n",[X, integer_to_list(Y),integer_to_list(Z)]) end, Res),
    {list_to_binary(Body), Req, State}.

to_json(Req, State) ->
    Res = print_stat:total_stat(),
    Body= lists:map(fun({X,[Y,Z]})-> io_lib:format("{\"user\":\"~s\", \"totalTime\":~s,\"totalReports\":~s}",[X, integer_to_list(Y),integer_to_list(Z)]) end, Res),
    {ok, Re} = re:compile("}{"),
    {re:replace(list_to_binary(io_lib:format("[~s]",[Body])), Re,"},{",[global,{return, list}]), Req, State}.

terminate(_Reason, _Req, _State) ->
	ok.
