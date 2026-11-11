-- Front matter for the .docx: a title page, then a table of contents, then
-- the body, each starting on a new page.
--
-- architecture.md starts with its one level-1 heading, the title. This
-- filter moves that heading into the document's title and raises every
-- other heading one level, so "## 1. Status and scope" becomes Heading 1.
-- Everything between the title and the first remaining heading (the status
-- line and the draft date) stays on the title page, so both are written
-- once, in the Markdown. A page break, the table of contents and another
-- page break go in front of that first heading.
--
-- Word and LibreOffice fill in the table of contents when the file is
-- opened, or on "Update field".

local function page_break()
  return pandoc.RawBlock('openxml', '<w:p><w:r><w:br w:type="page"/></w:r></w:p>')
end

local toc = pandoc.RawBlock('openxml', table.concat({
  '<w:sdt><w:sdtPr><w:docPartObj>',
  '<w:docPartGallery w:val="Table of Contents"/><w:docPartUnique/>',
  '</w:docPartObj></w:sdtPr><w:sdtContent>',
  '<w:p><w:pPr><w:pStyle w:val="TOCHeading"/></w:pPr>',
  '<w:r><w:t xml:space="preserve">Contents</w:t></w:r></w:p>',
  '<w:p><w:r><w:fldChar w:fldCharType="begin" w:dirty="true"/>',
  '<w:instrText xml:space="preserve">TOC \\o "1-2" \\h \\z \\u</w:instrText>',
  '<w:fldChar w:fldCharType="separate"/>',
  '<w:fldChar w:fldCharType="end"/></w:r></w:p>',
  '</w:sdtContent></w:sdt>',
}))

function Pandoc(doc)
  if FORMAT ~= 'docx' then
    return doc
  end

  local first = doc.blocks[1]
  if not (first and first.t == 'Header' and first.level == 1) then
    error('docx-front.lua: the Markdown must start with its level-1 title')
  end
  doc.meta.title = pandoc.MetaInlines(first.content)
  doc.blocks:remove(1)

  doc.blocks = doc.blocks:walk({
    Header = function(h)
      if h.level == 1 then
        error('docx-front.lua: only the title may be a level-1 heading')
      end
      h.level = h.level - 1
      return h
    end,
  })

  for i, block in ipairs(doc.blocks) do
    if block.t == 'Header' then
      doc.blocks:insert(i, page_break())
      doc.blocks:insert(i + 1, toc)
      doc.blocks:insert(i + 2, page_break())
      return doc
    end
  end
  error('docx-front.lua: no heading found after the title')
end
