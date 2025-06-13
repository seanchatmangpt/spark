defmodule ChatDemoWeb.ChatChannel do
  use ChatDemoWeb, :channel

  @impl true
  def join("chat:" <> room_id, payload, socket) do
    user_id = socket.assigns.user_id
    
    # Announce user joined
    broadcast!(socket, "user_joined", %{
      user_id: user_id,
      room_id: room_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })

    {:ok, %{status: "joined", room_id: room_id}, assign(socket, :room_id, room_id)}
  end

  # Handle incoming messages
  @impl true
  def handle_in("new_message", %{"body" => body}, socket) do
    user_id = socket.assigns.user_id
    room_id = socket.assigns.room_id
    
    message = %{
      id: generate_message_id(),
      user_id: user_id,
      body: body,
      room_id: room_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    # Broadcast message to all users in the room
    broadcast!(socket, "new_message", message)
    
    {:reply, {:ok, %{status: "sent", message_id: message.id}}, socket}
  end

  @impl true
  def handle_in("typing", %{"typing" => typing}, socket) do
    user_id = socket.assigns.user_id
    room_id = socket.assigns.room_id
    
    # Broadcast typing indicator to other users
    broadcast_from!(socket, "typing", %{
      user_id: user_id,
      room_id: room_id,
      typing: typing,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
    
    {:noreply, socket}
  end

  @impl true
  def handle_in("ping", _payload, socket) do
    {:reply, {:ok, %{pong: DateTime.utc_now() |> DateTime.to_iso8601()}}, socket}
  end

  # Handle user leaving
  @impl true
  def terminate(_reason, socket) do
    user_id = socket.assigns.user_id
    room_id = socket.assigns.room_id
    
    broadcast!(socket, "user_left", %{
      user_id: user_id,
      room_id: room_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
    
    :ok
  end

  defp generate_message_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end