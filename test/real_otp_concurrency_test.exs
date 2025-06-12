defmodule RealOtpConcurrencyTest do
  use ExUnit.Case, async: false
  
  @moduledoc """
  Jose Valim: REAL OTP testing with actual process lifecycle management,
  fault injection, and proper supervision tree testing.
  """
  
  # Jose: Real GenServer with actual state management and crash recovery
  defmodule TestGenServer do
    use GenServer
    
    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts, name: {:global, __MODULE__})
    end
    
    def increment(pid) do
      GenServer.call(pid, :increment)
    end
    
    def get_state(pid) do
      GenServer.call(pid, :get_state)
    end
    
    def crash(pid) do
      GenServer.call(pid, :crash)
    end
    
    @impl true
    def init(opts) do
      Process.flag(:trap_exit, true)
      initial_value = Keyword.get(opts, :initial_value, 0)
      crash_on = Keyword.get(opts, :crash_on, nil)
      
      # Jose: Real process registration and monitoring
      :telemetry.execute([:genserver, :init], %{initial_value: initial_value}, %{module: __MODULE__})
      
      {:ok, %{value: initial_value, crash_on: crash_on, calls: 0}}
    end
    
    @impl true
    def handle_call(:increment, _from, state) do
      new_calls = state.calls + 1
      new_value = state.value + 1
      
      # Jose: Inject fault based on configuration
      if state.crash_on == new_value do
        raise "Intentional crash at value #{new_value}"
      end
      
      :telemetry.execute([:genserver, :increment], %{value: new_value, calls: new_calls}, %{})
      
      {:reply, new_value, %{state | value: new_value, calls: new_calls}}
    end
    
    @impl true
    def handle_call(:get_state, _from, state) do
      {:reply, state, state}
    end
    
    @impl true
    def handle_call(:crash, _from, _state) do
      # Jose: Intentional crash for supervision testing
      raise "Intentional crash for testing"
    end
    
    @impl true
    def terminate(reason, state) do
      :telemetry.execute([:genserver, :terminate], %{calls: state.calls}, %{reason: reason})
      :ok
    end
  end
  
  # Jose: Real supervision tree with actual restart strategies
  defmodule TestSupervisor do
    use Supervisor
    
    def start_link(opts) do
      Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
    end
    
    def restart_child(child_id) do
      Supervisor.restart_child(__MODULE__, child_id)
    end
    
    @impl true
    def init(opts) do
      restart_strategy = Keyword.get(opts, :restart_strategy, :one_for_one)
      
      children = [
        %{
          id: :worker1,
          start: {TestGenServer, :start_link, [[initial_value: 0, crash_on: 5]]},
          restart: :permanent,
          shutdown: 5000,
          type: :worker
        },
        %{
          id: :worker2,
          start: {TestGenServer, :start_link, [[initial_value: 100]]},
          restart: :temporary,
          shutdown: 5000,
          type: :worker
        }
      ]
      
      Supervisor.init(children, strategy: restart_strategy)
    end
  end
  
  # Jose: Real telemetry event collection
  defmodule TelemetryCollector do
    use GenServer
    
    def start_link(_) do
      GenServer.start_link(__MODULE__, [], name: __MODULE__)
    end
    
    def get_events() do
      GenServer.call(__MODULE__, :get_events)
    end
    
    def clear_events() do
      GenServer.call(__MODULE__, :clear_events)
    end
    
    @impl true
    def init(_) do
      # Jose: Attach to real telemetry events
      :telemetry.attach_many(
        "test-collector",
        [
          [:genserver, :init],
          [:genserver, :increment],
          [:genserver, :terminate]
        ],
        &handle_telemetry_event/4,
        %{}
      )
      
      {:ok, []}
    end
    
    @impl true
    def handle_call(:get_events, _from, events) do
      {:reply, Enum.reverse(events), events}
    end
    
    @impl true
    def handle_call(:clear_events, _from, _events) do
      {:reply, :ok, []}
    end
    
    @impl true
    def handle_info({:telemetry_event, event}, events) do
      {:noreply, [event | events]}
    end
    
    defp handle_telemetry_event(event_name, measurements, metadata, _config) do
      send(__MODULE__, {:telemetry_event, {event_name, measurements, metadata, System.monotonic_time()}})
    end
  end
  
  setup do
    # Jose: Clean process registry before each test
    case GenServer.whereis({:global, TestGenServer}) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end
    
    {:ok, collector} = TelemetryCollector.start_link([])
    {:ok, supervisor} = TestSupervisor.start_link([])
    
    # Jose: Wait for supervisor to fully initialize
    Process.sleep(50)
    
    on_exit(fn ->
      GenServer.stop(collector)
      Supervisor.stop(supervisor)
      TelemetryCollector.clear_events()
    end)
    
    {:ok, supervisor: supervisor, collector: collector}
  end
  
  describe "Real OTP Process Lifecycle Testing" do
    test "processes start and register correctly with telemetry", %{collector: collector} do
      # Jose: Test actual process registration and initialization
      worker1 = :global.whereis_name(TestGenServer)
      assert is_pid(worker1)
      assert Process.alive?(worker1)
      
      # Verify telemetry events were fired
      Process.sleep(10) # Allow telemetry to propagate
      events = TelemetryCollector.get_events()
      
      init_events = Enum.filter(events, fn {event_name, _, _, _} -> 
        event_name == [:genserver, :init] 
      end)
      
      assert length(init_events) >= 1
      
      {_, measurements, _, _} = hd(init_events)
      assert measurements.initial_value == 0
    end
    
    test "concurrent state mutations with process isolation", %{collector: collector} do
      worker = :global.whereis_name(TestGenServer)
      
      # Jose: Real concurrent operations testing actual GenServer serialization
      tasks = for i <- 1..50 do
        Task.async(fn ->
          try do
            TestGenServer.increment(worker)
          catch
            :exit, _ -> :crashed  # Expected when process crashes at value 5
          end
        end)
      end
      
      results = Task.await_many(tasks, 5000)
      
      # Jose: Some operations should succeed, some should fail due to crash
      successful_results = Enum.filter(results, &is_integer/1)
      crashed_results = Enum.filter(results, &(&1 == :crashed))
      
      assert length(successful_results) >= 4  # Should get at least 1,2,3,4
      assert length(crashed_results) >= 1    # Should crash at 5
      
      # Verify telemetry captured the increment operations
      events = TelemetryCollector.get_events()
      increment_events = Enum.filter(events, fn {event_name, _, _, _} -> 
        event_name == [:genserver, :increment] 
      end)
      
      assert length(increment_events) >= 4
    end
    
    test "supervision tree crash recovery with restart strategies" do
      worker = :global.whereis_name(TestGenServer)
      original_pid = worker
      
      # Jose: Force crash and verify supervisor restarts the process
      try do
        TestGenServer.crash(worker)
      catch
        :exit, _ -> :expected_crash
      end
      
      # Jose: Wait for supervisor to restart the process
      Process.sleep(100)
      
      new_worker = :global.whereis_name(TestGenServer)
      
      # Process should be restarted with new PID
      assert new_worker != original_pid
      assert is_pid(new_worker)
      assert Process.alive?(new_worker)
      
      # New process should have reset state
      state = TestGenServer.get_state(new_worker)
      assert state.value == 0  # Reset to initial value
      assert state.calls == 0  # Reset call counter
    end
    
    test "memory pressure under high concurrent load" do
      worker = :global.whereis_name(TestGenServer)
      
      initial_memory = :erlang.memory(:total)
      
      # Jose: Create actual memory pressure with real process spawning
      stress_tasks = for _i <- 1..1000 do
        Task.async(fn ->
          # Create short-lived processes that do real work
          pid = spawn(fn ->
            # Do some actual work that uses memory
            list = Enum.to_list(1..1000)
            Enum.map(list, &(&1 * &1))
            receive do
              :stop -> :ok
            after 
              100 -> :timeout
            end
          end)
          
          send(pid, :stop)
          pid
        end)
      end
      
      _pids = Task.await_many(stress_tasks, 10_000)
      
      # Force garbage collection
      :erlang.garbage_collect()
      Process.sleep(50)
      
      final_memory = :erlang.memory(:total)
      memory_increase = final_memory - initial_memory
      
      # Jose: Memory increase should be reasonable (less than 50MB)
      assert memory_increase < 50_000_000
      
      # Original worker should still be alive
      assert Process.alive?(worker)
      assert TestGenServer.increment(worker) == 1
    end
    
    test "process message queue overflow handling" do
      worker = :global.whereis_name(TestGenServer)
      
      # Jose: Flood the process with messages to test queue behavior
      flood_tasks = for _i <- 1..10_000 do
        Task.async(fn ->
          try do
            TestGenServer.increment(worker)
          catch
            :exit, reason -> {:error, reason}
          end
        end)
      end
      
      results = Task.await_many(flood_tasks, 30_000)
      
      successful = Enum.count(results, &is_integer/1)
      errors = Enum.count(results, &match?({:error, _}, &1))
      
      # Most should succeed, some might timeout or error
      assert successful > 5000
      assert successful + errors == 10_000
      
      # Process should still be responsive after flood
      assert is_integer(TestGenServer.increment(worker))
    end
  end
  
  describe "Real Telemetry Integration Testing" do
    test "telemetry events capture actual process metrics", %{collector: collector} do
      worker = :global.whereis_name(TestGenServer)
      
      TelemetryCollector.clear_events()
      
      # Perform operations
      TestGenServer.increment(worker)
      TestGenServer.increment(worker)
      TestGenServer.increment(worker)
      
      Process.sleep(20) # Allow telemetry to propagate
      
      events = TelemetryCollector.get_events()
      increment_events = Enum.filter(events, fn {event_name, _, _, _} -> 
        event_name == [:genserver, :increment] 
      end)
      
      assert length(increment_events) == 3
      
      # Verify measurements include actual values
      values = Enum.map(increment_events, fn {_, measurements, _, _} -> 
        measurements.value 
      end)
      
      assert values == [1, 2, 3]
      
      # Verify call counts are tracked
      call_counts = Enum.map(increment_events, fn {_, measurements, _, _} -> 
        measurements.calls 
      end)
      
      assert call_counts == [1, 2, 3]
    end
    
    test "telemetry captures process termination events" do
      worker = :global.whereis_name(TestGenServer)
      
      TelemetryCollector.clear_events()
      
      # Force termination
      GenServer.stop(worker, :normal)
      
      Process.sleep(50) # Allow telemetry to propagate
      
      events = TelemetryCollector.get_events()
      terminate_events = Enum.filter(events, fn {event_name, _, _, _} -> 
        event_name == [:genserver, :terminate] 
      end)
      
      assert length(terminate_events) >= 1
      
      {_, measurements, metadata, _} = hd(terminate_events)
      assert measurements.calls >= 0
      assert metadata.reason == :normal
    end
  end
end