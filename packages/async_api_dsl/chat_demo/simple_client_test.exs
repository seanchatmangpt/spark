#!/usr/bin/env elixir

Mix.install([
  {:gun, "~> 2.0"},
  {:jason, "~> 1.4"}
])

defmodule SimpleWebSocketClient do
  def start_client(user_id) do
    {:ok, conn_pid} = :gun.open(~c"localhost", 4000)
    {:ok, :http} = :gun.await_up(conn_pid)
    
    stream_ref = :gun.ws_upgrade(conn_pid, "/socket/websocket?user_id=#{user_id}&vsn=2.0.0", [
      {"sec-websocket-protocol", "phoenix"}
    ])
    
    receive do
      {:gun_upgrade, ^conn_pid, ^stream_ref, [<<"websocket">>], _headers} ->
        IO.puts("#{user_id} connected to WebSocket")
        
        # Send heartbeat to keep connection alive
        heartbeat_msg = Jason.encode!(["1", "1", "phoenix", "heartbeat", %{}])
        :gun.ws_send(conn_pid, stream_ref, {:text, heartbeat_msg})
        
        # Join the chat channel
        join_msg = Jason.encode!(["2", "2", "chat:lobby", "phx_join", %{}])
        :gun.ws_send(conn_pid, stream_ref, {:text, join_msg})
        
        {conn_pid, stream_ref}
    after
      5000 ->
        IO.puts("#{user_id} failed to connect")
        :gun.close(conn_pid)
        nil
    end
  end
  
  def send_message(conn_pid, stream_ref, user_id, message) do
    ref = :erlang.unique_integer([:positive]) |> to_string()
    msg = Jason.encode!([ref, ref, "chat:lobby", "new_message", %{"body" => message}])
    :gun.ws_send(conn_pid, stream_ref, {:text, msg})
    IO.puts("#{user_id} sent: #{message}")
  end
  
  def listen_for_messages(conn_pid, stream_ref, user_id) do
    spawn(fn ->
      listen_loop(conn_pid, stream_ref, user_id)
    end)
  end
  
  defp listen_loop(conn_pid, stream_ref, user_id) do
    receive do
      {:gun_ws, ^conn_pid, ^stream_ref, {:text, data}} ->
        case Jason.decode(data) do
          {:ok, [_ref, _join_ref, "chat:lobby", "new_message", payload]} ->
            sender = payload["user"] || "unknown"
            body = payload["body"] || ""
            if sender != user_id do
              IO.puts("#{user_id} received: [#{sender}] #{body}")
            end
          {:ok, [_ref, _join_ref, "chat:lobby", "user_joined", payload]} ->
            joined_user = payload["user"] || "unknown"
            if joined_user != user_id do
              IO.puts("#{user_id} saw: #{joined_user} joined the chat")
            end
          _ ->
            :ok
        end
        listen_loop(conn_pid, stream_ref, user_id)
      
      {:gun_ws, ^conn_pid, ^stream_ref, _other} ->
        listen_loop(conn_pid, stream_ref, user_id)
      
      other ->
        IO.puts("#{user_id} got unexpected message: #{inspect(other)}")
        listen_loop(conn_pid, stream_ref, user_id)
    after
      30000 ->
        IO.puts("#{user_id} listener timeout")
    end
  end
end

# Demo conversation
IO.puts("Starting WebSocket conversation demo...")

# Start Alice
alice_client = SimpleWebSocketClient.start_client("Alice")
Process.sleep(500)

# Start Bob  
bob_client = SimpleWebSocketClient.start_client("Bob")
Process.sleep(500)

if alice_client && bob_client do
  {alice_conn, alice_stream} = alice_client
  {bob_conn, bob_stream} = bob_client
  
  # Start message listeners
  SimpleWebSocketClient.listen_for_messages(alice_conn, alice_stream, "Alice")
  SimpleWebSocketClient.listen_for_messages(bob_conn, bob_stream, "Bob")
  
  Process.sleep(1000)
  
  IO.puts("\n=== Starting Conversation ===")
  
  SimpleWebSocketClient.send_message(alice_conn, alice_stream, "Alice", "Hello Bob! How are you?")
  Process.sleep(1000)
  
  SimpleWebSocketClient.send_message(bob_conn, bob_stream, "Bob", "Hi Alice! I'm doing great, thanks!")
  Process.sleep(1000)
  
  SimpleWebSocketClient.send_message(alice_conn, alice_stream, "Alice", "That's wonderful! This chat demo is working perfectly")
  Process.sleep(1000)
  
  SimpleWebSocketClient.send_message(bob_conn, bob_stream, "Bob", "Yes! Real-time messaging with Phoenix channels is amazing")
  Process.sleep(1000)
  
  SimpleWebSocketClient.send_message(alice_conn, alice_stream, "Alice", "The WebSocket connection is so responsive!")
  Process.sleep(1000)
  
  SimpleWebSocketClient.send_message(bob_conn, bob_stream, "Bob", "This proves the AsyncAPI implementation works great")
  Process.sleep(2000)
  
  IO.puts("\n=== Conversation Complete ===")
  
  # Clean up
  :gun.close(alice_conn)
  :gun.close(bob_conn)
else
  IO.puts("Failed to establish WebSocket connections")
end