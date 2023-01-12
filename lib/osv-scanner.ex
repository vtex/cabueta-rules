defmodule OsvScanner do
  @behaviour Tool

  def to_markdown(nil) do
    ""
  end

  def to_markdown(reports) do
    title = fn x ->
      p = x["package"]
      "`#{p["name"]}:#{p["version"]}` (#{p["ecosystem"]})"
    end

    body = fn x ->
      "[#{x["database_specific"]["severity"]}] `#{x["aliases"] |> Enum.join(", ")}` #{x["summary"]}; #{x["details"]}"
    end

    details =
      reports
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
    |> then(fn x ->
      if is_nil(x) do
        nil
      else
        x
        |> Map.get("results")
        |> then(fn x ->
          case x do
            [_ | _]  ->
              x |> hd |> Map.get("packages")

            _any ->
              nil
          end
        end)
      end
    end)
  end

  def test_report() do
    ["./example-reports/osv-scanner.json"]
  end

  def id() do
    :osv_scanner
  end
end
