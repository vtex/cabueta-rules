defmodule OsvScanner do
  @behaviour Tool

  def to_markdown(nil) do
    ""
  end

  def to_markdown(reports) do
    # reports |> dbg()
    IO.puts(:stderr, "A")

    title = fn x ->
      IO.puts(:stderr, "C")
      p = x["package"]
      "`#{p["name"]}:#{p["version"]}` (#{p["ecosystem"]})"
      IO.puts(:stderr, "D")
    end

    safe_str = fn
      nil -> ""
      x -> x
    end

    body = fn x ->
      "[#{x["database_specific"]["severity"] |> then(safe_str)}] `#{x["aliases"] |> then(fn
        x when is_atom(x) -> [""]
        x -> x
      end) |> Enum.join(", ")}` #{x["summary"]}; #{x["details"]}"
    end

    IO.puts(:stderr, "B")

    details =
      reports
      |> Enum.filter(fn r ->
        Map.has_key?(r, "vulnerabilities") && length(r["vulnerabilities"]) > 0
      end)
      # |> dbg()
      |> Enum.map(fn report ->
        Markdown.list(title.(report), Map.get(report, "vulnerabilities") |> Enum.map(body))
      end)
      |> Enum.join("\n")

    Markdown.toggle_stats("Vulnerable Dependencies", length(reports), details) |> IO.puts()
  end

  def process_report(data) do
    data
    # here
    |> Main.read_json_file()
    |> Map.get(:json)
    |> then(fn
      nil ->
        nil

      x ->
        x
        |> Map.get("results")
        |> then(fn
          [_ | _] = list ->
            list |> hd |> Map.get("packages")

          nil ->
            nil

          x ->
            x |> Map.get("packages")
        end)
    end)
  end

  def test_report() do
    ["./example-reports/osv-scanner.json"]
  end

  def id() do
    :osv_scanner
  end
end
