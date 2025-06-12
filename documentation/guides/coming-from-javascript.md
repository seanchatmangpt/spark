# Coming from JavaScript: Your First Elixir DSL with Spark

## Welcome, JavaScript Developer! 🟨 → 🧪

If you're here from the JavaScript world, you've probably hit the limits of configuration management, type safety, or API boilerplate. Spark DSL and Ash solve these problems elegantly - think of it as having TypeScript's type safety, GraphQL's introspection, and Rails' conventions, but at compile time and with functional programming superpowers.

## The Mental Model Shift

### JavaScript vs Elixir: Core Philosophy

```javascript
// JavaScript: Mutable objects, imperative style
class UserConfig {
  constructor() {
    this.permissions = [];  // Mutable array
    this.settings = {};     // Mutable object
  }
  
  addPermission(perm) {
    this.permissions.push(perm);  // Mutates state
  }
  
  validate() {
    if (this.permissions.length === 0) {
      throw new Error("No permissions");
    }
  }
}
```

```elixir
# Elixir: Immutable data, functional style
defmodule UserConfig do
  # Pattern matching instead of conditionals
  def validate_permissions([]), do: {:error, "No permissions"}
  def validate_permissions(perms), do: {:ok, perms}
  
  # Pure functions - always return new data
  def add_permission(permissions, new_perm) do
    [new_perm | permissions]  # Returns new list
  end
end
```

**Key Mindset Shift**: Instead of modifying objects, you transform data through function pipelines.

## What You Already Know (JS → Elixir Mappings)

### Data Structures & Array Methods
```javascript
// JavaScript
const user = {
  name: "Alice",
  age: 30,
  permissions: ["read", "write"]
};

// Array methods you know and love
const adults = users.filter(u => u.age >= 18);
const names = users.map(u => u.name);
const total = prices.reduce((sum, price) => sum + price, 0);

// Destructuring
const { name, age } = user;
const [first, ...rest] = permissions;
```

```elixir
# Elixir - very similar!
user = %{
  name: "Alice",
  age: 30,
  permissions: ["read", "write"]
}

# Similar array operations
adults = Enum.filter(users, fn u -> u.age >= 18 end)
names = Enum.map(users, fn u -> u.name end)
total = Enum.reduce(prices, 0, fn price, sum -> sum + price end)

# Pattern matching (like destructuring++)
%{name: name, age: age} = user
[first | rest] = permissions
```

### Functions and Modules
```javascript
// JavaScript
function calculateTotal(items) {
  return items
    .map(item => item.price)
    .reduce((sum, price) => sum + price, 0);
}

// ES6 modules
export const Calculator = {
  add: (a, b) => a + b,
  multiply: (a, b) => a * b
};
```

```elixir
# Elixir - pipe operator is like method chaining
def calculate_total(items) do
  items
  |> Enum.map(& &1.price)     # & &1 is like (item) => item
  |> Enum.sum()
end

defmodule Calculator do
  def add(a, b), do: a + b
  def multiply(a, b), do: a * b
end
```

### Promises/Error Handling
```javascript
// JavaScript: Promises and try/catch
async function fetchUser(id) {
  try {
    const response = await fetch(`/users/${id}`);
    if (!response.ok) throw new Error('Not found');
    return await response.json();
  } catch (error) {
    console.error('Failed to fetch user:', error);
    return null;
  }
}
```

```elixir
# Elixir: Pattern matching on return values (no exceptions!)
def fetch_user(id) do
  case HTTPoison.get("/users/#{id}") do
    {:ok, %{status_code: 200, body: body}} ->
      {:ok, Jason.decode!(body)}
    {:ok, %{status_code: 404}} ->
      {:error, :not_found}
    {:error, reason} ->
      Logger.error("Failed to fetch user: #{inspect(reason)}")
      {:error, :network_error}
  end
end
```

## Your First Spark DSL: Configuration Management

### The Problem You Know from JavaScript
```javascript
// config.js - No validation, runtime errors
const config = {
  database: {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT) || 5432,
    name: process.env.DB_NAME || 'myapp'
  },
  permissions: [
    { action: 'read', resource: 'users' },
    { action: 'write', resource: 'posts' }
  ],
  features: {
    userRegistration: true,
    emailNotifications: false
  }
};

// Manual validation (often forgotten!)
function validateConfig(config) {
  if (!config.database) {
    throw new Error('Missing database config');
  }
  if (config.database.port < 1024) {
    throw new Error('Port too low');
  }
  // Easy to forget validation rules...
}
```

### The Spark DSL Solution
```elixir
defmodule MyApp.Config do
  use Spark.Dsl

  dsl do
    section :database do
      entity :connection do
        attribute :host, :string, required: true, default: "localhost"
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

# Usage: Like TypeScript interfaces but enforced at compile time!
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

**What You Gained (vs JavaScript config objects):**
- ✅ **Compile-time validation** - Typos caught before deployment (like TypeScript++)
- ✅ **IDE autocomplete** - IntelliSense for your configuration
- ✅ **Runtime introspection** - Query config programmatically
- ✅ **Type safety** - Can't pass wrong types
- ✅ **Self-documenting** - Schema IS the documentation

## Comparing with JS Tools You Know

### Instead of Zod/Joi Validation
```javascript
// Zod schema validation
import { z } from 'zod';

const DatabaseSchema = z.object({
  host: z.string(),
  port: z.number().min(1024),
  name: z.string()
});

const ConfigSchema = z.object({
  database: DatabaseSchema,
  permissions: z.array(z.object({
    action: z.enum(['read', 'write', 'delete']),
    resource: z.string()
  }))
});

// Runtime validation
const config = ConfigSchema.parse(rawConfig);
```

```elixir
# Spark DSL gives you the same + more
defmodule MyApp.Config do
  use Spark.Dsl

  dsl do
    section :database do
      entity :connection do
        attribute :host, :string, required: true
        attribute :port, :integer, required: true
        # Custom validation function
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

### Instead of GraphQL Schema Definition
```javascript
// GraphQL SDL
const typeDefs = `
  type User {
    id: ID!
    email: String!
    name: String!
    posts: [Post!]!
  }
  
  type Post {
    id: ID!
    title: String!
    content: String!
    author: User!
  }
  
  type Query {
    users: [User!]!
    user(id: ID!): User
  }
  
  type Mutation {
    createUser(input: CreateUserInput!): User!
  }
`;

// Resolvers (lots of boilerplate)
const resolvers = {
  Query: {
    users: () => User.findAll(),
    user: (_, { id }) => User.findById(id)
  },
  Mutation: {
    createUser: (_, { input }) => User.create(input)
  }
  // ... lots more boilerplate
};
```

```elixir
# Ash Resource - generates GraphQL schema + resolvers automatically
defmodule MyApp.User do
  use Ash.Resource,
    domain: MyApp.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshGraphql.Resource]  # Add GraphQL support

  attributes do
    uuid_primary_key :id
    attribute :email, :string, allow_nil?: false
    attribute :name, :string, allow_nil?: false
  end

  relationships do
    has_many :posts, MyApp.Post
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  graphql do
    type :user
    
    queries do
      get :user, :read
      list :users, :read
    end
    
    mutations do
      create :create_user, :create
    end
  end
end

# That's it! GraphQL schema + resolvers generated automatically
```

### Instead of Express.js Routes
```javascript
// Express.js - lots of boilerplate
app.get('/users', async (req, res) => {
  try {
    const users = await User.findAll();
    res.json(users);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/users', async (req, res) => {
  try {
    const user = await User.create(req.body);
    res.status(201).json(user);
  } catch (error) {
    if (error.name === 'ValidationError') {
      res.status(400).json({ error: error.message });
    } else {
      res.status(500).json({ error: 'Internal server error' });
    }
  }
});

// Repeat for every endpoint...
```

```elixir
# Phoenix + Ash - one line gives you full REST API
defmodule MyAppWeb.Router do
  use Phoenix.Router
  
  scope "/api" do
    # This one line generates all CRUD endpoints with proper error handling
    ash_resources [MyApp.User, MyApp.Post]
  end
end

# Automatically generates:
# GET    /users      (list users)
# GET    /users/:id  (get user)  
# POST   /users      (create user)
# PATCH  /users/:id  (update user)
# DELETE /users/:id  (delete user)
# All with validation, error handling, serialization, etc.
```

## Installation and Setup

### 1. Install Elixir (like installing Node.js)
```bash
# macOS (like 'brew install node')
brew install elixir

# Ubuntu/Debian
apt install elixir

# Windows
# Download from https://elixir-lang.org/install.html
```

### 2. Create Your First Project
```bash
# Like 'npx create-react-app myapp'
mix new myapp
cd myapp

# Add dependencies (like package.json)
```

Edit `mix.exs` (similar to `package.json`):
```elixir
defp deps do
  [
    {:spark, "~> 2.0"},
    {:ash, "~> 3.0"},
    {:ash_postgres, "~> 2.0"},  # Like 'pg' for PostgreSQL
    {:phoenix, "~> 1.7"},       # Like Express.js
    {:jason, "~> 1.0"}          # Like JSON.stringify/parse
  ]
end
```

```bash
# Install dependencies (like 'npm install')
mix deps.get
```

### 3. Your First DSL Module
Create `lib/myapp/config.ex`:
```elixir
defmodule MyApp.Config do
  use Spark.Dsl

  dsl do
    section :api_settings do
      entity :endpoint do
        attribute :path, :string, required: true
        attribute :method, :atom, required: true, default: :get
        attribute :auth_required, :boolean, default: false
      end
    end
  end
end
```

Create `lib/myapp/api_config.ex`:
```elixir
defmodule MyApp.ApiConfig do
  use MyApp.Config

  api_settings do
    endpoint do
      path "/users"
      method :get
      auth_required true
    end

    endpoint do
      path "/posts"
      method :post
      auth_required true
    end
  end
end
```

### 4. Test It Works
```bash
# Start interactive Elixir (like 'node' REPL)
iex -S mix

# Query your configuration (like console.log)
iex> MyApp.ApiConfig.api_settings()
[
  %{path: "/users", method: :get, auth_required: true},
  %{path: "/posts", method: :post, auth_required: true}
]
```

## Common JavaScript Patterns → Elixir DSL

### Config Objects → DSL Modules
```javascript
// JavaScript: Plain config objects
const config = {
  api: {
    baseUrl: 'https://api.example.com',
    timeout: 5000,
    retries: 3
  },
  features: {
    userRegistration: true,
    emailNotifications: false
  }
};

// Different environments
const devConfig = { ...config, api: { ...config.api, baseUrl: 'http://localhost:3000' } };
const prodConfig = { ...config, api: { ...config.api, timeout: 10000 } };
```

```elixir
# Elixir: DSL-based configuration with inheritance
defmodule MyApp.BaseConfig do
  use Spark.Dsl
  
  dsl do
    section :api do
      entity :settings do
        attribute :base_url, :string, required: true
        attribute :timeout, :integer, default: 5000
        attribute :retries, :integer, default: 3
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

defmodule MyApp.DevConfig do
  use MyApp.BaseConfig
  
  api do
    settings do
      base_url "http://localhost:3000"
      timeout 5000
    end
  end
  
  features do
    feature do
      name :user_registration
      enabled true
    end
  end
end

defmodule MyApp.ProdConfig do
  use MyApp.BaseConfig
  
  api do
    settings do
      base_url "https://api.example.com"
      timeout 10000  # Higher timeout for prod
    end
  end
end
```

### Class Definitions → Ash Resources
```javascript
// JavaScript: Class with validation
class User {
  constructor({ email, name, age }) {
    this.id = crypto.randomUUID();
    this.email = email;
    this.name = name;
    this.age = age;
    this.createdAt = new Date();
    
    this.validate();
  }
  
  validate() {
    if (!this.email.includes('@')) {
      throw new Error('Invalid email');
    }
    if (this.age < 0) {
      throw new Error('Age must be positive');
    }
  }
  
  async save() {
    // Database logic here...
  }
  
  static async findById(id) {
    // Database query logic...
  }
}
```

```elixir
# Elixir: Ash Resource (auto-generates CRUD + validation + more)
defmodule MyApp.User do
  use Ash.Resource, domain: MyApp.Domain

  attributes do
    uuid_primary_key :id
    attribute :email, :string, allow_nil?: false
    attribute :name, :string, allow_nil?: false
    attribute :age, :integer
    timestamps()  # created_at, updated_at
  end

  validations do
    validate format(:email, ~r/@/, message: "Invalid email")
    validate numericality(:age, greater_than: 0, message: "Age must be positive")
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    # Custom actions
    read :adults do
      filter expr(age >= 18)
    end
  end
end

# Usage (all generated automatically):
# MyApp.User.create!(%{email: "alice@example.com", name: "Alice", age: 30})
# MyApp.User.read!() # Get all users
# MyApp.User.adults!() # Get users >= 18
```

## Testing Your DSL (Jest → ExUnit)

```javascript
// user.test.js
import { User } from './user.js';

describe('User', () => {
  test('creates user with valid data', () => {
    const user = new User({
      email: 'alice@example.com',
      name: 'Alice',
      age: 30
    });
    
    expect(user.email).toBe('alice@example.com');
    expect(user.name).toBe('Alice');
  });
  
  test('throws error for invalid email', () => {
    expect(() => {
      new User({ email: 'invalid', name: 'Alice', age: 30 });
    }).toThrow('Invalid email');
  });
});
```

```elixir
# test/myapp/user_test.exs
defmodule MyApp.UserTest do
  use ExUnit.Case

  test "creates user with valid data" do
    {:ok, user} = MyApp.User.create(%{
      email: "alice@example.com",
      name: "Alice", 
      age: 30
    })
    
    assert user.email == "alice@example.com"
    assert user.name == "Alice"
  end
  
  test "returns error for invalid email" do
    {:error, changeset} = MyApp.User.create(%{
      email: "invalid",
      name: "Alice", 
      age: 30
    })
    
    assert changeset.errors[:email]
  end
end
```

```bash
# Run tests (like 'npm test')
mix test
```

## Advanced: Real-time Features (Socket.io → Phoenix LiveView)

### JavaScript: Socket.io + Manual DOM Updates
```javascript
// client.js
const socket = io();
const userList = document.getElementById('users');

socket.on('user_created', (user) => {
  const li = document.createElement('li');
  li.textContent = `${user.name} (${user.email})`;
  userList.appendChild(li);
});

document.getElementById('create-user').addEventListener('click', () => {
  const email = document.getElementById('email').value;
  const name = document.getElementById('name').value;
  
  fetch('/users', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, name })
  })
  .then(response => response.json())
  .then(user => {
    socket.emit('user_created', user);
  });
});
```

### Elixir: Phoenix LiveView (No JavaScript Needed!)
```elixir
# lib/myapp_web/live/users_live.ex
defmodule MyAppWeb.UsersLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    # Subscribe to user updates
    if connected?(socket), do: MyApp.subscribe_to_users()
    
    users = MyApp.User.read!()
    {:ok, assign(socket, users: users, form: to_form(%{}))}
  end

  def handle_event("create_user", %{"email" => email, "name" => name}, socket) do
    case MyApp.User.create(%{email: email, name: name}) do
      {:ok, user} ->
        # Broadcast to all connected clients
        MyApp.broadcast_user_created(user)
        {:noreply, socket}
      
      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_info({:user_created, user}, socket) do
    users = [user | socket.assigns.users]
    {:noreply, assign(socket, users: users)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <h1>Users</h1>
      
      <.form for={@form} phx-submit="create_user">
        <input type="email" name="email" placeholder="Email" required />
        <input type="text" name="name" placeholder="Name" required />
        <button type="submit">Create User</button>
      </.form>
      
      <ul>
        <li :for={user <- @users}>
          <%= user.name %> (<%= user.email %>)
        </li>
      </ul>
    </div>
    """
  end
end
```

**What you get automatically:**
- ✅ Real-time updates across all connected clients
- ✅ Form handling and validation
- ✅ No JavaScript needed
- ✅ Optimistic updates
- ✅ Automatic error handling

## Mental Model Transitions

### 1. Promises → Pattern Matching
```javascript
// JavaScript: Promise chains
fetch('/api/user/123')
  .then(response => {
    if (!response.ok) throw new Error('Not found');
    return response.json();
  })
  .then(user => processUser(user))
  .catch(error => handleError(error));
```

```elixir
# Elixir: Pattern matching (no exceptions!)
case HTTPoison.get("/api/user/123") do
  {:ok, %{status_code: 200, body: body}} ->
    user = Jason.decode!(body)
    process_user(user)
  
  {:ok, %{status_code: 404}} ->
    handle_error(:not_found)
  
  {:error, reason} ->
    handle_error({:network_error, reason})
end
```

### 2. Callbacks → Message Passing
```javascript
// JavaScript: Event callbacks
button.addEventListener('click', (event) => {
  processClick(event);
});

setTimeout(() => {
  doDelayedWork();
}, 1000);
```

```elixir
# Elixir: Actor model with message passing
defmodule MyWorker do
  use GenServer

  def handle_call(:process_click, _from, state) do
    result = process_click()
    {:reply, result, state}
  end

  def handle_info(:delayed_work, state) do
    do_delayed_work()
    {:noreply, state}
  end
end

# Usage
GenServer.call(MyWorker, :process_click)
Process.send_after(MyWorker, :delayed_work, 1000)
```

### 3. Mutable State → State Machines
```javascript
// JavaScript: Mutable state management
class OrderProcessor {
  constructor() {
    this.state = 'pending';
    this.items = [];
  }
  
  addItem(item) {
    if (this.state !== 'pending') {
      throw new Error('Cannot add items to non-pending order');
    }
    this.items.push(item);
  }
  
  process() {
    this.state = 'processing';
    // ... processing logic
    this.state = 'completed';
  }
}
```

```elixir
# Elixir: Explicit state transitions
defmodule OrderProcessor do
  def add_item({:pending, items}, item) do
    {:pending, [item | items]}
  end
  
  def add_item({state, _}, _item) do
    {:error, "Cannot add items to #{state} order"}
  end
  
  def process({:pending, items}) do
    # Processing logic here
    {:completed, items}
  end
  
  def process({state, _}) do
    {:error, "Cannot process #{state} order"}
  end
end
```

## Common Gotchas for JavaScript Developers

### 1. Variables Are Immutable
```elixir
# This doesn't modify the original list
list = [1, 2, 3]
new_list = [0 | list]  # new_list is [0, 1, 2, 3], list is still [1, 2, 3]

# Use pattern matching to "update" maps
user = %{name: "Alice", age: 30}
updated_user = %{user | age: 31}  # Returns new map, doesn't modify original
```

### 2. Atoms vs Strings
```elixir
# Atoms (like symbols) - use for constants, keys, status values
:ok, :error, :pending, :name, :email

# Strings - use for user data
"Alice", "alice@example.com", "Hello world"

# Maps typically use atoms for keys
%{name: "Alice", email: "alice@example.com"}
```

### 3. Pattern Matching is More Powerful Than Destructuring
```elixir
# Match on structure AND values
case user do
  %{name: "Alice", age: age} when age >= 18 -> 
    "Adult Alice, age #{age}"
  %{name: name, age: age} when age >= 18 ->
    "Adult #{name}, age #{age}"
  %{name: name, age: age} ->
    "Minor #{name}, age #{age}"
end
```

### 4. Pipe Operator is Like Method Chaining
```javascript
// JavaScript method chaining
const result = data
  .filter(item => item.active)
  .map(item => item.value)
  .reduce((sum, value) => sum + value, 0);
```

```elixir
# Elixir pipe operator (data flows left to right)
result = 
  data
  |> Enum.filter(& &1.active)
  |> Enum.map(& &1.value)
  |> Enum.sum()
```

## Next Steps

1. **Read the [Phoenix LiveView Tutorial](https://hexdocs.pm/phoenix_live_view/installation.html)** - Real-time web without JavaScript
2. **Try the [Ash Getting Started Guide](https://ash-hq.org/docs/guides/ash/latest/tutorials/get-started.html)** - Auto-generated APIs
3. **Explore [Spark DSL Examples](../examples/)** - More DSL patterns
4. **Join the [Elixir Forum](https://elixirforum.com/)** - Friendly community with lots of JS refugees!

## Resources for JavaScript Developers

- **[Elixir for JavaScript Developers](https://elixir-lang.org/getting-started/introduction.html)**
- **[Phoenix vs Node.js Comparison](https://phoenixframework.org/)**
- **[LiveView vs React/Vue](https://dockyard.com/blog/2021/12/09/phoenix-liveview-vs-react)**
- **[Functional Programming for JS Devs](https://elixirschool.com/en/lessons/basics/functions/)**

Remember: Elixir might feel weird at first (no classes! immutable data!), but once you experience the reliability of pattern matching, the simplicity of LiveView, and the power of DSLs, you'll wonder why you were dealing with all that JavaScript complexity! 🚀

The learning curve is real, but the productivity gains are massive. Welcome to the functional side! 💜