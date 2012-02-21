%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License
%% at http://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and
%% limitations under the License.
%%
%% The Original Code is RabbitMQ.
%%
%% The Initial Developer of the Original Code is VMware, Inc.
%% Copyright (c) 2011-2012 VMware, Inc.  All rights reserved.
%%

-define(HEADER_ACCEPT_VERSION, "accept-version").
-define(HEADER_ACK, "ack").
-define(HEADER_AMQP_MESSAGE_ID, "amqp-message-id").
-define(HEADER_CONTENT_ENCODING, "content-encoding").
-define(HEADER_CONTENT_TYPE, "content-type").
-define(HEADER_CORRELATION_ID, "correlation-id").
-define(HEADER_DESTINATION, "destination").
-define(HEADER_HEART_BEAT, "heart-beat").
-define(HEADER_HOST, "host").
-define(HEADER_ID, "id").
-define(HEADER_LOGIN, "login").
-define(HEADER_MESSAGE_ID, "message-id").
-define(HEADER_PASSCODE, "passcode").
-define(HEADER_PERSISTENT, "persistent").
-define(HEADER_PRIORITY, "priority").
-define(HEADER_RECEIPT, "receipt").
-define(HEADER_REPLY_TO, "reply-to").
-define(HEADER_SESSION, "session").
-define(HEADER_VERSION, "version").

-define(MESSAGE_ID_SEPARATOR, "@@").

-define(HEADERS_NOT_ON_SEND, [?HEADER_MESSAGE_ID]).

-define(HEADERS_SUBSCRIPTION_PREFIX, "/temp-queue/").
