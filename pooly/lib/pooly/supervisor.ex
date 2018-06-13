defmodule Pooly.Supervisor do
  use Supervisor

  alias Pooly.Server.PoolConfig, as: PoolConfig

  def start_link(%PoolConfig{} = pool_config) do
    Supervisor.start_link(__MODULE__, pool_config)
  end

  def init(pool_config) do
    children = [
      {Pooly.Server, [self(), pool_config]}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
