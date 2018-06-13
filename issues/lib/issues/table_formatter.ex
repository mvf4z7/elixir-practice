defmodule Issues.TableFormatter do
  import Enum, only: [each: 2, map: 2, map_join: 3, max: 1, zip: 2]

  def print_table_for_columns(rows, headers) do
    with data_by_columns = split_into_columns(rows, headers),
         column_widths = widths_of(data_by_columns) do
      print_row(headers, column_widths)
      print_divider(column_widths)
      print_rows(data_by_columns, column_widths)
    end
  end

  def split_into_columns(rows, headers) do
    for header <- headers do
      for row <- rows, do: printable(row[header])
    end
  end

  def printable(str) when is_binary(str), do: str
  def printable(other), do: to_string(other)

  def widths_of(columns) do
    for col <- columns, do: col |> map(&String.length/1) |> max
  end

  def print_divider(column_widths) do
    column_widths
    # |> map(&String.duplicate("-", &1))
    |> map_join("-+-", &String.duplicate("-", &1))
    |> IO.puts()
  end

  def print_rows(data_by_columns, column_widths) do
    data_by_columns
    |> List.zip()
    |> map(&Tuple.to_list/1)
    |> each(&print_row(&1, column_widths))
  end

  def print_row(row, column_widths) do
    row
    |> zip(column_widths)
    |> map_join(" | ", fn {el, width} -> String.pad_trailing(el, width) end)
    |> IO.puts()
  end
end
