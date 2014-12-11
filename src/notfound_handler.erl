-module(notfound_handler).
%% Cowboy_http_handler callbacks
-export([
         init/3
        ]).

init(_Type,Req, []) ->
    {URL, Req2} = cowboy_req:url(Req),
    {ok, HTML} = '404_dtl':render([{url, URL}]),
    Req3 = cowboy_req:reply(404, [], HTML, Req2),
    {ok, Req3, no_state}.


%terminate(_Reason, _Req, _State) ->
%    ok.
