defmodule Kiva.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      KivaWeb.Telemetry,
      Kiva.Repo,
      {DNSCluster, query: Application.get_env(:kiva, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Kiva.PubSub},
      {Task.Supervisor, name: Kiva.TaskSupervisor},
      # Start a worker by calling: Kiva.Worker.start_link(arg)
      # {Kiva.Worker, arg},
      # Start to serve requests, typically the last entry
      KivaWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Kiva.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    KivaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
