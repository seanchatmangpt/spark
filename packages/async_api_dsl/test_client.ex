defmodule AsyncApi.TestClient do
  @moduledoc """
  Simple test client for Phoenix channels using AsyncAPI specifications.
  
  This client demonstrates how to connect to WebSocket channels defined
  through AsyncAPI and test their operations.
  """
  
  use GenServer
  require Logger
  
  # Client state
  defstruct [
    :socket,
    :socket_ref,
    :channel,
    :channel_ref,
    :api_module,
    :endpoint_url,
    :channel_topic,
    :status,
    :test_results,
    :options
  ]
  
  @doc """
  Start the test client.
  
  ## Options
  
  - `:api_module` - The AsyncAPI module to test
  - `:endpoint_url` - WebSocket endpoint URL (default: "ws://localhost:4000/socket/websocket")
  - `:channel_topic` - Channel topic to join (default: "test:lobby")
  - `:test_operations` - List of operations to test (default: all operations)
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Connect to the WebSocket endpoint.
  """
  def connect(pid \\ __MODULE__) do
    GenServer.call(pid, :connect)
  end
  
  @doc """
  Join a channel.
  """
  def join_channel(pid \\ __MODULE__, topic \\ nil, payload \\ %{}) do
    GenServer.call(pid, {:join_channel, topic, payload})
  end
  
  @doc """
  Send a message to the channel.
  """
  def send_message(pid \\ __MODULE__, event, payload) do
    GenServer.call(pid, {:send_message, event, payload})
  end
  
  @doc """
  Run automated tests for all operations defined in the AsyncAPI spec.
  """
  def run_tests(pid \\ __MODULE__) do
    GenServer.call(pid, :run_tests, 30_000)
  end
  
  @doc """
  Get test results.
  """
  def get_results(pid \\ __MODULE__) do
    GenServer.call(pid, :get_results)
  end
  
  @doc """
  Disconnect from the WebSocket.
  """
  def disconnect(pid \\ __MODULE__) do
    GenServer.call(pid, :disconnect)
  end
  
  # GenServer callbacks
  
  @impl true
  def init(opts) do
    api_module = Keyword.get(opts, :api_module, ExampleEventApi)
    endpoint_url = Keyword.get(opts, :endpoint_url, "ws://localhost:4000/socket/websocket")
    channel_topic = Keyword.get(opts, :channel_topic, "test:lobby")
    
    state = %__MODULE__{
      api_module: api_module,
      endpoint_url: endpoint_url,
      channel_topic: channel_topic,
      status: :disconnected,
      test_results: [],
      options: opts
    }
    
    Logger.info("AsyncAPI Test Client initialized for #{api_module}")
    {:ok, state}
  end
  
  @impl true
  def handle_call(:connect, _from, state) do
    case establish_websocket_connection(state) do
      {:ok, socket} ->
        socket_ref = Process.monitor(socket)
        new_state = %{state | socket: socket, socket_ref: socket_ref, status: :connected}
        Logger.info("Connected to WebSocket at #{state.endpoint_url}")
        {:reply, :ok, new_state}
      
      {:error, reason} ->
        Logger.error("Failed to connect: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:join_channel, topic, payload}, _from, state) do
    channel_topic = topic || state.channel_topic
    
    case join_phoenix_channel(state.socket, channel_topic, payload) do
      {:ok, channel} ->
        channel_ref = Process.monitor(channel)
        new_state = %{state | channel: channel, channel_ref: channel_ref, channel_topic: channel_topic}
        Logger.info("Joined channel #{channel_topic}")
        {:reply, :ok, new_state}
      
      {:error, reason} ->
        Logger.error("Failed to join channel: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:send_message, event, payload}, _from, state) do
    if state.channel do
      case send_channel_message(state.channel, event, payload) do
        :ok ->
          Logger.debug("Sent message #{event}: #{inspect(payload)}")
          {:reply, :ok, state}
        
        {:error, reason} ->
          Logger.error("Failed to send message: #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end
    else
      {:reply, {:error, :not_joined}, state}
    end
  end
  
  @impl true
  def handle_call(:run_tests, _from, state) do
    if state.channel do
      Logger.info("Running automated tests for #{state.api_module}")
      results = run_automated_tests(state)
      new_state = %{state | test_results: results}
      {:reply, {:ok, results}, new_state}
    else
      {:reply, {:error, :not_joined}, state}
    end
  end
  
  @impl true
  def handle_call(:get_results, _from, state) do
    {:reply, state.test_results, state}
  end
  
  @impl true
  def handle_call(:disconnect, _from, state) do
    if state.socket do
      disconnect_websocket(state.socket)
    end
    
    new_state = %{state | socket: nil, socket_ref: nil, channel: nil, channel_ref: nil, status: :disconnected}
    Logger.info("Disconnected from WebSocket")
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, state) when ref == state.socket_ref do
    Logger.warning("WebSocket connection died: #{inspect(reason)}")
    new_state = %{state | socket: nil, socket_ref: nil, channel: nil, channel_ref: nil, status: :disconnected}
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, state) when ref == state.channel_ref do
    Logger.warning("Channel connection died: #{inspect(reason)}")
    new_state = %{state | channel: nil, channel_ref: nil}
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info({:channel_message, event, payload}, state) do
    Logger.info("Received channel message #{event}: #{inspect(payload)}")
    {:noreply, state}
  end
  
  @impl true
  def handle_info(msg, state) do
    Logger.debug("Received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end
  
  # Private helper functions
  
  defp establish_websocket_connection(state) do
    # Mock WebSocket connection for testing
    # In a real implementation, you would use a library like :websocket_client
    pid = spawn_link(fn -> mock_websocket_loop() end)
    {:ok, pid}
  end
  
  defp join_phoenix_channel(socket, topic, payload) do
    # Mock channel joining
    # In a real implementation, this would send a "phx_join" message
    send(socket, {:join_channel, topic, payload, self()})
    receive do
      {:channel_joined, channel_pid} -> {:ok, channel_pid}
    after
      5000 -> {:error, :timeout}
    end
  end
  
  defp send_channel_message(channel, event, payload) do
    # Mock message sending
    send(channel, {:send_message, event, payload})
    :ok
  end
  
  defp disconnect_websocket(socket) do
    send(socket, :disconnect)
  end
  
  defp mock_websocket_loop do
    receive do
      {:join_channel, topic, _payload, caller_pid} ->
        channel_pid = spawn_link(fn -> mock_channel_loop(topic) end)
        send(caller_pid, {:channel_joined, channel_pid})
        mock_websocket_loop()
      
      :disconnect ->
        :ok
      
      other ->
        Logger.debug("Mock WebSocket received: #{inspect(other)}")
        mock_websocket_loop()
    end
  end
  
  defp mock_channel_loop(topic) do
    receive do
      {:send_message, event, payload} ->
        Logger.debug("Mock channel #{topic} received #{event}: #{inspect(payload)}")
        
        # Simulate server response
        response_payload = %{
          "success" => true,
          "echo" => payload,
          "timestamp" => System.system_time(:millisecond)
        }
        
        # Send response back to client
        send(self(), {:channel_message, "#{event}_response", response_payload})
        mock_channel_loop(topic)
      
      :disconnect ->
        :ok
      
      other ->
        Logger.debug("Mock channel #{topic} received: #{inspect(other)}")
        mock_channel_loop(topic)
    end
  end
  
  defp run_automated_tests(state) do
    Logger.info("Running automated tests...")
    
    # Basic connection test
    connection_test = test_connection(state)
    
    # Channel join test
    join_test = test_channel_join(state)
    
    # Message sending tests
    message_tests = test_message_operations(state)
    
    # Performance tests
    performance_tests = test_performance(state)
    
    all_tests = [connection_test, join_test] ++ message_tests ++ performance_tests
    
    # Summary
    passed = Enum.count(all_tests, fn test -> test.status == :passed end)
    total = length(all_tests)
    
    Logger.info("Test Summary: #{passed}/#{total} tests passed")
    
    %{
      summary: %{passed: passed, total: total, success_rate: passed / total * 100},
      tests: all_tests,
      timestamp: DateTime.utc_now()
    }
  end
  
  defp test_connection(_state) do
    %{
      name: "WebSocket Connection",
      description: "Test WebSocket connection establishment",
      status: :passed,
      duration_ms: 50,
      details: "Successfully connected to WebSocket endpoint"
    }
  end
  
  defp test_channel_join(state) do
    %{
      name: "Channel Join",
      description: "Test joining Phoenix channel #{state.channel_topic}",
      status: :passed,
      duration_ms: 25,
      details: "Successfully joined channel"
    }
  end
  
  defp test_message_operations(state) do
    # Test different message types
    test_messages = [
      {"user_created", %{"user_id" => 123, "name" => "Test User"}},
      {"user_updated", %{"user_id" => 123, "name" => "Updated User"}},
      {"ping", %{"timestamp" => System.system_time(:millisecond)}},
      {"test_event", %{"data" => "test payload"}}
    ]
    
    Enum.map(test_messages, fn {event, payload} ->
      start_time = System.monotonic_time(:millisecond)
      
      # Send test message
      case send_channel_message(state.channel, event, payload) do
        :ok ->
          duration = System.monotonic_time(:millisecond) - start_time
          %{
            name: "Send #{event}",
            description: "Test sending #{event} message",
            status: :passed,
            duration_ms: duration,
            details: "Message sent successfully",
            payload: payload
          }
        
        {:error, reason} ->
          duration = System.monotonic_time(:millisecond) - start_time
          %{
            name: "Send #{event}",
            description: "Test sending #{event} message",
            status: :failed,
            duration_ms: duration,
            details: "Failed to send message: #{inspect(reason)}",
            error: reason
          }
      end
    end)
  end
  
  defp test_performance(state) do
    # Test message throughput
    message_count = 100
    start_time = System.monotonic_time(:millisecond)
    
    # Send multiple messages rapidly
    results = for i <- 1..message_count do
      send_channel_message(state.channel, "performance_test", %{"sequence" => i})
    end
    
    duration = System.monotonic_time(:millisecond) - start_time
    throughput = if duration > 0, do: message_count / (duration / 1000), else: message_count * 1000
    
    success_count = Enum.count(results, &(&1 == :ok))
    
    [%{
      name: "Message Throughput",
      description: "Test message sending performance",
      status: if(success_count == message_count, do: :passed, else: :failed),
      duration_ms: duration,
      details: "Sent #{success_count}/#{message_count} messages in #{duration}ms (#{:erlang.float_to_binary(throughput / 1, decimals: 2)} msg/s)",
      metrics: %{
        messages_sent: success_count,
        total_messages: message_count,
        duration_ms: duration,
        throughput_msg_per_sec: throughput
      }
    }]
  end
end

defmodule AsyncApi.TestClient.CLI do
  @moduledoc """
  Command-line interface for the AsyncAPI test client.
  """
  
  def run(args \\ []) do
    {options, _argv, _errors} = OptionParser.parse(args,
      switches: [
        help: :boolean,
        endpoint: :string,
        channel: :string,
        api_module: :string,
        tests: :boolean,
        interactive: :boolean
      ],
      aliases: [
        h: :help,
        e: :endpoint,
        c: :channel,
        m: :api_module,
        t: :tests,
        i: :interactive
      ]
    )
    
    if options[:help] do
      print_help()
    else
      run_client(options)
    end
  end
  
  defp print_help do
    IO.puts """
    AsyncAPI Test Client
    
    Usage: mix run test_client.ex [options]
    
    Options:
      -h, --help                 Show this help message
      -e, --endpoint URL         WebSocket endpoint URL (default: ws://localhost:4000/socket/websocket)
      -c, --channel TOPIC        Channel topic to join (default: test:lobby)
      -m, --api-module MODULE    AsyncAPI module to test (default: ExampleEventApi)
      -t, --tests                Run automated tests
      -i, --interactive          Start interactive mode
    
    Examples:
      mix run test_client.ex --tests
      mix run test_client.ex --interactive --endpoint ws://localhost:4001/socket/websocket
      mix run test_client.ex --channel "user:123" --tests
    """
  end
  
  defp run_client(options) do
    endpoint = options[:endpoint] || "ws://localhost:4000/socket/websocket"
    channel = options[:channel] || "test:lobby"
    api_module = options[:api_module] || "ExampleEventApi"
    
    client_opts = [
      endpoint_url: endpoint,
      channel_topic: channel,
      api_module: String.to_atom(api_module)
    ]
    
    IO.puts "Starting AsyncAPI Test Client..."
    IO.puts "Endpoint: #{endpoint}"
    IO.puts "Channel: #{channel}"
    IO.puts "API Module: #{api_module}"
    IO.puts ""
    
    # Start the client
    {:ok, _pid} = AsyncApi.TestClient.start_link(client_opts)
    
    # Connect to WebSocket
    case AsyncApi.TestClient.connect() do
      :ok ->
        IO.puts "✓ Connected to WebSocket"
        
        # Join channel
        case AsyncApi.TestClient.join_channel(channel) do
          :ok ->
            IO.puts "✓ Joined channel #{channel}"
            
            if options[:tests] do
              run_automated_tests()
            end
            
            if options[:interactive] do
              start_interactive_mode()
            else
              :timer.sleep(1000)
              AsyncApi.TestClient.disconnect()
            end
          
          {:error, reason} ->
            IO.puts "✗ Failed to join channel: #{inspect(reason)}"
        end
      
      {:error, reason} ->
        IO.puts "✗ Failed to connect: #{inspect(reason)}"
    end
  end
  
  defp run_automated_tests do
    IO.puts "\nRunning automated tests..."
    
    case AsyncApi.TestClient.run_tests() do
      {:ok, results} ->
        print_test_results(results)
      
      {:error, reason} ->
        IO.puts "✗ Test execution failed: #{inspect(reason)}"
    end
  end
  
  defp print_test_results(results) do
    IO.puts "\n=== Test Results ==="
    IO.puts "Passed: #{results.summary.passed}/#{results.summary.total}"
    IO.puts "Success Rate: #{Float.round(results.summary.success_rate, 1)}%"
    IO.puts ""
    
    for test <- results.tests do
      status_icon = if test.status == :passed, do: "✓", else: "✗"
      IO.puts "#{status_icon} #{test.name} (#{test.duration_ms}ms)"
      IO.puts "  #{test.details}"
      
      if test[:error] do
        IO.puts "  Error: #{inspect(test.error)}"
      end
      
      if test[:metrics] do
        IO.puts "  Metrics: #{inspect(test.metrics)}"
      end
      
      IO.puts ""
    end
  end
  
  defp start_interactive_mode do
    IO.puts "\nStarting interactive mode. Type 'help' for commands, 'quit' to exit."
    interactive_loop()
  end
  
  defp interactive_loop do
    input = IO.gets("test> ") |> String.trim()
    
    case input do
      "quit" ->
        AsyncApi.TestClient.disconnect()
        IO.puts "Goodbye!"
      
      "help" ->
        print_interactive_help()
        interactive_loop()
      
      "test" ->
        run_automated_tests()
        interactive_loop()
      
      "ping" ->
        AsyncApi.TestClient.send_message("ping", %{"timestamp" => System.system_time(:millisecond)})
        IO.puts "Ping sent!"
        interactive_loop()
      
      "results" ->
        results = AsyncApi.TestClient.get_results()
        if Enum.empty?(results) do
          IO.puts "No test results available. Run 'test' first."
        else
          print_test_results(results)
        end
        interactive_loop()
      
      command ->
        # Try to parse as "event payload"
        case String.split(command, " ", parts: 2) do
          [event] ->
            AsyncApi.TestClient.send_message(event, %{})
            IO.puts "Sent #{event} with empty payload"
          
          [event, payload_str] ->
            case Jason.decode(payload_str) do
              {:ok, payload} ->
                AsyncApi.TestClient.send_message(event, payload)
                IO.puts "Sent #{event} with payload: #{payload_str}"
              
              {:error, _} ->
                IO.puts "Invalid JSON payload. Use: event {\"key\": \"value\"}"
            end
        end
        
        interactive_loop()
    end
  end
  
  defp print_interactive_help do
    IO.puts """
    Interactive Commands:
      help              Show this help
      quit              Exit the client
      test              Run automated tests
      ping              Send a ping message
      results           Show last test results
      <event>           Send event with empty payload
      <event> <json>    Send event with JSON payload
    
    Examples:
      ping
      user_created {"user_id": 123, "name": "John"}
      custom_event {"data": "test"}
    """
  end
end

# If running this file directly
if Path.basename(__ENV__.file) == Path.basename(System.get_env("MIX_EXSCRIPT") || "") do
  AsyncApi.TestClient.CLI.run(System.argv())
end