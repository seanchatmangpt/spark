defmodule AsyncApi.BasicTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Basic tests to verify AsyncAPI DSL compilation and functionality.
  """

  defmodule SimpleApi do
    use AsyncApi

    info do
      title "Simple Test API"
      version "1.0.0"
      description "A simple test API"
    end
  end

  defmodule ApiWithServers do
    use AsyncApi

    info do
      title "API With Servers"
      version "1.0.0"
    end

    servers do
      server :production, "api.example.com" do
        protocol :https
        description "Production server"
      end
    end
  end

  describe "Basic AsyncAPI DSL" do
    test "can compile a simple API with info section" do
      # If we get here, the DSL compiled successfully
      assert SimpleApi.spark_dsl_config() != nil
    end

    test "can access info through introspection" do
      info = AsyncApi.Info.info(SimpleApi)
      assert info.title == "Simple Test API"
      assert info.version == "1.0.0"
      assert info.description == "A simple test API"
    end

    test "can generate basic spec" do
      spec = AsyncApi.to_spec(SimpleApi)
      assert spec.asyncapi == "3.0.0"
      assert spec.info.title == "Simple Test API"
      assert spec.info.version == "1.0.0"
    end

    test "can compile API with servers" do
      # If we get here, the DSL compiled successfully
      assert ApiWithServers.spark_dsl_config() != nil
    end

    test "can access server information" do
      servers = AsyncApi.Info.servers(ApiWithServers)
      assert length(servers) == 1
      server = hd(servers)
      assert server.name == :production
      assert server.host == "api.example.com"
    end
  end
end