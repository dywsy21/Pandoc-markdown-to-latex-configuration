function Image(el)
  local fname = el.src
  local caption = pandoc.utils.stringify(el.caption)
  return {
    pandoc.RawInline("latex",
      "\\begin{figure}[H]\\centering" ..
      "\\includegraphics[width=0.75\\textwidth]{" .. fname .. "}" ..
      "\\caption{" .. caption .. "}" ..
      "\\end{figure}"),
    pandoc.RawInline("html", "<!-- -->"),
    pandoc.Str("\xE2\x80\x8B") -- zero-width space
  }
end
