defmodule Pooly.PoolConfig do
  @enforce_keys [:worker_module, :size, :name]
  defstruct worker_module: nil, worker_args: [], size: nil, name: nil
end
