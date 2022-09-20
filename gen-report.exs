#! /usr/bin/env elixir 

# @TODO: Provide correct links to findings

Mix.install([{:jason, "~> 1.4"}, {:csv, "~> 2.4"}])

defmodule Tool do
  @doc """
  Operations common to processing reports from tools
  """
  @callback to_markdown([Map.t()]) :: String.t()
  @callback process_reports([String.t()]) :: [Map.t()]
  @callback test_report() :: String.t()
  @callback id() :: Atom.t()
end

defmodule Semgrep do
  @behaviour Tool

  @rules %{
    ignore: %{
      check_id: [],
      severity: []
    }
  }

  def rules, do: @rules

  def extract_data(%{:json => contents}) do
    contents["results"]
    |> Enum.map(fn x ->
      case x do
        %{
          "path" => path,
          "start" => %{"line" => start_line},
          "check_id" => check_id,
          "extra" => %{
            "message" => message,
            "severity" => severity
          }
        } ->
          %{
            path: path,
            line: start_line,
            severity: severity,
            check_id: check_id,
            message: message
          }

        _ ->
          {:error, "Didn't match", x} |> IO.inspect()
      end
    end)
  end

  def extract_data(_pass) do
  end

  def filter_rules(report, rules) do
    ans =
      rules
      |> Enum.map(fn {k, v} -> matches_rule(Map.fetch(report, k), v) end)
      |> Enum.any?()

    not ans
  end

  def filter_ignored(reports) do
    reports |> Enum.filter(&Semgrep.filter_rules(&1, Semgrep.rules().ignore))
  end

  def matches_rule({:ok, val}, rule) do
    Enum.member?(rule, val)
  end

  def matches_rule(_any, _rule) do
    false
  end

  def remove_details(reports) do
    reports |> Enum.map(fn {freq, k, _lines} -> {freq, k} end)
  end

  def group_reports(reports) do
    report_key = fn x -> %{severity: x.severity, id: x.check_id, message: x.message} end
    report_value = fn x -> %{path: x.path, line: x.line} end

    reports
    |> Enum.group_by(report_key, report_value)
    |> Enum.map(fn {k, v} -> %{freq: length(v), meta: k, data: v} end)
    |> Enum.sort()
    |> Enum.reverse()
  end

  def to_csv(reports) do
    reports
    |> Enum.map(fn {freq, {type, id, message}} -> [freq, type, id, message] end)
    |> CSV.encode()
    |> Enum.to_list()
  end

  def render_list(title, list, depth \\ 0) do
    sep0 = String.duplicate("\t", depth)
    sep1 = String.duplicate("\t", depth + 1)

    first = ~s(#{sep0}- #{title})

    lines =
      list
      |> Enum.map(fn %{path: path, line: line} ->
        ~s(#{sep1}- #{Markdown.file_reflink(path, line)})
      end)

    [first | lines] |> Enum.join("\n")
  end

  @impl Tool
  def to_markdown(reports) do
    critical =
      reports
      |> Enum.filter(fn %{freq: _freq, meta: %{severity: severity}, data: _findings} ->
        severity == "ERROR"
      end)

    warnings =
      reports
      |> Enum.filter(fn %{freq: _freq, meta: %{severity: severity}, data: _findings} ->
        severity != "ERROR"
      end)

    call_render = fn %{freq: _freq, meta: %{message: msg}, data: findings} ->
      render_list(msg, findings)
    end

    header = ":heavy_exclamation_mark: Critical Findings"
    critical_list = critical |> Enum.map(&call_render.(&1))

    critical_rendered = critical_list |> Enum.join("\n")

    warns_list = warnings |> Enum.map(&call_render.(&1)) |> Enum.join("\n")

    warns_rendered = Markdown.toggle(":raised_eyebrow: Other findings", warns_list)

    Markdown.toggle_stats(
      "Critical Findings",
      length(critical_list),
      critical_rendered <> "\n---\n" <> warns_rendered
    )
  end

  def read_reports(reports) do
    reports
    |> Main.read_json_files()
    |> Stream.map(&Semgrep.extract_data/1)
    |> Enum.to_list()
    |> Enum.flat_map(& &1)
  end

  @impl Tool
  def process_reports(files) do
    files
    |> read_reports()
    |> filter_ignored()
    |> group_reports()

    # |> dbg()
  end

  @impl Tool
  def test_report() do
    "./example-reports/semgrep-report.json"
  end

  @impl Tool
  def id do
    :semgrep
  end
end

defmodule Ferox do
  @behaviour Tool

  def read_reports(reports) do
    reports |> Main.read_json_files()
  end

  def group_endpoints(%{json: endpoints}) do
    fn_path = fn %{"path" => p} -> p end

    servers =
      endpoints
      |> Enum.filter(fn mp -> Map.has_key?(mp, "server") end)
      |> Enum.map(fn %{"server" => s} -> s end)
      |> Enum.sort()
      |> Enum.dedup()

    ends =
      endpoints
      |> Enum.group_by(fn_path, fn %{"status" => s} -> s end)
      |> Enum.map(fn {path, slist} -> {path, slist |> Enum.sort() |> Enum.dedup()} end)
      |> Enum.dedup()
      |> Enum.sort_by(fn {path, statuses} -> {statuses, path} end)

    %{endpoints: ends, server_info: servers}
  end

  @impl Tool
  def to_markdown(%{endpoints: endpoints, server_info: servers}) do
    header = ":unlock: Open paths"

    footer = Main.status_text()

    svmd = Markdown.list0(servers |> Enum.map(fn x -> ~s(`#{x}`) end), -1)
    server_md = ~s(## Server software\n\n#{svmd}\n)

    list =
      endpoints
      |> Enum.map(fn {path, slist} ->
        Markdown.list(
          ~s(`#{path}`),
          slist
          |> Enum.map(fn x -> ~s(`#{x}`) end)
        )
      end)
      |> Enum.join("\n")

    Markdown.toggle(header, "#{list}\n#{server_md}\n\n#{footer}\n")
  end

  @impl Tool
  def process_reports(reports) do
    reports
    |> Main.read_json_files()
    |> Enum.to_list()
    |> hd
    |> group_endpoints()
  end

  @impl Tool
  def test_report() do
    "./example-reports/feroxbuster-report-new-2.json"
  end

  @impl Tool
  def id do
    :feroxbuster
  end
end

defmodule DepCheck do
  @behaviour Tool

  def read_reports(reports) do
    reports |> Main.read_json_files()
  end

  def format_reports(%{json: reports}) do
    ids =
      reports
      |> Enum.map(fn x -> Map.get(x, "vulnerableSoftware") end)
      |> Enum.filter(fn x -> x != nil end)
      |> Enum.flat_map(fn x -> x |> Enum.map(fn %{"software" => %{"id" => id}} -> id end) end)

    description = reports |> Enum.map(fn x -> Map.get(x, "description") end)

    # Enum.zip(ids, description)
    Enum.zip_with([ids, description], & &1)
  end

  @impl Tool
  def to_markdown(reports) do
    nvulns = length(reports)

    details =
      reports
      |> Enum.map(fn [id, desc] -> Markdown.list("Software: `#{id}`", [desc]) end)
      |> Enum.join("\n")

    Markdown.toggle_stats("Vulnerable Dependencies", length(reports), details)
  end

  @impl Tool
  def process_reports(reports) do
    reports
    |> Main.read_json_files()
    |> Enum.to_list()
    |> hd
    |> format_reports()
  end

  @impl Tool
  def test_report() do
    "./example-reports/dependency-check-report.json"
  end

  @impl Tool
  def id do
    :dependency_check
  end
end

defmodule Gitleaks do
  @behaviour Tool

  def extract_data(%{json: reports}) do
    reports
    |> Enum.map(fn %{"File" => f, "StartLine" => line, "Description" => desc, "Match" => match} ->
      %{file: f, line: line, description: desc, match: match}
    end)
  end

  def ignore_custom_rule(reports) do
    reports
    |> Enum.filter(&(not String.equivalent?(Map.get(&1, :description), "VTEX's Custom Rule 01")))
  end

  @impl Tool
  def to_markdown(reports) do
    ncreds = length(reports)

    body =
      reports
      |> Enum.map(fn x ->
        Markdown.list("#{Markdown.file_reflink(x.file, x.line)}", [
          "#{x.description}: `#{x.match}`"
        ])
      end)
      |> Enum.join("\n")

    Markdown.toggle_stats("Leaked Credentials", ncreds, body)
  end

  @impl Tool
  def process_reports(reports) do
    reports
    |> Main.read_json_files()
    |> Enum.to_list()
    |> hd
    |> Gitleaks.extract_data()
    |> Gitleaks.ignore_custom_rule()
  end

  @impl Tool
  def test_report do
    "./example-reports/gitleaks-report.json"
  end

  @impl Tool
  def id do
    :gitleaks
  end
end

defmodule Markdown do
  def list(title, list, depth \\ 0) do
    sep0 = String.duplicate("\t", depth)
    sep1 = String.duplicate("\t", depth + 1)

    first = ~s(#{sep0}- #{title})

    lines = list |> Enum.map(fn x -> ~s(#{sep1}- #{x}) end)

    [first | lines] |> Enum.join("\n")
  end

  def list0(list, depth \\ 0) do
    sep1 = String.duplicate("\t", depth + 1)

    list |> Enum.map(fn x -> ~s(#{sep1}- #{x}) end) |> Enum.join("\n")
  end

  def toggle(description, body) do
    "<details>\n<summary><b> #{description} </b></summary>\n\n#{body}\n\n</details>"
  end

  def toggle_stats(description, n, body) do
    something = ":heavy_exclamation_mark: #{n}"
    nothing = ":white_check_mark: Nothing found in "

    if n > 0 do
      "<details>\n<summary><b> #{something} #{description} </b></summary>\n\n#{body}\n\n</details>"
    else
      "\n#### #{nothing} #{description}\n\n"
    end
  end

  def file_reflink(path, line) do
    "[#{path}:#{line}](#{Main.repo_url()}/#{path}#L#{line})"
  end
end

defmodule Main do
  @tools [Ferox, DepCheck, Gitleaks, Semgrep]

  @header_text "## 🪬 Cabueta's Report"

  @goal_text "This workflow's goal is to look for vulnerabilities in the source
  code and in the running web application, and then display it's findings."

  @status_text "**Disclaimer**: 403 status codes discloses useful information
  to potential attackers. The server software section was built only with
  information available to external agents."
  def status_text, do: @status_text

  @sast_text "The first set of scans will search the source code for credentials and potential dangerous practices."

  @dast_text "The second set of scans will test the running application in the URL that was provided."

  def repo_url() do
    base_url = System.get_env("GITHUB_SERVER_URL", "")
    repo = System.get_env("GITHUB_REPOSITORY", "")
    branch = System.get_env("GITHUB_REF", "main")

    "#{base_url}/#{repo}/blob/#{branch}"
  end

  def test_tools() do
    reports =
      Enum.map(@tools, fn tool ->
        tool.test_report()
        |> read_report()
      end)
      |> assemble
      |> dbg()

    # IO.puts(reports.markdown)
  end

  def read_json_files(files) do
    safe_read = fn x ->
      case File.read(x) do
        {:ok, data} -> data
        _ -> "{}"
      end
    end

    files
    |> Stream.map(fn x -> %{path: x, json: safe_read.(x) |> Jason.decode!()} end)
  end

  def get_module(file) do
    cond do
      String.contains?(file, "semgrep") ->
        Semgrep

      String.contains?(file, "feroxbuster") ->
        Ferox

      String.contains?(file, "dependency-check") ->
        DepCheck

      String.contains?(file, "gitleaks") ->
        Gitleaks

      true ->
        nil
    end
  end

  def read_report(file) do
    mod = get_module(file)
    report = mod.process_reports([file])
    md = mod.to_markdown(report)

    %{id: mod.id(), markdown: md, report: report}
  end

  def assemble(rep_list) do
    reports = rep_list |> List.foldl(%{}, fn report, acc -> Map.put(acc, report.id, report) end)

    get_md =
      &case get_in(&1, &2) do
        nil -> ""
        x -> x
      end

    pieces = [
      @header_text,
      "> " <> @goal_text,
      @sast_text,
      get_md.(reports, [:dependency_check, :markdown]),
      get_md.(reports, [:gitleaks, :markdown]),
      get_md.(reports, [:semgrep, :markdown]),
      "\n> " <> @dast_text,
      get_md.(reports, [:feroxbuster, :markdown])
    ]

    %{
      markdown: pieces |> Enum.join("\n"),
      reports: reports,
      repository: System.get_env("GITHUB_REPOSITORY", ""),
      time: DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d-%H-%M-%S"),
      url: repo_url()
    }
  end

  def serialize_report(report) do
  end

  def report_id() do
    repo = System.get_env("GITHUB_REPOSITORY", "") |> String.replace("\/", "#")
    branch = System.get_env("GITHUB_REF", "main") |> String.replace("\/", "#")
    time = DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d-%H-%M-%S")

    "#{repo}@#{branch}@#{time}-cabueta-report-v0.json"
    "#{repo}@#{branch}@#{time}-cabueta-report-v0.json"
  end

  def store_report(report) do
    data = report |> Map.delete(:markdown) |> Jason.encode!()

    case Main.report_id() |> File.open([:write]) do
      {:ok, file} ->
        IO.binwrite(file, data)
        File.close(file)

      {:error, _err} ->
        _
    end
  end
end

in_files = System.argv()

if length(in_files) == 0 do
  IO.puts("No files given")
  Main.test_tools()
end

reports =
  in_files
  |> Enum.map(&Main.read_report(&1))
  |> Main.assemble()

# Main.store_report(reports)
IO.puts(reports.markdown)
