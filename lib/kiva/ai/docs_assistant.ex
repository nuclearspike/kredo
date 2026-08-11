defmodule Kiva.AI.DocsAssistant do
  @moduledoc """
  The developer-docs "AI query builder": turns a natural-language request into an
  example API call in a chosen language. Rides the app's existing LLM
  (`Kiva.AI.LLM`); when the LLM is offline (or in tests) it degrades to a
  deterministic example drawn from `KivaWeb.Developer.Docs` + `CodeGen`, so the
  page always renders something useful.
  """
  use Gettext, backend: KivaWeb.Gettext
  alias KivaWeb.Developer.{Docs, CodeGen}

  @langs ~w(curl javascript python ruby php go)a

  @doc "Generate an example for `req` = `%{intent, language, surface, locale}`."
  def generate(req) do
    req = Map.update(req, :intent, "", &String.slice(to_string(&1), 0, 500))

    case Kiva.AI.LLM.docs_query(req) do
      {:ok, result} -> Map.put(result, :source, :llm)
      {:error, _} -> fallback(req)
    end
  end

  defp fallback(req) do
    lang = to_lang(req[:language])
    ep = default_endpoint(req[:surface])

    %{
      source: :fallback,
      summary: ep.title,
      language: CodeGen.language_label(lang),
      snippet: CodeGen.render(ep, lang),
      notes: gettext("The AI builder is offline; this is a matching example from the docs.")
    }
  end

  defp default_endpoint(surface) do
    sid = to_surface(surface)
    List.first(Docs.endpoints_for(sid)) || List.first(Docs.endpoints())
  end

  defp to_lang(l) when is_atom(l), do: if(l in @langs, do: l, else: :curl)
  defp to_lang(l) when is_binary(l), do: Enum.find(@langs, :curl, &(to_string(&1) == l))
  defp to_lang(_), do: :curl

  defp to_surface(s) when is_binary(s) do
    Enum.find(Enum.map(Docs.surfaces(), & &1.id), :platform_rest, &(to_string(&1) == s))
  end

  defp to_surface(s) when is_atom(s) and not is_nil(s), do: s
  defp to_surface(_), do: :platform_rest
end
