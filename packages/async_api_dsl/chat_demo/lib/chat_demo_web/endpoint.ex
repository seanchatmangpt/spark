defmodule ChatDemoWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :chat_demo

  # Serve at "/" the static files from "priv/static" directory.
  plug Plug.Static,
    at: "/",
    from: :chat_demo,
    gzip: false,
    only: ChatDemoWeb.static_paths()

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

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
  plug Plug.Session, @session_options

  # WebSocket configuration
  socket "/socket", ChatDemoWeb.UserSocket,
    websocket: true,
    longpoll: false

  plug ChatDemoWeb.Router

  @session_options [
    store: :cookie,
    key: "_chat_demo_key",
    signing_salt: "chat_demo_salt",
    same_site: "Lax"
  ]

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)
end