defmodule Pooly.PoolServer do
  use GenServer

  alias Pooly.PoolConfig, as: PoolConfig

  defmodule State do
    defstruct [:pool_sup, :worker_sup, :monitors, :workers, :pool_config]
  end

  # defmodule PoolConfig do
  #   @enforce_keys [:worker_module, :size, :name]
  #   defstruct worker_module: nil, worker_args: [], size: nil, name: nil
  # end

  # API
  def start_link([pool_sup, %PoolConfig{name: pool_name} = pool_config]) when is_pid(pool_sup) do
    GenServer.start_link(__MODULE__, [pool_sup, pool_config], name: name(pool_name))
  end

  def checkout(pool_name) do
    GenServer.call(name(pool_name), :checkout)
  end

  def checkin(pool_name, worker_pid) when is_pid(worker_pid) do
    GenServer.cast(name(pool_name), {:checkin, worker_pid})
  end

  def status(pool_name) do
    GenServer.call(name(pool_name), :status)
  end

  # Callbacks
  def init([pool_sup, pool_config]) do
    Process.flag(:trap_exit, true)
    monitors = :ets.new(:monitors, [:private])
    send(self(), :start_worker_supervisor)
    {:ok, %State{pool_sup: pool_sup, monitors: monitors, pool_config: pool_config}}
  end

  def handle_info(
        :start_worker_supervisor,
        state = %State{pool_sup: pool_sup, pool_config: pool_config}
      ) do
    {:ok, worker_sup} = Supervisor.start_child(pool_sup, Pooly.WorkerSupervisor)

    # The server needs to be linked to the WorkerSupervisor because the
    # WorkerSupervisor has a restart strategy of :temporary. If a process with a
    # :temporary restart strategy is killed, it does not cause its Supervisor
    # to kill the the other children, even if the Supervisor has a :one_for_all
    # strategy.
    Process.link(worker_sup)

    workers = prepopulate(worker_sup, pool_config)
    {:noreply, %{state | worker_sup: worker_sup, workers: workers}}
  end

  # This catches when a consumer process (process that called Pooly.checkout) goes
  # down, removes entry in monitors table, and returns process to pool
  def handle_info({:DOWN, ref, _, _, _}, state = %State{monitors: monitors, workers: workers}) do
    case :ets.match(monitors, {:"$1", ref}) do
      [[pid]] ->
        true = :ets.delete(monitors, pid)
        new_state = %{state | workers: [pid | workers]}
        {:no_reply, new_state}
    end
  end

  # Since we are trapping exits, we want to bring down the server when the
  # WorkerSupervisor goes down.
  def handle_info({:EXIT, worker_sup, reason}, state = %State{worker_sup: worker_sup}) do
    {:stop, reason, state}
  end

  # Catches when a worker process exits
  def handle_info(
        {:EXIT, worker_pid, _reason},
        state = %State{
          monitors: monitors,
          pool_config: pool_config,
          workers: workers,
          worker_sup: worker_sup
        }
      ) do
    case :ets.lookup(monitors, worker_pid) do
      # worker was checked out and had an associated monitor
      [{worker_pid, ref}] ->
        true = Process.demonitor(ref)
        true = :ets.delete(monitors, worker_pid)

      _ ->
        nil
    end

    new_state = %{state | workers: [new_worker(worker_sup, pool_config) | workers]}
    {:noreply, new_state}
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

  def terminate(_reason, _state) do
    :ok
  end

  # Private Functions
  defp name(pool_name) do
    :"#{pool_name}Server"
  end

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

    # This was not in the book, but I think it is required so that server is
    # notified when any of the worker processes exit.
    Process.link(worker)

    worker
  end
end
