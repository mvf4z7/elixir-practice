defmodule MyList do
  def mapsum(list, func), do: _mapsum(list, func, 0)
  defp _mapsum([], _func, sum), do: sum
  defp _mapsum([head | tail], func, sum), do: _mapsum(tail, func, sum + func.(head))

  def max([head | tail]), do: _max(tail, head)
  defp _max([], current_max), do: current_max
  defp _max([head | tail], current_max) do
    if head > current_max do
      _max(tail, head)
    else
      _max(tail, current_max)
    end
  end

  def caesar(list, shift), do: _caesar(list, shift, [])
  defp _caesar([head | tail], shift, result) do
    shifted = rem((head - 97) + shift, 26) + 97
    _caesar(tail, shift, result ++ [shifted])
  end
  defp _caesar([], _shift, result), do: result

  def span(from, to), do: _span(from, to, [])
  defp _span(from, to, result) when from == to, do: [from | result ]
  defp _span(from, to, result) when from < to, do: _span(from, to - 1, [to | result])

  def flatten(list), do: flatten(list, []) |> Enum.reverse
  defp flatten([head | tail], acc) when head == [], do: flatten(tail, acc)
  defp flatten([head | tail], acc) when is_list(head), do: flatten(tail, flatten(head, acc))
  defp flatten([head | tail], acc), do: flatten(tail, [head | acc])
  defp flatten([], acc), do: acc

  def center(list) when is_list(list), do: _center(list, Enum.map(list, &String.length/1) |> Enum.max, [])
  defp _center([], _, acc), do: Enum.reverse(acc) |> Enum.map(&IO.puts/1)
  defp _center([h | t], max_width, acc) when is_binary h do
    diff = max_width - String.length(h)
    lpad = div diff, 2
    h_length = String.length h
    padded = String.pad_leading(h, lpad + h_length) |> String.pad_trailing(max_width)
    _center(t, max_width, [padded | acc])
  end

  def capitalize_sentences(str, pattern \\ ". ") when is_binary(str) do
    str
      |> String.split(pattern)
      |> Enum.map(&String.capitalize/1)
      |> Enum.join(pattern)
  end
end
