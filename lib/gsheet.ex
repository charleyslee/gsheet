defmodule GSheet do
  @moduledoc """
  Documentation for `GSheet`.
  """
  alias __MODULE__

  defstruct [:spreadsheet_id, :sheet, :columns, :data]

  def get_sheet(spreadsheet_id, sheet, opts \\ []) do
    id_column = Keyword.get(opts, :id_column, :id)
    starting_row = Keyword.get(opts, :starting_row, 1)

    [first_row | rows] =
      Req.get!(
        gsheet_request(),
        url: "/#{spreadsheet_id}/values/#{sheet}"
      ).body["values"]
      |> Enum.drop(starting_row - 1)

    columns = first_row |> Enum.map(&String.to_atom(&1))

    id_index =
      Enum.find_index(columns, &(&1 == id_column)) ||
        raise "sheet must have an #{id_column} column"

    data =
      rows
      |> Enum.with_index(2)
      |> Enum.map(fn {row, row_num} ->
        case Enum.at(row, id_index) do
          row_id when row_id in [nil, ""] ->
            nil

          row_id ->
            to_pad = max(length(columns) - length(row), 0)
            padded_row = row ++ List.duplicate(nil, to_pad)
            {row_id, {row_num, padded_row}}
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Map.new()

    %GSheet{
      spreadsheet_id: spreadsheet_id,
      sheet: sheet,
      columns: columns,
      data: data
    }
  end

  def refresh(%GSheet{spreadsheet_id: spreadsheet_id, sheet: sheet}) do
    get_sheet(spreadsheet_id, sheet)
  end

  def to_rows(%GSheet{columns: columns, data: data}) do
    data
    |> Enum.sort_by(fn {_, {row_num, _}} -> row_num end)
    |> Enum.map(fn {_, {_, row}} ->
      Enum.zip(columns, row) |> Map.new()
    end)
  end

  def append_rows(%GSheet{} = sheet, rows) do
    final_row = Enum.count(sheet.data) + 1

    Req.post!(
      gsheet_request(),
      url:
        "#{sheet.spreadsheet_id}/values/#{sheet.sheet}!#{final_row}:#{final_row}:append?valueInputOption=RAW",
      json: %{values: rows}
    )

    refresh(sheet)
  end

  def update_row(%GSheet{} = sheet, row_id, row) do
    {row_num, original_row} = sheet.data[row_id]
    row_map = Enum.into(row, %{})

    ordered_row =
      Enum.zip(sheet.columns, original_row)
      |> Enum.map(fn {column, original_value} ->
        row_map[column] || original_value
      end)

    Req.put!(
      gsheet_request(),
      url:
        "#{sheet.spreadsheet_id}/values/#{sheet.sheet}!#{row_num}:#{row_num}?valueInputOption=RAW",
      json: %{values: [ordered_row]}
    )

    %{sheet | data: Map.put(sheet.data, row_id, {row_num, ordered_row})}
  end

  def get_cell(%GSheet{columns: columns, data: data}, row_id, column) do
    with col_index when col_index != nil <- Enum.find_index(columns, &(&1 == column)),
         {_, row} <- data[row_id] do
      {:ok, Enum.at(row, col_index)}
    else
      nil -> :error
    end
  end

  def set_cell(%GSheet{} = sheet, row_id, column, value) do
    {row_num, _} = sheet.data[row_id]

    col_index =
      Enum.find_index(sheet.columns, &(&1 == column)) || raise "column #{column} not found"

    cell = convert_to_excel_column(col_index) <> Integer.to_string(row_num)

    %Req.Response{status: 200} =
      Req.put!(
        gsheet_request(),
        url: "#{sheet.spreadsheet_id}/values/#{sheet.sheet}!#{cell}:#{cell}?valueInputOption=RAW",
        json: %{
          values: [[value]]
        }
      )

    sheet
  end

  def convert_to_excel_column(index) when index < 26, do: <<index + ?A>>

  def convert_to_excel_column(index) do
    q = div(index, 26)
    r = rem(index, 26)
    convert_to_excel_column(q - 1) <> <<r + ?A>>
  end

  defp gsheet_request() do
    access_token = Goth.fetch!(GSheet.Goth).token

    Req.new(
      base_url: "https://sheets.googleapis.com/v4/spreadsheets",
      auth: {:bearer, access_token}
    )
  end
end
