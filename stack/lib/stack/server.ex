defmodule Stack.Server do
  use GenServer

  def init(initial_state \\ []) when is_list(initial_state) do
    {:ok, initial_state}
  end

  def handle_call(:pop, _from, [h | t]) do
    {:reply, h, t}
  end

  def handle_cast({:push, value}, stack) do
    {:noreply, [value | stack]}
  end
end
