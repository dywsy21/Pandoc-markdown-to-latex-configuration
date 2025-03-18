function Image(el)
    local fname = el.src
    local caption = pandoc.utils.stringify(el.caption)
    
    -- Check if this is a mermaid diagram
    local is_mermaid = false
    if el.classes then
      for _, class in ipairs(el.classes) do
        if class == "mermaid-diagram" then
          is_mermaid = true
          break
        end
      end
    end
    
    if is_mermaid then
      -- Special handling for mermaid diagrams to ensure they fit
      return {
        pandoc.RawInline("latex",
          "\\begin{figure}[htbp]\\centering" ..
          "\\adjustbox{max width=0.95\\textwidth,max height=0.7\\textheight,keepaspectratio}{" ..
          "\\includegraphics{" .. fname .. "}" ..
          "}" ..
          "\\caption{" .. caption .. "}" ..
          "\\end{figure}"),
        pandoc.RawInline("html", "<!-- -->"),
        pandoc.Str("\xE2\x80\x8B") -- zero-width space
      }
    else
      -- Regular image handling
      return {
        pandoc.RawInline("latex",
          "\\begin{figure}[H]\\centering" ..
          "\\includegraphics[width=0.85\\textwidth]{" .. fname .. "}" ..
          "\\caption{" .. caption .. "}" ..
          "\\end{figure}"),
        pandoc.RawInline("html", "<!-- -->"),
        pandoc.Str("\xE2\x80\x8B") -- zero-width space
      }
    
  end
  
  return {
    { Image = Image }
  }
end
