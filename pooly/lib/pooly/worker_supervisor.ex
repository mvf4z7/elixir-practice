defmodule Pooly.WorkerSupervisor do
  # Want to use :temporary restart strategy because Pooly.Server is in charge
  # of starting the WorkerSupervisor. If it was not temporary, then the top
  # level supervisor would restart the WorkerSupervisor before Pooly.Server
  # could have a chance.
  use DynamicSupervisor, restart: :temporary

  #  API
  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, :ok)
  end

  def start_child(pid, worker_module, args \\ []) do
    DynamicSupervisor.start_child(
      pid,
      Supervisor.child_spec({worker_module, args}, restart: :temporary)
    )
  end

  # Callbacks
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one, max_restarts: 5, max_seconds: 5)
  end
end
