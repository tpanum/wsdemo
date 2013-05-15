-module(wsdemo_client).

-behaviour(websocket_client).

-export([start_link/0, start_link/2, start_link/3]).

-export([ws_init/0, ws_onopen/2, ws_onmessage/3, ws_info/3, ws_onclose/3]).

-record(state, {start_time}).

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

start_link() ->
    start_link("localhost", 8000).

start_link(Host, Port) ->
    start_link(Host, Port, "/").

start_link(Host, Port, Path) ->
    websocket_client:start_link(?MODULE, Host, Port, Path).

ws_init() ->
    wsdemo_logger:event({ws_init, self()}),
    #state{start_time=erlang:now()}.

ws_onopen(_Client, State) ->
    wsdemo_logger:event({ws_onopen, self()}),
    erlang:start_timer(0, self(), send_ping),
    State.

ws_onmessage(Client, Msg, State) ->
    handle_msg(Client, Msg, State).

handle_msg(Client, {text, <<"ref:",_/bits>> = Msg}, State) ->
    % rewrite the text message as a binary message
    handle_msg(Client, {binary, Msg}, State);
handle_msg(_Client, {binary, <<"ref:",RefBin/bits>>}, State) ->
    Ref = binary_to_term(RefBin),
    wsdemo_logger:event({recv_message, self(), Ref}),
    State;
handle_msg(_Client, Msg = {Type, TM}, State) ->
    M = binary_to_list(TM),
    {match, [_, {Start, End}]} = re:run(M, "p\":\"([0-9]+)\"", []),
    Ref = string:sub_string(M, Start+1, Start+End),
    wsdemo_logger:event({recv_message, self(), Ref}),
    State.

ws_info(Client, {timeout, _Ref, send_ping}, State) ->
    Ref = make_ref(),
    RefBin = term_to_binary(Ref),
    Data = <<"ref:", RefBin/binary>>,

    wsdemo_logger:event({send_message, self(), Ref}),
    websocket_client:write_sync(Client, {binary, Data}),
    % queue up the next send_ping message
    erlang:start_timer(1000, self(), send_ping),
    State.

ws_onclose(_Client, tcp_closed, State) ->
    % Server disconnected
    wsdemo_logger:event({ws_onclose, self()}),
    State;
ws_onclose(_Client, normal, State) ->
    % We told the client to close
    State.


