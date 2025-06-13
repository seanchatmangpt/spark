#!/usr/bin/env elixir

# Simple script to run the chat demo
IO.puts("Starting Chat Demo Server...")
IO.puts("This will start a Phoenix server at http://localhost:4000")
IO.puts("Press Ctrl+C to stop")
IO.puts("")

# Add current directory to path for local modules
Code.append_path("../")

# Start the application
Mix.install([
  {:phoenix, "~> 1.7.0"},
  {:phoenix_html, "~> 3.3"},
  {:phoenix_live_view, "~> 0.20.0"},
  {:jason, "~> 1.4"},
  {:plug_cowboy, "~> 2.5"}
])

Application.put_env(:chat_demo, ChatDemoWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  secret_key_base: String.duplicate("a", 64),
  live_view: [signing_salt: "chat_demo"],
  check_origin: false,
  pubsub_server: ChatDemo.PubSub
)

Application.put_env(:phoenix, :json_library, Jason)

# PubSub is handled by Phoenix.PubSub directly

defmodule ChatDemoWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :chat_demo

  socket "/socket", ChatDemoWeb.UserSocket,
    websocket: true,
    longpoll: false

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]]

  plug Plug.Static,
    at: "/",
    from: "priv/static",
    gzip: false

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head

  # Session config
  @session_options [
    store: :cookie,
    key: "_chat_demo_key",
    signing_salt: "chat_demo",
    same_site: "Lax"
  ]

  plug Plug.Session, @session_options
  plug ChatDemoWeb.Router
end

defmodule ChatDemoWeb.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ChatDemoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", ChatDemoWeb do
    pipe_through :browser
    live "/", ChatLive, :index
  end
end

# Load all the required modules
Code.require_file("lib/chat_demo/application.ex")
Code.require_file("lib/chat_demo_web.ex")
Code.require_file("lib/chat_demo_web/gettext.ex")
Code.require_file("lib/chat_demo_web/channels/user_socket.ex")
Code.require_file("lib/chat_demo_web/channels/chat_channel.ex")
Code.require_file("lib/chat_demo_web/components/core_components.ex")
Code.require_file("lib/chat_demo_web/components/layouts.ex")
Code.require_file("lib/chat_demo_web/live/chat_live.ex")

# Start the system
{:ok, _} = Phoenix.PubSub.start_link(name: ChatDemo.PubSub)
{:ok, _} = ChatDemoWeb.Endpoint.start_link()

IO.puts("🚀 Chat Demo started at http://localhost:4000")
IO.puts("Open multiple browser tabs to test the chat!")

# Keep the server running
Process.sleep(:infinity)