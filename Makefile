PROJECT = webreportmgr
ERLC_OPTS= "+{parse_transform, lager_transform}"

DEPS = sync gproc erlydtl  task_queue cowboy lager

dep_lager = git https://github.com/basho/lager.git 2.0.3
dep_task_queue = git https://github.com/GGS/erlang-task-queue.git master

include erlang.mk
.PHONY: run

run:
	@(erl -pa `pwd`/ebin deps/*/ebin -config webreportmgr.config -s webreportmgr )
	#@(erl -pa `pwd`/ebin deps/*/ebin -s webreportmgr )


