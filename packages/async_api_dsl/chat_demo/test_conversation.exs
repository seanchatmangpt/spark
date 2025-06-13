#!/usr/bin/env elixir

Mix.install([
  {:websocket_client, "~> 1.5"},
  {:jason, "~> 1.4"}
])

defmodule ChatClient do
  @behaviour :websocket_client

  def start_link(user_id) do
    url = 'ws://localhost:4000/socket/websocket?user_id=#{user_id}&vsn=2.0.0'
    :websocket_client.start_link(url, __MODULE__, %{user_id: user_id, messages: []})
  end

  def send_message(client, message) do
    :websocket_client.cast(client, {:text, Jason.encode!([
      "4", "4", "chat:lobby", "phx_join", %{}
    ])})
    
    # Wait a bit then send message
    Process.sleep(100)
    
    :websocket_client.cast(client, {:text, Jason.encode!([
      "5", "5", "chat:lobby", "new_message", %{"body" => message}
    ])})
  end

  def get_messages(client) do
    :sys.get_state(client).messages
  end

  # WebSocket callbacks
  def init(state) do
    {:ok, state}
  end

  def onconnect(_req, state) do
    IO.puts("#{state.user_id} connected")
    {:ok, state}
  end

  def ondisconnect(reason, state) do
    IO.puts("#{state.user_id} disconnected: #{inspect(reason)}")
    {:ok, state}
  end

  def websocket_handle({:text, msg}, _req, state) do
    case Jason.decode(msg) do
      {:ok, [_ref, _join_ref, "chat:lobby", event, payload]} ->
        case event do
          "new_message" ->
            user = payload["user"] || "unknown"
            body = payload["body"] || ""
            timestamp = payload["timestamp"] || ""
            message = "[#{user}]: #{body}"
            IO.puts("#{state.user_id} received: #{message}")
            {:ok, %{state | messages: [message | state.messages]}}
          
          "user_joined" ->
            user = payload["user"] || "unknown"
            IO.puts("#{state.user_id} saw: #{user} joined")
            {:ok, state}
          
          _ ->
            {:ok, state}
        end
      
      _ ->
        {:ok, state}
    end
  end

  def websocket_handle(_frame, _req, state) do
    {:ok, state}
  end

  def websocket_info(_info, _req, state) do
    {:ok, state}
  end

  def websocket_terminate(_reason, _req, _state) do
    :ok
  end
end

# Start two clients
IO.puts("Starting conversation demo...")

{:ok, alice} = ChatClient.start_link("Alice")
{:ok, bob} = ChatClient.start_link("Bob")

Process.sleep(1000)

# Have a conversation
IO.puts("\n=== Starting Conversation ===")

ChatClient.send_message(alice, "Hello Bob! How are you?")
Process.sleep(500)

ChatClient.send_message(bob, "Hi Alice! I'm doing great, thanks for asking!")
Process.sleep(500)

ChatClient.send_message(alice, "That's wonderful! I've been working on this chat demo")
Process.sleep(500)

ChatClient.send_message(bob, "Nice! The real-time messaging is working perfectly")
Process.sleep(500)

ChatClient.send_message(alice, "Yes, Phoenix channels are amazing for this kind of thing")
Process.sleep(500)

ChatClient.send_message(bob, "Absolutely! WebSockets make it so responsive")
Process.sleep(1000)

IO.puts("\n=== Conversation Complete ===")
IO.puts("Alice's message history:")
alice_messages = ChatClient.get_messages(alice) |> Enum.reverse()
Enum.each(alice_messages, fn msg -> IO.puts("  #{msg}") end)

IO.puts("\nBob's message history:")
bob_messages = ChatClient.get_messages(bob) |> Enum.reverse()
Enum.each(bob_messages, fn msg -> IO.puts("  #{msg}") end)