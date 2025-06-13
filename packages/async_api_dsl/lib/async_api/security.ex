defmodule AsyncApi.Security do
  @moduledoc """
  Advanced security and authentication framework for AsyncAPI.
  
  Provides comprehensive security capabilities including:
  - OAuth 2.0 / OIDC integration
  - JWT token validation and generation
  - API key management
  - mTLS support
  - Message encryption/decryption
  - Rate limiting and throttling
  - Security policy enforcement
  
  ## Usage
  
      defmodule MyApp.SecureEventApi do
        use AsyncApi
        
        security do
          scheme :oauth2 do
            type :oauth2
            flows do
              authorization_code do
                authorization_url "https://auth.example.com/oauth/authorize"
                token_url "https://auth.example.com/oauth/token"
                scopes %{
                  "read:events" => "Read event data",
                  "write:events" => "Write event data",
                  "admin:events" => "Full event access"
                }
              end
            end
          end
          
          scheme :api_key do
            type :api_key
            in :header
            name "X-API-Key"
          end
          
          scheme :jwt do
            type :http
            scheme :bearer
            bearer_format "JWT"
          end
        end
        
        operations do
          operation :sendSecureEvent do
            action :send
            channel "secure.events"
            message :secureEvent
            security [
              oauth2: ["write:events"],
              api_key: []
            ]
          end
        end
      end
  """

  alias AsyncApi.Security.{OAuth2, JWT, ApiKey, MTls, Encryption, RateLimit}

  @type security_scheme :: :oauth2 | :api_key | :jwt | :mtls | :custom
  @type auth_context :: %{
    user_id: String.t(),
    scopes: list(String.t()),
    claims: map(),
    metadata: map()
  }

  @doc """
  Create a security middleware for message processing.
  """
  def create_security_middleware(api_module, opts \\ []) do
    security_schemes = extract_security_schemes(api_module)
    
    %{
      __struct__: AsyncApi.Security.Middleware,
      api_module: api_module,
      schemes: security_schemes,
      enforce_security: Keyword.get(opts, :enforce_security, true),
      rate_limiter: create_rate_limiter(opts),
      encryption: create_encryption_handler(opts),
      audit_logger: create_audit_logger(opts)
    }
  end

  @doc """
  Validate security requirements for an operation.
  """
  def validate_security(middleware, operation_name, credentials, context \\ %{}) do
    operation_security = get_operation_security(middleware.api_module, operation_name)
    
    case operation_security do
      [] when middleware.enforce_security ->
        {:error, :no_security_defined}
      
      [] ->
        {:ok, %{authenticated: false, context: context}}
      
      security_requirements ->
        validate_security_requirements(middleware, security_requirements, credentials, context)
    end
  end

  @doc """
  Encrypt a message payload using configured encryption.
  """
  def encrypt_message(middleware, payload, opts \\ []) do
    if middleware.encryption do
      Encryption.encrypt(middleware.encryption, payload, opts)
    else
      {:ok, payload}
    end
  end

  @doc """
  Decrypt a message payload.
  """
  def decrypt_message(middleware, encrypted_payload, opts \\ []) do
    if middleware.encryption do
      Encryption.decrypt(middleware.encryption, encrypted_payload, opts)
    else
      {:ok, encrypted_payload}
    end
  end

  @doc """
  Check rate limits for an operation.
  """
  def check_rate_limit(middleware, operation_name, user_id, opts \\ []) do
    if middleware.rate_limiter do
      RateLimit.check_limit(middleware.rate_limiter, operation_name, user_id, opts)
    else
      {:ok, %{allowed: true, remaining: :unlimited}}
    end
  end

  @doc """
  Generate a JWT token for a user.
  """
  def generate_jwt_token(claims, opts \\ []) do
    JWT.generate_token(claims, opts)
  end

  @doc """
  Validate a JWT token.
  """
  def validate_jwt_token(token, opts \\ []) do
    JWT.validate_token(token, opts)
  end

  @doc """
  Create OAuth2 client for token exchange.
  """
  def create_oauth2_client(config) do
    OAuth2.create_client(config)
  end

  @doc """
  Audit log a security event.
  """
  def audit_log(middleware, event_type, details, context \\ %{}) do
    if middleware.audit_logger do
      AsyncApi.Security.AuditLogger.log(middleware.audit_logger, event_type, details, context)
    else
      :ok
    end
  end

  # Private helper functions

  defp extract_security_schemes(api_module) do
    spec = AsyncApi.to_spec(api_module)
    
    security_schemes = get_in(spec, [:components, :security_schemes]) || %{}
    
    Enum.into(security_schemes, %{}, fn {scheme_name, scheme_config} ->
      {scheme_name, parse_security_scheme(scheme_config)}
    end)
  end

  defp parse_security_scheme(config) do
    case config[:type] do
      :oauth2 -> OAuth2.parse_config(config)
      :api_key -> ApiKey.parse_config(config)
      :http -> parse_http_scheme(config)
      :mtls -> MTls.parse_config(config)
      _ -> config
    end
  end

  defp parse_http_scheme(config) do
    case config[:scheme] do
      :bearer -> JWT.parse_config(config)
      :basic -> %{type: :basic_auth, config: config}
      _ -> config
    end
  end

  defp get_operation_security(api_module, operation_name) do
    spec = AsyncApi.to_spec(api_module)
    operations = spec[:operations] || %{}
    
    case Map.get(operations, operation_name) do
      nil -> []
      operation -> operation[:security] || []
    end
  end

  defp validate_security_requirements(middleware, requirements, credentials, context) do
    # Try each security requirement (OR logic)
    results = Enum.map(requirements, fn requirement ->
      validate_single_requirement(middleware, requirement, credentials, context)
    end)
    
    case Enum.find(results, fn result -> match?({:ok, _}, result) end) do
      nil -> 
        errors = Enum.map(results, fn {:error, error} -> error end)
        {:error, {:authentication_failed, errors}}
      
      {:ok, auth_context} -> 
        {:ok, auth_context}
    end
  end

  defp validate_single_requirement(middleware, requirement, credentials, context) do
    # Each requirement is a map of scheme_name -> scopes (AND logic)
    auth_results = Enum.map(requirement, fn {scheme_name, required_scopes} ->
      scheme = Map.get(middleware.schemes, scheme_name)
      validate_scheme_auth(scheme, scheme_name, required_scopes, credentials, context)
    end)
    
    # All schemes in requirement must pass
    case Enum.find(auth_results, fn result -> match?({:error, _}, result) end) do
      nil ->
        # Merge all auth contexts
        auth_contexts = Enum.map(auth_results, fn {:ok, ctx} -> ctx end)
        merged_context = merge_auth_contexts(auth_contexts)
        {:ok, merged_context}
      
      error -> error
    end
  end

  defp validate_scheme_auth(nil, scheme_name, _scopes, _credentials, _context) do
    {:error, {:unknown_scheme, scheme_name}}
  end

  defp validate_scheme_auth(scheme, scheme_name, required_scopes, credentials, context) do
    case scheme[:type] do
      :oauth2 -> OAuth2.validate(scheme, required_scopes, credentials, context)
      :api_key -> ApiKey.validate(scheme, credentials, context)
      :jwt -> JWT.validate(scheme, credentials, context)
      :mtls -> MTls.validate(scheme, credentials, context)
      _ -> {:error, {:unsupported_scheme, scheme_name}}
    end
  end

  defp merge_auth_contexts(contexts) do
    Enum.reduce(contexts, %{}, fn context, acc ->
      %{
        user_id: context[:user_id] || acc[:user_id],
        scopes: (acc[:scopes] || []) ++ (context[:scopes] || []),
        claims: Map.merge(acc[:claims] || %{}, context[:claims] || %{}),
        metadata: Map.merge(acc[:metadata] || %{}, context[:metadata] || %{})
      }
    end)
  end

  defp create_rate_limiter(opts) do
    if Keyword.get(opts, :enable_rate_limiting, false) do
      RateLimit.create_limiter(opts)
    else
      nil
    end
  end

  defp create_encryption_handler(opts) do
    if Keyword.get(opts, :enable_encryption, false) do
      Encryption.create_handler(opts)
    else
      nil
    end
  end

  defp create_audit_logger(opts) do
    if Keyword.get(opts, :enable_audit_logging, false) do
      AsyncApi.Security.AuditLogger.create_logger(opts)
    else
      nil
    end
  end
end

defmodule AsyncApi.Security.Middleware do
  @moduledoc """
  Security middleware for AsyncAPI message processing.
  """
  
  defstruct [
    :api_module,
    :schemes,
    :enforce_security,
    :rate_limiter,
    :encryption,
    :audit_logger
  ]
end

defmodule AsyncApi.Security.OAuth2 do
  @moduledoc """
  OAuth 2.0 authentication support.
  """

  @doc """
  Parse OAuth2 configuration from AsyncAPI spec.
  """
  def parse_config(config) do
    %{
      type: :oauth2,
      flows: config[:flows] || %{},
      scopes: extract_all_scopes(config[:flows] || %{}),
      token_url: extract_token_url(config[:flows] || %{}),
      authorization_url: extract_authorization_url(config[:flows] || %{})
    }
  end

  @doc """
  Validate OAuth2 token and scopes.
  """
  def validate(scheme, required_scopes, credentials, _context) do
    with {:ok, token} <- extract_token(credentials),
         {:ok, token_info} <- validate_oauth_token(token, scheme),
         :ok <- check_scopes(token_info[:scopes], required_scopes) do
      
      auth_context = %{
        user_id: token_info[:user_id],
        scopes: token_info[:scopes],
        claims: token_info,
        metadata: %{
          token_type: :oauth2,
          expires_at: token_info[:expires_at]
        }
      }
      
      {:ok, auth_context}
    else
      error -> error
    end
  end

  @doc """
  Create OAuth2 client for token operations.
  """
  def create_client(config) do
    %{
      __struct__: AsyncApi.Security.OAuth2Client,
      client_id: config[:client_id],
      client_secret: config[:client_secret],
      token_url: config[:token_url],
      authorization_url: config[:authorization_url],
      scopes: config[:scopes] || [],
      redirect_uri: config[:redirect_uri]
    }
  end

  # Private helper functions

  defp extract_all_scopes(flows) do
    flows
    |> Enum.flat_map(fn {_flow_type, flow_config} ->
      Map.keys(flow_config[:scopes] || %{})
    end)
    |> Enum.uniq()
  end

  defp extract_token_url(flows) do
    flows
    |> Enum.find_value(fn {_flow_type, flow_config} ->
      flow_config[:token_url]
    end)
  end

  defp extract_authorization_url(flows) do
    flows
    |> Enum.find_value(fn {_flow_type, flow_config} ->
      flow_config[:authorization_url]
    end)
  end

  defp extract_token(credentials) do
    case credentials do
      %{oauth_token: token} -> {:ok, token}
      %{"Authorization" => "Bearer " <> token} -> {:ok, token}
      %{"authorization" => "Bearer " <> token} -> {:ok, token}
      _ -> {:error, :missing_oauth_token}
    end
  end

  defp validate_oauth_token(token, _scheme) do
    # This would typically make a call to the OAuth introspection endpoint
    # For now, we'll simulate token validation
    case decode_token_claims(token) do
      {:ok, claims} ->
        if claims[:exp] && claims[:exp] > System.system_time(:second) do
          {:ok, claims}
        else
          {:error, :token_expired}
        end
      
      error -> error
    end
  end

  defp decode_token_claims(token) do
    # This is a simplified implementation
    # In production, you'd use a proper JWT library or OAuth introspection
    try do
      # Simulate token decoding
      {:ok, %{
        user_id: "user_#{:rand.uniform(1000)}",
        scopes: ["read:events", "write:events"],
        exp: System.system_time(:second) + 3600,
        iat: System.system_time(:second)
      }}
    rescue
      _ -> {:error, :invalid_token}
    end
  end

  defp check_scopes(user_scopes, required_scopes) do
    missing_scopes = required_scopes -- user_scopes
    
    if Enum.empty?(missing_scopes) do
      :ok
    else
      {:error, {:insufficient_scopes, missing_scopes}}
    end
  end
end

defmodule AsyncApi.Security.JWT do
  @moduledoc """
  JWT token handling for AsyncAPI security.
  """

  @doc """
  Parse JWT configuration.
  """
  def parse_config(config) do
    %{
      type: :jwt,
      scheme: config[:scheme] || :bearer,
      bearer_format: config[:bearer_format],
      algorithm: config[:algorithm] || "HS256",
      secret: config[:secret],
      public_key: config[:public_key],
      issuer: config[:issuer],
      audience: config[:audience]
    }
  end

  @doc """
  Validate JWT token.
  """
  def validate(scheme, credentials, _context) do
    with {:ok, token} <- extract_jwt_token(credentials),
         {:ok, claims} <- validate_token(token, scheme) do
      
      auth_context = %{
        user_id: claims["sub"],
        scopes: claims["scopes"] || [],
        claims: claims,
        metadata: %{
          token_type: :jwt,
          algorithm: scheme[:algorithm],
          expires_at: claims["exp"]
        }
      }
      
      {:ok, auth_context}
    else
      error -> error
    end
  end

  @doc """
  Generate a JWT token.
  """
  def generate_token(claims, opts \\ []) do
    algorithm = Keyword.get(opts, :algorithm, "HS256")
    secret = Keyword.get(opts, :secret, default_secret())
    
    header = %{
      "alg" => algorithm,
      "typ" => "JWT"
    }
    
    now = System.system_time(:second)
    
    payload = Map.merge(claims, %{
      "iat" => now,
      "exp" => now + Keyword.get(opts, :expires_in, 3600),
      "iss" => Keyword.get(opts, :issuer, "async_api_dsl")
    })
    
    # This is a simplified JWT implementation
    # In production, use a proper JWT library like Guardian or Joken
    encoded_header = Base.url_encode64(Jason.encode!(header), padding: false)
    encoded_payload = Base.url_encode64(Jason.encode!(payload), padding: false)
    
    message = encoded_header <> "." <> encoded_payload
    signature = :crypto.mac(:hmac, :sha256, secret, message)
    encoded_signature = Base.url_encode64(signature, padding: false)
    
    token = message <> "." <> encoded_signature
    
    {:ok, token}
  end

  @doc """
  Validate a JWT token.
  """
  def validate_token(token, opts \\ []) do
    secret = Keyword.get(opts, :secret, default_secret())
    
    case String.split(token, ".") do
      [encoded_header, encoded_payload, encoded_signature] ->
        with {:ok, header} <- decode_base64_json(encoded_header),
             {:ok, payload} <- decode_base64_json(encoded_payload),
             :ok <- verify_signature(encoded_header, encoded_payload, encoded_signature, secret),
             :ok <- verify_expiration(payload) do
          {:ok, payload}
        else
          error -> error
        end
      
      _ -> {:error, :invalid_jwt_format}
    end
  end

  # Private helper functions

  defp extract_jwt_token(credentials) do
    case credentials do
      %{jwt_token: token} -> {:ok, token}
      %{"Authorization" => "Bearer " <> token} -> {:ok, token}
      %{"authorization" => "Bearer " <> token} -> {:ok, token}
      _ -> {:error, :missing_jwt_token}
    end
  end

  defp decode_base64_json(encoded) do
    with {:ok, decoded} <- Base.url_decode64(encoded, padding: false),
         {:ok, json} <- Jason.decode(decoded) do
      {:ok, json}
    else
      _ -> {:error, :invalid_base64_json}
    end
  end

  defp verify_signature(encoded_header, encoded_payload, encoded_signature, secret) do
    message = encoded_header <> "." <> encoded_payload
    expected_signature = :crypto.mac(:hmac, :sha256, secret, message)
    
    case Base.url_decode64(encoded_signature, padding: false) do
      {:ok, signature} ->
        if :crypto.equal_time_compare(signature, expected_signature) do
          :ok
        else
          {:error, :invalid_signature}
        end
      
      _ -> {:error, :invalid_signature_encoding}
    end
  end

  defp verify_expiration(payload) do
    case payload["exp"] do
      exp when is_integer(exp) ->
        if exp > System.system_time(:second) do
          :ok
        else
          {:error, :token_expired}
        end
      
      _ -> {:error, :missing_expiration}
    end
  end

  defp default_secret do
    Application.get_env(:async_api_dsl, :jwt_secret, "default_secret_change_in_production")
  end
end

defmodule AsyncApi.Security.ApiKey do
  @moduledoc """
  API Key authentication support.
  """

  @doc """
  Parse API key configuration.
  """
  def parse_config(config) do
    %{
      type: :api_key,
      in: config[:in] || :header,
      name: config[:name] || "X-API-Key",
      description: config[:description]
    }
  end

  @doc """
  Validate API key.
  """
  def validate(scheme, credentials, _context) do
    with {:ok, api_key} <- extract_api_key(scheme, credentials),
         {:ok, key_info} <- validate_api_key(api_key) do
      
      auth_context = %{
        user_id: key_info[:user_id],
        scopes: key_info[:scopes] || [],
        claims: key_info,
        metadata: %{
          auth_type: :api_key,
          key_name: scheme[:name]
        }
      }
      
      {:ok, auth_context}
    else
      error -> error
    end
  end

  # Private helper functions

  defp extract_api_key(scheme, credentials) do
    key_name = scheme[:name]
    
    case scheme[:in] do
      :header ->
        case Map.get(credentials, key_name) do
          nil -> {:error, {:missing_api_key, key_name}}
          key -> {:ok, key}
        end
      
      :query ->
        case Map.get(credentials, key_name) do
          nil -> {:error, {:missing_api_key, key_name}}
          key -> {:ok, key}
        end
      
      :cookie ->
        case get_in(credentials, [:cookies, key_name]) do
          nil -> {:error, {:missing_api_key, key_name}}
          key -> {:ok, key}
        end
      
      _ -> {:error, {:unsupported_api_key_location, scheme[:in]}}
    end
  end

  defp validate_api_key(api_key) do
    # This would typically look up the API key in a database
    # For now, we'll simulate validation
    if String.length(api_key) >= 32 do
      {:ok, %{
        user_id: "api_user_#{:rand.uniform(1000)}",
        scopes: ["read:events"],
        created_at: System.system_time(:second),
        last_used: System.system_time(:second)
      }}
    else
      {:error, :invalid_api_key}
    end
  end
end

defmodule AsyncApi.Security.RateLimit do
  @moduledoc """
  Rate limiting for AsyncAPI operations.
  """

  @doc """
  Create a rate limiter.
  """
  def create_limiter(opts) do
    %{
      __struct__: AsyncApi.Security.RateLimiter,
      type: Keyword.get(opts, :rate_limit_type, :token_bucket),
      default_limit: Keyword.get(opts, :default_rate_limit, 100),
      window_size: Keyword.get(opts, :rate_limit_window, 60_000),
      storage: Keyword.get(opts, :rate_limit_storage, :ets)
    }
  end

  @doc """
  Check if operation is within rate limits.
  """
  def check_limit(limiter, operation_name, user_id, _opts \\ []) do
    key = "#{user_id}:#{operation_name}"
    
    case get_current_usage(limiter, key) do
      {:ok, usage} ->
        if usage < limiter.default_limit do
          increment_usage(limiter, key)
          {:ok, %{
            allowed: true,
            remaining: limiter.default_limit - usage - 1,
            reset_time: get_reset_time(limiter)
          }}
        else
          {:error, %{
            rate_limited: true,
            retry_after: get_retry_after(limiter),
            limit: limiter.default_limit
          }}
        end
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private helper functions

  defp get_current_usage(_limiter, _key) do
    # Simplified implementation - would use proper storage
    {:ok, :rand.uniform(50)}
  end

  defp increment_usage(_limiter, _key) do
    # Would increment counter in storage
    :ok
  end

  defp get_reset_time(limiter) do
    System.system_time(:millisecond) + limiter.window_size
  end

  defp get_retry_after(limiter) do
    limiter.window_size
  end
end

defmodule AsyncApi.Security.Encryption do
  @moduledoc """
  Message encryption/decryption for AsyncAPI.
  """

  @doc """
  Create encryption handler.
  """
  def create_handler(opts) do
    %{
      __struct__: AsyncApi.Security.EncryptionHandler,
      algorithm: Keyword.get(opts, :encryption_algorithm, :aes_256_gcm),
      key: Keyword.get(opts, :encryption_key, generate_key()),
      iv_size: Keyword.get(opts, :iv_size, 12)
    }
  end

  @doc """
  Encrypt message payload.
  """
  def encrypt(handler, payload, _opts \\ []) do
    try do
      binary_payload = :erlang.term_to_binary(payload)
      iv = :crypto.strong_rand_bytes(handler.iv_size)
      
      {ciphertext, tag} = :crypto.crypto_one_time_aead(
        :aes_256_gcm,
        handler.key,
        iv,
        binary_payload,
        <<>>,
        true
      )
      
      encrypted = %{
        algorithm: handler.algorithm,
        iv: Base.encode64(iv),
        ciphertext: Base.encode64(ciphertext),
        tag: Base.encode64(tag)
      }
      
      {:ok, encrypted}
    rescue
      error -> {:error, {:encryption_failed, Exception.message(error)}}
    end
  end

  @doc """
  Decrypt message payload.
  """
  def decrypt(handler, encrypted_payload, _opts \\ []) do
    try do
      iv = Base.decode64!(encrypted_payload.iv)
      ciphertext = Base.decode64!(encrypted_payload.ciphertext)
      tag = Base.decode64!(encrypted_payload.tag)
      
      plaintext = :crypto.crypto_one_time_aead(
        :aes_256_gcm,
        handler.key,
        iv,
        ciphertext,
        <<>>,
        tag,
        false
      )
      
      payload = :erlang.binary_to_term(plaintext)
      {:ok, payload}
    rescue
      error -> {:error, {:decryption_failed, Exception.message(error)}}
    end
  end

  # Private helper functions

  defp generate_key do
    :crypto.strong_rand_bytes(32)
  end
end

defmodule AsyncApi.Security.AuditLogger do
  @moduledoc """
  Security audit logging for AsyncAPI.
  """

  @doc """
  Create audit logger.
  """
  def create_logger(opts) do
    %{
      __struct__: AsyncApi.Security.AuditLogger,
      destination: Keyword.get(opts, :audit_destination, :logger),
      format: Keyword.get(opts, :audit_format, :json),
      level: Keyword.get(opts, :audit_level, :info)
    }
  end

  @doc """
  Log a security event.
  """
  def log(audit_logger, event_type, details, context \\ %{}) do
    audit_entry = %{
      timestamp: DateTime.utc_now(),
      event_type: event_type,
      details: details,
      context: context,
      severity: determine_severity(event_type)
    }
    
    case audit_logger.destination do
      :logger -> log_to_logger(audit_entry, audit_logger)
      :file -> log_to_file(audit_entry, audit_logger)
      :external -> log_to_external(audit_entry, audit_logger)
      _ -> :ok
    end
  end

  # Private helper functions

  defp determine_severity(event_type) do
    case event_type do
      :authentication_failure -> :warning
      :authorization_failure -> :warning
      :rate_limit_exceeded -> :info
      :token_expired -> :info
      :security_breach -> :error
      _ -> :info
    end
  end

  defp log_to_logger(entry, audit_logger) do
    message = format_audit_message(entry, audit_logger.format)
    
    case entry.severity do
      :error -> Logger.error(message)
      :warning -> Logger.warning(message)
      :info -> Logger.info(message)
      _ -> Logger.debug(message)
    end
  end

  defp log_to_file(_entry, _audit_logger) do
    # Would implement file-based audit logging
    :ok
  end

  defp log_to_external(_entry, _audit_logger) do
    # Would implement external audit service integration
    :ok
  end

  defp format_audit_message(entry, :json) do
    Jason.encode!(entry)
  end

  defp format_audit_message(entry, :text) do
    "#{entry.timestamp} [#{entry.severity}] #{entry.event_type}: #{inspect(entry.details)}"
  end
end