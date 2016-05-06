:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_unix_daemon)).

:- initialization http_daemon.

:- http_handler(/, handle_request, [prefix]).

handle_request(Request) :- http_404([], Request).
