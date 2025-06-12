defmodule TestInfoDebug do
  @moduledoc false
  
  # Simple test to understand what functions InfoGenerator creates
  defmodule SimpleDsl do
    defmodule Entity do
      defstruct [:name]
    end

    @entity %Spark.Dsl.Entity{
      name: :entity,
      args: [:name],
      target: Entity,
      schema: [
        name: [type: :atom, required: true]
      ]
    }

    @section %Spark.Dsl.Section{
      name: :section,
      entities: [@entity]
    }

    use Spark.Dsl.Extension, sections: [@section]
  end

  defmodule SimpleInfo do
    use Spark.InfoGenerator,
      extension: SimpleDsl,
      sections: [:section]
  end

  defmodule TestModule do
    use Spark.Dsl, default_extensions: [extensions: [SimpleDsl]]

    section do
      entity :test_entity
    end
  end

  def test_generated_functions do
    # See what functions are available
    functions = SimpleInfo.__info__(:functions)
    IO.inspect(functions, label: "Generated functions")
    
    # Test getting entities
    entities = SimpleInfo.section_entity(TestModule)
    IO.inspect(entities, label: "Entities")
  end
end

# Run the test
TestInfoDebug.test_generated_functions()