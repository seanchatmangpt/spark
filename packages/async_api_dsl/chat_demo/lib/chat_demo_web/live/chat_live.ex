defmodule ChatDemoWeb.ChatLive do
  use ChatDemoWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    user_id = generate_user_id()
    
    socket = 
      socket
      |> assign(:user_id, user_id)
      |> assign(:room_id, "lobby")
      |> assign(:messages, [])
      |> assign(:message_input, "")
      |> assign(:connected_users, [])
      |> assign(:typing_users, [])

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="chat-container">
      <div class="chat-header">
        <h2>Chat Demo - Room: <%= @room_id %></h2>
        <p>Your ID: <%= @user_id %></p>
        <div class="connection-info">
          <button phx-click="connect" id="connect-btn" class="btn">Connect to Chat</button>
          <span id="connection-status">Disconnected</span>
        </div>
      </div>

      <div class="chat-messages" id="messages">
        <%= for message <- @messages do %>
          <div class="message">
            <span class="user"><%= message.user_id %>:</span>
            <span class="body"><%= message.body %></span>
            <span class="time"><%= format_time(message.timestamp) %></span>
          </div>
        <% end %>
      </div>

      <div class="typing-indicator">
        <%= if length(@typing_users) > 0 do %>
          <%= Enum.join(@typing_users, ", ") %> typing...
        <% end %>
      </div>

      <form phx-submit="send_message" class="message-form">
        <input 
          type="text" 
          name="message" 
          value={@message_input}
          phx-change="update_message"
          placeholder="Type a message..."
          class="message-input"
        />
        <button type="submit" class="btn send-btn">Send</button>
      </form>

      <div class="users-online">
        <h4>Online Users:</h4>
        <ul>
          <%= for user <- @connected_users do %>
            <li><%= user %></li>
          <% end %>
        </ul>
      </div>
    </div>

    <style>
      .chat-container {
        max-width: 800px;
        margin: 0 auto;
        padding: 20px;
        font-family: Arial, sans-serif;
      }
      
      .chat-header {
        border-bottom: 1px solid #ccc;
        padding-bottom: 10px;
        margin-bottom: 20px;
      }
      
      .connection-info {
        margin-top: 10px;
      }
      
      .chat-messages {
        height: 400px;
        overflow-y: auto;
        border: 1px solid #ddd;
        padding: 10px;
        margin-bottom: 10px;
        background-color: #f9f9f9;
      }
      
      .message {
        margin-bottom: 10px;
        padding: 5px;
        border-radius: 4px;
        background-color: white;
      }
      
      .user {
        font-weight: bold;
        color: #007cba;
      }
      
      .body {
        margin-left: 10px;
      }
      
      .time {
        font-size: 12px;
        color: #666;
        float: right;
      }
      
      .typing-indicator {
        font-style: italic;
        color: #666;
        height: 20px;
        margin-bottom: 10px;
      }
      
      .message-form {
        display: flex;
        gap: 10px;
        margin-bottom: 20px;
      }
      
      .message-input {
        flex: 1;
        padding: 10px;
        border: 1px solid #ddd;
        border-radius: 4px;
      }
      
      .btn {
        padding: 10px 20px;
        background-color: #007cba;
        color: white;
        border: none;
        border-radius: 4px;
        cursor: pointer;
      }
      
      .btn:hover {
        background-color: #005a87;
      }
      
      .users-online {
        border-top: 1px solid #ccc;
        padding-top: 20px;
      }
      
      .users-online ul {
        list-style-type: none;
        padding: 0;
      }
      
      .users-online li {
        padding: 5px;
        background-color: #f0f0f0;
        margin-bottom: 5px;
        border-radius: 4px;
      }
    </style>

    <script>
      window.addEventListener('DOMContentLoaded', function() {
        let socket = null;
        let channel = null;
        const userId = '<%= @user_id %>';
        const roomId = '<%= @room_id %>';

        document.getElementById('connect-btn').addEventListener('click', function() {
          if (!socket) {
            // Connect to WebSocket
            socket = new Phoenix.Socket('/socket', {
              params: { token: userId }
            });

            socket.connect();

            // Join chat channel
            channel = socket.channel(`chat:${roomId}`, {});
            
            channel.join()
              .receive('ok', resp => {
                console.log('Joined chat', resp);
                document.getElementById('connection-status').textContent = 'Connected';
                document.getElementById('connect-btn').textContent = 'Connected';
                document.getElementById('connect-btn').disabled = true;
              })
              .receive('error', resp => {
                console.log('Unable to join', resp);
                document.getElementById('connection-status').textContent = 'Error';
              });

            // Listen for new messages
            channel.on('new_message', payload => {
              console.log('New message:', payload);
              // Send to LiveView
              window.dispatchEvent(new CustomEvent('new_message', { detail: payload }));
            });

            // Listen for user events
            channel.on('user_joined', payload => {
              console.log('User joined:', payload);
              window.dispatchEvent(new CustomEvent('user_joined', { detail: payload }));
            });

            channel.on('user_left', payload => {
              console.log('User left:', payload);
              window.dispatchEvent(new CustomEvent('user_left', { detail: payload }));
            });

            // Listen for typing events
            channel.on('typing', payload => {
              console.log('User typing:', payload);
              window.dispatchEvent(new CustomEvent('typing', { detail: payload }));
            });
          }
        });

        // Send message function
        window.sendMessage = function(message) {
          if (channel && message.trim()) {
            channel.push('new_message', { body: message })
              .receive('ok', resp => console.log('Message sent', resp))
              .receive('error', resp => console.log('Error sending message', resp));
          }
        };

        // Send typing indicator
        let typingTimer;
        document.querySelector('.message-input').addEventListener('input', function() {
          if (channel) {
            channel.push('typing', { typing: true });
            
            clearTimeout(typingTimer);
            typingTimer = setTimeout(() => {
              channel.push('typing', { typing: false });
            }, 1000);
          }
        });
      });
    </script>
    """
  end

  @impl true
  def handle_event("connect", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) do
    # This will be handled by JavaScript
    {:noreply, assign(socket, :message_input, "")}
  end

  @impl true
  def handle_event("update_message", %{"message" => message}, socket) do
    {:noreply, assign(socket, :message_input, message)}
  end

  # Handle JavaScript events
  @impl true
  def handle_info({:new_message, message}, socket) do
    messages = [message | socket.assigns.messages] |> Enum.take(50)
    {:noreply, assign(socket, :messages, messages)}
  end

  defp generate_user_id do
    "user_" <> (:crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower))
  end

  defp format_time(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _} -> 
        dt
        |> DateTime.to_time()
        |> Time.to_string()
        |> String.slice(0, 8)
      _ -> timestamp
    end
  end
end