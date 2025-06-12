# Spark DSL Infinite Agentic Loop - Makefile
# Convenient commands for running the agentic loop system

.PHONY: help auto continuous target clean setup test docs

# Default target
help:
	@echo ""
	@echo "╔═══════════════════════════════════════════════════════════════╗"
	@echo "║              🚀 SPARK DSL INFINITE AGENTIC LOOP 🚀            ║"
	@echo "║                                                               ║"
	@echo "║  Autonomous Domain-Specific Language Generation System        ║"
	@echo "╚═══════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "Available commands:"
	@echo ""
	@echo "  make auto          Run one complete agentic cycle"
	@echo "  make continuous    Run continuous agentic loops"
	@echo "  make target DOM    Run targeted cycle for specific domain"
	@echo "  make setup         Setup development environment"
	@echo "  make test          Run test suite"
	@echo "  make docs          Generate documentation"
	@echo "  make clean         Clean generated files"
	@echo ""
	@echo "Domain examples:"
	@echo "  make target DOM=multi_cloud_infrastructure"
	@echo "  make target DOM=ai_enhanced_testing"
	@echo "  make target DOM=compliance_framework"
	@echo ""

# Run single agentic loop cycle
auto:
	@echo "🚀 Running single agentic loop cycle..."
	./auto

# Run continuous agentic loops
continuous:
	@echo "🔄 Starting continuous agentic loops..."
	./auto --continuous

# Run targeted cycle for specific domain
target:
ifndef DOM
	@echo "❌ Error: Domain not specified. Use: make target DOM=domain_name"
	@exit 1
endif
	@echo "🎯 Running targeted cycle for domain: $(DOM)"
	./auto --target $(DOM)

# Setup development environment
setup:
	@echo "🔧 Setting up development environment..."
	mix deps.get
	mix compile
	@echo "✅ Setup complete!"

# Run test suite
test:
	@echo "🧪 Running test suite..."
	mix test
	mix credo --strict
	mix dialyzer

# Generate documentation
docs:
	@echo "📚 Generating documentation..."
	mix docs
	@echo "✅ Documentation generated in doc/"

# Clean generated files
clean:
	@echo "🧹 Cleaning generated files..."
	rm -rf _build/
	rm -rf deps/
	rm -rf doc/
	rm -rf lib/multi_cloud_dsl/
	rm -rf lib/testing_dsl/
	rm -rf lib/compliance_dsl/
	rm -rf results/
	@echo "✅ Cleanup complete!"

# Development helpers
dev-setup: setup
	@echo "🛠️ Setting up development tools..."
	mix archive.install hex ex_doc --force
	mix archive.install hex credo --force
	mix archive.install hex dialyxir --force

# Quality checks
quality:
	@echo "🔍 Running quality checks..."
	mix format --check-formatted
	mix credo --strict
	mix dialyzer
	mix test --cover

# Install system dependencies (macOS)
install-deps-mac:
	@echo "🍎 Installing macOS dependencies..."
	brew install elixir
	@echo "✅ Dependencies installed!"

# Install system dependencies (Ubuntu/Debian)
install-deps-ubuntu:
	@echo "🐧 Installing Ubuntu/Debian dependencies..."
	sudo apt update
	sudo apt install elixir erlang-dev erlang-xmerl
	@echo "✅ Dependencies installed!"

# Version information
version:
	@echo "Spark DSL Infinite Agentic Loop v2.0.0"
	@echo "Elixir version: $$(elixir --version | head -1)"
	@echo "Erlang version: $$(erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell)"

# Quick start for new users
quickstart: setup auto
	@echo ""
	@echo "🎉 Quick start complete!"
	@echo "Your first agentic cycle has finished."
	@echo "Check the results/ directory for generated DSL code."
	@echo ""
	@echo "Next steps:"
	@echo "  make continuous    # Run continuous loops"
	@echo "  make target DOM=multi_cloud_infrastructure  # Focus on specific domain"