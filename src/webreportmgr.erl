-module(webreportmgr).

%For erl -s webrepotrmgr
-export([start/0]).

% Application here
-behavior(application).
-export([start/2, stop/1, update_routes/0]).
%% Supervisor is also here
-behaviour(supervisor).
-export([init/1]).

%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type), {I, {I, start_link, []}, permanent, 5000, Type, [I]}).

start() ->
    application:ensure_all_started(?MODULE). %Убеждаемся что всё стартовало из applications


%% ===================================================================
%% Application callback
%% ===================================================================

start(_,_) ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, root).
    
stop(_) ->
    ok.
update_routes() ->
    Routes = dispatch_rules(),
    cowboy:set_env(?MODULE, dispatch, Routes).
%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init(root) ->
    {ok, _} = start_cowboy(),
    {ok, { {one_for_one, 5, 10}, []} }.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Internals
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
start_cowboy() ->
    Dispatch = dispatch_rules(),
    Env = [{env, [{dispatch, Dispatch}]}],
    Port = 7007,
    Hooks = [{onresponse, fun webreportmgr_log:access_log_hook/4}],
    Listpass = ["Operator1::oper1"],
    ets:new(passwd,[set, named_table]),
    lists:map(fun(X) ->  [H|T] = string:tokens(X,"::"),
              ets:insert(passwd,{H,hd(T)}),
              io:format("~p~n",ets:lookup(passwd, H))
              end, Listpass),
    task_queue:start(texreport_worker, [], [{workers_num, 4},{unique_tasks, false}]),
    poll:start(),
    ets_report:init(report),
    cowboy:start_http(?MODULE, 10, [{port, Port}], Env ++ Hooks).

mime() -> [{mimetypes,cow_mimetypes,all}].
dispatch_rules() ->
    Static = fun(Filetype) ->
                    {lists:append(["/", Filetype, "/[...]"]), cowboy_static, 
                     {priv_dir, webreportmgr, [list_to_binary(Filetype)], mime()}}
            end,
    {ok, CWD} = file:get_cwd(),
    Pdf_dest = filename:join([CWD, "priv","pdf"]),
    Logs_dest = filename:join([CWD, "logs"]),
    cowboy_router:compile([
                           {'_', [
                                  Static("css"),
                                  Static("js"),
                                  Static("img"),
                                  {"/pdf/[...]", cowboy_static, {dir,list_to_binary(Pdf_dest),[{mimetypes, cow_mimetypes, all}]}},
                                  {"/logs/[...]", cowboy_static, {dir,list_to_binary(Logs_dest),[{mimetypes, cow_mimetypes, all}]}},
                                  {"/", login_handler, []},
                                  {"/login", login_handler, []},
                                  {"/index", index_handler, []},
                                  {"/upload", upload_handler, []},
                                  {"/status", status_handler, []},
                                  {"/websocket", bullet_handler, [{handler, ws_handler}]},
                                  {'_', notfound_handler, []}
                                 ]}
                          ]). 
    
