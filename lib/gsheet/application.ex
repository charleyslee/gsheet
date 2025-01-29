defmodule GSheet.Application do
  @moduledoc """
  Bootstrap Google Sheets application.
  """
  use Application

  def start(_type, _args) do
    credentials =
      case Application.fetch_env(:gsheet, :service_account_json) do
        {:ok, json} -> json
        :error -> System.fetch_env!("LB_GOOGLE_SERVICE_ACCOUNT_JSON")
      end
      |> JSON.decode!()

    claims = %{
      "sub" => System.fetch_env!("LB_GOOGLE_SERVICE_ACCOUNT_EMAIL"),
      "scope" => "https://www.googleapis.com/auth/spreadsheets"
    }

    source = {:service_account, credentials, claims: claims}

    children = [
      {Goth, name: GSheet.Goth, source: source}
    ]

    Supervisor.start_link(children, strategy: :one_for_all)
  end

  @doc """
  Read config settings scoped for GSS.
  """
  @spec config(atom(), any()) :: any()
  def config(key, default \\ nil) do
    Application.get_env(:gsheet, key, default)
  end
end
