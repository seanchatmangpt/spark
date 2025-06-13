defmodule AsyncApi.TransformersTest do
  use ExUnit.Case, async: true

  describe "channel validation" do
    test "rejects duplicate channel addresses" do
      assert_raise Spark.Error.DslError, ~r/Duplicate channel address/, fn ->
        defmodule DuplicateChannelsApi do
          use AsyncApi

          info do
            title "Test API"
            version "1.0.0"
          end

          channels do
            channel "/events" do
              description "Events channel"
            end

            channel "/events" do
              description "Duplicate events channel"
            end
          end
        end
      end
    end

    test "rejects channels with undefined parameters" do
      assert_raise Spark.Error.DslError, ~r/references parameters.*that are not defined/, fn ->
        defmodule UndefinedParametersApi do
          use AsyncApi

          info do
            title "Test API"
            version "1.0.0"
          end

          channels do
            channel "/user/{userId}/events/{eventId}" do
              description "User events"
              
              parameters do
                parameter :userId do
                  schema :string
                  description "User ID"
                end
                # Missing eventId parameter
              end
            end
          end
        end
      end
    end

    test "rejects operations with undefined message references" do
      assert_raise Spark.Error.DslError, ~r/references undefined messages/, fn ->
        defmodule UndefinedMessagesApi do
          use AsyncApi

          info do
            title "Test API"
            version "1.0.0"
          end

          channels do
            channel "/events" do
              description "Events channel"
              
              operations do
                operation :receive, :receive_event do
                  messages [:nonexistent_message]
                end
              end
            end
          end
        end
      end
    end
  end

  describe "message validation" do
    test "rejects duplicate message names" do
      assert_raise Spark.Error.DslError, ~r/Duplicate message name/, fn ->
        defmodule DuplicateMessagesApi do
          use AsyncApi

          info do
            title "Test API"
            version "1.0.0"
          end

          components do
            message :event_message do
              payload :event_schema
            end

            message :event_message do
              payload :other_schema
            end
          end
        end
      end
    end

    test "rejects messages without payload" do
      assert_raise Spark.Error.DslError, ~r/must have a payload defined/, fn ->
        defmodule NoPayloadApi do
          use AsyncApi

          info do
            title "Test API"
            version "1.0.0"
          end

          components do
            message :event_message do
              content_type "application/json"
              # Missing payload
            end
          end
        end
      end
    end

    test "rejects messages with undefined payload schema references" do
      assert_raise Spark.Error.DslError, ~r/references undefined payload schema/, fn ->
        defmodule UndefinedPayloadApi do
          use AsyncApi

          info do
            title "Test API"
            version "1.0.0"
          end

          components do
            message :event_message do
              payload :nonexistent_schema
            end
          end
        end
      end
    end

    test "rejects messages with undefined header schema references" do
      assert_raise Spark.Error.DslError, ~r/references undefined headers schema/, fn ->
        defmodule UndefinedHeadersApi do
          use AsyncApi

          info do
            title "Test API"
            version "1.0.0"
          end

          components do
            schema :event_schema do
              type :object
              properties do
                property :id, :string
              end
            end

            message :event_message do
              payload :event_schema
              headers :nonexistent_headers_schema
            end
          end
        end
      end
    end

    test "accepts valid content types" do
      # This should not raise an error
      defmodule ValidContentTypeApi do
        use AsyncApi

        info do
          title "Test API"
          version "1.0.0"
        end

        components do
          schema :event_schema do
            type :object
            properties do
              property :id, :string
            end
          end

          message :json_message do
            content_type "application/json"
            payload :event_schema
          end

          message :xml_message do
            content_type "application/xml"
            payload :event_schema
          end

          message :custom_message do
            content_type "application/vnd.api+json"
            payload :event_schema
          end
        end
      end

      # If we get here without an exception, the test passes
      assert ValidContentTypeApi.__spark_dsl_config__() != nil
    end
  end

  describe "schema validation" do
    test "rejects duplicate schema names" do
      assert_raise Spark.Error.DslError, ~r/Duplicate schema name/, fn ->
        defmodule DuplicateSchemasApi do
          use AsyncApi

          info do
            title "Test API"
            version "1.0.0"
          end

          components do
            schema :event_schema do
              type :object
              properties do
                property :id, :string
              end
            end

            schema :event_schema do
              type :object
              properties do
                property :name, :string
              end
            end
          end
        end
      end
    end

    test "rejects invalid schema types" do
      assert_raise Spark.Error.DslError, ~r/has invalid type/, fn ->
        defmodule InvalidSchemaTypeApi do
          use AsyncApi

          info do
            title "Test API"
            version "1.0.0"
          end

          components do
            schemas do
              schema :invalid_schema do
                type :invalid_type
              end
            end
          end
        end
      end
    end

    test "rejects object schemas without properties" do
      assert_raise Spark.Error.DslError, ~r/is of type 'object' but has no properties/, fn ->
        defmodule ObjectWithoutPropertiesApi do
          use AsyncApi

          info do
            title "Test API"
            version "1.0.0"
          end

          components do
            schemas do
              schema :empty_object do
                type :object
              end
            end
          end
        end
      end
    end

    test "rejects non-object schemas with properties" do
      assert_raise Spark.Error.DslError, ~r/but has properties defined/, fn ->
        defmodule NonObjectWithPropertiesApi do
          use AsyncApi

          info do
            title "Test API"
            version "1.0.0"
          end

          components do
            schemas do
              schema :string_with_properties do
                type :string
                properties do
                  property :invalid, :string
                end
              end
            end
          end
        end
      end
    end

    test "rejects required properties not defined in schema" do
      assert_raise Spark.Error.DslError, ~r/has required properties.*that are not defined/, fn ->
        defmodule RequiredUndefinedApi do
          use AsyncApi

          info do
            title "Test API"
            version "1.0.0"
          end

          components do
            schemas do
              schema :invalid_required do
                type :object
                properties do
                  property :id, :string
                end
                required [:id, :name]  # name is not defined
              end
            end
          end
        end
      end
    end

    test "rejects array schemas without items" do
      assert_raise Spark.Error.DslError, ~r/is of type 'array' but has no items/, fn ->
        defmodule ArrayWithoutItemsApi do
          use AsyncApi

          info do
            title "Test API"
            version "1.0.0"
          end

          components do
            schemas do
              schema :array_schema do
                type :array
              end
            end
          end
        end
      end
    end

    test "rejects non-array schemas with items" do
      assert_raise Spark.Error.DslError, ~r/but has items defined/, fn ->
        defmodule NonArrayWithItemsApi do
          use AsyncApi

          info do
            title "Test API"
            version "1.0.0"
          end

          components do
            schemas do
              schema :string_with_items do
                type :string
                items %{type: :string}
              end
            end
          end
        end
      end
    end

    test "accepts valid schema configurations" do
      # This should not raise an error
      defmodule ValidSchemasApi do
        use AsyncApi

        info do
          title "Test API"
          version "1.0.0"
        end

        components do
          schema :user_schema do
            type :object
            description "A user object"
            properties do
              property :id, :string
              property :name, :string
              property :email, :string, format: "email"
              property :age, :integer, minimum: 0, maximum: 150
              property :tags, :array
            end
            required [:id, :name, :email]
          end

          schema :string_array do
            type :array
            items %{type: :string}
            min_items 1
            max_items 10
          end

          schema :simple_string do
            type :string
            format "email"
            min_length 5
            max_length 100
          end
        end
      end

      # If we get here without an exception, the test passes
      assert ValidSchemasApi.__spark_dsl_config__() != nil
    end
  end
end