-module(reportstat_handler).

%% Standard callbacks.
-export([init/3]).
-export([content_types_provided/2]).
-export([terminate/3]).

%% Custom callbacks.
-export([to_text/2]).
-export([to_html/2]).
-export([to_json/2]).

init(_Type, _Req, []) ->
	{upgrade, protocol, cowboy_rest}.

content_types_provided(Req, State) ->
    
    {[
      {<<"text/plain">>, to_text},
      {<<"text/html">>, to_html},
      {<<"application/json">>, to_json}
     ], Req, State}.

to_text(Req, State) ->
    Res = print_stat:total_tbl(),
    Body= lists:map(fun({_,Bt,Et,User,Rname,Page,Type})->
                            io_lib:format("~s;~s;~s;~s;~s;~s~n",[User,  integer_to_list(Bt), integer_to_list(Et-Bt),Rname,Page,Type]) end, Res),
    {list_to_binary(Body), Req, State}.

to_json(Req, State) ->
    Res = print_stat:total_tbl(),
    Body= lists:map(fun({_,Bt,Et,User,Rname,Page,Type})-> io_lib:format("{\"user\":\"~s\", \"BeginTime\":~s, \"totalTime\":~s,\"Name\":\"~s\",\"totalPage\":\"~s\",\"Type\":\"~s\"}",[User, integer_to_list(Bt-719528*24*3600),integer_to_list(Et-Bt),Rname,Page,Type]) end, Res),
    {ok, Re} = re:compile("}{"),
    {re:replace(list_to_binary(io_lib:format("[~s]",[Body])), Re,"},{",[global,{return, list}]), Req, State}.

to_html(Req,State) ->
    Res = print_stat:total_stat(),
    Header = <<"<!DOCTYPE html><html><head>
    <title>Webserver</title>
    <meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\"/>
    <link rel='stylesheet' href=\"/css/bootstrap.min.css\">
    <link rel='stylesheet' href=\"/css/bootstrap-responsive.min.css\">
    <link rel='stylesheet' href=\"/css/webreport.css\">
    <script type='text/javascript' src=\"/js/zepto.min.js\"></script>
    </head><body><div class=\"container\"><table  class=\"table\">
    <thead><tr><th>User</th><th>Total time</th><th>Total Report</th></tr></thead><tbody>">>,
    Footer = <<"</tbody></table></div></body></html>">>,
     Body= lists:map(fun({X,[Y,Z]})-> io_lib:format("<tr><td>~s</td><td>~s</td><td>~s</td>",[X, integer_to_list(Y),integer_to_list(Z)]) end, Res),
    {[Header,list_to_binary(Body),Footer], Req, State}.

terminate(_Reason, _Req, _State) ->
	ok.
%% -719528*24*3600 поправка на время 1.1.1970 
