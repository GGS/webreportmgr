-module(login_handler).
-export([init/3,
         content_types_provided/2,
         is_authorized/2,
         to_html/2,
         terminate/3
]).

init(_Type, Req, []) ->
   
    %#{client := ClientCookie , session_id:= SessionCookie} 
    %    =cowboy_req:match_cookies([client, session_id], Req),
          %Req4 = cowboy_req:reply(200, [{<<"content-type">>, <<"text/html">>}], HTML, Req3),
    {upgrade, protocol,cowboy_rest}.

is_authorized(Req, State) ->
    {ok, Auth, Req1} = cowboy_req:parse_header(<<"authorization">>, Req),
    case  Auth of
        {<<"basic">>, {User, Passw}}  -> 
            case trypass(User) of
                {ok, Passw} ->
                    {Method,Req2} = cowboy_req:method(Req1),
                    io:format("--Pid HTTP open --~p ~n", [self()]),
                                   % #{username := Username} = cowboy_req:match_qs([username], Req),
                    SessionID = integer_to_list(random:uniform(100000000000)),
                    Req3 = cowboy_req:set_resp_cookie(
                             <<"session_id">>, SessionID, [{path, <<"/">>},{max_age, 3600}], Req2),
                    Req4 = cowboy_req:set_resp_cookie(
                             <<"username">>, User, [{path, <<"/">>}], Req3),
                    io:format("~p--~p--~p~n",[Method,User,SessionID]), 
                    {true,Req4, User };
                _->
                    {{false, <<"Basic realm=\"cowboy\"">>}, Req1, State}
            end;
        _ ->
            {{false, <<"Basic realm=\"cowboy\"">>}, Req1, State}
    end.
 
trypass(User) ->
    case ets:lookup(passwd, binary_to_list(User)) of
        [{_, Passw}] -> 
     io:format("----~p~n",[list_to_binary(Passw)]),
            {ok, list_to_binary(Passw)};
        _->
            io:format("~p-~n",["Not User in ets"]),
            {false, User}
    end.
content_types_provided(Req, State) ->
    {[
      {<<"text/html">>, to_html}], Req, State}.

to_html(Req, User) ->
    %io:format("~p~n",[ets:lookup(passwd, "Operator2")]),
    Sname = "Report",
    %#{username := User} = cowboy_req:match_cookies([username], Req),
    Header = <<"<!DOCTYPE html><html><head>
    <title>Webserver</title>
    <meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\"/>
    <link rel='stylesheet' href=\"/css/bootstrap.min.css\">
    <link rel='stylesheet' href=\"/css/bootstrap-responsive.min.css\">
    <link rel='stylesheet' href=\"/css/webreport.css\">
    <script type='text/javascript' src=\"/js/zepto.min.js\"></script></head><body>">>,
    Footer = <<"</body></html>">>,
    {ok, HTML} = login_dtl:render([{shortname, Sname},{currentUser, User}]), 
    {[Header,HTML,Footer], Req, User}.
terminate(_Reason, _Req, _State) ->
    ok.
