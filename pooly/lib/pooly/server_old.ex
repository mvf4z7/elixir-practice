defmodule Pooly.ServerOld do
  use GenServer

  defmodule State do
    defstruct [:sup, :worker_sup, :monitors, :workers, :pool_config]
  end

  defmodule PoolConfig do
    @enforce_keys [:worker_module, :size, :name]
    defstruct worker_module: nil, worker_args: [], size: nil, name: nil
  end

  # API
  def start_link([sup, %PoolConfig{} = pool_config]) when is_pid(sup) do
    IO.puts("Pooly.Server start_link")
    GenServer.start_link(__MODULE__, [sup, pool_config], name: __MODULE__)
  end

  def checkout() do
    GenServer.call(__MODULE__, :checkout)
  end

  def checkin(worker_pid) when is_pid(worker_pid) do
    GenServer.cast(__MODULE__, {:checkin, worker_pid})
  end

  def status do
    GenServer.call(__MODULE__, :status)
  end

  # Callbacks
  def init([sup, pool_config]) do
    monitors = :ets.new(:monitors, [:private])
    send(self(), :start_worker_supervisor)
    {:ok, %State{sup: sup, monitors: monitors, pool_config: pool_config}}
  end

  def handle_info(:start_worker_supervisor, state = %{sup: sup, pool_config: pool_config}) do
    {:ok, worker_sup} = Supervisor.start_child(sup, Pooly.WorkerSupervisor)

    # The server needs to be linked to the WorkerSupervisor because the
    # WorkerSupervisor has a restart strategy of :temporary. If a process with a
    # :temporary restart strategy is killed, it does not cause its Supervisor
    # to kill the the other children, even if the Supervisor has a :one_for_all
    # strategy.
    Process.link(worker_sup)

    workers = prepopulate(worker_sup, pool_config)
    {:noreply, %{state | worker_sup: worker_sup, workers: workers}}
  end

  def handle_call(:checkout, {from_pid, _ref}, %{workers: workers, monitors: monitors} = state) do
    case workers do
      [worker | rest] ->
        # Monitor the calling process
        ref = Process.monitor(from_pid)
        # Map from worker pid to calling process monitor ref
        true = :ets.insert(monitors, {worker, ref})
        {:reply, worker, %{state | workers: rest}}

      [] ->
        {:reply, :noproc, state}
    end
  end

  def handle_call(:status, _from, %{workers: workers, monitors: monitors} = state) do
    {:reply, {length(workers), :ets.info(monitors, :size)}, state}
  end

  def handle_cast({:checkin, worker}, %{workers: workers, monitors: monitors} = state) do
    case :ets.lookup(monitors, worker) do
      [{worker_pid, ref}] ->
        true = Process.demonitor(ref)
        true = :ets.delete(monitors, worker_pid)
        {:noreply, %{state | workers: [worker_pid | workers]}}

      [] ->
        {:noreply, state}
    end
  end

  # Private Functions
  defp prepopulate(worker_sup, %PoolConfig{size: size} = pool_config) do
    prepopulate(worker_sup, pool_config, size, [])
  end

  defp prepopulate(
         _worker_sup,
         _pool_config,
         remaining,
         workers
       )
       when remaining < 1 do
    workers
  end

  defp prepopulate(
         worker_sup,
         %PoolConfig{} = pool_config,
         remaining,
         workers
       ) do
    prepopulate(worker_sup, pool_config, remaining - 1, [
      new_worker(worker_sup, pool_config) | workers
    ])
  end

  defp new_worker(worker_sup, %PoolConfig{worker_module: worker_module, worker_args: worker_args}) do
    {:ok, worker} = Pooly.WorkerSupervisor.start_child(worker_sup, worker_module, worker_args)
    worker
  end
end
