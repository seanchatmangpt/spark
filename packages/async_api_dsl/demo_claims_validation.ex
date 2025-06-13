#!/usr/bin/env elixir

# Demo: Claims Validation Results
IO.puts("=== 🔍 AsyncAPI Claims Validation Results ===")
IO.puts("")

# Simulate test results
test_results = %{
  authentication: %{
    category: "Authentication",
    passed: 3,
    total: 3,
    tests: [
      %{test: "JWT Token Validation", status: :passed},
      %{test: "API Key Validation", status: :passed},
      %{test: "OAuth Token Validation", status: :passed}
    ]
  },
  message_schema: %{
    category: "Message Schema",
    passed: 3,
    total: 4,
    tests: [
      %{test: "Valid Chat Message", status: :passed},
      %{test: "Missing Required Field", status: :failed},
      %{test: "Wrong Data Type", status: :passed},
      %{test: "Extra Fields", status: :passed}
    ]
  },
  performance: %{
    category: "Performance",
    passed: 2,
    total: 2,
    tests: [
      %{test: "Message Throughput", status: :passed},
      %{test: "Response Latency", status: :passed}
    ]
  },
  security: %{
    category: "Security",
    passed: 3,
    total: 3,
    tests: [
      %{test: "WSS/TLS Encryption", status: :passed},
      %{test: "Rate Limiting", status: :passed},
      %{test: "Input Sanitization", status: :passed}
    ]
  }
}

IO.puts("🔐 Testing Authentication Claims...")
IO.puts("📋 Testing Message Schema Claims...")
IO.puts("⚡ Testing Performance Claims...")
IO.puts("🛡️  Testing Security Claims...")
IO.puts("")

IO.puts("=== 📊 Validation Summary ===")

total_tests = 0
total_passed = 0

Enum.each(test_results, fn {_category, result} ->
  passed = result.passed
  total = result.total
  success_rate = if total > 0, do: (passed / total) * 100, else: 0
  
  status_icon = case success_rate do
    100.0 -> "✅"
    rate when rate >= 80 -> "⚠️"
    _ -> "❌"
  end
  
  IO.puts("#{status_icon} #{result.category}: #{passed}/#{total} (#{Float.round(success_rate/1, 1)}%)")
  
  # Show failed tests
  failed_tests = Enum.filter(result.tests, &(&1.status == :failed))
  if not Enum.empty?(failed_tests) do
    Enum.each(failed_tests, fn test ->
      IO.puts("  ❌ #{test.test}")
    end)
  end
  
  total_tests = total_tests + total
  total_passed = total_passed + passed
end)

overall_success_rate = if total_tests > 0, do: (total_passed / total_tests) * 100, else: 0

IO.puts("")
IO.puts("🎯 Overall: #{total_passed}/#{total_tests} (#{Float.round(overall_success_rate/1, 1)}%)")

cond do
  overall_success_rate == 100 ->
    IO.puts("🎉 Perfect! All claims validated successfully")
  overall_success_rate >= 90 ->
    IO.puts("✅ Excellent validation results")
  overall_success_rate >= 70 ->
    IO.puts("⚠️  Good results, some improvements needed")
  true ->
    IO.puts("❌ Significant validation issues found")
end

IO.puts("")
IO.puts("=== 💡 Key Claims Validated ===")
IO.puts("• 🔐 Authentication: JWT, API keys, OAuth tokens")
IO.puts("• 📋 Message Schemas: Payload validation against AsyncAPI specs")
IO.puts("• ⚡ Performance: Throughput and latency claims")
IO.puts("• 🛡️  Security: Encryption, rate limiting, input sanitization")
IO.puts("")
IO.puts("✅ Claims validation complete!")