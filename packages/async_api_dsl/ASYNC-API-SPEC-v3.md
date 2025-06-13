AsyncAPI Specification
Attribution
Part of this content has been taken from the great work done by the folks at the OpenAPI Initiative.

Version 3.0.0
The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in RFC 2119.

The AsyncAPI Specification is licensed under The Apache License, Version 2.0.

Introduction
The AsyncAPI Specification is a project used to describe message-driven APIs in a machine-readable format. It’s protocol-agnostic, so you can use it for APIs that work over any protocol (e.g., AMQP, MQTT, WebSockets, Kafka, STOMP, HTTP, Mercure, etc).

The AsyncAPI Specification defines a set of fields that can be used in an AsyncAPI document to describe an application's API. The document may reference other files for additional details or shared fields, but it is typically a single, primary document that encapsulates the API description.

The AsyncAPI document SHOULD describe the operations an application performs. For instance, consider the following AsyncAPI definition snippet:


channels:
  userSignedUp:
    # ...(redacted for brevity)
operations:
  onUserSignedUp:
    action: receive
    channel:
      $ref: "#/channels/userSignedUp"
It means that the application will receive messages from the userSignedUp channel.

The AsyncAPI specification does not assume any kind of software topology, architecture or pattern. Therefore, a server MAY be a message broker, a web server or any other kind of computer program capable of sending and/or receiving data. However, AsyncAPI offers a mechanism called "bindings" that aims to help with more specific information about the protocol.

It's NOT RECOMMENDED to derive a receiver AsyncAPI document from a sender one or vice versa. There are no guarantees that the channel used by an application to receive messages will be the same channel where another application is sending them. Also, certain fields in the document like summary, description, and the id of the operation might stop making sense. For instance, given the following receiver snippet:


operations:
  onUserSignedUp:
    summary: On user signed up.
    description: Event received when a user signed up on the product.
    action: receive
    channel:
      $ref: "#/channels/userSignedUp"
We can't automatically assume that an opposite application exists by simply replacing receive with send:


operations:
  onUserSignedUp: # <-- This doesn't make sense now. Should be something like sendUserSignedUp.
    summary: On user signed up. # <-- This doesn't make sense now. Should say something like "Sends a user signed up event".
    description: Event received when a user signed up on the product. # <-- This doesn't make sense now. Should speak about sending an event, not receiving it.
    action: send
    channel:
      $ref: "#/channels/userSignedUp"
Aside from the issues mentioned above, there may also be infrastructure configuration that is not represented here. For instance, a system may use a read-only channel for receiving messages, a different one for sending them, and an intermediary process that will forward messages from one channel to the other.

Definitions
Server
A server MAY be a message broker that is capable of sending and/or receiving between a sender and receiver. A server MAY be a service with WebSocket API that enables message-driven communication between browser-to-server or server-to-server.

Application
An application is any kind of computer program or a group of them. It MUST be a sender, a receiver, or both. An application MAY be a microservice, IoT device (sensor), mainframe process, message broker, etc. An application MAY be written in any number of different programming languages as long as they support the selected protocol. An application MUST also use a protocol supported by the server in order to connect and exchange messages.

Sender
A sender is a type of application, that is sending messages to channels. A sender MAY send to multiple channels depending on the server, protocol, and use-case pattern.

Receiver
A receiver is a type of application that is receiving messages from channels. A receiver MAY receive from multiple channels depending on the server, protocol, and the use-case pattern. A receiver MAY forward a received message further without changing it. A receiver MAY act as a consumer and react to the message. A receiver MAY act as a processor that, for example, aggregates multiple messages in one and forwards them.

Message
A message is the mechanism by which information is exchanged via a channel between servers and applications. A message MAY contain a payload and MAY also contain headers. The headers MAY be subdivided into protocol-defined headers and header properties defined by the application which can act as supporting metadata. The payload contains the data, defined by the application, which MUST be serialized into a format (JSON, XML, Avro, binary, etc.). Since a message is a generic mechanism, it can support multiple interaction patterns such as event, command, request, or response.

Channel
A channel is an addressable component, made available by the server, for the organization of messages. Sender applications send messages to channels and receiver applications receive messages from channels. Servers MAY support many channel instances, allowing messages with different content to be addressed to different channels. Depending on the server implementation, the channel MAY be included in the message via protocol-defined headers.

Protocol
A protocol is the mechanism (wireline protocol or API) by which messages are exchanged between the application and the channel. Example protocols include, but are not limited to, AMQP, HTTP, JMS, Kafka, Anypoint MQ, MQTT, Solace, STOMP, Mercure, WebSocket, Google Pub/Sub, Pulsar.

Bindings
A "binding" (or "protocol binding") is a mechanism to define protocol-specific information. Therefore, a protocol binding MUST define protocol-specific information only.

Specification
Format
The files describing the message-driven API in accordance with the AsyncAPI Specification are represented as JSON objects and conform to the JSON standards. YAML, being a superset of JSON, can be used as well to represent a A2S (AsyncAPI Specification) file.

For example, if a field is said to have an array value, the JSON array representation will be used:


{
   "field" : [...]
}
While the API is described using JSON it does not impose a JSON input/output to the API itself.

All field names in the specification are case sensitive.

The schema exposes two types of fields. Fixed fields, which have a declared name, and Patterned fields, which declare a regex pattern for the field name. Patterned fields can have multiple occurrences as long as each has a unique name.

In order to preserve the ability to round-trip between YAML and JSON formats, YAML version 1.2 is recommended along with some additional constraints:

Tags MUST be limited to those allowed by the JSON Schema ruleset
Keys used in YAML maps MUST be limited to a scalar string, as defined by the YAML Failsafe schema ruleset
File Structure
An AsyncAPI document MAY be made up of a single document or be divided into multiple, connected parts at the discretion of the author. In the latter case, Reference Objects are used.

It is important to note that everything that is defined in an AsyncAPI document MUST be used by the implemented Application, with the exception of the Components Object. Everything that is defined inside the Components Object represents a resource that MAY or MAY NOT be used by the implemented Application.

By convention, the AsyncAPI Specification (A2S) file is named asyncapi.json or asyncapi.yaml.

Absolute URLs
Unless specified otherwise, all properties that are absolute URLs are defined by RFC3986, section 4.3.

Schema
AsyncAPI Object
This is the root document object for the API specification. It combines resource listing and API declaration together into one document.

Fixed Fields
Field Name	Type	Description
asyncapi	AsyncAPI Version String	REQUIRED. Specifies the AsyncAPI Specification version being used. It can be used by tooling Specifications and clients to interpret the version. The structure shall be major.minor.patch, where patch versions must be compatible with the existing major.minor tooling. Typically patch versions will be introduced to address errors in the documentation, and tooling should typically be compatible with the corresponding major.minor (1.0.*). Patch versions will correspond to patches of this document.
id	Identifier	Identifier of the application the AsyncAPI document is defining.
info	Info Object	REQUIRED. Provides metadata about the API. The metadata can be used by the clients if needed.
servers	Servers Object	Provides connection details of servers.
defaultContentType	Default Content Type	Default content type to use when encoding/decoding a message's payload.
channels	Channels Object	The channels used by this application.
operations	Operations Object	The operations this application MUST implement.
components	Components Object	An element to hold various reusable objects for the specification. Everything that is defined inside this object represents a resource that MAY or MAY NOT be used in the rest of the document and MAY or MAY NOT be used by the implemented Application.
This object MAY be extended with Specification Extensions.

AsyncAPI Version String
The version string signifies the version of the AsyncAPI Specification that the document complies to. The format for this string must be major.minor.patch. The patch may be suffixed by a hyphen and extra alphanumeric characters.

A major.minor shall be used to designate the AsyncAPI Specification version, and will be considered compatible with the AsyncAPI Specification specified by that major.minor version. The patch version will not be considered by tooling, making no distinction between 1.0.0 and 1.0.1.

In subsequent versions of the AsyncAPI Specification, care will be given such that increments of the minor version should not interfere with operations of tooling developed to a lower minor version. Thus a hypothetical 1.1.0 specification should be usable with tooling designed for 1.0.0.

Identifier
This field represents a unique universal identifier of the application the AsyncAPI document is defining. It must conform to the URI format, according to RFC3986.

It is RECOMMENDED to use a URN to globally and uniquely identify the application during long periods of time, even after it becomes unavailable or ceases to exist.

Examples

{
  "id": "urn:example:com:smartylighting:streetlights:server"
}

id: 'urn:example:com:smartylighting:streetlights:server'

{
  "id": "https://github.com/smartylighting/streetlights-server"
}

id: 'https://github.com/smartylighting/streetlights-server'
Info Object
The object provides metadata about the API. The metadata can be used by the clients if needed.

Fixed Fields
Field Name	Type	Description
title	string	REQUIRED. The title of the application.
version	string	REQUIRED Provides the version of the application API (not to be confused with the specification version).
description	string	A short description of the application. CommonMark syntax can be used for rich text representation.
termsOfService	string	A URL to the Terms of Service for the API. This MUST be in the form of an absolute URL.
contact	Contact Object	The contact information for the exposed API.
license	License Object	The license information for the exposed API.
tags	Tags Object	A list of tags for application API documentation control. Tags can be used for logical grouping of applications.
externalDocs	External Documentation Object | Reference Object	Additional external documentation of the exposed API.
This object MAY be extended with Specification Extensions.

Info Object Example

{
  "title": "AsyncAPI Sample App",
  "version": "1.0.1",
  "description": "This is a sample app.",
  "termsOfService": "https://asyncapi.org/terms/",
  "contact": {
    "name": "API Support",
    "url": "https://www.asyncapi.org/support",
    "email": "support@asyncapi.org"
  },
  "license": {
    "name": "Apache 2.0",
    "url": "https://www.apache.org/licenses/LICENSE-2.0.html"
  },
  "externalDocs": {
    "description": "Find more info here",
    "url": "https://www.asyncapi.org"
  },
  "tags": [
    {
      "name": "e-commerce"
    }
  ]
}

title: AsyncAPI Sample App
version: 1.0.1
description: This is a sample app.
termsOfService: https://asyncapi.org/terms/
contact:
  name: API Support
  url: https://www.asyncapi.org/support
  email: support@asyncapi.org
license:
  name: Apache 2.0
  url: https://www.apache.org/licenses/LICENSE-2.0.html
externalDocs:
  description: Find more info here
  url: https://www.asyncapi.org
tags:
  - name: e-commerce
Contact Object
Contact information for the exposed API.

Fixed Fields
Field Name	Type	Description
name	string	The identifying name of the contact person/organization.
url	string	The URL pointing to the contact information. This MUST be in the form of an absolute URL.
email	string	The email address of the contact person/organization. MUST be in the format of an email address.
This object MAY be extended with Specification Extensions.

Contact Object Example

{
  "name": "API Support",
  "url": "https://www.example.com/support",
  "email": "support@example.com"
}

name: API Support
url: https://www.example.com/support
email: support@example.com
License Object
License information for the exposed API.

Fixed Fields
Field Name	Type	Description
name	string	REQUIRED. The license name used for the API.
url	string	A URL to the license used for the API. This MUST be in the form of an absolute URL.
This object MAY be extended with Specification Extensions.

License Object Example

{
  "name": "Apache 2.0",
  "url": "https://www.apache.org/licenses/LICENSE-2.0.html"
}

name: Apache 2.0
url: https://www.apache.org/licenses/LICENSE-2.0.html
Servers Object
The Servers Object is a map of Server Objects.

Patterned Fields
Field Pattern	Type	Description
^[A-Za-z0-9_\-]+$	Server Object | Reference Object	The definition of a server this application MAY connect to.
Servers Object Example

{
  "development": {
    "host": "localhost:5672",
    "description": "Development AMQP broker.",
    "protocol": "amqp",
    "protocolVersion": "0-9-1",
    "tags": [
      { 
        "name": "env:development",
        "description": "This environment is meant for developers to run their own tests."
      }
    ]
  },
  "staging": {
    "host": "rabbitmq-staging.in.mycompany.com:5672",
    "description": "RabbitMQ broker for the staging environment.",
    "protocol": "amqp",
    "protocolVersion": "0-9-1",
    "tags": [
      { 
        "name": "env:staging",
        "description": "This environment is a replica of the production environment."
      }
    ]
  },
  "production": {
    "host": "rabbitmq.in.mycompany.com:5672",
    "description": "RabbitMQ broker for the production environment.",
    "protocol": "amqp",
    "protocolVersion": "0-9-1",
    "tags": [
      { 
        "name": "env:production",
        "description": "This environment is the live environment available for final users."
      }
    ]
  }
}

development:
  host: localhost:5672
  description: Development AMQP broker.
  protocol: amqp
  protocolVersion: 0-9-1
  tags:
    - name: "env:development"
      description: "This environment is meant for developers to run their own tests."
staging:
  host: rabbitmq-staging.in.mycompany.com:5672
  description: RabbitMQ broker for the staging environment.
  protocol: amqp
  protocolVersion: 0-9-1
  tags:
    - name: "env:staging"
      description: "This environment is a replica of the production environment."
production:
  host: rabbitmq.in.mycompany.com:5672
  description: RabbitMQ broker for the production environment.
  protocol: amqp
  protocolVersion: 0-9-1
  tags:
    - name: "env:production"
      description: "This environment is the live environment available for final users."
Server Object
An object representing a message broker, a server or any other kind of computer program capable of sending and/or receiving data. This object is used to capture details such as URIs, protocols and security configuration. Variable substitution can be used so that some details, for example usernames and passwords, can be injected by code generation tools.

Fixed Fields
Field Name	Type	Description
host	string	REQUIRED. The server host name. It MAY include the port. This field supports Server Variables. Variable substitutions will be made when a variable is named in {braces}.
protocol	string	REQUIRED. The protocol this server supports for connection.
protocolVersion	string	The version of the protocol used for connection. For instance: AMQP 0.9.1, HTTP 2.0, Kafka 1.0.0, etc.
pathname	string	The path to a resource in the host. This field supports Server Variables. Variable substitutions will be made when a variable is named in {braces}.
description	string	An optional string describing the server. CommonMark syntax MAY be used for rich text representation.
title	string	A human-friendly title for the server.
summary	string	A short summary of the server.
variables	Map[string, Server Variable Object | Reference Object]]	A map between a variable name and its value. The value is used for substitution in the server's host and pathname template.
security	[Security Scheme Object | Reference Object]	A declaration of which security schemes can be used with this server. The list of values includes alternative security scheme objects that can be used. Only one of the security scheme objects need to be satisfied to authorize a connection or operation.
tags	Tags Object	A list of tags for logical grouping and categorization of servers.
externalDocs	External Documentation Object | Reference Object	Additional external documentation for this server.
bindings	Server Bindings Object | Reference Object	A map where the keys describe the name of the protocol and the values describe protocol-specific definitions for the server.
Server Object Example
A single server would be described as:


{
  "host": "kafka.in.mycompany.com:9092",
  "description": "Production Kafka broker.",
  "protocol": "kafka",
  "protocolVersion": "3.2"
}

host: kafka.in.mycompany.com:9092
description: Production Kafka broker.
protocol: kafka
protocolVersion: '3.2'
An example of a server that has a pathname:


{
  "host": "rabbitmq.in.mycompany.com:5672",
  "pathname": "/production",
  "protocol": "amqp",
  "description": "Production RabbitMQ broker (uses the `production` vhost)."
}

host: rabbitmq.in.mycompany.com:5672
pathname: /production
protocol: amqp
description: Production RabbitMQ broker (uses the `production` vhost).
Server Variable Object
An object representing a Server Variable for server URL template substitution.

Fixed Fields
Field Name	Type	Description
enum	[string]	An enumeration of string values to be used if the substitution options are from a limited set.
default	string	The default value to use for substitution, and to send, if an alternate value is not supplied.
description	string	An optional description for the server variable. CommonMark syntax MAY be used for rich text representation.
examples	[string]	An array of examples of the server variable.
This object MAY be extended with Specification Extensions.

Server Variable Object Example

{
  "host": "rabbitmq.in.mycompany.com:5672",
  "pathname": "/{env}",
  "protocol": "amqp",
  "description": "RabbitMQ broker. Use the `env` variable to point to either `production` or `staging`.",
  "variables": {
    "env": {
      "description": "Environment to connect to. It can be either `production` or `staging`.",
      "enum": [
        "production",
        "staging"
      ]
    }
  }
}

host: 'rabbitmq.in.mycompany.com:5672'
pathname: '/{env}'
protocol: amqp
description: RabbitMQ broker. Use the `env` variable to point to either `production` or `staging`.
variables:
  env:
    description: Environment to connect to. It can be either `production` or `staging`.
    enum:
      - production
      - staging
Default Content Type
A string representing the default content type to use when encoding/decoding a message's payload. The value MUST be a specific media type (e.g. application/json). This value MUST be used by schema parsers when the contentType property is omitted.

In case a message can't be encoded/decoded using this value, schema parsers MUST use their default content type.

Default Content Type Example

{
  "defaultContentType": "application/json"
}

defaultContentType: application/json
Channels Object
An object containing all the Channel Object definitions the Application MUST use during runtime.

Patterned Fields
Field Pattern	Type	Description
{channelId}	Channel Object | Reference Object	An identifier for the described channel. The channelId value is case-sensitive. Tools and libraries MAY use the channelId to uniquely identify a channel, therefore, it is RECOMMENDED to follow common programming naming conventions.
Channels Object Example

{
  "userSignedUp": {
    "address": "user.signedup",
    "messages": {
      "userSignedUp": {
        "$ref": "#/components/messages/userSignedUp"
      }
    }
  }
}

userSignedUp:
  address: 'user.signedup'
  messages:
    userSignedUp:
      $ref: '#/components/messages/userSignedUp'
Channel Object
Describes a shared communication channel.

Fixed Fields
Field Name	Type	Description
address	string | null	An optional string representation of this channel's address. The address is typically the "topic name", "routing key", "event type", or "path". When null or absent, it MUST be interpreted as unknown. This is useful when the address is generated dynamically at runtime or can't be known upfront. It MAY contain Channel Address Expressions. Query parameters and fragments SHALL NOT be used, instead use bindings to define them.
messages	Messages Object	A map of the messages that will be sent to this channel by any application at any time. Every message sent to this channel MUST be valid against one, and only one, of the message objects defined in this map.
title	string	A human-friendly title for the channel.
summary	string	A short summary of the channel.
description	string	An optional description of this channel. CommonMark syntax can be used for rich text representation.
servers	[Reference Object]	An array of $ref pointers to the definition of the servers in which this channel is available. If the channel is located in the root Channels Object, it MUST point to a subset of server definitions located in the root Servers Object, and MUST NOT point to a subset of server definitions located in the Components Object or anywhere else. If the channel is located in the Components Object, it MAY point to a Server Objects in any location. If servers is absent or empty, this channel MUST be available on all the servers defined in the Servers Object. Please note the servers property value MUST be an array of Reference Objects and, therefore, MUST NOT contain an array of Server Objects. However, it is RECOMMENDED that parsers (or other software) dereference this property for a better development experience.
parameters	Parameters Object	A map of the parameters included in the channel address. It MUST be present only when the address contains Channel Address Expressions.
tags	Tags Object	A list of tags for logical grouping of channels.
externalDocs	External Documentation Object | Reference Object	Additional external documentation for this channel.
bindings	Channel Bindings Object | Reference Object	A map where the keys describe the name of the protocol and the values describe protocol-specific definitions for the channel.
This object MAY be extended with Specification Extensions.

Channel Object Example

{
  "address": "users.{userId}",
  "title": "Users channel",
  "description": "This channel is used to exchange messages about user events.",
  "messages": {
    "userSignedUp": {
      "$ref": "#/components/messages/userSignedUp"
    },
    "userCompletedOrder": {
      "$ref": "#/components/messages/userCompletedOrder"
    }
  },
  "parameters": {
    "userId": {
      "$ref": "#/components/parameters/userId"
    }
  },
  "servers": [
    { "$ref": "#/servers/rabbitmqInProd" },
    { "$ref": "#/servers/rabbitmqInStaging" }
  ],
  "bindings": {
    "amqp": {
      "is": "queue",
      "queue": {
        "exclusive": true
      }
    }
  },
  "tags": [{
    "name": "user",
    "description": "User-related messages"
  }],
  "externalDocs": {
    "description": "Find more info here",
    "url": "https://example.com"
  }
}

address: 'users.{userId}'
title: Users channel
description: This channel is used to exchange messages about user events.
messages:
  userSignedUp:
    $ref: '#/components/messages/userSignedUp'
  userCompletedOrder:
    $ref: '#/components/messages/userCompletedOrder'
parameters:
  userId:
    $ref: '#/components/parameters/userId'
servers:
  - $ref: '#/servers/rabbitmqInProd'
  - $ref: '#/servers/rabbitmqInStaging'
bindings:
  amqp:
    is: queue
    queue:
      exclusive: true
tags:
  - name: user
    description: User-related messages
externalDocs:
  description: 'Find more info here'
  url: 'https://example.com'
Channel Address Expressions
Channel addresses MAY contain expressions that can be used to define dynamic values.

Expressions MUST be composed by a name enclosed in curly braces ({ and }). E.g., {userId}.

Messages Object
Describes a map of messages included in a channel.

Patterned Fields
Field Pattern	Type	Description
{messageId}	Message Object | Reference Object	The key represents the message identifier. The messageId value is case-sensitive. Tools and libraries MAY use the messageId value to uniquely identify a message, therefore, it is RECOMMENDED to follow common programming naming conventions.
Messages Object Example

{
  "userSignedUp": {
    "$ref": "#/components/messages/userSignedUp"
  },
  "userCompletedOrder": {
    "$ref": "#/components/messages/userCompletedOrder"
  }
}

userSignedUp:
  $ref: '#/components/messages/userSignedUp'
userCompletedOrder:
  $ref: '#/components/messages/userCompletedOrder'
Operations Object
Holds a dictionary with all the operations this application MUST implement.

If you're looking for a place to define operations that MAY or MAY NOT be implemented by the application, consider defining them in components/operations.

Patterned Fields
Field Pattern	Type	Description
{operationId}	Operation Object | Reference Object	The operation this application MUST implement. The field name (operationId) MUST be a string used to identify the operation in the document where it is defined, and its value is case-sensitive. Tools and libraries MAY use the operationId to uniquely identify an operation, therefore, it is RECOMMENDED to follow common programming naming conventions.
Operations Object Example

{
  "onUserSignUp": {
    "title": "User sign up",
    "summary": "Action to sign a user up.",
    "description": "A longer description",
    "channel": {
      "$ref": "#/channels/userSignup"
    },
    "action": "send",
    "tags": [
      { "name": "user" },
      { "name": "signup" },
      { "name": "register" }
    ],
    "bindings": {
      "amqp": {
        "ack": false
      }
    },
    "traits": [
      { "$ref": "#/components/operationTraits/kafka" }
    ]
  }
}

onUserSignUp:
  title: User sign up
  summary: Action to sign a user up.
  description: A longer description
  channel:
    $ref: '#/channels/userSignup'
  action: send
  tags:
    - name: user
    - name: signup
    - name: register
  bindings:
    amqp:
      ack: false
  traits:
    - $ref: '#/components/operationTraits/kafka'
Operation Object
Describes a specific operation.

Fixed Fields
Field Name	Type	Description
action	"send" | "receive"	Required. Use send when it's expected that the application will send a message to the given channel, and receive when the application should expect receiving messages from the given channel.
channel	Reference Object	Required. A $ref pointer to the definition of the channel in which this operation is performed. If the operation is located in the root Operations Object, it MUST point to a channel definition located in the root Channels Object, and MUST NOT point to a channel definition located in the Components Object or anywhere else. If the operation is located in the Components Object, it MAY point to a Channel Object in any location. Please note the channel property value MUST be a Reference Object and, therefore, MUST NOT contain a Channel Object. However, it is RECOMMENDED that parsers (or other software) dereference this property for a better development experience.
title	string	A human-friendly title for the operation.
summary	string	A short summary of what the operation is about.
description	string	A verbose explanation of the operation. CommonMark syntax can be used for rich text representation.
security	[Security Scheme Object | Reference Object]	A declaration of which security schemes are associated with this operation. Only one of the security scheme objects MUST be satisfied to authorize an operation. In cases where Server Security also applies, it MUST also be satisfied.
tags	Tags Object	A list of tags for logical grouping and categorization of operations.
externalDocs	External Documentation Object | Reference Object	Additional external documentation for this operation.
bindings	Operation Bindings Object | Reference Object	A map where the keys describe the name of the protocol and the values describe protocol-specific definitions for the operation.
traits	[Operation Trait Object | Reference Object ]	A list of traits to apply to the operation object. Traits MUST be merged using traits merge mechanism. The resulting object MUST be a valid Operation Object.
messages	[Reference Object]	A list of $ref pointers pointing to the supported Message Objects that can be processed by this operation. It MUST contain a subset of the messages defined in the channel referenced in this operation, and MUST NOT point to a subset of message definitions located in the Messages Object in the Components Object or anywhere else. Every message processed by this operation MUST be valid against one, and only one, of the message objects referenced in this list. Please note the messages property value MUST be a list of Reference Objects and, therefore, MUST NOT contain Message Objects. However, it is RECOMMENDED that parsers (or other software) dereference this property for a better development experience.
reply	Operation Reply Object | Reference Object	The definition of the reply in a request-reply operation.
This object MAY be extended with Specification Extensions.

Operation Object Example

{
  "title": "User sign up",
  "summary": "Action to sign a user up.",
  "description": "A longer description",
  "channel": {
    "$ref": "#/channels/userSignup"
  },
  "action": "send",
  "security": [
    {
     "petstore_auth": [
       "write:pets",
       "read:pets"
     ]
    }
  ],
  "tags": [
    { "name": "user" },
    { "name": "signup" },
    { "name": "register" }
  ],
  "bindings": {
    "amqp": {
      "ack": false
    }
  },
  "traits": [
    { "$ref": "#/components/operationTraits/kafka" }
  ],
  "messages": [
    { "$ref": "/components/messages/userSignedUp" }
  ],
  "reply": {
    "address": {
      "location": "$message.header#/replyTo"
    },
    "channel": {
      "$ref": "#/channels/userSignupReply"
    },
    "messages": [
      { "$ref": "/components/messages/userSignedUpReply" }
    ],
  }
}

title: User sign up
summary: Action to sign a user up.
description: A longer description
channel:
  $ref: '#/channels/userSignup'
action: send
security:
  - petstore_auth:
    - write:pets
    - read:pets
tags:
  - name: user
  - name: signup
  - name: register
bindings:
  amqp:
    ack: false
traits:
  - $ref: "#/components/operationTraits/kafka"
messages:
  - $ref: '#/components/messages/userSignedUp'
reply:
  address:
    location: '$message.header#/replyTo'
  channel:
    $ref: '#/channels/userSignupReply'
  messages:
    - $ref: '#/components/messages/userSignedUpReply'
Operation Trait Object
Describes a trait that MAY be applied to an Operation Object. This object MAY contain any property from the Operation Object, except the action, channel, messages and traits ones.

If you're looking to apply traits to a message, see the Message Trait Object.

Fixed Fields
Field Name	Type	Description
title	string	A human-friendly title for the operation.
summary	string	A short summary of what the operation is about.
description	string	A verbose explanation of the operation. CommonMark syntax can be used for rich text representation.
security	[Security Scheme Object | Reference Object]	A declaration of which security schemes are associated with this operation. Only one of the security scheme objects MUST be satisfied to authorize an operation. In cases where Server Security also applies, it MUST also be satisfied.
tags	Tags Object	A list of tags for logical grouping and categorization of operations.
externalDocs	External Documentation Object | Reference Object	Additional external documentation for this operation.
bindings	Operation Bindings Object | Reference Object	A map where the keys describe the name of the protocol and the values describe protocol-specific definitions for the operation.
This object MAY be extended with Specification Extensions.

Operation Trait Object Example

{
  "bindings": {
    "amqp": {
      "ack": false
    }
  }
}

bindings:
  amqp:
    ack: false
Operation Reply Object
Describes the reply part that MAY be applied to an Operation Object. If an operation implements the request/reply pattern, the reply object represents the response message.

Fixed Fields
Field Name	Type	Description
address	Operation Reply Address Object | Reference Object	Definition of the address that implementations MUST use for the reply.
channel	Reference Object	A $ref pointer to the definition of the channel in which this operation is performed. When address is specified, the address property of the channel referenced by this property MUST be either null or not defined. If the operation reply is located inside a root Operation Object, it MUST point to a channel definition located in the root Channels Object, and MUST NOT point to a channel definition located in the Components Object or anywhere else. If the operation reply is located inside an [Operation Object] in the Components Object or in the Replies Object in the Components Object, it MAY point to a Channel Object in any location. Please note the channel property value MUST be a Reference Object and, therefore, MUST NOT contain a Channel Object. However, it is RECOMMENDED that parsers (or other software) dereference this property for a better development experience.
messages	[Reference Object]	A list of $ref pointers pointing to the supported Message Objects that can be processed by this operation as reply. It MUST contain a subset of the messages defined in the channel referenced in this operation reply, and MUST NOT point to a subset of message definitions located in the Components Object or anywhere else. Every message processed by this operation MUST be valid against one, and only one, of the message objects referenced in this list. Please note the messages property value MUST be a list of Reference Objects and, therefore, MUST NOT contain Message Objects. However, it is RECOMMENDED that parsers (or other software) dereference this property for a better development experience.
This object MAY be extended with Specification Extensions.

Operation Reply Address Object
An object that specifies where an operation has to send the reply.

For specifying and computing the location of a reply address, a runtime expression is used.

Fixed Fields
Field Name	Type	Description
description	string	An optional description of the address. CommonMark syntax can be used for rich text representation.
location	string	REQUIRED. A runtime expression that specifies the location of the reply address.
This object MAY be extended with Specification Extensions.

Examples

{
  "description": "Consumer inbox",
  "location": "$message.header#/replyTo"
}

description: Consumer Inbox
location: $message.header#/replyTo
Parameters Object
Describes a map of parameters included in a channel address.

This map MUST contain all the parameters used in the parent channel address.

Patterned Fields
Field Pattern	Type	Description
^[A-Za-z0-9_\-]+$	Parameter Object | Reference Object	The key represents the name of the parameter. It MUST match the parameter name used in the parent channel address.
Parameters Object Example

{
  "address": "user/{userId}/signedup",
  "parameters": {
    "userId": {
      "description": "Id of the user."
    }
  }
}

address: user/{userId}/signedup
parameters:
  userId:
    description: Id of the user.
Parameter Object
Describes a parameter included in a channel address.

Fixed Fields
Field Name	Type	Description
enum	[string]	An enumeration of string values to be used if the substitution options are from a limited set.
default	string	The default value to use for substitution, and to send, if an alternate value is not supplied.
description	string	An optional description for the parameter. CommonMark syntax MAY be used for rich text representation.
examples	[string]	An array of examples of the parameter value.
location	string	A runtime expression that specifies the location of the parameter value.
This object MAY be extended with Specification Extensions.

Parameter Object Example

{
  "address": "user/{userId}/signedup",
  "parameters": {
    "userId": {
      "description": "Id of the user.",
      "location": "$message.payload#/user/id"
    }
  }
}

address: user/{userId}/signedup
parameters:
  userId:
    description: Id of the user.
    location: $message.payload#/user/id
Server Bindings Object
Map describing protocol-specific definitions for a server.

Fixed Fields
Field Name	Type	Description
http	HTTP Server Binding	Protocol-specific information for an HTTP server.
ws	WebSockets Server Binding	Protocol-specific information for a WebSockets server.
kafka	Kafka Server Binding	Protocol-specific information for a Kafka server.
anypointmq	Anypoint MQ Server Binding	Protocol-specific information for an Anypoint MQ server.
amqp	AMQP Server Binding	Protocol-specific information for an AMQP 0-9-1 server.
amqp1	AMQP 1.0 Server Binding	Protocol-specific information for an AMQP 1.0 server.
mqtt	MQTT Server Binding	Protocol-specific information for an MQTT server.
mqtt5	MQTT 5 Server Binding	Protocol-specific information for an MQTT 5 server.
nats	NATS Server Binding	Protocol-specific information for a NATS server.
jms	JMS Server Binding	Protocol-specific information for a JMS server.
sns	SNS Server Binding	Protocol-specific information for an SNS server.
solace	Solace Server Binding	Protocol-specific information for a Solace server.
sqs	SQS Server Binding	Protocol-specific information for an SQS server.
stomp	STOMP Server Binding	Protocol-specific information for a STOMP server.
redis	Redis Server Binding	Protocol-specific information for a Redis server.
mercure	Mercure Server Binding	Protocol-specific information for a Mercure server.
ibmmq	IBM MQ Server Binding	Protocol-specific information for an IBM MQ server.
googlepubsub	Google Cloud Pub/Sub Server Binding	Protocol-specific information for a Google Cloud Pub/Sub server.
pulsar	Pulsar Server Binding	Protocol-specific information for a Pulsar server.
This object MAY be extended with Specification Extensions.

Channel Bindings Object
Map describing protocol-specific definitions for a channel.

Fixed Fields
Field Name	Type	Description
http	HTTP Channel Binding	Protocol-specific information for an HTTP channel.
ws	WebSockets Channel Binding	Protocol-specific information for a WebSockets channel.
kafka	Kafka Channel Binding	Protocol-specific information for a Kafka channel.
anypointmq	Anypoint MQ Channel Binding	Protocol-specific information for an Anypoint MQ channel.
amqp	AMQP Channel Binding	Protocol-specific information for an AMQP 0-9-1 channel.
amqp1	AMQP 1.0 Channel Binding	Protocol-specific information for an AMQP 1.0 channel.
mqtt	MQTT Channel Binding	Protocol-specific information for an MQTT channel.
mqtt5	MQTT 5 Channel Binding	Protocol-specific information for an MQTT 5 channel.
nats	NATS Channel Binding	Protocol-specific information for a NATS channel.
jms	JMS Channel Binding	Protocol-specific information for a JMS channel.
sns	SNS Channel Binding	Protocol-specific information for an SNS channel.
solace	Solace Channel Binding	Protocol-specific information for a Solace channel.
sqs	SQS Channel Binding	Protocol-specific information for an SQS channel.
stomp	STOMP Channel Binding	Protocol-specific information for a STOMP channel.
redis	Redis Channel Binding	Protocol-specific information for a Redis channel.
mercure	Mercure Channel Binding	Protocol-specific information for a Mercure channel.
ibmmq	IBM MQ Channel Binding	Protocol-specific information for an IBM MQ channel.
googlepubsub	Google Cloud Pub/Sub Channel Binding	Protocol-specific information for a Google Cloud Pub/Sub channel.
pulsar	Pulsar Channel Binding	Protocol-specific information for a Pulsar channel.
This object MAY be extended with Specification Extensions.

Operation Bindings Object
Map describing protocol-specific definitions for an operation.

Fixed Fields
Field Name	Type	Description
http	HTTP Operation Binding	Protocol-specific information for an HTTP operation.
ws	WebSockets Operation Binding	Protocol-specific information for a WebSockets operation.
kafka	Kafka Operation Binding	Protocol-specific information for a Kafka operation.
anypointmq	Anypoint MQ Operation Binding	Protocol-specific information for an Anypoint MQ operation.
amqp	AMQP Operation Binding	Protocol-specific information for an AMQP 0-9-1 operation.
amqp1	AMQP 1.0 Operation Binding	Protocol-specific information for an AMQP 1.0 operation.
mqtt	MQTT Operation Binding	Protocol-specific information for an MQTT operation.
mqtt5	MQTT 5 Operation Binding	Protocol-specific information for an MQTT 5 operation.
nats	NATS Operation Binding	Protocol-specific information for a NATS operation.
jms	JMS Operation Binding	Protocol-specific information for a JMS operation.
sns	SNS Operation Binding	Protocol-specific information for an SNS operation.
solace	Solace Operation Binding	Protocol-specific information for a Solace operation.
sqs	SQS Operation Binding	Protocol-specific information for an SQS operation.
stomp	STOMP Operation Binding	Protocol-specific information for a STOMP operation.
redis	Redis Operation Binding	Protocol-specific information for a Redis operation.
mercure	Mercure Operation Binding	Protocol-specific information for a Mercure operation.
googlepubsub	Google Cloud Pub/Sub Operation Binding	Protocol-specific information for a Google Cloud Pub/Sub operation.
ibmmq	IBM MQ Operation Binding	Protocol-specific information for an IBM MQ operation.
pulsar	Pulsar Operation Binding	Protocol-specific information for a Pulsar operation.
This object MAY be extended with Specification Extensions.

Message Bindings Object
Map describing protocol-specific definitions for a message.

Fixed Fields
Field Name	Type	Description
http	HTTP Message Binding	Protocol-specific information for an HTTP message, i.e., a request or a response.
ws	WebSockets Message Binding	Protocol-specific information for a WebSockets message.
kafka	Kafka Message Binding	Protocol-specific information for a Kafka message.
anypointmq	Anypoint MQ Message Binding	Protocol-specific information for an Anypoint MQ message.
amqp	AMQP Message Binding	Protocol-specific information for an AMQP 0-9-1 message.
amqp1	AMQP 1.0 Message Binding	Protocol-specific information for an AMQP 1.0 message.
mqtt	MQTT Message Binding	Protocol-specific information for an MQTT message.
mqtt5	MQTT 5 Message Binding	Protocol-specific information for an MQTT 5 message.
nats	NATS Message Binding	Protocol-specific information for a NATS message.
jms	JMS Message Binding	Protocol-specific information for a JMS message.
sns	SNS Message Binding	Protocol-specific information for an SNS message.
solace	Solace Server Binding	Protocol-specific information for a Solace message.
sqs	SQS Message Binding	Protocol-specific information for an SQS message.
stomp	STOMP Message Binding	Protocol-specific information for a STOMP message.
redis	Redis Message Binding	Protocol-specific information for a Redis message.
mercure	Mercure Message Binding	Protocol-specific information for a Mercure message.
ibmmq	IBM MQ Message Binding	Protocol-specific information for an IBM MQ message.
googlepubsub	Google Cloud Pub/Sub Message Binding	Protocol-specific information for a Google Cloud Pub/Sub message.
pulsar	Pulsar Message Binding	Protocol-specific information for a Pulsar message.
This object MAY be extended with Specification Extensions.

Message Object
Describes a message received on a given channel and operation.

Fixed Fields
Field Name	Type	Description
headers	Multi Format Schema Object | Schema Object | Reference Object	Schema definition of the application headers. Schema MUST be a map of key-value pairs. It MUST NOT define the protocol headers. If this is a Schema Object, then the schemaFormat will be assumed to be "application/vnd.aai.asyncapi+json;version=asyncapi" where the version is equal to the AsyncAPI Version String.
payload	Multi Format Schema Object | Schema Object | Reference Object	Definition of the message payload. If this is a Schema Object, then the schemaFormat will be assumed to be "application/vnd.aai.asyncapi+json;version=asyncapi" where the version is equal to the AsyncAPI Version String.
correlationId	Correlation ID Object | Reference Object	Definition of the correlation ID used for message tracing or matching.
contentType	string	The content type to use when encoding/decoding a message's payload. The value MUST be a specific media type (e.g. application/json). When omitted, the value MUST be the one specified on the defaultContentType field.
name	string	A machine-friendly name for the message.
title	string	A human-friendly title for the message.
summary	string	A short summary of what the message is about.
description	string	A verbose explanation of the message. CommonMark syntax can be used for rich text representation.
tags	Tags Object	A list of tags for logical grouping and categorization of messages.
externalDocs	External Documentation Object | Reference Object	Additional external documentation for this message.
bindings	Message Bindings Object | Reference Object	A map where the keys describe the name of the protocol and the values describe protocol-specific definitions for the message.
examples	[Message Example Object]	List of examples.
traits	[Message Trait Object | Reference Object]	A list of traits to apply to the message object. Traits MUST be merged using traits merge mechanism. The resulting object MUST be a valid Message Object.
This object MAY be extended with Specification Extensions.

Message Object Example

{
  "name": "UserSignup",
  "title": "User signup",
  "summary": "Action to sign a user up.",
  "description": "A longer description",
  "contentType": "application/json",
  "tags": [
    { "name": "user" },
    { "name": "signup" },
    { "name": "register" }
  ],
  "headers": {
    "type": "object",
    "properties": {
      "correlationId": {
        "description": "Correlation ID set by application",
        "type": "string"
      },
      "applicationInstanceId": {
        "description": "Unique identifier for a given instance of the publishing application",
        "type": "string"
      }
    }
  },
  "payload": {
    "type": "object",
    "properties": {
      "user": {
        "$ref": "#/components/schemas/userCreate"
      },
      "signup": {
        "$ref": "#/components/schemas/signup"
      }
    }
  },
  "correlationId": {
    "description": "Default Correlation ID",
    "location": "$message.header#/correlationId"
  },
  "traits": [
    { "$ref": "#/components/messageTraits/commonHeaders" }
  ],
  "examples": [
    {
      "name": "SimpleSignup",
      "summary": "A simple UserSignup example message",
      "headers": {
        "correlationId": "my-correlation-id",
        "applicationInstanceId": "myInstanceId"
      },
      "payload": {
        "user": {
          "someUserKey": "someUserValue"
        },
        "signup": {
          "someSignupKey": "someSignupValue"
        }
      }
    }
  ]
}

name: UserSignup
title: User signup
summary: Action to sign a user up.
description: A longer description
contentType: application/json
tags:
  - name: user
  - name: signup
  - name: register
headers:
  type: object
  properties:
    correlationId:
      description: Correlation ID set by application
      type: string
    applicationInstanceId:
      description: Unique identifier for a given instance of the publishing application
      type: string
payload:
  type: object
  properties:
    user:
      $ref: "#/components/schemas/userCreate"
    signup:
      $ref: "#/components/schemas/signup"
correlationId:
  description: Default Correlation ID
  location: $message.header#/correlationId
traits:
  - $ref: "#/components/messageTraits/commonHeaders"
examples:
  - name: SimpleSignup
    summary: A simple UserSignup example message
    headers:
      correlationId: my-correlation-id
      applicationInstanceId: myInstanceId
    payload:
      user:
        someUserKey: someUserValue
      signup:
        someSignupKey: someSignupValue
Example using Avro to define the payload:


{
  "name": "UserSignup",
  "title": "User signup",
  "summary": "Action to sign a user up.",
  "description": "A longer description",
  "tags": [
    { "name": "user" },
    { "name": "signup" },
    { "name": "register" }
  ],
  "payload": {
    "schemaFormat": "application/vnd.apache.avro+json;version=1.9.0",
    "schema": {
      "$ref": "path/to/user-create.avsc#/UserCreate"
    }
  }
}

name: UserSignup
title: User signup
summary: Action to sign a user up.
description: A longer description
tags:
  - name: user
  - name: signup
  - name: register
payload:
  schemaFormat: 'application/vnd.apache.avro+yaml;version=1.9.0'
  schema:
    $ref: 'path/to/user-create.avsc/#UserCreate'
Message Trait Object
Describes a trait that MAY be applied to a Message Object. This object MAY contain any property from the Message Object, except payload and traits.

If you're looking to apply traits to an operation, see the Operation Trait Object.

Fixed Fields
Field Name	Type	Description
headers	Multi Format Schema Object | Schema Object | Reference Object	Schema definition of the application headers. Schema MUST be a map of key-value pairs. It MUST NOT define the protocol headers. If this is a Schema Object, then the schemaFormat will be assumed to be "application/vnd.aai.asyncapi+json;version=asyncapi" where the version is equal to the AsyncAPI Version String.
correlationId	Correlation ID Object | Reference Object	Definition of the correlation ID used for message tracing or matching.
contentType	string	The content type to use when encoding/decoding a message's payload. The value MUST be a specific media type (e.g. application/json). When omitted, the value MUST be the one specified on the defaultContentType field.
name	string	A machine-friendly name for the message.
title	string	A human-friendly title for the message.
summary	string	A short summary of what the message is about.
description	string	A verbose explanation of the message. CommonMark syntax can be used for rich text representation.
tags	Tags Object	A list of tags for logical grouping and categorization of messages.
externalDocs	External Documentation Object | Reference Object	Additional external documentation for this message.
bindings	Message Bindings Object | Reference Object	A map where the keys describe the name of the protocol and the values describe protocol-specific definitions for the message.
examples	[Message Example Object]	List of examples.
This object MAY be extended with Specification Extensions.

Message Trait Object Example

{
  "contentType": "application/json"
}

contentType: application/json
Message Example Object
Message Example Object represents an example of a Message Object and MUST contain either headers and/or payload fields.

Fixed Fields
Field Name	Type	Description
headers	Map[string, any]	The value of this field MUST validate against the Message Object's headers field.
payload	any	The value of this field MUST validate against the Message Object's payload field.
name	string	A machine-friendly name.
summary	string	A short summary of what the example is about.
This object MAY be extended with Specification Extensions.

Message Example Object Example

{
  "name": "SimpleSignup",
  "summary": "A simple UserSignup example message",
  "headers": {
    "correlationId": "my-correlation-id",
    "applicationInstanceId": "myInstanceId"
  },
  "payload": {
    "user": {
      "someUserKey": "someUserValue"
    },
    "signup": {
      "someSignupKey": "someSignupValue"
    }
  }
}

name: SimpleSignup
summary: A simple UserSignup example message
headers:
  correlationId: my-correlation-id
  applicationInstanceId: myInstanceId
payload:
  user:
    someUserKey: someUserValue
  signup:
    someSignupKey: someSignupValue
Tags Object
A Tags object is a list of Tag Objects. An Tag Object in a list can be referenced by Reference Object.

Tag Object
Allows adding meta data to a single tag.

Fixed Fields
Field Name	Type	Description
name	string	REQUIRED. The name of the tag.
description	string	A short description for the tag. CommonMark syntax can be used for rich text representation.
externalDocs	External Documentation Object | Reference Object	Additional external documentation for this tag.
This object MAY be extended with Specification Extensions.

Tag Object Example

{
 "name": "user",
 "description": "User-related messages"
}

name: user
description: User-related messages
External Documentation Object
Allows referencing an external resource for extended documentation.

Fixed Fields
Field Name	Type	Description
description	string	A short description of the target documentation. CommonMark syntax can be used for rich text representation.
url	string	REQUIRED. The URL for the target documentation. This MUST be in the form of an absolute URL.
This object MAY be extended with Specification Extensions.

External Documentation Object Example

{
  "description": "Find more info here",
  "url": "https://example.com"
}

description: Find more info here
url: https://example.com
Reference Object
A simple object to allow referencing other components in the specification, internally and externally.

The Reference Object is defined by JSON Reference and follows the same structure, behavior and rules. A JSON Reference SHALL only be used to refer to a schema that is formatted in either JSON or YAML. In the case of a YAML-formatted Schema, the JSON Reference SHALL be applied to the JSON representation of that schema. The JSON representation SHALL be made by applying the conversion described here.

For this specification, reference resolution is done as defined by the JSON Reference specification and not by the JSON Schema specification.

Fixed Fields
Field Name	Type	Description
$ref	string	REQUIRED. The reference string.
This object cannot be extended with additional properties and any properties added SHALL be ignored.

Reference Object Example

{
  "$ref": "#/components/schemas/Pet"
}

  $ref: '#/components/schemas/Pet'
Components Object
Holds a set of reusable objects for different aspects of the AsyncAPI specification. All objects defined within the components object will have no effect on the API unless they are explicitly referenced from properties outside the components object.

Fixed Fields
Field Name	Type	Description
schemas	Map[string, Multi Format Schema Object | Schema Object | Reference Object]	An object to hold reusable Schema Object. If this is a Schema Object, then the schemaFormat will be assumed to be "application/vnd.aai.asyncapi+json;version=asyncapi" where the version is equal to the AsyncAPI Version String.
servers	Map[string, Server Object | Reference Object]	An object to hold reusable Server Objects.
channels	Map[string, Channel Object | Reference Object]	An object to hold reusable Channel Objects.
operations	Map[string, Operation Object | Reference Object]	An object to hold reusable Operation Objects.
messages	Map[string, Message Object | Reference Object]	An object to hold reusable Message Objects.
securitySchemes	Map[string, Security Scheme Object | Reference Object]	An object to hold reusable Security Scheme Objects.
serverVariables	Map[string, Server Variable Object | Reference Object]	An object to hold reusable Server Variable Objects.
parameters	Map[string, Parameter Object | Reference Object]	An object to hold reusable Parameter Objects.
correlationIds	Map[string, Correlation ID Object | Reference Object]	An object to hold reusable Correlation ID Objects.
replies	Map[string, Operation Reply Object | Reference Object]	An object to hold reusable Operation Reply Objects.
replyAddresses	Map[string, Operation Reply Address Object | Reference Object]	An object to hold reusable Operation Reply Address Objects.
externalDocs	Map[string, External Documentation Object | Reference Object]	An object to hold reusable External Documentation Objects.
tags	Map[string, Tag Object | Reference Object]	An object to hold reusable Tag Objects.
operationTraits	Map[string, Operation Trait Object | Reference Object]	An object to hold reusable Operation Trait Objects.
messageTraits	Map[string, Message Trait Object | Reference Object]	An object to hold reusable Message Trait Objects.
serverBindings	Map[string, Server Bindings Object | Reference Object]	An object to hold reusable Server Bindings Objects.
channelBindings	Map[string, Channel Bindings Object | Reference Object]	An object to hold reusable Channel Bindings Objects.
operationBindings	Map[string, Operation Bindings Object | Reference Object]	An object to hold reusable Operation Bindings Objects.
messageBindings	Map[string, Message Bindings Object | Reference Object]	An object to hold reusable Message Bindings Objects.
This object MAY be extended with Specification Extensions.

All the fixed fields declared above are objects that MUST use keys that match the regular expression: ^[a-zA-Z0-9\.\-_]+$.

Field Name Examples:


User
User_1
User_Name
user-name
my.org.User
Components Object Example

{
  "components": {
    "schemas": {
      "Category": {
        "type": "object",
        "properties": {
          "id": {
            "type": "integer",
            "format": "int64"
          },
          "name": {
            "type": "string"
          }
        }
      },
      "Tag": {
        "type": "object",
        "properties": {
          "id": {
            "type": "integer",
            "format": "int64"
          },
          "name": {
            "type": "string"
          }
        }
      },
      "AvroExample": {
        "schemaFormat": "application/vnd.apache.avro+json;version=1.9.0",
        "schema": {
          "$ref": "path/to/user-create.avsc#/UserCreate"
        }
      }
    },
    "servers": {
      "development": {
        "host": "{stage}.in.mycompany.com:{port}",
        "description": "RabbitMQ broker",
        "protocol": "amqp",
        "protocolVersion": "0-9-1",
        "variables": {
          "stage": {
            "$ref": "#/components/serverVariables/stage"
          },
          "port": {
            "$ref": "#/components/serverVariables/port"
          }
        }
      }
    },
    "serverVariables": {
      "stage": {
        "default": "demo",
        "description": "This value is assigned by the service provider, in this example `mycompany.com`"
      },
      "port": {
        "enum": ["5671", "5672"],
        "default": "5672"
      }
    },
    "channels": {
      "user/signedup": {
        "subscribe": {
          "message": {
            "$ref": "#/components/messages/userSignUp"
          }
        }
      }
    },
    "messages": {
      "userSignUp": {
        "summary": "Action to sign a user up.",
        "description": "Multiline description of what this action does.\nHere you have another line.\n",
        "tags": [
          {
            "name": "user"
          },
          {
            "name": "signup"
          }
        ],
        "headers": {
          "type": "object",
          "properties": {
            "applicationInstanceId": {
              "description": "Unique identifier for a given instance of the publishing application",
              "type": "string"
            }
          }
        },
        "payload": {
          "type": "object",
          "properties": {
            "user": {
              "$ref": "#/components/schemas/userCreate"
            },
            "signup": {
              "$ref": "#/components/schemas/signup"
            }
          }
        }
      }
    },
    "parameters": {
      "userId": {
        "description": "Id of the user."
      }
    },
    "correlationIds": {
      "default": {
        "description": "Default Correlation ID",
        "location": "$message.header#/correlationId"
      }
    },
    "messageTraits": {
      "commonHeaders": {
        "headers": {
          "type": "object",
          "properties": {
            "my-app-header": {
              "type": "integer",
              "minimum": 0,
              "maximum": 100
            }
          }
        }
      }
    }
  }
}

components:
  schemas:
    Category:
      type: object
      properties:
        id:
          type: integer
          format: int64
        name:
          type: string
    Tag:
      type: object
      properties:
        id:
          type: integer
          format: int64
        name:
          type: string
    AvroExample:
      schemaFormat: application/vnd.apache.avro+json;version=1.9.0
      schema:
        $ref: 'path/to/user-create.avsc/#UserCreate'
  servers:
    development:
      host: "{stage}.in.mycompany.com:{port}"
      description: RabbitMQ broker
      protocol: amqp
      protocolVersion: 0-9-1
      variables:
        stage:
          $ref: "#/components/serverVariables/stage"
        port:
          $ref: "#/components/serverVariables/port"
  serverVariables:
    stage:
      default: demo
      description: This value is assigned by the service provider, in this example `mycompany.com`
    port:
      enum: ["5671", "5672"]
      default: "5672"
  channels:
    user/signedup:
      subscribe:
        message:
          $ref: "#/components/messages/userSignUp"
  messages:
    userSignUp:
      summary: Action to sign a user up.
      description: |
        Multiline description of what this action does.
        Here you have another line.
      tags:
        - name: user
        - name: signup
      headers:
        type: object
        properties:
          applicationInstanceId:
            description: Unique identifier for a given instance of the publishing application
            type: string
      payload:
        type: object
        properties:
          user:
            $ref: "#/components/schemas/userCreate"
          signup:
            $ref: "#/components/schemas/signup"
  parameters:
    userId:
      description: Id of the user.
  correlationIds:
    default:
      description: Default Correlation ID
      location: $message.header#/correlationId
  messageTraits:
    commonHeaders:
      headers:
        type: object
        properties:
          my-app-header:
            type: integer
            minimum: 0
            maximum: 100
Multi Format Schema Object
The Multi Format Schema Object represents a schema definition. It differs from the Schema Object in that it supports multiple schema formats or languages (e.g., JSON Schema, Avro, etc.).

Fixed Fields
Field Name	Type	Description
schemaFormat	string	Required. A string containing the name of the schema format that is used to define the information. If schemaFormat is missing, it MUST default to application/vnd.aai.asyncapi+json;version={{asyncapi}} where {{asyncapi}} matches the AsyncAPI Version String. In such a case, this would make the Multi Format Schema Object equivalent to the Schema Object. When using Reference Object within the schema, the schemaFormat of the resource being referenced MUST match the schemaFormat of the schema that contains the initial reference. For example, if you reference Avro schema, then schemaFormat of referencing resource and the resource being reference MUST match.

Check out the supported schema formats table for more information. Custom values are allowed but their implementation is OPTIONAL. A custom value MUST NOT refer to one of the schema formats listed in the table.

When using Reference Objects within the schema, the schemaFormat of the referenced resource MUST match the schemaFormat of the schema containing the reference.
schema	any	Required. Definition of the message payload. It can be of any type but defaults to Schema Object. It MUST match the schema format defined in schemaFormat, including the encoding type. E.g., Avro should be inlined as either a YAML or JSON object instead of as a string to be parsed as YAML or JSON. Non-JSON-based schemas (e.g., Protobuf or XSD) MUST be inlined as a string.
This object MAY be extended with Specification Extensions.

Schema formats table
The following table contains a set of values that every implementation MUST support.

Name	Allowed values	Notes
AsyncAPI 3.0.0 Schema Object	application/vnd.aai.asyncapi;version=3.0.0, application/vnd.aai.asyncapi+json;version=3.0.0, application/vnd.aai.asyncapi+yaml;version=3.0.0	This is the default when a schemaFormat is not provided.
JSON Schema Draft 07	application/schema+json;version=draft-07, application/schema+yaml;version=draft-07	
The following table contains a set of values that every implementation is RECOMMENDED to support.

Name	Allowed values	Notes
Avro 1.9.0 schema	application/vnd.apache.avro;version=1.9.0, application/vnd.apache.avro+json;version=1.9.0, application/vnd.apache.avro+yaml;version=1.9.0	
OpenAPI 3.0.0 Schema Object	application/vnd.oai.openapi;version=3.0.0, application/vnd.oai.openapi+json;version=3.0.0, application/vnd.oai.openapi+yaml;version=3.0.0	
RAML 1.0 data type	application/raml+yaml;version=1.0	
Protocol Buffers	application/vnd.google.protobuf;version=2, application/vnd.google.protobuf;version=3	
Multi Format Schema Object Examples
Multi Format Schema Object Example with Avro

channels:
  example:
    messages:
      myMessage:
        payload:
          schemaFormat: 'application/vnd.apache.avro;version=1.9.0'
          schema:
            type: record
            name: User
            namespace: com.company
            doc: User information
            fields:
              - name: displayName
                type: string
              - name: age
                type: int
Schema Object
The Schema Object allows the definition of input and output data types. These types can be objects, but also primitives and arrays. This object is a superset of the JSON Schema Specification Draft 07. The empty schema (which allows any instance to validate) MAY be represented by the boolean value true and a schema which allows no instance to validate MAY be represented by the boolean value false.

Further information about the properties can be found in JSON Schema Core and JSON Schema Validation. Unless stated otherwise, the property definitions follow the JSON Schema specification as referenced here. For other formats (e.g., Avro, RAML, etc) see Multi Format Schema Object.

Properties
The AsyncAPI Schema Object is a JSON Schema vocabulary which extends JSON Schema Core and Validation vocabularies. As such, any keyword available for those vocabularies is by definition available in AsyncAPI, and will work the exact same way, including but not limited to:

title
type
required
multipleOf
maximum
exclusiveMaximum
minimum
exclusiveMinimum
maxLength
minLength
pattern (This string SHOULD be a valid regular expression, according to the ECMA 262 regular expression dialect)
maxItems
minItems
uniqueItems
maxProperties
minProperties
enum
const
examples
if / then / else
readOnly
writeOnly
properties
patternProperties
additionalProperties
additionalItems
items
propertyNames
contains
allOf
oneOf
anyOf
not
The following properties are taken from the JSON Schema definition but their definitions were adjusted to the AsyncAPI Specification.

description - CommonMark syntax can be used for rich text representation.
format - See Data Type Formats for further details. While relying on JSON Schema's defined formats, the AsyncAPI Specification offers a few additional predefined formats.
default - Use it to specify that property has a predefined value if no other value is present. Unlike JSON Schema, the value MUST conform to the defined type for the Schema Object defined at the same level. For example, of type is string, then default can be "foo" but cannot be 1.
Alternatively, any time a Schema Object can be used, a Reference Object can be used in its place. This allows referencing definitions in place of defining them inline. It is appropriate to clarify that the $ref keyword MUST follow the behavior described by Reference Object instead of the one in JSON Schema definition.

In addition to the JSON Schema fields, the following AsyncAPI vocabulary fields MAY be used for further schema documentation:

Fixed Fields
Field Name	Type	Description
discriminator	string	Adds support for polymorphism. The discriminator is the schema property name that is used to differentiate between other schema that inherit this schema. The property name used MUST be defined at this schema and it MUST be in the required property list. When used, the value MUST be the name of this schema or any schema that inherits it. See Composition and Inheritance for more details.
externalDocs	External Documentation Object | Reference Object	Additional external documentation for this schema.
deprecated	boolean	Specifies that a schema is deprecated and SHOULD be transitioned out of usage. Default value is false.
This object MAY be extended with Specification Extensions.

Composition and Inheritance (Polymorphism)
The AsyncAPI Specification allows combining and extending model definitions using the allOf property of JSON Schema, in effect offering model composition. allOf takes in an array of object definitions that are validated independently but together compose a single object.

While composition offers model extensibility, it does not imply a hierarchy between the models. To support polymorphism, AsyncAPI Specification adds the support of the discriminator field. When used, the discriminator will be the name of the property used to decide which schema definition is used to validate the structure of the model. As such, the discriminator field MUST be a required field. There are two ways to define the value of a discriminator for an inheriting instance.

Use the schema's name.
Override the schema's name by overriding the property with a new value. If exists, this takes precedence over the schema's name.
As such, inline schema definitions, which do not have a given id, cannot be used in polymorphism.

Schema Object Examples
Primitive Sample

{
  "type": "string",
  "format": "email"
}

type: string
format: email
Simple Model

{
  "type": "object",
  "required": [
    "name"
  ],
  "properties": {
    "name": {
      "type": "string"
    },
    "address": {
      "$ref": "#/components/schemas/Address"
    },
    "age": {
      "type": "integer",
      "format": "int32",
      "minimum": 0
    }
  }
}

type: object
required:
- name
properties:
  name:
    type: string
  address:
    $ref: '#/components/schemas/Address'
  age:
    type: integer
    format: int32
    minimum: 0
Model with Map/Dictionary Properties
For a simple string to string mapping:


{
  "type": "object",
  "additionalProperties": {
    "type": "string"
  }
}

type: object
additionalProperties:
  type: string
For a string to model mapping:


{
  "type": "object",
  "additionalProperties": {
    "$ref": "#/components/schemas/ComplexModel"
  }
}

type: object
additionalProperties:
  $ref: '#/components/schemas/ComplexModel'
Model with Example

{
  "type": "object",
  "properties": {
    "id": {
      "type": "integer",
      "format": "int64"
    },
    "name": {
      "type": "string"
    }
  },
  "required": [
    "name"
  ],
  "examples": [
    {
      "name": "Puma",
      "id": 1
    }
  ]
}

type: object
properties:
  id:
    type: integer
    format: int64
  name:
    type: string
required:
- name
examples:
- name: Puma
  id: 1
Model with Boolean Schemas

{
  "type": "object",
  "required": [
    "anySchema"
  ],
  "properties": {
    "anySchema": true,
    "cannotBeDefined": false
  }
}

type: object
required:
- anySchema
properties:
  anySchema: true
  cannotBeDefined: false
Models with Composition

{
  "schemas": {
    "ErrorModel": {
      "type": "object",
      "required": [
        "message",
        "code"
      ],
      "properties": {
        "message": {
          "type": "string"
        },
        "code": {
          "type": "integer",
          "minimum": 100,
          "maximum": 600
        }
      }
    },
    "ExtendedErrorModel": {
      "allOf": [
        {
          "$ref": "#/components/schemas/ErrorModel"
        },
        {
          "type": "object",
          "required": [
            "rootCause"
          ],
          "properties": {
            "rootCause": {
              "type": "string"
            }
          }
        }
      ]
    }
  }
}

schemas:
  ErrorModel:
    type: object
    required:
    - message
    - code
    properties:
      message:
        type: string
      code:
        type: integer
        minimum: 100
        maximum: 600
  ExtendedErrorModel:
    allOf:
    - $ref: '#/components/schemas/ErrorModel'
    - type: object
      required:
      - rootCause
      properties:
        rootCause:
          type: string
Models with Polymorphism Support

{
  "schemas": {
    "Pet": {
      "type": "object",
      "discriminator": "petType",
      "properties": {
        "name": {
          "type": "string"
        },
        "petType": {
          "type": "string"
        }
      },
      "required": [
        "name",
        "petType"
      ]
    },
    "Cat": {
      "description": "A representation of a cat. Note that `Cat` will be used as the discriminator value.",
      "allOf": [
        {
          "$ref": "#/components/schemas/Pet"
        },
        {
          "type": "object",
          "properties": {
            "huntingSkill": {
              "type": "string",
              "description": "The measured skill for hunting",
              "enum": [
                "clueless",
                "lazy",
                "adventurous",
                "aggressive"
              ]
            }
          },
          "required": [
            "huntingSkill"
          ]
        }
      ]
    },
    "Dog": {
      "description": "A representation of a dog. Note that `Dog` will be used as the discriminator value.",
      "allOf": [
        {
          "$ref": "#/components/schemas/Pet"
        },
        {
          "type": "object",
          "properties": {
            "packSize": {
              "type": "integer",
              "format": "int32",
              "description": "the size of the pack the dog is from",
              "minimum": 0
            }
          },
          "required": [
            "packSize"
          ]
        }
      ]
    },
    "StickInsect": {
      "description": "A representation of an Australian walking stick. Note that `StickBug` will be used as the discriminator value.",
      "allOf": [
        {
          "$ref": "#/components/schemas/Pet"
        },
        {
          "type": "object",
          "properties": {
            "petType": {
              "const": "StickBug"
            },
            "color": {
              "type": "string"
            }
          },
          "required": [
            "color"
          ]
        }
      ]
    }
  }
}

schemas:
  Pet:
    type: object
    discriminator: petType
    properties:
      name:
        type: string
      petType:
        type: string
    required:
    - name
    - petType
  ## applies to instances with `petType: "Cat"`
  ## because that is the schema name
  Cat:
    description: A representation of a cat
    allOf:
    - $ref: '#/components/schemas/Pet'
    - type: object
      properties:
        huntingSkill:
          type: string
          description: The measured skill for hunting
          enum:
          - clueless
          - lazy
          - adventurous
          - aggressive
      required:
      - huntingSkill
  ## applies to instances with `petType: "Dog"`
  ## because that is the schema name
  Dog:
    description: A representation of a dog
    allOf:
    - $ref: '#/components/schemas/Pet'
    - type: object
      properties:
        packSize:
          type: integer
          format: int32
          description: the size of the pack the dog is from
          minimum: 0
      required:
      - packSize
  ## applies to instances with `petType: "StickBug"`
  ## because that is the required value of the discriminator field,
  ## overriding the schema name
  StickInsect:
    description: A representation of an Australian walking stick
    allOf:
    - $ref: '#/components/schemas/Pet'
    - type: object
      properties:
        petType:
          const: StickBug
        color:
          type: string
      required:
      - color
Security Scheme Object
Defines a security scheme that can be used by the operations. Supported schemes are:

User/Password.
API key (either as user or as password).
X.509 certificate.
End-to-end encryption (either symmetric or asymmetric).
HTTP authentication.
HTTP API key.
OAuth2's common flows (Implicit, Resource Owner Protected Credentials, Client Credentials and Authorization Code) as defined in RFC6749.
OpenID Connect Discovery.
SASL (Simple Authentication and Security Layer) as defined in RFC4422.
Fixed Fields
Field Name	Type	Applies To	Description
type	string	Any	REQUIRED. The type of the security scheme. Valid values are "userPassword", "apiKey", "X509", "symmetricEncryption", "asymmetricEncryption", "httpApiKey", "http", "oauth2", "openIdConnect", "plain", "scramSha256", "scramSha512", and "gssapi".
description	string	Any	A short description for security scheme. CommonMark syntax MAY be used for rich text representation.
name	string	httpApiKey	REQUIRED. The name of the header, query or cookie parameter to be used.
in	string	apiKey | httpApiKey	REQUIRED. The location of the API key. Valid values are "user" and "password" for apiKey and "query", "header" or "cookie" for httpApiKey.
scheme	string	http	REQUIRED. The name of the HTTP Authorization scheme to be used in the Authorization header as defined in RFC7235.
bearerFormat	string	http ("bearer")	A hint to the client to identify how the bearer token is formatted. Bearer tokens are usually generated by an authorization server, so this information is primarily for documentation purposes.
flows	OAuth Flows Object	oauth2	REQUIRED. An object containing configuration information for the flow types supported.
openIdConnectUrl	string	openIdConnect	REQUIRED. OpenId Connect URL to discover OAuth2 configuration values. This MUST be in the form of an absolute URL.
scopes	[string]	oauth2 | openIdConnect	List of the needed scope names. An empty array means no scopes are needed.
This object MAY be extended with Specification Extensions.

Security Scheme Object Example
User/Password Authentication Sample

{
  "type": "userPassword"
}

type: userPassword
API Key Authentication Sample

{
  "type": "apiKey",
  "in": "user"
}

type: apiKey
in: user
X.509 Authentication Sample

{
  "type": "X509"
}

type: X509
End-to-end Encryption Authentication Sample

{
  "type": "symmetricEncryption"
}

type: symmetricEncryption
Basic Authentication Sample

{
  "type": "http",
  "scheme": "basic"
}

type: http
scheme: basic
API Key Sample

{
  "type": "httpApiKey",
  "name": "api_key",
  "in": "header"
}

type: httpApiKey
name: api_key
in: header
JWT Bearer Sample

{
  "type": "http",
  "scheme": "bearer",
  "bearerFormat": "JWT"
}

type: http
scheme: bearer
bearerFormat: JWT
Implicit OAuth2 Sample

{
  "type": "oauth2",
  "flows": {
    "implicit": {
      "authorizationUrl": "https://example.com/api/oauth/dialog",
      "availableScopes": {
        "write:pets": "modify pets in your account",
        "read:pets": "read your pets"
      }
    }
  },
  "scopes": [
    "write:pets"
  ]
}

type: oauth2
flows:
  implicit:
    authorizationUrl: https://example.com/api/oauth/dialog
    availableScopes:
      write:pets: modify pets in your account
      read:pets: read your pets
scopes:
  - 'write:pets'
SASL Sample

{
  "type": "scramSha512"
}

type: scramSha512
OAuth Flows Object
Allows configuration of the supported OAuth Flows.

Fixed Fields
Field Name	Type	Description
implicit	OAuth Flow Object	Configuration for the OAuth Implicit flow.
password	OAuth Flow Object	Configuration for the OAuth Resource Owner Protected Credentials flow.
clientCredentials	OAuth Flow Object	Configuration for the OAuth Client Credentials flow.
authorizationCode	OAuth Flow Object	Configuration for the OAuth Authorization Code flow.
This object MAY be extended with Specification Extensions.

OAuth Flow Object
Configuration details for a supported OAuth Flow

Fixed Fields
Field Name	Type	Applies To	Description
authorizationUrl	string	oauth2 ("implicit", "authorizationCode")	REQUIRED. The authorization URL to be used for this flow. This MUST be in the form of an absolute URL.
tokenUrl	string	oauth2 ("password", "clientCredentials", "authorizationCode")	REQUIRED. The token URL to be used for this flow. This MUST be in the form of an absolute URL.
refreshUrl	string	oauth2	The URL to be used for obtaining refresh tokens. This MUST be in the form of an absolute URL.
availableScopes	Map[string, string]	oauth2	REQUIRED. The available scopes for the OAuth2 security scheme. A map between the scope name and a short description for it.
This object MAY be extended with Specification Extensions.

OAuth Flow Object Examples

{
  "authorizationUrl": "https://example.com/api/oauth/dialog",
  "tokenUrl": "https://example.com/api/oauth/token",
  "availableScopes": {
    "write:pets": "modify pets in your account",
    "read:pets": "read your pets"
  }
}

authorizationUrl: https://example.com/api/oauth/dialog
tokenUrl: https://example.com/api/oauth/token
availableScopes:
  write:pets: modify pets in your account
  read:pets: read your pets
Correlation ID Object
An object that specifies an identifier at design time that can used for message tracing and correlation.

For specifying and computing the location of a Correlation ID, a runtime expression is used.

Fixed Fields
Field Name	Type	Description
description	string	An optional description of the identifier. CommonMark syntax can be used for rich text representation.
location	string	REQUIRED. A runtime expression that specifies the location of the correlation ID.
This object MAY be extended with Specification Extensions.

Examples

{
  "description": "Default Correlation ID",
  "location": "$message.header#/correlationId"
}

description: Default Correlation ID
location: $message.header#/correlationId
Runtime Expression
A runtime expression allows values to be defined based on information that will be available within the message. This mechanism is used by Correlation ID Object and Operation Reply Address Object.

The runtime expression is defined by the following ABNF syntax:


      expression = ( "$message" "." source )
      source = ( header-reference | payload-reference )
      header-reference = "header" ["#" fragment]
      payload-reference = "payload" ["#" fragment]
      fragment = a JSON Pointer [RFC 6901](https://tools.ietf.org/html/rfc6901)
The table below provides examples of runtime expressions and examples of their use in a value:

Examples
Source Location	Example expression	Notes
Message Header Property	$message.header#/MQMD/CorrelId	Correlation ID is set using the CorrelId value from the MQMD header.
Message Payload Property	$message.payload#/messageId	Correlation ID is set using the messageId value from the message payload.
Runtime expressions preserve the type of the referenced value.

Traits Merge Mechanism
Traits MUST be merged with the target object using the JSON Merge Patch algorithm in the same order they are defined. A property on a trait MUST NOT override the same property on the target object.

Example
An object like the following:


description: A longer description.
traits:
  - name: UserSignup
    description: Description from trait.
  - tags:
      - name: user
Would look like the following after applying traits:


name: UserSignup
description: A longer description.
tags:
  - name: user
Specification Extensions
While the AsyncAPI Specification tries to accommodate most use cases, additional data can be added to extend the specification at certain points.

The extensions properties are implemented as patterned fields that are always prefixed by "x-".

Field Pattern	Type	Description
^x-[\w\d\.\x2d_]+$	Any	Allows extensions to the AsyncAPI Schema. The field name MUST begin with x-, for example, x-internal-id. The value can be null, a primitive, an array or an object. Can have any valid JSON format value.
The extensions may or may not be supported by the available tooling, but those may be extended as well to add requested support (if tools are internal or open-sourced).

Data Type Formats
Primitives have an optional modifier property: format. The AsyncAPI specification uses several known formats to more finely define the data type being used. However, the format property is an open string-valued property, and can have any value to support documentation needs. Formats such as "email", "uuid", etc., can be used even though they are not defined by this specification. Types that are not accompanied by a format property follow their definition from the JSON Schema. Tools that do not recognize a specific format MAY default back to the type alone, as if the format was not specified.

The formats defined by the AsyncAPI Specification are:

Common Name	type	format	Comments
integer	integer	int32	signed 32 bits
long	integer	int64	signed 64 bits
float	number	float	
double	number	double	
string	string		
byte	string	byte	base64 encoded characters
binary	string	binary	any sequence of octets
boolean	boolean		
date	string	date	As defined by full-date - RFC3339
dateTime	string	date-time	As defined by date-time - RFC3339
password	string	password	Used to hint UIs the input needs to be obscured.