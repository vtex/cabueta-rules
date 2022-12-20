defmodule OsvScanner do
  @behaviour Tool

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
    |> Main.read_json_file()
    |> Map.get(:json)
    |> Map.get("results")
    |> hd
    |> Map.get("packages")
  end

  def test_report() do
    ["./example-reports/osv-scanner.json"]
  end

  def id() do
    :osv_scanner
  end
end
