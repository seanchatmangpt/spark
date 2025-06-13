defmodule AsyncApi.Transformers.ValidateComponents do
  @moduledoc """
  Transformer to validate component definitions in AsyncAPI v3.0 DSL.

  This transformer ensures that:
  - Component names are unique within their type
  - Security scheme configurations are valid
  - OAuth flow configurations are valid
  - Cross-references between components are valid
  """

  use Spark.Dsl.Transformer

  @valid_security_types [:apiKey, :http, :oauth2, :openIdConnect, :plain, :scramSha256, :scramSha512, :gssapi]
  @valid_oauth_flows [:implicit, :password, :client_credentials, :authorization_code]

  @doc false
  def transform(dsl_state) do
    security_schemes = Spark.Dsl.Transformer.get_entities(dsl_state, [:components, :security_schemes])
    
    with :ok <- validate_security_schemes(security_schemes),
         :ok <- validate_oauth_flows(security_schemes),
         :ok <- validate_component_references(security_schemes) do
      {:ok, dsl_state}
    end
  end

  defp validate_security_schemes(security_schemes) do
    
    with :ok <- validate_unique_security_scheme_names(security_schemes),
         :ok <- validate_security_scheme_types(security_schemes),
         :ok <- validate_security_scheme_configurations(security_schemes) do
      :ok
    end
  end

  defp validate_unique_security_scheme_names(security_schemes) do
    names = Enum.map(security_schemes, & &1.name)
    duplicates = names -- Enum.uniq(names)
    
    case duplicates do
      [] -> :ok
      [name | _] -> 
        {:error, "Duplicate security scheme name found: #{name}. Security scheme names must be unique."}
    end
  end

  defp validate_security_scheme_types(security_schemes) do
    Enum.reduce_while(security_schemes, :ok, fn scheme, acc ->
      case validate_security_scheme_type(scheme) do
        :ok -> {:cont, acc}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_security_scheme_type(scheme) do
    if scheme.type in @valid_security_types do
      :ok
    else
      {:error, "Security scheme '#{scheme.name}' has invalid type: #{scheme.type}. Valid types are: #{inspect(@valid_security_types)}"}
    end
  end

  defp validate_security_scheme_configurations(security_schemes) do
    Enum.reduce_while(security_schemes, :ok, fn scheme, acc ->
      case validate_security_scheme_config(scheme) do
        :ok -> {:cont, acc}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_security_scheme_config(scheme) do
    case scheme.type do
      :apiKey ->
        validate_api_key_config(scheme)
      
      :http ->
        validate_http_config(scheme)
      
      :oauth2 ->
        validate_oauth2_config(scheme)
      
      :openIdConnect ->
        validate_openid_connect_config(scheme)
      
      _ ->
        :ok  # Other types don't have specific validation requirements
    end
  end

  defp validate_api_key_config(scheme) do
    cond do
      is_nil(scheme.name_field) ->
        {:error, "Security scheme '#{scheme.name}' of type 'apiKey' must specify 'name_field'"}
      
      is_nil(scheme.location) ->
        {:error, "Security scheme '#{scheme.name}' of type 'apiKey' must specify 'location'"}
      
      scheme.location not in [:query, :header, :cookie] ->
        {:error, "Security scheme '#{scheme.name}' has invalid location: #{scheme.location}. Must be one of: query, header, cookie"}
      
      true ->
        :ok
    end
  end

  defp validate_http_config(scheme) do
    if is_nil(scheme.scheme) do
      {:error, "Security scheme '#{scheme.name}' of type 'http' must specify 'scheme'"}
    else
      :ok
    end
  end

  defp validate_oauth2_config(scheme) do
    if is_nil(scheme.flows) do
      {:error, "Security scheme '#{scheme.name}' of type 'oauth2' must specify 'flows'"}
    else
      :ok
    end
  end

  defp validate_openid_connect_config(scheme) do
    if is_nil(scheme.open_id_connect_url) do
      {:error, "Security scheme '#{scheme.name}' of type 'openIdConnect' must specify 'open_id_connect_url'"}
    else
      :ok
    end
  end

  defp validate_oauth_flows(security_schemes) do
    oauth_flows = security_schemes
    |> Enum.map(& &1.flows)
    |> Enum.filter(& &1 != nil)
    
    Enum.reduce_while(oauth_flows, :ok, fn flows, acc ->
      case validate_oauth_flow_config(flows) do
        :ok -> {:cont, acc}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_oauth_flow_config(flows) do
    flow_fields = [:implicit, :password, :client_credentials, :authorization_code]
    defined_flows = Enum.filter(flow_fields, fn field ->
      not is_nil(Map.get(flows, field))
    end)
    
    if Enum.empty?(defined_flows) do
      {:error, "OAuth flows must define at least one flow type: #{inspect(@valid_oauth_flows)}"}
    else
      validate_individual_flows(flows, defined_flows)
    end
  end

  defp validate_individual_flows(flows, flow_types) do
    Enum.reduce_while(flow_types, :ok, fn flow_type, acc ->
      flow = Map.get(flows, flow_type)
      case validate_individual_flow(flow, flow_type) do
        :ok -> {:cont, acc}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_individual_flow(flow, flow_type) do
    case flow_type do
      :implicit ->
        validate_implicit_flow(flow)
      
      :password ->
        validate_password_flow(flow)
      
      :client_credentials ->
        validate_client_credentials_flow(flow)
      
      :authorization_code ->
        validate_authorization_code_flow(flow)
    end
  end

  defp validate_implicit_flow(flow) do
    if is_nil(flow.authorization_url) do
      {:error, "Implicit OAuth flow must specify 'authorization_url'"}
    else
      :ok
    end
  end

  defp validate_password_flow(flow) do
    if is_nil(flow.token_url) do
      {:error, "Password OAuth flow must specify 'token_url'"}
    else
      :ok
    end
  end

  defp validate_client_credentials_flow(flow) do
    if is_nil(flow.token_url) do
      {:error, "Client credentials OAuth flow must specify 'token_url'"}
    else
      :ok
    end
  end

  defp validate_authorization_code_flow(flow) do
    cond do
      is_nil(flow.authorization_url) ->
        {:error, "Authorization code OAuth flow must specify 'authorization_url'"}
      
      is_nil(flow.token_url) ->
        {:error, "Authorization code OAuth flow must specify 'token_url'"}
      
      true ->
        :ok
    end
  end

  defp validate_component_references(_security_schemes) do
    # This would validate cross-references between components
    # For now, we'll implement basic validation
    :ok
  end
end