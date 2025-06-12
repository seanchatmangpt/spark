defmodule SimpleDatabaseDsl do
  @moduledoc """
  Simplified database DSL that follows real Spark patterns.
  """
  
  defmodule Table do
    @moduledoc "Represents a database table"
    defstruct [:name, :primary_key, :timestamps]
  end
  
  @table %Spark.Dsl.Entity{
    name: :table,
    target: Table,
    args: [:name],
    schema: [
      name: [type: :atom, required: true],
      primary_key: [type: :atom, default: :id],
      timestamps: [type: :boolean, default: true]
    ]
  }
  
  @tables %Spark.Dsl.Section{
    name: :tables,
    entities: [@table]
  }
  
  defmodule AddTableInfo do
    @moduledoc "Transformer that adds table metadata"
    use Spark.Dsl.Transformer
    
    def transform(dsl_state) do
      tables = Spark.Dsl.Transformer.get_entities(dsl_state, [:tables])
      
      dsl_state = Enum.reduce(tables, dsl_state, fn table, acc ->
        updated_table = %{table | 
          primary_key: table.primary_key || :id,
          timestamps: table.timestamps != false
        }
        Spark.Dsl.Transformer.replace_entity(acc, [:tables], updated_table, fn entity ->
          entity.name == table.name
        end)
      end)
      {:ok, dsl_state}
    end
  end
  
  defmodule ValidateTables do
    @moduledoc "Verifier that validates table configuration"
    use Spark.Dsl.Verifier
    
    def verify(dsl_state) do
      tables = Spark.Dsl.Transformer.get_entities(dsl_state, [:tables])
      
      if Enum.empty?(tables) do
        {:error,
          Spark.Error.DslError.exception(
            message: "At least one table must be defined",
            path: [:tables]
          )}
      else
        :ok
      end
    end
  end
  
  use Spark.Dsl.Extension,
    sections: [@tables],
    transformers: [AddTableInfo],
    verifiers: [ValidateTables]

  use Spark.Dsl, default_extensions: [extensions: [__MODULE__]]
end

defmodule SimpleDatabaseDsl.Info do
  @moduledoc """
  Info module for SimpleDatabaseDsl.
  """
  
  use Spark.InfoGenerator,
    extension: SimpleDatabaseDsl,
    sections: [:tables]
end