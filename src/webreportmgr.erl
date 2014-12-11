-module(webreportmgr).

-export([
    start/0,
    stop/0,
    update_routes/0
   ]).

-define(APPS, [crypto, ranch, cowlib, cowboy, gproc, webreportmgr]).

%% ===================================================================
%% API functions
%% ===================================================================

start() ->
    ok = lager:start(),
    ok = ensure_started(?APPS),
    ok = sync:go().
    
stop() ->
    sync:stop(),
    ok = stop_apps(lists:reverse(?APPS)).
   
update_routes() ->
    Routes = webreportmgr_app:dispatch_rules(),
    cowboy:set_env(http_listener, dispatch, Routes).


%% ===================================================================
%% Internal functions
%% ===================================================================

ensure_started([]) -> ok;
ensure_started([App | Apps]) ->
    case application:start(App) of
        ok -> ensure_started(Apps);
        {error, {already_started, App}} -> ensure_started(Apps)
    end.

stop_apps([]) -> ok;
stop_apps([App | Apps]) ->
    application:stop(App),
    stop_apps(Apps).
