:- use_module(library(http/http_unix_daemon)).
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).

:- initialization http_daemon.

:- http_handler(/, handle_request, [prefix]).

handle_request(_Request) :-
        format("Content-type: text/plain~n~n"),
        format("Hello!").
