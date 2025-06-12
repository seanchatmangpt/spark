defmodule RealMemoryProfilingTest do
  use ExUnit.Case, async: false
  
  @moduledoc """
  Jose Valim: REAL memory profiling and leak detection using actual BEAM
  memory management primitives, not fake simulations.
  """
  
  # Jose: Real memory profiling infrastructure
  defmodule MemoryProfiler do
    @moduledoc """
    Actual memory profiling using BEAM introspection, not toy metrics.
    """
    
    def profile_execution(function, opts \\ []) do
      sample_interval = Keyword.get(opts, :sample_interval, 10)  # milliseconds
      duration_limit = Keyword.get(opts, :duration_limit, 30_000)  # 30 seconds max
      
      # Jose: Start actual memory monitoring process
      monitor_pid = spawn_link(fn ->
        memory_monitor_loop(self(), sample_interval, duration_limit)
      end)
      
      # Force garbage collection to get clean baseline
      :erlang.garbage_collect()
      
      initial_memory = :erlang.memory()
      initial_process_count = :erlang.system_info(:process_count)
      start_time = :erlang.monotonic_time(:microsecond)
      
      # Execute the function
      {execution_time, result} = :timer.tc(function)
      
      end_time = :erlang.monotonic_time(:microsecond)
      
      # Stop monitoring
      send(monitor_pid, {:stop, self()})
      
      # Collect memory samples
      memory_samples = receive do
        {:memory_samples, samples} -> samples
      after
        5000 -> []
      end
      
      # Force GC again to see final memory state
      :erlang.garbage_collect()
      final_memory = :erlang.memory()
      final_process_count = :erlang.system_info(:process_count)
      
      %{
        execution_time_microseconds: execution_time,
        wall_clock_time_microseconds: end_time - start_time,
        initial_memory: initial_memory,
        final_memory: final_memory,
        memory_delta: calculate_memory_delta(initial_memory, final_memory),
        initial_process_count: initial_process_count,
        final_process_count: final_process_count,
        process_delta: final_process_count - initial_process_count,
        memory_samples: memory_samples,
        peak_memory: calculate_peak_memory(memory_samples),
        memory_efficiency: calculate_memory_efficiency(memory_samples, execution_time),
        potential_leaks: detect_memory_leaks(memory_samples),
        gc_statistics: collect_gc_statistics(),
        result: result
      }
    end
    
    defp memory_monitor_loop(parent_pid, interval, max_duration) do
      end_time = :erlang.monotonic_time(:millisecond) + max_duration
      samples = collect_memory_samples([], interval, end_time)
      send(parent_pid, {:memory_samples, samples})
    end
    
    defp collect_memory_samples(samples, interval, end_time) do
      receive do
        {:stop, _pid} -> 
          Enum.reverse(samples)
      after
        interval ->
          current_time = :erlang.monotonic_time(:millisecond)
          
          if current_time >= end_time do
            Enum.reverse(samples)
          else
            sample = %{
              timestamp: current_time,
              memory: :erlang.memory(),
              process_count: :erlang.system_info(:process_count),
              run_queue_lengths: :erlang.statistics(:run_queue_lengths),
              gc_count: :erlang.statistics(:garbage_collection),
              io_stats: :erlang.statistics(:io),
              reductions: :erlang.statistics(:reductions)
            }
            
            collect_memory_samples([sample | samples], interval, end_time)
          end
      end
    end
    
    defp calculate_memory_delta(initial, final) do
      memory_types = [:total, :processes, :processes_used, :system, :atom, :atom_used, 
                     :binary, :code, :ets]
      
      Enum.into(memory_types, %{}, fn type ->
        initial_value = Keyword.get(initial, type, 0)
        final_value = Keyword.get(final, type, 0)
        {type, final_value - initial_value}
      end)
    end
    
    defp calculate_peak_memory(samples) when length(samples) == 0, do: 0
    defp calculate_peak_memory(samples) do
      samples
      |> Enum.map(fn sample -> Keyword.get(sample.memory, :total, 0) end)
      |> Enum.max()
    end
    
    defp calculate_memory_efficiency(samples, execution_time) when length(samples) == 0, do: 0.0
    defp calculate_memory_efficiency(samples, execution_time) when execution_time == 0, do: 0.0
    defp calculate_memory_efficiency(samples, execution_time) do
      # Calculate average memory usage over time
      total_memory = samples
      |> Enum.map(fn sample -> Keyword.get(sample.memory, :total, 0) end)
      |> Enum.sum()
      
      avg_memory = total_memory / length(samples)
      
      # Memory efficiency: operations per byte per microsecond
      (execution_time / 1_000_000) / (avg_memory / 1_000_000)
    end
    
    defp detect_memory_leaks(samples) when length(samples) < 10, do: []
    defp detect_memory_leaks(samples) do
      # Jose: Real leak detection using memory growth analysis
      memory_values = Enum.map(samples, fn sample -> 
        Keyword.get(sample.memory, :total, 0) 
      end)
      
      process_counts = Enum.map(samples, & &1.process_count)
      
      memory_trend = analyze_trend(memory_values)
      process_trend = analyze_trend(process_counts)
      
      leaks = []
      
      # Detect sustained memory growth
      leaks = if memory_trend.slope > 1000 and memory_trend.r_squared > 0.7 do
        [:memory_leak | leaks]
      else
        leaks
      end
      
      # Detect process leaks
      leaks = if process_trend.slope > 0.5 and process_trend.r_squared > 0.8 do
        [:process_leak | leaks]
      else
        leaks
      end
      
      # Detect ETS table leaks by checking ETS memory growth
      ets_values = Enum.map(samples, fn sample ->
        Keyword.get(sample.memory, :ets, 0)
      end)
      
      ets_trend = analyze_trend(ets_values)
      
      leaks = if ets_trend.slope > 500 and ets_trend.r_squared > 0.6 do
        [:ets_leak | leaks]
      else
        leaks
      end
      
      leaks
    end
    
    defp analyze_trend(values) when length(values) < 3 do
      %{slope: 0, r_squared: 0, trend: :insufficient_data}
    end
    
    defp analyze_trend(values) do
      # Jose: Linear regression for trend analysis
      n = length(values)
      x_values = Enum.to_list(1..n)
      
      x_mean = Enum.sum(x_values) / n
      y_mean = Enum.sum(values) / n
      
      numerator = Enum.zip(x_values, values)
      |> Enum.map(fn {x, y} -> (x - x_mean) * (y - y_mean) end)
      |> Enum.sum()
      
      denominator = x_values
      |> Enum.map(fn x -> (x - x_mean) * (x - x_mean) end)
      |> Enum.sum()
      
      slope = if denominator == 0, do: 0, else: numerator / denominator
      
      # Calculate R-squared
      ss_res = Enum.zip(x_values, values)
      |> Enum.map(fn {x, y} -> 
        predicted = y_mean + slope * (x - x_mean)
        (y - predicted) * (y - predicted)
      end)
      |> Enum.sum()
      
      ss_tot = values
      |> Enum.map(fn y -> (y - y_mean) * (y - y_mean) end)
      |> Enum.sum()
      
      r_squared = if ss_tot == 0, do: 0, else: 1 - (ss_res / ss_tot)
      
      trend = cond do
        slope > 100 -> :increasing
        slope < -100 -> :decreasing
        true -> :stable
      end
      
      %{
        slope: slope,
        r_squared: max(0, r_squared),
        trend: trend
      }
    end
    
    defp collect_gc_statistics do
      {gc_count, words_reclaimed, 0} = :erlang.statistics(:garbage_collection)
      
      %{
        total_gc_count: gc_count,
        total_words_reclaimed: words_reclaimed,
        scheduler_wall_time: :erlang.statistics(:scheduler_wall_time_all)
      }
    end
  end
  
  # Jose: Real process spawning and management for stress testing
  defmodule ProcessStressTester do
    def spawn_worker_processes(count, work_duration_ms \\ 100) do
      workers = for i <- 1..count do
        spawn_link(fn ->
          worker_loop(i, work_duration_ms)
        end)
      end
      
      {workers, fn -> 
        Enum.each(workers, fn pid ->
          if Process.alive?(pid) do
            send(pid, :stop)
          end
        end)
      end}
    end
    
    defp worker_loop(worker_id, work_duration) do
      # Jose: Do actual work that uses memory and CPU
      work_data = for i <- 1..1000 do
        %{
          id: i,
          worker: worker_id,
          data: :crypto.strong_rand_bytes(100),
          timestamp: :os.system_time(:microsecond)
        }
      end
      
      # Simulate some processing
      Enum.each(work_data, fn item ->
        :crypto.hash(:sha256, item.data)
      end)
      
      receive do
        :stop -> :ok
      after
        work_duration ->
          worker_loop(worker_id, work_duration)
      end
    end
  end
  
  describe "Real Memory Profiling Infrastructure" do
    test "profiles actual memory usage during execution" do
      # Jose: Test with real memory allocation
      profile = MemoryProfiler.profile_execution(fn ->
        # Allocate significant memory
        large_list = for i <- 1..10_000 do
          %{
            id: i,
            data: :crypto.strong_rand_bytes(1000),  # 1KB per item = 10MB total
            metadata: %{
              created: DateTime.utc_now(),
              worker: self(),
              checksum: :crypto.hash(:md5, "item_#{i}")
            }
          }
        end
        
        # Do some work with the data
        Enum.map(large_list, fn item ->
          :crypto.hash(:sha256, item.data)
        end)
      end, sample_interval: 5)
      
      # Verify profiling captured real data
      assert profile.execution_time_microseconds > 0
      assert profile.memory_delta.total > 0
      assert length(profile.memory_samples) > 0
      
      # Should have allocated at least several MB
      assert profile.memory_delta.total > 5_000_000
      
      # Peak memory should be higher than final memory
      assert profile.peak_memory >= Keyword.get(profile.final_memory, :total, 0)
    end
    
    test "detects memory leaks in process spawning" do
      # Jose: Create a function that actually leaks memory
      leaky_function = fn ->
        # Spawn processes that don't terminate properly
        for _i <- 1..50 do
          spawn(fn ->
            # Create some data and never clean it up properly
            :ets.new(:leak_table, [:public, :set])
            data = :crypto.strong_rand_bytes(100_000)  # 100KB per process
            
            # Sleep without proper cleanup
            receive do
              :never_sent -> :ok
            after
              60_000 -> :timeout
            end
          end)
        end
        
        # Give processes time to start
        Process.sleep(100)
      end
      
      profile = MemoryProfiler.profile_execution(leaky_function, sample_interval: 20)
      
      # Should detect process leak
      assert :process_leak in profile.potential_leaks
      
      # Process count should have increased
      assert profile.process_delta > 40
      
      # Memory should have increased significantly
      assert profile.memory_delta.total > 1_000_000
    end
    
    test "handles high-frequency memory monitoring" do
      # Jose: Test profiler with very frequent sampling
      profile = MemoryProfiler.profile_execution(fn ->
        # Create and destroy data repeatedly
        for _round <- 1..100 do
          data = for _i <- 1..1000 do
            :crypto.strong_rand_bytes(100)
          end
          
          # Force some GC activity
          if rem(_round, 10) == 0 do
            :erlang.garbage_collect()
          end
          
          # Use the data so it's not optimized away
          Enum.count(data)
        end
      end, sample_interval: 1)  # Sample every 1ms
      
      # Should have many samples
      assert length(profile.memory_samples) > 50
      
      # Each sample should have complete memory info
      sample = hd(profile.memory_samples)
      assert is_map(sample)
      assert Map.has_key?(sample, :memory)
      assert Map.has_key?(sample, :process_count)
      assert Map.has_key?(sample, :gc_count)
      
      # GC statistics should be captured
      assert is_map(profile.gc_statistics)
      assert profile.gc_statistics.total_gc_count > 0
    end
  end
  
  describe "Real Process and Concurrency Stress Testing" do
    test "stress tests process spawning and cleanup" do
      initial_process_count = :erlang.system_info(:process_count)
      
      profile = MemoryProfiler.profile_execution(fn ->
        {workers, cleanup_fn} = ProcessStressTester.spawn_worker_processes(100, 50)
        
        # Let workers run for a bit
        Process.sleep(200)
        
        # Check that all workers are alive
        alive_count = Enum.count(workers, &Process.alive?/1)
        assert alive_count == 100
        
        # Clean up workers
        cleanup_fn.()
        
        # Wait for cleanup
        Process.sleep(100)
        
        workers
      end)
      
      final_process_count = :erlang.system_info(:process_count)
      
      # Processes should be cleaned up properly (within a small tolerance)
      process_difference = final_process_count - initial_process_count
      assert abs(process_difference) < 10  # Allow for some test processes
      
      # Should not detect process leaks after cleanup
      refute :process_leak in profile.potential_leaks
    end
    
    test "measures scheduler utilization under load" do
      profile = MemoryProfiler.profile_execution(fn ->
        # Create CPU-intensive work across all schedulers
        scheduler_count = :erlang.system_info(:schedulers_online)
        
        tasks = for _i <- 1..scheduler_count do
          Task.async(fn ->
            # CPU-intensive work
            for _j <- 1..100_000 do
              :crypto.hash(:sha256, "heavy_computation_#{:rand.uniform(1000)}")
            end
          end)
        end
        
        Task.await_many(tasks, 10_000)
      end)
      
      # Should have scheduler statistics
      samples_with_scheduler_data = Enum.filter(profile.memory_samples, fn sample ->
        Map.has_key?(sample, :run_queue_lengths)
      end)
      
      assert length(samples_with_scheduler_data) > 0
      
      # Check that schedulers were actually utilized
      sample = hd(samples_with_scheduler_data)
      run_queue_lengths = sample.run_queue_lengths
      
      # Should be a list of scheduler run queue lengths
      assert is_list(run_queue_lengths)
      assert length(run_queue_lengths) > 0
    end
    
    test "detects ETS table leaks" do
      profile = MemoryProfiler.profile_execution(fn ->
        # Create many ETS tables without cleaning them up
        for i <- 1..100 do
          table = :ets.new(String.to_atom("leak_table_#{i}"), [:public, :set])
          
          # Insert data into each table
          for j <- 1..100 do
            :ets.insert(table, {j, :crypto.strong_rand_bytes(1000)})
          end
          
          # Don't delete the table - this is intentional leak
        end
      end)
      
      # Should detect ETS memory leak
      assert :ets_leak in profile.potential_leaks
      
      # ETS memory should have increased significantly
      assert profile.memory_delta.ets > 1_000_000
    end
    
    test "measures memory efficiency of different algorithms" do
      # Jose: Compare memory efficiency of different approaches
      
      # Approach 1: Naive list building
      profile_naive = MemoryProfiler.profile_execution(fn ->
        result = for i <- 1..10_000 do
          processed = i * i
          [processed | []]
        end
        List.flatten(result)
      end)
      
      # Approach 2: Proper list building
      profile_proper = MemoryProfiler.profile_execution(fn ->
        for i <- 1..10_000 do
          i * i
        end
      end)
      
      # Approach 3: Stream-based processing
      profile_stream = MemoryProfiler.profile_execution(fn ->
        1..10_000
        |> Stream.map(fn i -> i * i end)
        |> Enum.to_list()
      end)
      
      # Proper approach should be more memory efficient
      assert profile_proper.memory_efficiency > profile_naive.memory_efficiency
      
      # Stream should have reasonable memory usage
      assert profile_stream.peak_memory < profile_naive.peak_memory
      
      # All should produce same result size
      assert length(profile_naive.result) == 10_000
      assert length(profile_proper.result) == 10_000
      assert length(profile_stream.result) == 10_000
    end
    
    test "monitors garbage collection behavior" do
      profile = MemoryProfiler.profile_execution(fn ->
        # Create allocation patterns that trigger GC
        for round <- 1..50 do
          # Allocate large chunks
          large_data = for _i <- 1..1000 do
            :crypto.strong_rand_bytes(1000)
          end
          
          # Force GC every 10 rounds
          if rem(round, 10) == 0 do
            :erlang.garbage_collect()
          end
          
          # Use data to prevent optimization
          Enum.count(large_data)
        end
      end)
      
      # Should have GC statistics
      gc_stats = profile.gc_statistics
      assert gc_stats.total_gc_count > 0
      assert gc_stats.total_words_reclaimed > 0
      
      # Should have scheduler wall time data
      assert is_list(gc_stats.scheduler_wall_time)
    end
  end
  
  describe "Real Memory Leak Prevention" do
    test "verifies proper cleanup in supervised processes" do
      # Jose: Test that supervised processes clean up memory properly
      
      defmodule TestSupervisor do
        use Supervisor
        
        def start_link(_) do
          Supervisor.start_link(__MODULE__, [], name: __MODULE__)
        end
        
        def init(_) do
          children = [
            %{
              id: :memory_worker,
              start: {TestWorker, :start_link, []},
              restart: :permanent
            }
          ]
          
          Supervisor.init(children, strategy: :one_for_one)
        end
      end
      
      defmodule TestWorker do
        use GenServer
        
        def start_link do
          GenServer.start_link(__MODULE__, [], name: __MODULE__)
        end
        
        def allocate_memory(size) do
          GenServer.call(__MODULE__, {:allocate, size})
        end
        
        def crash do
          GenServer.call(__MODULE__, :crash)
        end
        
        def init(_) do
          {:ok, %{allocated_data: []}}
        end
        
        def handle_call({:allocate, size}, _from, state) do
          new_data = :crypto.strong_rand_bytes(size)
          updated_state = %{state | allocated_data: [new_data | state.allocated_data]}
          {:reply, :ok, updated_state}
        end
        
        def handle_call(:crash, _from, _state) do
          raise "Intentional crash"
        end
      end
      
      # Start supervisor
      {:ok, _sup_pid} = TestSupervisor.start_link([])
      
      initial_memory = :erlang.memory(:total)
      
      # Allocate memory in worker
      TestWorker.allocate_memory(1_000_000)  # 1MB
      TestWorker.allocate_memory(1_000_000)  # Another 1MB
      
      memory_after_allocation = :erlang.memory(:total)
      assert memory_after_allocation > initial_memory
      
      # Crash the worker - supervisor should restart it
      try do
        TestWorker.crash()
      catch
        :exit, _ -> :expected
      end
      
      # Wait for restart
      Process.sleep(100)
      
      # Force GC to clean up orphaned memory
      :erlang.garbage_collect()
      Process.sleep(50)
      
      final_memory = :erlang.memory(:total)
      
      # Memory should be cleaned up (within reasonable tolerance)
      memory_cleanup = memory_after_allocation - final_memory
      assert memory_cleanup > 500_000  # Should have cleaned up at least 500KB
      
      # Worker should be alive again with clean state
      TestWorker.allocate_memory(100)  # Should work
      
      # Cleanup
      Supervisor.stop(TestSupervisor)
    end
  end
end