defmodule MockAsh do
  @moduledoc "Mock Ash modules for testing without Ash dependency"
  
  defmodule Resource do
    defmacro __using__(_opts) do
      quote do
        @behaviour MockAsh.Resource
        
        def __ash_resource__?, do: true
        def spark_dsl_config, do: %{}
        def spark_is(_), do: true
      end
    end
    
    @callback __ash_resource__? :: boolean()
  end
  
  defmodule Domain do
    defmacro __using__(_opts) do
      quote do
        @behaviour MockAsh.Domain
        
        def __ash_domain__?, do: true
      end
    end
    
    @callback __ash_domain__? :: boolean()
  end
  
  defmodule Reactor do
    defmacro __using__(_opts) do
      quote do
        def __reactor__?, do: true
      end
    end
  end
  
  defmodule DataLayer do
    defmodule Ets do
      def __ash_data_layer__?, do: true
    end
  end
end

defmodule AshPostgres do
  defmodule Repo do
    defmacro __using__(_opts) do
      quote do
        def __adapter__, do: Ecto.Adapters.Postgres
        def config, do: []
        def child_spec(_), do: %{id: __MODULE__, start: {__MODULE__, :start_link, []}}
        def start_link(_opts \\ []), do: {:ok, self()}
      end
    end
  end
end

# Add aliases to make tests work
Code.ensure_loaded!(MockAsh.Resource)
Code.ensure_loaded!(MockAsh.Domain)
Code.ensure_loaded!(MockAsh.Reactor)

# Create module aliases for tests
Module.create(Ash.Resource, quote do
  defdelegate __using__(opts), to: MockAsh.Resource
end, Macro.Env.location(__ENV__))

Module.create(Ash.Domain, quote do
  defdelegate __using__(opts), to: MockAsh.Domain
end, Macro.Env.location(__ENV__))

Module.create(Ash.Reactor, quote do
  defdelegate __using__(opts), to: MockAsh.Reactor
end, Macro.Env.location(__ENV__))