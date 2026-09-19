-module(test_ffi).
-export([os_pid/1]).

os_pid(Port) ->
    case erlang:port_info(Port, os_pid) of
        {os_pid, Pid} -> {ok, Pid};
        undefined -> {error, nil}
    end.