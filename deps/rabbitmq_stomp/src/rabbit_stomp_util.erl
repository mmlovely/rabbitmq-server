%%   The contents of this file are subject to the Mozilla Public License
%%   Version 1.1 (the "License"); you may not use this file except in
%%   compliance with the License. You may obtain a copy of the License at
%%   http://www.mozilla.org/MPL/
%%
%%   Software distributed under the License is distributed on an "AS IS"
%%   basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
%%   License for the specific language governing rights and limitations
%%   under the License.
%%
%%   The Original Code is RabbitMQ.
%%
%%   The Initial Developers of the Original Code are LShift Ltd,
%%   Cohesive Financial Technologies LLC, and Rabbit Technologies Ltd.
%%
%%   Portions created before 22-Nov-2008 00:00:00 GMT by LShift Ltd,
%%   Cohesive Financial Technologies LLC, or Rabbit Technologies Ltd
%%   are Copyright (C) 2007-2008 LShift Ltd, Cohesive Financial
%%   Technologies LLC, and Rabbit Technologies Ltd.
%%
%%   Portions created by LShift Ltd are Copyright (C) 2007-2009 LShift
%%   Ltd. Portions created by Cohesive Financial Technologies LLC are
%%   Copyright (C) 2007-2009 Cohesive Financial Technologies
%%   LLC. Portions created by Rabbit Technologies Ltd are Copyright
%%   (C) 2007-2009 Rabbit Technologies Ltd.
%%
%%   All Rights Reserved.
%%
%%   Contributor(s): ______________________________________.
%%

-module(rabbit_stomp_util).

-export([parse_destination/1, parse_routing_information/1,
         parse_message_id/1]).
-export([longstr_field/2]).
-export([ack_mode/1, consumer_tag/1, message_headers/4, message_properties/1]).
-export([negotiate_version/2]).

-include_lib("amqp_client/include/amqp_client.hrl").
-include("rabbit_stomp_frame.hrl").

-define(QUEUE_PREFIX, "/queue").
-define(TOPIC_PREFIX, "/topic").
-define(EXCHANGE_PREFIX, "/exchange").

-define(MESSAGE_ID_SEPARATOR, "@@").

%%--------------------------------------------------------------------
%% Frame and Header Parsing
%%--------------------------------------------------------------------

consumer_tag(Frame) ->
    case rabbit_stomp_frame:header(Frame, "id") of
        {ok, Str} ->
            {ok, list_to_binary("T_" ++ Str)};
        not_found ->
            case rabbit_stomp_frame:header(Frame, "destination") of
                {ok, DestHdr} ->
                    {ok, list_to_binary("Q_" ++ DestHdr)};
                not_found ->
                    {error, missing_destination_header}
            end
    end.

ack_mode(Frame) ->
    case rabbit_stomp_frame:header(Frame, "ack", "auto") of
        "auto"              -> {auto, false};
        "client"            -> {client, true};
        "client-individual" -> {client, false}
    end.

message_properties(Frame = #stomp_frame{headers = Headers}) ->
    BinH = fun(K, V) -> rabbit_stomp_frame:binary_header(Frame, K, V) end,
    IntH = fun(K, V) -> rabbit_stomp_frame:integer_header(Frame, K, V) end,


    #'P_basic'{
      content_type     = BinH("content-type",     <<"text/plain">>),
      content_encoding = BinH("content-encoding", undefined),
      delivery_mode    = IntH("delivery-mode",    undefined),
      priority         = IntH("priority",         undefined),
      correlation_id   = BinH("correlation-id",   undefined),
      reply_to         = BinH("reply-to",         undefined),
      message_id       = BinH("amqp-message-id",  undefined),
      headers          = [longstr_field(K, V) || {"X-" ++ K, V} <- Headers]}.

message_headers(Destination, SessionId,
                #'basic.deliver'{consumer_tag = ConsumerTag,
                                 delivery_tag = DeliveryTag},
                #'P_basic'{headers          = Headers,
                           content_type     = ContentType,
                           content_encoding = ContentEncoding,
                           delivery_mode    = DeliveryMode,
                           priority         = Priority,
                           correlation_id   = CorrelationId,
                           reply_to         = ReplyTo,
                           message_id       = MessageId}) ->
    [{"destination", Destination},
       %% TODO append ContentEncoding as ContentType;
       %% charset=ContentEncoding?  The STOMP SEND handler could also
       %% parse "content-type" to split it, perhaps?
       {"message-id", create_message_id(ConsumerTag,
                                        SessionId,
                                        DeliveryTag)}]
      ++ maybe_header("content-type", ContentType)
      ++ maybe_header("content-encoding", ContentEncoding)
      ++ case ConsumerTag of
             <<"Q_",  _/binary>> -> [];
             <<"T_", Id/binary>> -> [{"subscription", binary_to_list(Id)}]
         end
      ++ adhoc_convert_headers(case Headers of
                                   undefined -> [];
                                   _         -> Headers
                               end)
      ++ maybe_header("delivery-mode", DeliveryMode)
      ++ maybe_header("priority", Priority)
      ++ maybe_header("correlation-id", CorrelationId)
      ++ maybe_header("reply-to", ReplyTo)
      ++ maybe_header("amqp-message-id", MessageId).

parse_message_id(MessageId) ->
    {ok, Pieces} = regexp:split(MessageId, ?MESSAGE_ID_SEPARATOR),
    case Pieces of
        [ConsumerTag, SessionId, DeliveryTag] ->
            {ok, {list_to_binary(ConsumerTag),
                  SessionId,
                  list_to_integer(DeliveryTag)}};
        _ ->
            {error, invalid_message_id}
    end.

negotiate_version(ClientVers, ServerVers) ->
    Common = lists:filter(fun(Ver) ->
                                  lists:member(Ver, ServerVers)
                          end, ClientVers),
    case Common of
        [] ->
            {error, no_common_version};
        [H|T] ->
            {ok, lists:foldl(fun(Ver, AccN) ->
                                max_version(Ver, AccN)
                        end, H, T)}
    end.

max_version(V, V) ->
    V;
max_version(V1, V2) ->
    Split = fun(X) -> re:split(X, "\\.", [{return, list}]) end,
    find_max_version({V1, Split(V1)}, {V2, Split(V2)}).

find_max_version({V1, [X|T1]}, {V2, [X|T2]}) ->
    find_max_version({V1, T1}, {V2, T2});
find_max_version({V1, [X]}, {V2, [Y]}) ->
    case list_to_integer(X) >= list_to_integer(Y) of
        true  -> V1;
        false -> V2
    end;
find_max_version({_V1, []}, {V2, Y}) when length(Y) > 0 ->
    V2;
find_max_version({V1, X}, {_V2, []}) when length(X) > 0 ->
    V1.

%% ---- Header processing helpers ----

longstr_field(K, V) ->
    {list_to_binary(K), longstr, list_to_binary(V)}.

maybe_header(_Key, undefined) ->
    [];
maybe_header(Key, Value) when is_binary(Value) ->
    [{Key, binary_to_list(Value)}];
maybe_header(Key, Value) when is_integer(Value) ->
    [{Key, integer_to_list(Value)}];
maybe_header(_Key, _Value) ->
    [].

adhoc_convert_headers(Headers) ->
    lists:foldr(fun ({K, longstr, V}, Acc) ->
                        [{"X-" ++ binary_to_list(K), binary_to_list(V)} | Acc];
                    ({K, signedint, V}, Acc) ->
                        [{"X-" ++ binary_to_list(K), integer_to_list(V)} | Acc];
                    (_, Acc) ->
                        Acc
                end, [], Headers).

create_message_id(ConsumerTag, SessionId, DeliveryTag) ->
    [ConsumerTag,
     ?MESSAGE_ID_SEPARATOR,
     SessionId,
     ?MESSAGE_ID_SEPARATOR,
     integer_to_list(DeliveryTag)].

%%--------------------------------------------------------------------
%% Destination Parsing
%%--------------------------------------------------------------------

parse_destination(?QUEUE_PREFIX ++ Rest) ->
    parse_simple_destination(queue, Rest);
parse_destination(?TOPIC_PREFIX ++ Rest) ->
    parse_simple_destination(topic, Rest);
parse_destination(?EXCHANGE_PREFIX ++ Rest) ->
    case parse_content(Rest) of
        %% One cannot refer to the default exchange this way; it has
        %% different semantics for subscribe and send
        ["" | _]        -> {error, {invalid_destination, exchange, Rest}};
        [Name]          -> {ok, {exchange, {Name, undefined}}};
        [Name, Pattern] -> {ok, {exchange, {Name, Pattern}}};
        _               -> {error, {invalid_destination, exchange, Rest}}
    end;
parse_destination(Destination) ->
    {error, {unknown_destination, Destination}}.

parse_routing_information({exchange, {Name, undefined}}) ->
    {Name, ""};
parse_routing_information({exchange, {Name, Pattern}}) ->
    {Name, Pattern};
parse_routing_information({queue, Name}) ->
    {"", Name};
parse_routing_information({topic, Name}) ->
    {"amq.topic", Name}.

%% ---- Destination parsing helpers ----

parse_simple_destination(Type, Content) ->
    case parse_content(Content) of
        [Name = [_|_]] -> {ok, {Type, Name}};
        _              -> {error, {invalid_destination, Type, Content}}
    end.

parse_content(Content)->
    case regexp:split(Content, "/") of
        {ok, Matches} -> [unescape(X) ||
                             X <- strip_leading_blank(Matches)];
        Other -> Other
    end.

strip_leading_blank([[] | Rest]) ->
    Rest;
strip_leading_blank(Matches) ->
    Matches.

unescape(Str) ->
    {ok, OutStr, _} = regexp:gsub(Str, "%2F", "/"),
    OutStr.

