defmodule Exercise2 do
  def run() do
    first = spawn(Exercise2, :reply, [])
    second = spawn(Exercise2, :reply, [])

    send(first, {self(), :first_token})
    send(second, {self(), :second_token})

    receive do
      {^second, token} -> IO.puts(token)
    end

    receive do
      {^first, token} -> IO.puts(token)
    end
  end

  def reply do
    receive do
      {sender, token} ->
        send(sender, {self(), token})
    end
  end
end

defmodule Exercise3 do
  def run() do
    spawn_link(Exercise3, :child, [self()])
    IO.puts("starting sleep")
    :timer.sleep(500)
    IO.puts("done sleeping")
    flush()
  end

  def child(parent_pid) do
    send(parent_pid, :child)
    # exit(:child_exit)
    raise "child_raise"
  end

  def flush() do
    receive do
      message ->
        IO.inspect(message)
        flush()
    after
      1000 ->
        IO.puts("All messages received")
    end
  end
end
