defmodule Vault.Auth.JWTTest do
  use ExUnit.Case, async: true

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  @credentials %{role: "valid-role", jwt: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"}
  @valid_response %{
    "auth" => %{
      "client_token" => "valid_token",
      "accessor" => "0e9e354a-520f-df04-6867-ee81cae3d42d",
      "policies" => [
        "default",
        "dev",
        "prod"
      ],
      "lease_duration" => 2_764_800,
      "renewable" => true
    }
  }

  test "JWT login with valid credentials", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/auth/jwt/login", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "role" => "valid-role",
               "jwt" => "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
             }

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(@valid_response))
    end)

    {:ok, client} =
      Vault.new(
        host: "http://localhost:#{bypass.port}",
        auth: Vault.Auth.JWT,
        http: Vault.HTTP.Tesla
      )
      |> Vault.auth(@credentials)

    assert Vault.token_expired?(client) == false
    assert client.token == "valid_token"
    assert client.credentials == @credentials
  end

  test "JWT login with string-map credentials", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/auth/azure/login", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "role" => "valid-role",
               "jwt" => "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
             }

      response = @valid_response

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(response))
    end)

    string_credentials = %{
      "role" => "valid-role",
      "jwt" => "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    }

    {:ok, client} =
      Vault.new(
        host: "http://localhost:#{bypass.port}",
        auth: Vault.Auth.Azure,
        http: Vault.HTTP.Tesla
      )
      |> Vault.auth(string_credentials)

    assert Vault.token_expired?(client) == false
    assert client.token == "valid_token"
    assert client.credentials == string_credentials
  end

  test "JWT login with custom path", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/auth/justwebtokens/login", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "role" => "valid-role",
               "jwt" => "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
             }

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(@valid_response))
    end)

    {:ok, client} =
      Vault.new(
        host: "http://localhost:#{bypass.port}",
        auth: Vault.Auth.JWT,
        auth_path: "justwebtokens",
        http: Vault.HTTP.Tesla
      )
      |> Vault.auth(@credentials)

    assert Vault.token_expired?(client) == false
    assert client.token == "valid_token"
    assert client.credentials == @credentials
  end

  test "JWT login with invalid credentials", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/auth/jwt/login", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(401, Jason.encode!(%{errors: ["Invalid Credentials"]}))
    end)

    {:error, reason} =
      Vault.new(
        host: "http://localhost:#{bypass.port}",
        auth: Vault.Auth.JWT,
        http: Vault.HTTP.Tesla
      )
      |> Vault.auth(@credentials)

    assert reason == ["Invalid Credentials"]
  end

  test "JWT login with non-spec response", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/auth/jwt/login", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(401, Jason.encode!(%{problems: ["misconfigured"]}))
    end)

    {:error, [reason | _]} =
      Vault.new(
        host: "http://localhost:#{bypass.port}",
        auth: Vault.Auth.JWT,
        http: Vault.HTTP.Tesla
      )
      |> Vault.auth(@credentials)

    assert reason =~ "Unexpected response from vault"
  end

  test "JWT login without a role" do
    {:error, [reason | _]} =
      Vault.new(
        host: "http://localhost",
        auth: Vault.Auth.JWT,
        http: Vault.HTTP.Tesla
      )
      |> Vault.auth(%{jwt: "present"})

    assert reason =~ "Missing credentials"
  end

  test "JWT login without a jwt" do
    {:error, [reason | _]} =
      Vault.new(
        host: "http://localhost",
        auth: Vault.Auth.JWT,
        http: Vault.HTTP.Tesla
      )
      |> Vault.auth(%{role: "role"})

    assert reason =~ "Missing credentials"
  end

  test "JWT login with http adapter error" do
    {:error, [reason | _]} =
      Vault.new(
        host: "http://localhost",
        auth: Vault.Auth.JWT,
        http: Vault.Http.Test
      )
      |> Vault.auth(%{role: "error", jwt: "error"})

    assert reason =~ "Http adapter error"
  end
end
