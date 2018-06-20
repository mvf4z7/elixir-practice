defmodule Pooly do
  use Application

  alias Pooly.PoolConfig, as: PoolConfig

  def start(_type, _args) do
    base_pool_config = %PoolConfig{name: nil, worker_module: Pooly.SampleWorker, size: 5}

    pools_config = [
      %{base_pool_config | name: "Pool1"},
      %{base_pool_config | name: "Pool2"},
      %{base_pool_config | name: "Pool3"}
    ]

    start_pools(pools_config)
  end

  def start_pools(pools_config) do
    Pooly.Supervisor.start_link(pools_config)
  end

  def checkout(pool_name) do
    Pooly.Server.checkout(pool_name)
  end

  def checkin(pool_name, worker_pid) do
    Pooly.Server.checkin(pool_name, worker_pid)
  end

  def status(pool_name) do
    Pooly.Server.status(pool_name)
  end
end
