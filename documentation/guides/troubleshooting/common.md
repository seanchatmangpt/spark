# Common Issues and Solutions

> **Quick fixes for the most frequent Spark DSL problems** - Get back to building in minutes

## 🚨 Critical Issues

### **"Module not found" Errors**

#### **Problem**
```elixir
** (CompileError) module MyApp.Validator.Dsl not found
```

#### **Solution**
1. **Check dependencies** - Ensure Spark is in your `mix.exs`:
   ```elixir
   defp deps do
     [
       {:spark, "~> 2.2.65"},
       {:igniter, "~> 0.6.6", only: [:dev]}
     ]
   end
   ```

2. **Install dependencies**:
   ```bash
   mix deps.get
   mix deps.compile
   ```

3. **Restart your editor** - Sometimes editors cache module information

4. **Check file structure** - Ensure your DSL module is in the correct location:
   ```
   lib/my_app/validator/dsl.ex  # MyApp.Validator.Dsl
   lib/my_app/validator.ex      # MyApp.Validator
   ```

### **"Invalid DSL syntax" Errors**

#### **Problem**
```elixir
** (Spark.Error.DslError) Invalid DSL syntax at [:fields, :field, :name]
```

#### **Solution**
1. **Check entity definition** - Ensure your entity matches the schema:
   ```elixir
   @field %Spark.Dsl.Entity{
     name: :field,
     args: [:name, :type],  # Required arguments
     schema: [
       name: [type: :atom, required: true],
       type: [type: {:one_of, [:string, :integer]}, required: true]
     ]
   }
   ```

2. **Verify usage** - Ensure you're using the DSL correctly:
   ```elixir
   # Correct
   field :name, :string
   
   # Incorrect - missing required argument
   field :name
   ```

3. **Check types** - Ensure values match the expected types:
   ```elixir
   # Correct
   field :name, :string, required: true
   
   # Incorrect - boolean expected
   field :name, :string, required: "true"
   ```

### **"Transformer not found" Errors**

#### **Problem**
```elixir
** (CompileError) module MyApp.Transformers.AddDefaults not found
```

#### **Solution**
1. **Create the transformer**:
   ```bash
   mix spark.gen.transformer MyApp.Transformers.AddDefaults \
     --dsl MyApp.Validator \
     --examples
   ```

2. **Check module name** - Ensure the transformer module exists and is correctly named

3. **Verify dependencies** - Ensure the transformer is compiled before the DSL

## 🔧 DSL Definition Issues

### **Schema Validation Errors**

#### **Problem**
```elixir
** (Spark.Error.DslError) Invalid value for :type: expected one of [:string, :integer], got :float
```

#### **Solution**
1. **Check schema definition** - Ensure your schema includes all valid types:
   ```elixir
   schema: [
     type: [
       type: {:one_of, [:string, :integer, :float]},  # Add :float
       required: true
     ]
   ]
   ```

2. **Use custom validation** for complex types:
   ```elixir
   schema: [
     type: [
       type: {:custom, __MODULE__, :validate_type, []},
       required: true
     ]
   ]

   def validate_type(value) when value in [:string, :integer, :float], do: {:ok, value}
   def validate_type(value), do: {:error, "Invalid type: #{inspect(value)}"}
   ```

### **Missing Required Arguments**

#### **Problem**
```elixir
** (Spark.Error.DslError) Missing required argument :name for entity :field
```

#### **Solution**
1. **Check entity definition** - Ensure `args` includes all required arguments:
   ```elixir
   @field %Spark.Dsl.Entity{
     name: :field,
     args: [:name, :type],  # Both are required
     schema: [
       name: [type: :atom, required: true],
       type: [type: :atom, required: true]
     ]
   }
   ```

2. **Update usage** - Provide all required arguments:
   ```elixir
   # Correct
   field :name, :string
   
   # Incorrect - missing :type
   field :name
   ```

### **Invalid Entity Structure**

#### **Problem**
```elixir
** (Spark.Error.DslError) Invalid entity structure: expected :name, got :field_name
```

#### **Solution**
1. **Check entity name** - Ensure the entity name matches the DSL keyword:
   ```elixir
   @field %Spark.Dsl.Entity{
     name: :field,  # This becomes the DSL keyword
     # ...
   }
   ```

2. **Use consistent naming** - The entity name should match your DSL usage:
   ```elixir
   # DSL usage
   field :name, :string
   
   # Entity definition
   @field %Spark.Dsl.Entity{name: :field, ...}
   ```

## 🔄 Runtime Issues

### **Info Module Not Found**

#### **Problem**
```elixir
** (UndefinedFunctionError) function MyApp.Validator.Info.fields/1 is undefined
```

#### **Solution**
1. **Generate info module**:
   ```bash
   mix spark.gen.info MyApp.Validator.Info \
     --extension MyApp.Validator.Dsl \
     --sections fields \
     --examples
   ```

2. **Check module name** - Ensure the info module name matches your DSL:
   ```elixir
   # DSL module
   defmodule MyApp.Validator do
     use Spark.Dsl, default_extensions: [extensions: [MyApp.Validator.Dsl]]
   end
   
   # Info module
   defmodule MyApp.Validator.Info do
     use Spark.InfoGenerator, extension: MyApp.Validator.Dsl
   end
   ```

### **Transformer Execution Errors**

#### **Problem**
```elixir
** (FunctionClauseError) no function clause matching in MyApp.Transformers.AddDefaults.transform/1
```

#### **Solution**
1. **Check transformer signature** - Ensure it matches the expected interface:
   ```elixir
   defmodule MyApp.Transformers.AddDefaults do
     use Spark.Dsl.Transformer

     def transform(dsl_state) do
       # Must return {:ok, dsl_state} or {:error, reason}
       {:ok, dsl_state}
     end
   end
   ```

2. **Handle all cases** - Ensure your transformer handles all possible inputs:
   ```elixir
   def transform(dsl_state) do
     case has_section?(dsl_state, :fields) do
       true -> {:ok, add_defaults(dsl_state)}
       false -> {:ok, dsl_state}  # Handle missing section
     end
   end
   ```

### **Verifier Validation Errors**

#### **Problem**
```elixir
** (Spark.Error.DslError) Verification failed: Invalid field configuration
```

#### **Solution**
1. **Check verifier logic** - Ensure your verifier returns the correct format:
   ```elixir
   defmodule MyApp.Verifiers.ValidateFields do
     use Spark.Dsl.Verifier

     def verify(dsl_state) do
       # Must return :ok or {:error, Spark.Error.DslError.t()}
       case validate_fields(dsl_state) do
         :ok -> :ok
         {:error, message} -> 
           {:error, Spark.Error.DslError.exception(message: message)}
       end
     end
   end
   ```

2. **Provide clear error messages** - Include context in error messages:
   ```elixir
   def verify(dsl_state) do
     fields = MyApp.Validator.Info.fields(dsl_state)
     
     case find_invalid_fields(fields) do
       [] -> :ok
       invalid -> 
         {:error, 
          Spark.Error.DslError.exception(
            message: "Invalid fields: #{inspect(invalid)}",
            path: [:fields]
          )}
     end
   end
   ```

## 🎯 Generator Issues

### **"Generator not found" Errors**

#### **Problem**
```bash
** (Mix) The task "spark.gen.dsl" could not be found
```

#### **Solution**
1. **Install Igniter** - Required for generators:
   ```elixir
   defp deps do
     [
       {:spark, "~> 2.2.65"},
       {:igniter, "~> 0.6.6", only: [:dev]}  # Required for generators
     ]
   end
   ```

2. **Install dependencies**:
   ```bash
   mix deps.get
   mix deps.compile
   ```

3. **Check Mix environment** - Ensure you're in the correct environment:
   ```bash
   MIX_ENV=dev mix spark.gen.dsl MyApp.Validator
   ```

### **Invalid Generator Options**

#### **Problem**
```bash
** (Mix) Invalid option --invalid_option for task spark.gen.dsl
```

#### **Solution**
1. **Check available options**:
   ```bash
   mix help spark.gen.dsl
   ```

2. **Use correct option format**:
   ```bash
   # Correct
   mix spark.gen.dsl MyApp.Validator --section fields --examples
   
   # Incorrect
   mix spark.gen.dsl MyApp.Validator --sections fields --example
   ```

3. **Check option values** - Ensure values match expected types:
   ```bash
   # Correct
   mix spark.gen.dsl MyApp.Validator --opt required:boolean:false
   
   # Incorrect
   mix spark.gen.dsl MyApp.Validator --opt required:boolean:true
   ```

### **Generator Output Issues**

#### **Problem**
Generated files don't match expected structure or are missing.

#### **Solution**
1. **Check file permissions** - Ensure you can write to the target directory

2. **Verify module names** - Ensure module names are valid:
   ```bash
   # Correct
   mix spark.gen.dsl MyApp.Validator
   
   # Incorrect - invalid module name
   mix spark.gen.dsl MyApp.validator
   ```

3. **Check for conflicts** - Ensure target files don't already exist:
   ```bash
   # Remove existing files first
   rm lib/my_app/validator.ex
   mix spark.gen.dsl MyApp.Validator
   ```

## 🔍 Debugging Tips

### **Enable Debug Logging**
```elixir
# config/dev.exs
config :spark, :debug, true
```

### **Check DSL State**
```elixir
# In your transformer or verifier
def transform(dsl_state) do
  IO.inspect(dsl_state, label: "DSL State")
  # ... your logic
end
```

### **Validate DSL Manually**
```elixir
# Test DSL compilation
defmodule TestValidator do
  use MyApp.Validator
  
  fields do
    field :name, :string
  end
end

# Check if it compiles
Code.ensure_loaded?(TestValidator)
```

### **Check Generated Functions**
```elixir
# Verify info module functions
MyApp.Validator.Info.__info__(:functions)
```

## 📞 Getting More Help

### **Self-Service Resources**
- **[Generator Reference](reference/generators/)** - Complete generator documentation
- **[API Documentation](https://hexdocs.pm/spark)** - Full API reference
- **[Examples](../examples/)** - Working code examples

### **Community Support**
- **[Elixir Forum](https://elixirforum.com/c/ash-framework)** - Community discussions
- **[GitHub Issues](https://github.com/ash-project/spark/issues)** - Bug reports
- **[Discord](https://discord.gg/DQHqJ8k)** - Real-time chat

### **When to Ask for Help**
- ✅ **Tried all solutions above** - You've exhausted self-service options
- ✅ **Have a minimal reproduction** - You can reproduce the issue in a simple example
- ✅ **Include error messages** - You have the complete error output
- ✅ **Show your code** - You're willing to share relevant code snippets

### **What to Include When Asking for Help**
1. **Complete error message** - Include the full stack trace
2. **Minimal reproduction** - Code that reproduces the issue
3. **Environment details** - Elixir version, Spark version, OS
4. **What you've tried** - Steps you've already attempted

---

**Still stuck?** [Get community help →](../README.md#-support) 