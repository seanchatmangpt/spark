defmodule AsyncApi.Config do
  @moduledoc """
  Configuration options for AsyncAPI DSL.
  
  This module provides configuration utilities and default settings for the AsyncAPI DSL.
  Configuration can be set in your application's config files.
  
  ## Configuration Options
  
      config :async_api_dsl,
        default_export_formats: [:json, :yaml],
        strict_validation: true,
        generate_examples: true,
        schema_validation: :strict
  
  ## Example Configuration
  
      # config/config.exs
      config :async_api_dsl,
        default_export_formats: [:json],
        strict_validation: false,
        output_directory: "priv/static/api-specs"
  """

  @doc """
  Get configuration value with fallback.
  
  ## Examples
  
      AsyncApi.Config.get(:strict_validation, true)
      AsyncApi.Config.get(:output_directory, "spec/")
  """
  def get(key, default \\ nil) do
    Application.get_env(:async_api_dsl, key, default)
  end

  @doc """
  Default export formats.
  
  Returns the list of default export formats to use when no format is specified.
  
  ## Examples
  
      AsyncApi.Config.default_export_formats()
      # => [:json, :yaml]
  """
  def default_export_formats do
    get(:default_export_formats, [:json, :yaml])
  end

  @doc """
  Enable strict validation mode.
  
  When enabled, additional validation checks are performed during compilation.
  
  ## Examples
  
      if AsyncApi.Config.strict_validation?() do
        # Perform additional validation
      end
  """
  def strict_validation? do
    get(:strict_validation, true)
  end

  @doc """
  Default output directory for generated specifications.
  
  ## Examples
  
      AsyncApi.Config.output_directory()
      # => "priv/static/api-specs"
  """
  def output_directory do
    get(:output_directory, "spec/")
  end

  @doc """
  Whether to generate examples in the specification.
  
  ## Examples
  
      AsyncApi.Config.generate_examples?()
      # => true
  """
  def generate_examples? do
    get(:generate_examples, true)
  end

  @doc """
  Schema validation level.
  
  Can be `:strict`, `:moderate`, or `:lenient`.
  
  ## Examples
  
      AsyncApi.Config.schema_validation()
      # => :strict
  """
  def schema_validation do
    get(:schema_validation, :strict)
  end

  @doc """
  Whether to include development metadata in specifications.
  
  ## Examples
  
      AsyncApi.Config.include_dev_metadata?()
      # => false
  """
  def include_dev_metadata? do
    get(:include_dev_metadata, Mix.env() == :dev)
  end

  @doc """
  Pretty print JSON output by default.
  
  ## Examples
  
      AsyncApi.Config.pretty_print?()
      # => true
  """
  def pretty_print? do
    get(:pretty_print, true)
  end
end