defmodule KivaWeb.Developer.CodeGen do
  @moduledoc """
  Renders ONE request spec into idiomatic snippets for cURL, JavaScript (fetch),
  Python (requests), Ruby (Net::HTTP), PHP (cURL), and Go (net/http).

  Each documented endpoint declares a single spec (see `KivaWeb.Developer.Docs`)
  and this module mechanically produces all six languages — so adding a language
  is one clause here, and adding an endpoint is one spec there. Code is not
  translated; only the surrounding prose is.
  """
  @languages [:curl, :javascript, :python, :ruby, :php, :go]

  def languages, do: @languages

  def language_label(:curl), do: "cURL"
  def language_label(:javascript), do: "JavaScript"
  def language_label(:python), do: "Python"
  def language_label(:ruby), do: "Ruby"
  def language_label(:php), do: "PHP"
  def language_label(:go), do: "Go"
  def language_label(other), do: to_string(other)

  @doc "Render `spec` (a Docs endpoint) into `lang` source."
  def render(spec, lang), do: spec |> request() |> emit(lang)

  @doc "The base URL shown in docs examples."
  def base_url, do: Application.get_env(:kiva, :docs_base_url, "http://localhost:4100")

  # --- normalize a spec into a concrete HTTP request -----------------------
  defp request(spec) do
    ex = Map.get(spec, :example, %{})
    headers = auth_headers(Map.get(spec, :auth))

    cond do
      gql = ex[:gql] ->
        json =
          Jason.encode!(%{"query" => gql.query, "variables" => Map.get(gql, :variables, %{})})

        %{
          method: "POST",
          url: base_url() <> spec.path,
          headers: [{"Content-Type", "application/json"} | headers],
          body: json
        }

      body = ex[:body] ->
        %{
          method: "POST",
          url: base_url() <> spec.path,
          headers: [{"Content-Type", "application/json"} | headers],
          body: Jason.encode!(body)
        }

      true ->
        %{
          method: "GET",
          url: base_url() <> spec.path <> qs(ex[:query]),
          headers: headers,
          body: nil
        }
    end
  end

  defp auth_headers(:api_key), do: [{"Authorization", "Bearer kva_live_YOUR_KEY"}]
  defp auth_headers(:oauth), do: [{"Authorization", "Bearer ACCESS_TOKEN"}]
  defp auth_headers(:login), do: [{"Authorization", "Bearer SESSION_TOKEN"}]
  defp auth_headers(_), do: []

  defp qs(nil), do: ""
  defp qs([]), do: ""

  defp qs(pairs),
    do:
      "?" <>
        Enum.map_join(pairs, "&", fn {k, v} -> "#{k}=#{URI.encode_www_form(to_string(v))}" end)

  # --- per-language emitters ----------------------------------------------
  defp emit(%{method: m, url: url, headers: hs, body: body}, :curl) do
    (["curl '#{url}'"] ++
       if(m != "GET", do: ["-X #{m}"], else: []) ++
       Enum.map(hs, fn {k, v} -> "-H '#{k}: #{v}'" end) ++
       if(body, do: ["-d '#{body}'"], else: []))
    |> Enum.join(" \\\n  ")
  end

  defp emit(%{method: m, url: url, headers: hs, body: body}, :javascript) do
    opts =
      ["method: #{inspect(m)}", "headers: #{js_obj(hs)}"] ++
        if(body, do: ["body: JSON.stringify(#{body})"], else: [])

    """
    const res = await fetch(#{inspect(url)}, {
      #{Enum.join(opts, ",\n  ")}
    });
    const data = await res.json();
    console.log(data);
    """
    |> String.trim()
  end

  defp emit(%{method: m, url: url, headers: hs, body: body}, :python) do
    args =
      [inspect(url)] ++
        if(hs == [], do: [], else: ["headers=#{py_dict(hs)}"]) ++
        if(body, do: ["data='#{body}'"], else: [])

    """
    import requests

    res = requests.#{String.downcase(m)}(#{Enum.join(args, ", ")})
    print(res.json())
    """
    |> String.trim()
  end

  defp emit(%{method: m, url: url, headers: hs, body: body}, :ruby) do
    klass = m |> String.downcase() |> String.capitalize()
    header_lines = Enum.map_join(hs, "\n", fn {k, v} -> "req[#{inspect(k)}] = #{inspect(v)}" end)
    body_line = if body, do: "\nreq.body = '#{body}'", else: ""

    """
    require "net/http"
    require "uri"

    uri = URI(#{inspect(url)})
    req = Net::HTTP::#{klass}.new(uri)
    #{header_lines}#{body_line}
    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(req) }
    puts res.body
    """
    |> String.trim()
  end

  defp emit(%{method: m, url: url, headers: hs, body: body}, :php) do
    header_arr = "[" <> Enum.map_join(hs, ", ", fn {k, v} -> ~s("#{k}: #{v}") end) <> "]"

    lines =
      [
        "$ch = curl_init(#{php_str(url)});",
        "curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);",
        "curl_setopt($ch, CURLOPT_HTTPHEADER, #{header_arr});"
      ] ++
        if(m != "GET", do: ["curl_setopt($ch, CURLOPT_CUSTOMREQUEST, #{php_str(m)});"], else: []) ++
        if(body, do: ["curl_setopt($ch, CURLOPT_POSTFIELDS, '#{body}');"], else: []) ++
        ["$response = curl_exec($ch);", "curl_close($ch);", "echo $response;"]

    "<?php\n" <> Enum.join(lines, "\n")
  end

  defp emit(%{method: m, url: url, headers: hs, body: body}, :go) do
    body_arg = if body, do: "strings.NewReader(`#{body}`)", else: "nil"

    imports =
      if body,
        do: ~s("fmt"\n\t"io"\n\t"net/http"\n\t"strings"),
        else: ~s("fmt"\n\t"io"\n\t"net/http")

    header_lines =
      Enum.map_join(hs, "\n\t", fn {k, v} -> "req.Header.Set(#{inspect(k)}, #{inspect(v)})" end)

    header_block = if header_lines == "", do: "", else: "\t#{header_lines}\n"

    """
    package main

    import (
    \t#{imports}
    )

    func main() {
    \treq, _ := http.NewRequest(#{inspect(m)}, #{inspect(url)}, #{body_arg})
    #{header_block}\tres, _ := http.DefaultClient.Do(req)
    \tdefer res.Body.Close()
    \tout, _ := io.ReadAll(res.Body)
    \tfmt.Println(string(out))
    }
    """
    |> String.trim()
  end

  # --- small formatting helpers -------------------------------------------
  defp js_obj([]), do: "{}"

  defp js_obj(hs),
    do: "{ " <> Enum.map_join(hs, ", ", fn {k, v} -> "#{inspect(k)}: #{inspect(v)}" end) <> " }"

  defp py_dict(hs),
    do: "{" <> Enum.map_join(hs, ", ", fn {k, v} -> "#{inspect(k)}: #{inspect(v)}" end) <> "}"

  defp php_str(s), do: ~s("#{s}")
end
