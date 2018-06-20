defmodule Pooly.Server do
  use GenServer

  alias Pooly.PoolConfig, as: PoolConfig

  # defmodule PoolConfig do
  #   @enforce_keys [:worker_module, :size, :name]
  #   defstruct worker_module: nil, worker_args: [], size: nil, name: nil
  # end

  # API
  def start_link(pools_config) do
    GenServer.start_link(__MODULE__, pools_config, name: __MODULE__)
  end

  def checkout(pool_name) when is_binary(pool_name) do
    GenServer.call(name(pool_name), :checkout)
  end

  def checkin(pool_name, worker_pid) when is_binary(pool_name) and is_pid(worker_pid) do
    GenServer.cast(name(pool_name), {:checkin, worker_pid})
  end

  def status(pool_name) when is_binary(pool_name) do
    GenServer.call(name(pool_name), :status)
  end

  # Callbacks
  def init(pools_config) do
    # monitors = :ets.new(:monitors, [:private])
    # send(self(), :start_worker_supervisor)
    # {:ok, %State{sup: sup, monitors: monitors, pool_config: pool_config}}

    pools_config
    |> Enum.each(fn %PoolConfig{} = pool_config ->
      send(self(), {:start_pool, pool_config})
    end)

    {:ok, pools_config}
  end

  def handle_info({:start_pool, %PoolConfig{} = pool_config}, state) do
    {:ok, _pool_sup} = Supervisor.start_child(Pooly.PoolsSupervisor, supervisor_spec(pool_config))
    {:noreply, state}
  end

  # Private Functions
  defp name(pool_name) when is_binary(pool_name) do
    :"#{pool_name}Server"
  end

  defp supervisor_spec(%PoolConfig{name: pool_name} = pool_config) do
    # Must provide an id, otherwise an :already_started error will be returned
    # once a second pool is started.
    Supervisor.child_spec({Pooly.PoolSupervisor, pool_config}, id: :"#{pool_name}Supervisor")
  end
end
