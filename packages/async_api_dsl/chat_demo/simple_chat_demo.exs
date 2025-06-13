#!/usr/bin/env elixir

# Simplified working chat demo
Mix.install([
  {:phoenix, "~> 1.7.0"},
  {:jason, "~> 1.4"},
  {:plug_cowboy, "~> 2.5"}
])

defmodule SimpleChatChannel do
  use Phoenix.Channel

  def join("chat:lobby", _params, socket) do
    send(self(), :after_join)
    {:ok, socket}
  end

  def handle_info(:after_join, socket) do
    broadcast!(socket, "user_joined", %{user: socket.assigns.user_id})
    {:noreply, socket}
  end

  def handle_in("new_message", %{"body" => body}, socket) do
    broadcast!(socket, "new_message", %{
      user: socket.assigns.user_id,
      body: body,
      timestamp: System.system_time(:millisecond)
    })
    {:reply, :ok, socket}
  end

  def terminate(_reason, socket) do
    broadcast!(socket, "user_left", %{user: socket.assigns.user_id})
    :ok
  end
end

defmodule SimpleChatSocket do
  use Phoenix.Socket

  channel "chat:*", SimpleChatChannel

  def connect(%{"user_id" => user_id}, socket, _connect_info) do
    {:ok, assign(socket, :user_id, user_id)}
  end

  def connect(_params, _socket, _connect_info), do: :error

  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end

defmodule SimpleChatEndpoint do
  use Phoenix.Endpoint, otp_app: :simple_chat

  socket "/socket", SimpleChatSocket,
    websocket: true,
    longpoll: false

  plug Plug.Static,
    at: "/",
    from: {:simple_chat, "priv/static"}

  plug :dispatch

  defp dispatch(conn, _opts) do
    case conn.request_path do
      "/" -> serve_index(conn)
      _ -> Plug.Conn.send_resp(conn, 404, "Not Found")
    end
  end

  defp serve_index(conn) do
    html = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Simple Chat Demo</title>
        <script src="https://cdn.jsdelivr.net/npm/phoenix@1.7.0/priv/static/phoenix.min.js"></script>
        <style>
            body { font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; }
            #messages { height: 300px; overflow-y: scroll; border: 1px solid #ccc; padding: 10px; margin: 10px 0; }
            #messageForm { display: flex; gap: 10px; }
            #messageInput { flex: 1; padding: 10px; }
            button { padding: 10px 20px; }
            .message { margin: 5px 0; }
            .user { font-weight: bold; color: #007cba; }
        </style>
    </head>
    <body>
        <h1>Simple Chat Demo</h1>
        <div id="messages"></div>
        <form id="messageForm">
            <input type="text" id="messageInput" placeholder="Type a message..." required>
            <button type="submit">Send</button>
        </form>
        
        <script>
            const userId = 'user_' + Math.random().toString(36).substr(2, 9);
            const socket = new Phoenix.Socket('/socket', {params: {user_id: userId}});
            socket.connect();

            const channel = socket.channel('chat:lobby', {});
            const messagesDiv = document.getElementById('messages');
            const messageForm = document.getElementById('messageForm');
            const messageInput = document.getElementById('messageInput');

            channel.join()
                .receive('ok', resp => {
                    console.log('Joined successfully', resp);
                    addMessage('System', 'Connected to chat!');
                })
                .receive('error', resp => {
                    console.log('Unable to join', resp);
                });

            channel.on('new_message', payload => {
                addMessage(payload.user, payload.body);
            });

            channel.on('user_joined', payload => {
                addMessage('System', payload.user + ' joined the chat');
            });

            channel.on('user_left', payload => {
                addMessage('System', payload.user + ' left the chat');
            });

            messageForm.addEventListener('submit', e => {
                e.preventDefault();
                const message = messageInput.value.trim();
                if (message) {
                    channel.push('new_message', {body: message});
                    messageInput.value = '';
                }
            });

            function addMessage(user, text) {
                const messageEl = document.createElement('div');
                messageEl.className = 'message';
                messageEl.innerHTML = '<span class="user">' + user + ':</span> ' + text;
                messagesDiv.appendChild(messageEl);
                messagesDiv.scrollTop = messagesDiv.scrollHeight;
            }

            addMessage('System', 'Your ID: ' + userId);
        </script>
    </body>
    </html>
    """
    
    conn
    |> Plug.Conn.put_resp_content_type("text/html")
    |> Plug.Conn.send_resp(200, html)
  end
end

# Configuration
Application.put_env(:simple_chat, SimpleChatEndpoint,
  http: [port: 4000],
  server: true,
  secret_key_base: String.duplicate("a", 64),
  pubsub_server: SimpleChat.PubSub
)

# Start PubSub and Endpoint
{:ok, _} = Supervisor.start_link([
  {Phoenix.PubSub, name: SimpleChat.PubSub}
], strategy: :one_for_one)
{:ok, _} = SimpleChatEndpoint.start_link()

IO.puts("🚀 Simple Chat Demo started at http://localhost:4000")
IO.puts("Open multiple browser tabs to test the chat!")
IO.puts("Press Ctrl+C to stop")

# Keep running
Process.sleep(:infinity)