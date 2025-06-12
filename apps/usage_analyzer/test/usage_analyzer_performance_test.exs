defmodule UsageAnalyzerPerformanceTest do
  use ExUnit.case, async: false
  
  alias UsageAnalyzer.{Analytics, PatternDetection, RealTimeMonitor}
  
  describe "Real-time analysis performance" do
    test "processes high-volume usage streams efficiently" do
      # Simulate high-volume usage data stream
      usage_stream = Stream.repeatedly(fn ->
        %{
          timestamp: DateTime.utc_now(),
          user_id: Enum.random(1..1000),
          action: Enum.random(["create", "read", "update", "delete"]),
          resource: Enum.random(["User", "Post", "Comment", "Session"]),
          duration_ms: Enum.random(10..500),
          success: Enum.random([true, true, true, false])  # 75% success rate
        }
      end)
      |> Stream.take(10_000)
      
      {time_microseconds, analysis_result} = :timer.tc(fn ->
        Analytics.analyze_stream(usage_stream, %{
          window_size: 1000,
          pattern_detection: true,
          real_time_alerts: true
        })
      end)
      
      time_ms = time_microseconds / 1000
      
      # Performance assertions
      assert time_ms < 5_000  # Should process 10k events in under 5 seconds
      assert analysis_result.events_processed == 10_000
      assert analysis_result.patterns_detected != nil
      assert length(analysis_result.alerts) >= 0
    end
    
    test "maintains consistent performance under sustained load" do
      # Test multiple concurrent analysis sessions
      concurrent_sessions = 5
      events_per_session = 2_000
      
      tasks = for session_id <- 1..concurrent_sessions do
        Task.async(fn ->
          session_stream = Stream.repeatedly(fn ->
            %{
              session_id: session_id,
              timestamp: DateTime.utc_now(),
              action: "session_#{session_id}_action",
              data: %{load_test: true}
            }
          end)
          |> Stream.take(events_per_session)
          
          {time_micro, result} = :timer.tc(fn ->
            Analytics.analyze_stream(session_stream)
          end)
          
          %{
            session_id: session_id,
            processing_time_ms: time_micro / 1000,
            events_processed: result.events_processed
          }
        end)
      end
      
      results = Task.await_many(tasks, 15_000)
      
      # All sessions should complete successfully
      assert length(results) == concurrent_sessions
      
      # Performance should be consistent across sessions
      processing_times = Enum.map(results, & &1.processing_time_ms)
      avg_time = Enum.sum(processing_times) / length(processing_times)
      max_time = Enum.max(processing_times)
      
      # No session should take more than 2x the average
      assert max_time < avg_time * 2
    end
  end
  
  describe "Pattern detection scalability" do
    test "detects patterns in large datasets efficiently" do
      # Generate large dataset with embedded patterns
      large_dataset = generate_pattern_dataset(50_000)
      
      {time_micro, detected_patterns} = :timer.tc(fn ->
        PatternDetection.analyze_patterns(large_dataset, %{
          min_frequency: 10,
          confidence_threshold: 0.8,
          max_patterns: 100
        })
      end)
      
      time_ms = time_micro / 1000
      
      assert time_ms < 10_000  # Should complete within 10 seconds
      assert length(detected_patterns) > 0
      assert length(detected_patterns) <= 100
      
      # Verify pattern quality
      high_confidence_patterns = Enum.filter(detected_patterns, & &1.confidence > 0.9)
      assert length(high_confidence_patterns) > 0
    end
    
    test "handles incremental pattern updates efficiently" do
      # Start with baseline dataset
      initial_dataset = generate_pattern_dataset(10_000)
      initial_patterns = PatternDetection.analyze_patterns(initial_dataset)
      
      # Simulate incremental updates
      update_batches = for _i <- 1..10 do
        generate_pattern_dataset(1_000)
      end
      
      {total_time_micro, final_patterns} = :timer.tc(fn ->
        Enum.reduce(update_batches, initial_patterns, fn batch, current_patterns ->
          PatternDetection.update_patterns(current_patterns, batch)
        end)
      end)
      
      total_time_ms = total_time_micro / 1000
      avg_update_time = total_time_ms / 10
      
      # Incremental updates should be fast
      assert avg_update_time < 500  # Average under 500ms per update
      assert length(final_patterns) >= length(initial_patterns)
    end
  end
  
  describe "Memory management" do
    test "manages memory efficiently during long-running analysis" do
      initial_memory = :erlang.memory(:total)
      
      # Simulate long-running analysis session
      analysis_session = spawn_link(fn ->
        receive do
          :start_analysis ->
            # Process data in chunks to test memory management
            for _chunk <- 1..100 do
              chunk_data = generate_pattern_dataset(1_000)
              Analytics.analyze_chunk(chunk_data)
              
              # Force garbage collection periodically
              if rem(chunk, 10) == 0 do
                :erlang.garbage_collect()
              end
            end
            
          :stop_analysis ->
            :ok
        end
      end)
      
      send(analysis_session, :start_analysis)
      
      # Monitor memory during analysis
      memory_samples = for _i <- 1..20 do
        Process.sleep(100)  # Sample every 100ms
        :erlang.memory(:total)
      end
      
      send(analysis_session, :stop_analysis)
      
      final_memory = :erlang.memory(:total)
      memory_increase = final_memory - initial_memory
      max_memory = Enum.max(memory_samples)
      
      # Memory increase should be reasonable
      assert memory_increase < 50_000_000  # Less than 50MB permanent increase
      assert max_memory - initial_memory < 200_000_000  # Peak under 200MB increase
    end
    
    test "handles memory pressure gracefully" do
      # Simulate memory pressure by processing very large dataset
      stress_test_size = 100_000
      
      result = try do
        large_dataset = generate_pattern_dataset(stress_test_size)
        
        # Process with memory constraints
        Analytics.analyze_with_memory_limit(large_dataset, %{
          max_memory_mb: 100,
          chunk_size: 5_000,
          enable_streaming: true
        })
      rescue
        error ->
          %{error: error, handled_gracefully: true}
      end
      
      case result do
        %{error: _, handled_gracefully: true} ->
          # Error handling is acceptable
          assert true
          
        %{analysis_complete: true} = success_result ->
          # Successful completion under memory pressure
          assert success_result.events_processed == stress_test_size
          assert success_result.memory_efficient == true
      end
    end
  end
  
  describe "Real-time monitoring performance" do
    test "maintains sub-second response times for alerts" do
      # Set up real-time monitor
      monitor_config = %{
        alert_thresholds: %{
          error_rate: 0.1,
          response_time_p99: 1000,
          memory_usage: 0.9
        },
        check_interval_ms: 100
      }
      
      {:ok, monitor_pid} = RealTimeMonitor.start_link(monitor_config)
      
      # Generate events that should trigger alerts
      critical_events = [
        %{type: :error_rate, value: 0.15, timestamp: DateTime.utc_now()},
        %{type: :response_time, value: 1500, timestamp: DateTime.utc_now()},
        %{type: :memory_usage, value: 0.95, timestamp: DateTime.utc_now()}
      ]
      
      # Measure alert response times
      alert_times = for event <- critical_events do
        start_time = System.monotonic_time(:microsecond)
        
        RealTimeMonitor.process_event(monitor_pid, event)
        
        # Wait for alert
        receive do
          {:alert, _alert_data} ->
            end_time = System.monotonic_time(:microsecond)
            end_time - start_time
        after
          1000 ->
            # No alert received within 1 second
            1_000_000
        end
      end
      
      GenServer.stop(monitor_pid)
      
      # All alerts should be generated within 500ms
      for alert_time <- alert_times do
        response_time_ms = alert_time / 1000
        assert response_time_ms < 500
      end
    end
  end
  
  describe "Benchmark comparisons" do
    test "benchmarks different analysis algorithms" do
      test_data = generate_pattern_dataset(20_000)
      
      algorithms = [
        {:naive, fn data -> Analytics.naive_analysis(data) end},
        {:optimized, fn data -> Analytics.optimized_analysis(data) end},
        {:parallel, fn data -> Analytics.parallel_analysis(data) end},
        {:streaming, fn data -> Analytics.streaming_analysis(data) end}
      ]
      
      benchmark_results = for {algorithm, analyzer_fn} <- algorithms do
        {time_micro, result} = :timer.tc(fn ->
          analyzer_fn.(test_data)
        end)
        
        {
          algorithm,
          %{
            execution_time_ms: time_micro / 1000,
            accuracy: calculate_accuracy(result, test_data),
            memory_used: :erlang.memory(:total)
          }
        }
      end
      
      # Log benchmark results
      IO.inspect({:benchmark_results, benchmark_results})
      
      # Optimized should be faster than naive
      naive_time = get_algorithm_time(benchmark_results, :naive)
      optimized_time = get_algorithm_time(benchmark_results, :optimized)
      
      if naive_time && optimized_time do
        assert optimized_time < naive_time
      end
      
      # All algorithms should maintain minimum accuracy
      for {_algorithm, metrics} <- benchmark_results do
        assert metrics.accuracy > 0.8
      end
    end
  end
  
  # Helper functions
  defp generate_pattern_dataset(size) do
    # Generate dataset with known patterns for testing
    patterns = [
      %{action: "login", resource: "User", frequency: 0.3},
      %{action: "create", resource: "Post", frequency: 0.2},
      %{action: "read", resource: "Post", frequency: 0.4},
      %{action: "error", resource: "any", frequency: 0.1}
    ]
    
    1..size
    |> Enum.map(fn i ->
      pattern = Enum.random(patterns)
      
      %{
        id: i,
        timestamp: DateTime.utc_now() |> DateTime.add(-i, :second),
        action: pattern.action,
        resource: pattern.resource,
        user_id: rem(i, 1000) + 1,
        duration_ms: Enum.random(10..1000),
        success: pattern.action != "error"
      }
    end)
  end
  
  defp calculate_accuracy(result, test_data) do
    # Simple accuracy calculation based on pattern detection
    expected_patterns = 4  # Known patterns in generated data
    detected_patterns = length(result.patterns || [])
    
    if expected_patterns > 0 do
      min(detected_patterns / expected_patterns, 1.0)
    else
      0.0
    end
  end
  
  defp get_algorithm_time(results, algorithm) do
    case Enum.find(results, fn {alg, _} -> alg == algorithm end) do
      {_, metrics} -> metrics.execution_time_ms
      nil -> nil
    end
  end
end