# Coming from Python: Your First Elixir DSL with Spark

## Welcome, Python Developer! 🐍 → 🧪

If you're here, you've probably discovered that Spark DSL and Ash solve problems that are painful in Python - things like configuration management, data validation, API generation, and complex business rules. This guide will help you understand Elixir and Spark DSL through the lens of your Python experience.

## The Mental Model Shift

### Python vs Elixir: Core Differences

```python
# Python: Object-oriented, mutable state
class UserConfig:
    def __init__(self):
        self.permissions = []  # Mutable list
        self.settings = {}     # Mutable dict
    
    def add_permission(self, perm):
        self.permissions.append(perm)  # Mutates state
        
    def validate(self):
        if not self.permissions:
            raise ValueError("No permissions")
```

```elixir
# Elixir: Functional, immutable data
defmodule UserConfig do
  # Pattern matching instead of classes
  def validate_permissions([]), do: {:error, "No permissions"}
  def validate_permissions(perms), do: {:ok, perms}
  
  # Pure functions - no side effects
  def add_permission(permissions, new_perm) do
    [new_perm | permissions]  # Returns new list, doesn't mutate
  end
end
```

**Key Mindset Shift**: In Python you modify objects; in Elixir you transform data.

## What You Already Know (Python → Elixir Mappings)

### Data Structures
```python
# Python
user = {
    "name": "Alice",
    "age": 30,
    "permissions": ["read", "write"]
}

# List comprehension
adults = [u for u in users if u["age"] >= 18]

# Dictionary access
name = user["name"]
age = user.get("age", 0)
```

```elixir
# Elixir
user = %{
  name: "Alice",
  age: 30,
  permissions: ["read", "write"]
}

# List comprehension (similar!)
adults = for u <- users, u.age >= 18, do: u

# Map access
name = user.name          # or user[:name]
age = Map.get(user, :age, 0)
```

### Functions and Modules
```python
# Python
def calculate_total(items):
    return sum(item['price'] for item in items)

class Calculator:
    @staticmethod
    def add(a, b):
        return a + b
```

```elixir
# Elixir
def calculate_total(items) do
  items
  |> Enum.map(& &1.price)
  |> Enum.sum()
end

defmodule Calculator do
  def add(a, b), do: a + b
end
```

### Error Handling
```python
# Python: Exceptions
try:
    result = risky_operation()
except ValueError as e:
    print(f"Error: {e}")
    result = default_value
```

```elixir
# Elixir: Pattern matching on return values
case risky_operation() do
  {:ok, result} -> result
  {:error, reason} -> 
    IO.puts("Error: #{reason}")
    default_value
end
```

## Your First Spark DSL: Configuration Management

### The Problem You Know from Python
```python
# config.py - Hard to validate, no IDE support
CONFIG = {
    "database": {
        "host": "localhost",
        "port": 5432,
        "name": "myapp"
    },
    "permissions": [
        {"action": "read", "resource": "users"},
        {"action": "write", "resource": "posts"}
    ],
    "features": {
        "user_registration": True,
        "email_notifications": False
    }
}

# Validation is manual and error-prone
def validate_config(config):
    if "database" not in config:
        raise ValueError("Missing database config")
    if config["database"]["port"] < 1024:
        raise ValueError("Port too low")
    # ... lots of manual validation
```

### The Spark DSL Solution
```elixir
defmodule MyApp.Config do
  use Spark.Dsl

  # Define what your configuration looks like
  dsl do
    section :database do
      entity :connection do
        attribute :host, :string, required: true
        attribute :port, :integer, required: true, default: 5432
        attribute :name, :string, required: true
      end
    end

    section :permissions do
      entity :permission do
        attribute :action, :atom, required: true
        attribute :resource, :string, required: true
      end
    end

    section :features do
      entity :feature do
        attribute :name, :atom, required: true
        attribute :enabled, :boolean, default: false
      end
    end
  end
end

# Usage: Type-safe, validated configuration
defmodule MyApp.ProductionConfig do
  use MyApp.Config

  database do
    connection do
      host "prod-db.example.com"
      port 5432
      name "myapp_prod"
    end
  end

  permissions do
    permission do
      action :read
      resource "users"
    end
    
    permission do
      action :write  
      resource "posts"
    end
  end

  features do
    feature do
      name :user_registration
      enabled true
    end
  end
end
```

**What You Gained:**
- ✅ **Compile-time validation** - Typos caught before deployment
- ✅ **IDE support** - Autocomplete and refactoring
- ✅ **Type safety** - Can't pass wrong data types
- ✅ **Self-documenting** - Schema is the documentation
- ✅ **Introspection** - Query configuration programmatically

## Comparing with Python Tools You Know

### Instead of Pydantic
```python
# pydantic_models.py
from pydantic import BaseModel, Field
from typing import List

class DatabaseConfig(BaseModel):
    host: str
    port: int = Field(default=5432, ge=1024)
    name: str

class Permission(BaseModel):
    action: str
    resource: str

class AppConfig(BaseModel):
    database: DatabaseConfig
    permissions: List[Permission]
```

```elixir
# Spark DSL gives you the same validation + more
defmodule MyApp.Config do
  use Spark.Dsl

  dsl do
    section :database do
      entity :connection do
        attribute :host, :string, required: true
        attribute :port, :integer, required: true, default: 5432
        # Custom validation
        validate {MyApp.Validators, :validate_port}
      end
    end
  end
end

defmodule MyApp.Validators do
  def validate_port(changeset) do
    case Ecto.Changeset.get_field(changeset, :port) do
      port when port < 1024 -> 
        Ecto.Changeset.add_error(changeset, :port, "must be >= 1024")
      _ -> 
        changeset
    end
  end
end
```

### Instead of Django Settings
```python
# settings.py
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'myapp',
        'USER': 'postgres',
        'PASSWORD': 'secret',
        'HOST': 'localhost',
        'PORT': '5432',
    }
}

INSTALLED_APPS = [
    'django.contrib.admin',
    'myapp.users',
    'myapp.posts',
]
```

```elixir
# With Ash + Spark DSL
defmodule MyApp.User do
  use Ash.Resource,
    domain: MyApp.Domain,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "users"
    repo MyApp.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :email, :string, allow_nil?: false
    attribute :name, :string, allow_nil?: false
    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
```

## Installation and Setup

### 1. Install Elixir (like installing Python)
```bash
# macOS
brew install elixir

# Ubuntu/Debian  
apt install elixir

# Windows
# Download from https://elixir-lang.org/install.html
```

### 2. Create Your First Project
```bash
# Like 'python -m venv myproject'
mix new myapp
cd myapp

# Add dependencies (like requirements.txt)
```

Edit `mix.exs` (similar to `setup.py` or `pyproject.toml`):
```elixir
defp deps do
  [
    {:spark, "~> 2.0"},
    {:ash, "~> 3.0"},
    {:ash_postgres, "~> 2.0"}  # If you want database features
  ]
end
```

```bash
# Install dependencies (like 'pip install -r requirements.txt')
mix deps.get
```

### 3. Your First DSL Module
Create `lib/myapp/config.ex`:
```elixir
defmodule MyApp.Config do
  use Spark.Dsl

  dsl do
    section :app_settings do
      entity :setting do
        attribute :name, :atom, required: true
        attribute :value, :string, required: true
        attribute :description, :string
      end
    end
  end
end
```

Create `lib/myapp/production_config.ex`:
```elixir
defmodule MyApp.ProductionConfig do
  use MyApp.Config

  app_settings do
    setting do
      name :api_key
      value "your-api-key-here"
      description "API key for external service"
    end

    setting do
      name :debug_mode
      value "false"
      description "Enable debug logging"
    end
  end
end
```

### 4. Test It Works
```bash
# Start interactive Elixir (like 'python -i')
iex -S mix

# Query your configuration
iex> MyApp.ProductionConfig.app_settings()
[
  %{name: :api_key, value: "your-api-key-here", description: "API key for external service"},
  %{name: :debug_mode, value: "false", description: "Enable debug logging"}
]
```

## Common Python Patterns → Elixir DSL

### Configuration Classes → DSL Modules
```python
# Python: Class-based configuration
class Config:
    DEBUG = False
    SECRET_KEY = "secret"
    
class DevelopmentConfig(Config):
    DEBUG = True
    DATABASE_URL = "sqlite:///dev.db"
    
class ProductionConfig(Config):
    DATABASE_URL = os.environ["DATABASE_URL"]
```

```elixir
# Elixir: DSL-based configuration
defmodule MyApp.BaseConfig do
  use Spark.Dsl
  
  dsl do
    section :app do
      entity :setting do
        attribute :debug, :boolean, default: false
        attribute :secret_key, :string, required: true
      end
    end
  end
end

defmodule MyApp.DevelopmentConfig do
  use MyApp.BaseConfig
  
  app do
    setting do
      debug true
      secret_key "dev-secret"
    end
  end
end

defmodule MyApp.ProductionConfig do
  use MyApp.BaseConfig
  
  app do
    setting do
      debug false
      secret_key System.get_env("SECRET_KEY")
    end
  end
end
```

### Dataclasses → Ash Resources
```python
# Python: Dataclass with validation
from dataclasses import dataclass
from typing import Optional

@dataclass
class User:
    email: str
    name: str
    age: Optional[int] = None
    
    def __post_init__(self):
        if "@" not in self.email:
            raise ValueError("Invalid email")
```

```elixir
# Elixir: Ash Resource (auto-generates CRUD, validation, etc.)
defmodule MyApp.User do
  use Ash.Resource, domain: MyApp.Domain

  attributes do
    uuid_primary_key :id
    attribute :email, :string, allow_nil?: false
    attribute :name, :string, allow_nil?: false  
    attribute :age, :integer
  end

  validations do
    validate format(:email, ~r/@/, message: "Invalid email")
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
```

## Testing Your DSL (pytest → ExUnit)

```python
# test_config.py
import pytest
from myapp.config import ProductionConfig

def test_production_config():
    config = ProductionConfig()
    assert config.DEBUG == False
    assert config.SECRET_KEY is not None
```

```elixir
# test/myapp/config_test.exs
defmodule MyApp.ConfigTest do
  use ExUnit.Case

  test "production config has correct settings" do
    settings = MyApp.ProductionConfig.app_settings()
    
    debug_setting = Enum.find(settings, & &1.name == :debug_mode)
    assert debug_setting.value == "false"
  end
end
```

```bash
# Run tests (like 'pytest')
mix test
```

## Advanced: Building APIs (Flask/FastAPI → Ash + Phoenix)

### Python API Route
```python
# Flask/FastAPI
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route("/users", methods=["GET"])
def get_users():
    users = User.query.all()
    return jsonify([u.to_dict() for u in users])

@app.route("/users", methods=["POST"]) 
def create_user():
    data = request.json
    user = User(**data)
    if not user.is_valid():
        return jsonify({"error": "Invalid data"}), 400
    db.session.add(user)
    db.session.commit()
    return jsonify(user.to_dict()), 201
```

### Elixir: Ash Auto-Generates This
```elixir
# Just define the resource, get REST API automatically
defmodule MyApp.User do
  use Ash.Resource,
    domain: MyApp.Domain,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :email, :string, allow_nil?: false
    attribute :name, :string, allow_nil?: false
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

# Add to Phoenix router - one line gives you full REST API
defmodule MyAppWeb.Router do
  use Phoenix.Router
  
  scope "/api" do
    # This generates GET /users, POST /users, etc.
    ash_resources [MyApp.User]
  end
end
```

**What you get automatically:**
- ✅ Input validation
- ✅ JSON serialization  
- ✅ Error handling
- ✅ Pagination
- ✅ Filtering and sorting
- ✅ API documentation

## Mental Model Transitions

### 1. Objects → Data + Functions
```python
# Python: Object with methods
class Calculator:
    def __init__(self):
        self.history = []
    
    def add(self, a, b):
        result = a + b
        self.history.append(f"{a} + {b} = {result}")
        return result
```

```elixir
# Elixir: Data structure + pure functions
defmodule Calculator do
  # Data structure
  defstruct history: []
  
  # Pure function - returns new state
  def add(%Calculator{history: history}, a, b) do
    result = a + b
    entry = "#{a} + #{b} = #{result}"
    {result, %Calculator{history: [entry | history]}}
  end
end
```

### 2. Exception Handling → Pattern Matching
```python
# Python: Try/catch
try:
    user = get_user(id)
    result = process_user(user)
except UserNotFound:
    result = "User not found"
except ValidationError as e:
    result = f"Invalid: {e}"
```

```elixir
# Elixir: Pattern matching on return values
case get_user(id) do
  {:ok, user} ->
    process_user(user)
  {:error, :not_found} ->
    "User not found"
  {:error, {:validation, message}} ->
    "Invalid: #{message}"
end
```

### 3. Inheritance → Composition/Protocols
```python
# Python: Class inheritance
class Animal:
    def speak(self):
        pass

class Dog(Animal):
    def speak(self):
        return "Woof!"
```

```elixir
# Elixir: Protocol (like interface)
defprotocol Animal do
  def speak(animal)
end

defmodule Dog do
  defstruct name: ""
end

defimpl Animal, for: Dog do
  def speak(_dog), do: "Woof!"
end
```

## Common Gotchas for Python Developers

### 1. Variables Are Immutable
```elixir
# This doesn't modify `list`, it creates a new one
list = [1, 2, 3]
new_list = [0 | list]  # new_list is [0, 1, 2, 3], list is still [1, 2, 3]
```

### 2. Atoms vs Strings
```elixir
# Atoms (like symbols in other languages) - use for keys/constants
:name, :email, :ok, :error

# Strings - use for user data
"Alice", "alice@example.com"

# Maps typically use atoms for keys
%{name: "Alice", email: "alice@example.com"}
```

### 3. Pattern Matching is Powerful
```elixir
# Instead of if/elif chains, use pattern matching
case response do
  {:ok, %{status: 200, body: body}} -> parse_success(body)
  {:ok, %{status: 404}} -> {:error, :not_found}  
  {:ok, %{status: status}} -> {:error, {:http_error, status}}
  {:error, reason} -> {:error, {:network_error, reason}}
end
```

## Next Steps

1. **Read the [Ash Getting Started Guide](https://ash-hq.org/docs/guides/ash/latest/tutorials/get-started.html)**
2. **Try the [Phoenix LiveView Tutorial](https://hexdocs.pm/phoenix_live_view/installation.html)**
3. **Explore [Spark DSL Examples](../examples/)**
4. **Join the [Elixir Forum](https://elixirforum.com/)** - very welcoming community!

## Resources for Python Developers

- **[Elixir for Python Developers](https://elixir-lang.org/getting-started/introduction.html)**
- **[Phoenix vs Django Comparison](https://phoenixframework.org/)**
- **[Ash vs Django ORM](https://ash-hq.org/docs/guides/ash/latest/how-to/)**

Remember: Elixir might feel different at first, but the patterns you learn (immutability, pattern matching, fault tolerance) will make you a better programmer in any language. The DSL capabilities of Spark and the automatic API generation of Ash will likely spoil you for other frameworks! 🚀