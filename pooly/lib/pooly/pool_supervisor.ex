defmodule Pooly.PoolSupervisor do
  use Supervisor

  alias Pooly.PoolConfig, as: PoolConfig

  def start_link(%PoolConfig{name: pool_name} = pool_config) do
    Supervisor.start_link(__MODULE__, pool_config, name: :"#{pool_name}Supervisor")
  end

  def init(pool_config) do
    children = [
      {Pooly.PoolServer, [self(), pool_config]}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
