--[[
Pandoc filter to extend pandoc's markdown to incorporate comment features and
other things I find useful. With `draft: true` in the YAML header, comments and
margin notes are displayed in red, and text that is highlighted or flagged with
`fixme` is marked up in the output. With `draft: false` in the YAML header,
comments and margin notes are not displayed at all, and highlightings and
`fixme` mark ups are suppressed (though the text is displayed).

The display of comments, marginal notes, fixmes, and highlighted text in the
final output can be fine-tuned by setting in the YAML header these to `draft`
(output as described above when draft is true), `print` (to print them as for
any normal text), or `hide` (to prevent them from showing up in the final
output at alal). Thus, the defaults when `draft: true` is set in the YAML
header is equivent to specifying:

    comment: draft
    margin: draft
    fixme: draft
    highlight: draft

and when `draft: false` is set, it is equivalent to:

    comment: hide
    margin: hide
    fixme: print
    highlight: print

Also provided are markup conventions for cross-references, index entries,
non-indented paragraphs, boxed text, centered text, and TikZ figures.

Copyright (C) 2017, 2018 Bennett Helm

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.


# Syntax Extensions

## Block-Level Items:

Fenced DIV elements, with `comment`, `box`, and `center` are used for creating
special blocks. Fenced DIV elements take the following form , where `comment`,
`box`, or `center` can fill in for `CLASS`:

    ::: CLASS
    Text of block CLASS item...
    :::

FIXME: I cannot nest block elements nicely in LaTeX: boxed text within comment
blocks are not colored (but they are omitted when `draft` is false).

## Inline Items:

Note that tag-style inlines no longer work and should be switched to
span-style. Please change `<tag> ... </tag>` to `[...]{.tag}` in all documents.
In vim, the following regex works:

    %s/<\(!\?comment\|highlight\|fixme\|margin\|smcaps\)>\(.\{-}\)<\/\1>/[\2]{.\1}/gc

Here are the defined inlines:

    - `[...]{.comment}`:    make `...` be a comment
    - `[...]{.highlight}`:  make `...` be highlighted (note that this requires
                            that `soul.sty` be loaded in LaTeX)
    - `[...]{.fixme}`:      make `...` be a FixMe margin note (with
                            highlighting)
    - `[...]{.margin}`:     make `...` be a margin note
    - `[...]{.smcaps}`:     make `...` be in small caps


## Other Items:

Note that tag-style inlines no longer work and should be switched to
span-style. Please change `<tag> ... </tag>` to `[...]{.tag}` in all documents.
In vim, the following regex works:

    %s/<\(l\|r\|rp\|i\)\s\+\([^>]\+\)>/[\2]{.\1}/gc

Here are the defined inlines:

    - `< `:                   (at begining of line) do not indent paragraph
                              (after quotation block or lists, e.g.)
    - `[LABEL]{.l}`:          create a label
    - `[LABEL]{.r}`:          create a reference
    - `[LABEL]{.rp}`:         create a page reference
    - `[text-for-index]{.i}`: create LaTeX index (`\\index{text-for-index}`)

Note: if putting LaTeX into these spans, must enclose it in code spans
("`...'"), or it will be omitted.

## Images:

1. Allow for TikZ figures in code blocks. They should have the following
   format:

    ~~~ {#identifier .tikz caption='A caption that allows *markdown* markup.' title='The title' tikzlibrary='items,to,go,in,\\usetikzlibrary{}'}

    [LaTeX code]

    ~~~

    Note that the caption can be formatted text in markdown, and can use any
    inline elements from this comment filter.

2. Similarly, allow for GraphViz figures in code blocks, in the following format:

    ~~~ {#identifier .dot caption='My caption' title='The title'}

    [dot code]

    ~~~

## Processing .tex Images

This filter will take an image of the form
`![caption](image_file.tex){attributes}` and create appropriate formatted image
from that file, converting it to the appropriate file format for the desired
output.


-- ## Macros:

-- Here I abuse math environments to create easy macros.

-- 1. In YAML header, specify macros as follows:

--     macros:
--     - first: this is the substituted text
--       second: this is more substituted text

-- 2. Then in text, have users specify macros to be substituted as follows:

--     This is my text and $first$. This is more text and $second$.

-- As long as the macro labels are not identical to any actual math the user would
-- use, there should be no problem.

----------------------------------------------------------------------------]]


-- Colors for various comment types
local COLORS = {}
COLORS.block_comment = 'red'
COLORS.comment       = 'red'
COLORS.highlight     = 'yellow'
COLORS.margin        = 'red'
COLORS.fixme         = 'cyan'

-- Location to save completed images
-- FIXME: Should I get rid of this? It's better not to rely on hard-coded
-- paths, but the benefit is that I can store images there and not have to
-- regenerate or reconvert them. Perhaps I should have a metadata value for
-- `tempdir`, which provides this value, and I use ~/tmp/pandoc as a default,
-- adding /Figures onto that for the IMAGE_PATH.
local HOME_PATH = os.getenv('HOME')
-- FIXME: I should ensure that this directory exists!
local IMAGE_PATH = HOME_PATH .. '/tmp/pandoc/Figures/'

-- Default font for `tikz` figures
local DEFAULT_FONT = 'fbb'


function Latex(text)
    return pandoc.RawInline("latex", text)
end


-- html code for producing a margin comment
local MARGIN_STYLE = "max-width:20%; border: 1px solid black; padding: 1ex; " ..
                     "margin: 1ex; float:right; font-size: small;"

local LATEX_TEXT = {}
LATEX_TEXT.block_comment = {}
LATEX_TEXT.block_comment.Open = Latex(string.format('\\color{%s}{}',
                                      COLORS.block_comment))
LATEX_TEXT.block_comment.Close = Latex('\\color{black}{}')
LATEX_TEXT.block_box = {}
LATEX_TEXT.block_box.Open = Latex('\\medskip\\begin{mdframed}')
LATEX_TEXT.block_box.Close = Latex('\\end{mdframed}\\medskip{}')
LATEX_TEXT.block_center = {}
LATEX_TEXT.block_center.Open = Latex('\\begin{center}')
LATEX_TEXT.block_center.Close = Latex('\\end{center}')
LATEX_TEXT.comment = {}
LATEX_TEXT.comment.Open = Latex(string.format('\\textcolor{%s}{',
                                              COLORS.comment))
LATEX_TEXT.comment.Close = Latex('}')
LATEX_TEXT.highlight = {}
LATEX_TEXT.highlight.Open = Latex('\\hl{')
LATEX_TEXT.highlight.Close = Latex('}')
LATEX_TEXT.margin = {}
LATEX_TEXT.margin.Open = Latex(string.format(
            '\\marginpar{\\begin{flushleft}\\scriptsize{\\textcolor{%s}{',
            COLORS.margin))
LATEX_TEXT.margin.Close = Latex('}}\\end{flushleft}}')
LATEX_TEXT.fixme = {}
LATEX_TEXT.fixme.Open = Latex(string.format(
            '\\marginpar{\\scriptsize{\\textcolor{%s}{Fix this!}}}\\textcolor{%s}{',
            COLORS.fixme, COLORS.fixme))
LATEX_TEXT.fixme.Close = Latex('}')
LATEX_TEXT.noindent = Latex('\\noindent{}')
LATEX_TEXT.l = {}
LATEX_TEXT.l.Open = '\\label{'
LATEX_TEXT.l.Close = '}'
LATEX_TEXT.r = {}
LATEX_TEXT.r.Open = '\\autoref{'
LATEX_TEXT.r.Close = '}'
LATEX_TEXT.rp = {}
LATEX_TEXT.rp.Open = '\\autopageref{'
LATEX_TEXT.rp.Close = '}'

function html(text)
    return pandoc.RawInline("html", text)
end

local HTML_TEXT = {}
HTML_TEXT.block_comment = {}
HTML_TEXT.block_comment.Open = html(string.format('<div style="color: %s;">',
                                    COLORS.block_comment))
HTML_TEXT.block_comment.Close = html('</div>')
HTML_TEXT.block_box = {}
HTML_TEXT.block_box.Open =
            html('<div style="border:1px solid black; padding:1.5ex;">')
HTML_TEXT.block_box.Close = html('</div>')
HTML_TEXT.block_center = {}
HTML_TEXT.block_center.Open = html('<div style="text-align:center";>')
HTML_TEXT.block_center.Close = html('</div>')
HTML_TEXT.comment = {}
HTML_TEXT.comment.Open = html(string.format('<span style="color: %s;">',
                              COLORS.comment))
HTML_TEXT.comment.Close = html('</span>')
HTML_TEXT.highlight = {}
HTML_TEXT.highlight.Open = html('<mark>')
HTML_TEXT.highlight.Close = html('</mark>')
HTML_TEXT.margin = {}
HTML_TEXT.margin.Open = html(string.format('<span style="color: %s; %s">',
                             COLORS.margin, MARGIN_STYLE))
HTML_TEXT.margin.Close = html('</span>')
HTML_TEXT.fixme = {}
HTML_TEXT.fixme.Open = html(string.format(
        '<span style="color: %s; %s">Fix this!</span><span style="color: %s;">',
        COLORS.fixme, MARGIN_STYLE, COLORS.fixme))
HTML_TEXT.fixme.Close = html('</span>')
HTML_TEXT.noindent = html('<p style="text-indent: 0px">')
HTML_TEXT.l = {}
HTML_TEXT.l.Open = '<a name="'
HTML_TEXT.l.Close = '"></a>'
HTML_TEXT.r = {}
HTML_TEXT.r.Open = '<a href="#'
HTML_TEXT.r.Close = '">here</a>'
HTML_TEXT.rp = {}
HTML_TEXT.rp.Open = '<a href="#'
HTML_TEXT.rp.Close = '">here</a>'

local REVEALJS_TEXT = {}
REVEALJS_TEXT.block_comment = {}
REVEALJS_TEXT.block_comment.Open = html(string.format(
        '<div style="color: %s;">', COLORS.block_comment))
REVEALJS_TEXT.block_comment.Close = html('</div>')
REVEALJS_TEXT.block_box = {}
REVEALJS_TEXT.block_box.Open = html(
        '<div style="border:1px solid black; padding:1.5ex;">')
REVEALJS_TEXT.block_box.Close = html('</div>')
REVEALJS_TEXT.block_center = {}
REVEALJS_TEXT.block_center.Open = html('<div style="text-align:center";>')
REVEALJS_TEXT.block_center.Close = html('</div>')
REVEALJS_TEXT.comment = {}
REVEALJS_TEXT.comment.Open = html(string.format('<span style="color: %s;">',
                                  COLORS.comment))
REVEALJS_TEXT.comment.Close = html('</span>')
REVEALJS_TEXT.highlight = {}
REVEALJS_TEXT.highlight.Open = html('<mark>')
REVEALJS_TEXT.highlight.Close = html('</mark>')
REVEALJS_TEXT.margin = {}
REVEALJS_TEXT.margin.Open = html(string.format(
        '<span style="color: %s; %s;">', COLORS.margin, MARGIN_STYLE))
REVEALJS_TEXT.margin.Close = html('</span>')
REVEALJS_TEXT.fixme = {}
REVEALJS_TEXT.fixme.Open = html(string.format(
        '<span style="color: %s; %s">Fix this!</span><span style="color: %s;">',
        COLORS.fixme, MARGIN_STYLE, COLORS.fixme))
REVEALJS_TEXT.fixme.Close = html('</span>')
REVEALJS_TEXT.noindent = html('<p class="noindent">')
REVEALJS_TEXT.l = {}
REVEALJS_TEXT.l.Open = '<a name="'
REVEALJS_TEXT.l.Close = '"></a>'
REVEALJS_TEXT.r = {}
REVEALJS_TEXT.r.Open = '<a href="#'
REVEALJS_TEXT.r.Close = '">here</a>'
REVEALJS_TEXT.rp = {}
REVEALJS_TEXT.rp.Open = '<a href="#'
REVEALJS_TEXT.rp.Close = '">here</a>'

function docx(text)
    return pandoc.RawInline("openxml", text)
end

local DOCX_TEXT = {}
DOCX_TEXT.block_comment = {}
DOCX_TEXT.block_comment.Open = docx('')
DOCX_TEXT.block_comment.Close = docx('')
DOCX_TEXT.block_box = {}
DOCX_TEXT.block_box.Open = docx('')
DOCX_TEXT.block_box.Close = docx('')
DOCX_TEXT.block_center = {}
DOCX_TEXT.block_center.Open = docx('')
DOCX_TEXT.block_center.Close = docx('')
DOCX_TEXT.comment = {}
DOCX_TEXT.comment.Open = docx('<w:rPr><w:color w:val="FF0000"/></w:rPr><w:t>')
DOCX_TEXT.comment.Close = docx('</w:t>')
DOCX_TEXT.highlight = {}
DOCX_TEXT.highlight.Open = docx('<w:rPr><w:highlight w:val="yellow"/></w:rPr><w:t>')
DOCX_TEXT.highlight.Close = docx('</w:t>')
DOCX_TEXT.margin = {}
DOCX_TEXT.margin.Open = docx('')
DOCX_TEXT.margin.Close = docx('')
DOCX_TEXT.fixme = {}
DOCX_TEXT.fixme.Open = docx('<w:rPr><w:color w:val="0000FF"/></w:rPr><w:t>')
DOCX_TEXT.fixme.Close = docx('</w:t>')
DOCX_TEXT.noindent = docx('')
DOCX_TEXT.i = {}
DOCX_TEXT.i.Open = '<w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText xml:space="preserve"> XE "</w:instrText></w:r><w:r><w:instrText>'
DOCX_TEXT.i.Close = '</w:instrText></w:r><w:r><w:instrText xml:space="preserve">" </w:instrText></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r>'
DOCX_TEXT.l = {}
DOCX_TEXT.l.Open = ''
DOCX_TEXT.l.Close = ''
DOCX_TEXT.r = {}
DOCX_TEXT.r.Open = ''
DOCX_TEXT.r.Close = ''
DOCX_TEXT.rp = {}
DOCX_TEXT.rp.Open = ''
DOCX_TEXT.rp.Close = ''


-- Used to store YAML variables (to check for `draft` status and for potential
-- modification later).
local YAML_VARS = {}

-- Indicates whether any box element has been used. If so, need to load LaTeX
-- package.
local BOX_USED = false

-- Used to count words in text, abstract, and footnotes
local WORD_COUNT = 0
local ABSTRACT_COUNT = 0
local NOTE_COUNT = 0
local YAML_WORDS = 0 -- Used for counting # words in YAML values (to be subtracted)

-- Used to specify whether to print various note types in draft.
local COMMENT_DEFAULT   = pandoc.MetaInlines({pandoc.Str('hide')})
local MARGIN_DEFAULT    = pandoc.MetaInlines({pandoc.Str('hide')})
local FIXME_DEFAULT     = pandoc.MetaInlines({pandoc.Str('print')})
local HIGHLIGHT_DEFAULT = pandoc.MetaInlines({pandoc.Str('print')})


-- FIXME: Used to keep track of current colors for blocks and inlines for LaTeX
-- ... I'm not sure this is going to work, unless I can determine when the
-- block or inline ends.
-- local CURRENT_BLOCK_COLOR = nil
-- local CURRENT_INLINE_COLOR = nil


function IsCommentBlock(text)
    return text == 'comment' or text == 'box' or text == 'center'
end


function IsHTML(format)
    -- Returns true/false if format is one that uses HTML
    if format == "html5" or format == "html" or format == "html4"  then
        return true
    else
        return false
    end
end


function IsLaTeX(format)
    -- Returns true/false if format is one that uses LaTeX
    if format == "latex" or format == "beamer" then
        return true
    else
        return false
    end
end


function IsWord(text)
    -- Returns true/false if text contains word characters (not just punctuation)
    return text:match("%P")
end


function GetYAML(meta)
    -- Record metadata for later use, and count words.
    for key, value in pairs(meta) do
        YAML_VARS[key] = value
        if type(value) ~= "boolean" then
            -- count words in YAML header, keeping track of those in abstract.
            if value.t == "MetaBlocks" then
                for _, block in pairs(value) do
                    pandoc.walk_block(block, {
                        Str = function(string)
                            if IsWord(string.text) then
                                YAML_WORDS = YAML_WORDS + 1
                                if key == "abstract" then
                                    ABSTRACT_COUNT = ABSTRACT_COUNT + 1
                                end
                            end
                            return
                        end})
                end
            elseif value.t == "MetaList" then
                for _, item in pairs(value) do
                    for _, inline in pairs(item) do
                        if inline.t == "Str" and IsWord(inline.text) then
                            YAML_WORDS = YAML_WORDS + 1
                        end
                    end
                end
            elseif value.t == "MetaInlines" then
                for _, inline in pairs(value) do
                    if inline.t == "Str" and IsWord(inline.text) then
                        YAML_WORDS = YAML_WORDS + 1
                        if key == "abstract" then
                            ABSTRACT_COUNT = ABSTRACT_COUNT + 1
                        -- elseif key == "tempdir" then
                        --     -- Set IMAGE_PATH from metadata
                        --     IMAGE_PATH = pandoc.utils.stringify(value.text) .. '/Figures/'
                        end
                    end
                end
            end
        end
    end
    -- Set defaults for inlines if not already set manually.
    if YAML_VARS.draft then
        YAML_VARS.comment   = YAML_VARS.comment   or pandoc.MetaInlines({pandoc.Str('draft')})
        YAML_VARS.margin    = YAML_VARS.margin    or pandoc.MetaInlines({pandoc.Str('draft')})
        YAML_VARS.fixme     = YAML_VARS.fixme     or pandoc.MetaInlines({pandoc.Str('draft')})
        YAML_VARS.highlight = YAML_VARS.highlight or pandoc.MetaInlines({pandoc.Str('draft')})
    else
        YAML_VARS.comment   = YAML_VARS.comment   or COMMENT_DEFAULT
        YAML_VARS.margin    = YAML_VARS.margin    or MARGIN_DEFAULT
        YAML_VARS.fixme     = YAML_VARS.fixme     or FIXME_DEFAULT
        YAML_VARS.highlight = YAML_VARS.highlight or HIGHLIGHT_DEFAULT
    end
end


function SetYAML(meta)
    -- Revise document metadata as appropriate; print detailed wordcount.
    if FORMAT == "markdown" then  -- Don't change anything if translating to .md
        return
    elseif BOX_USED and (IsLaTeX(FORMAT)) then  -- Need to add package for LaTeX
        local rawInlines = {pandoc.MetaInlines({Latex("\\RequirePackage{mdframed}")})}
        if meta["header-includes"] == nil then
            meta["header-includes"] = pandoc.MetaList(rawInlines)
        else
            table.insert(meta["header-includes"], pandoc.MetaList(rawInlines))
        end
    end
    if IsLaTeX(FORMAT) and (
            pandoc.utils.stringify(YAML_VARS.comment) == 'draft' or
            pandoc.utils.stringify(YAML_VARS.margin) == 'draft' or
            pandoc.utils.stringify(YAML_VARS.fixme) == 'draft'
            ) then  -- Need to add package for Latex
        local rawInlines = {pandoc.MetaInlines({Latex("\\RequirePackage{xcolor}")})}
        if meta["header-includes"] == nil then
            meta["header-includes"] = pandoc.MetaList(rawInlines)
        else
            table.insert(meta["header-includes"], pandoc.MetaList(rawInlines))
        end
    end
    print(string.format("Words: %d │ Abstract: %d │ Notes: %d │ Body: %d",
          WORD_COUNT - YAML_WORDS + ABSTRACT_COUNT, ABSTRACT_COUNT, NOTE_COUNT,
          WORD_COUNT - NOTE_COUNT - YAML_WORDS))
    return meta
end


local function fileExists(name)
    -- Returns true/false depending on whether file exists
    local file = io.open(name, 'r')
    if file == nil then
        return false
    else
        file:close()
        return true
    end
end


function HandleTransclusion(para)
    -- Process file transclusion
    if FORMAT == "markdown" then  -- Don't change anything if translating to .md
        return
    elseif #para.content == 2 and
            para.content[1].text == "@" and
            para.content[2].t == "Link" then
        fileName = para.content[2].target
        if not fileExists(fileName) then
            print("ERROR: Cannot find " .. fileName .. "!")
            return pandoc.Para({
                pandoc.Math("InlineMath", "\\Longrightarrow"),
                pandoc.Str(" ERROR: Cannot find "),
                pandoc.Code(fileName),
                pandoc.Str("! "),
                pandoc.Math("InlineMath", "\\Longleftarrow")
                })
        end
        local file = io.open(fileName, "r")
        local text = file:read("*all")
        file:close()
        return pandoc.read(text).blocks
    end
end


function HandleNoIndent(para)
    if FORMAT == "markdown" then  -- Don't change anything if translating to .md
        return
    elseif #para.content > 2 and
           para.content[1].text == "<" and
           para.content[2].t == 'Space' then
        -- Don't indent paragraph that starts with "< "
        if IsLaTeX(FORMAT) then
            return pandoc.Para({LATEX_TEXT.noindent,
                               table.unpack(para.content, 3, #para.content)})
        elseif IsHTML(FORMAT) then
            return pandoc.Plain({HTML_TEXT.noindent,
                                table.unpack(para.content, 3, #para.content)})
        elseif FORMAT == "revealjs" then
            return pandoc.Plain({REVEALJS_TEXT.noindent,
                                table.unpack(para.content, 3, #para.content)})
        elseif FORMAT == "docx" then
            return pandoc.Plain({DOCX_TEXT.noindent,
                                table.unpack(para.content, 3, #para.content)})
        end
    end
end


local function ImageOutdated(original, imageFile)
    -- Takes two filepaths and checks to see if original is newer than
    -- imageFile (if imageFile is outdated). Returns `true` if outdated.
    local f = io.popen('stat -f %m "' .. original .. '"')
    -- local f = io.popen('stat -f %m ' .. original)
    local originalModified = f:read()
    if originalModified == nil then
        return true
    end
    f:close()
    f = io.popen('stat -f %m "' .. imageFile .. '"')
    local copiedModified = f:read()
    f:close()
    if originalModified > copiedModified then  -- Need to update....
        return true
    else  -- Image is current.
        return false
    end
end


function ConvertImage(imageToConvert, convertedImage)
    -- Converts image to new file format
    if os.execute("convert -density 300 " .. imageToConvert ..
               " -quality 100 " .. convertedImage) then
        print('Successfully converted ' .. imageToConvert .. ' to ' ..
            convertedImage .. '.')
    else
        print('ERROR: Could not convert ' .. imageToConvert .. ' to ' ..
            convertedImage .. '.')
    end
end


function Typeset(outputLocation, filehead, filetype, codeType)
    -- filetype is the desired output filetype (`.pdf` or `.png`).
    local success = nil
    if codeType == "dot" then
        -- Note: outputLocation is the actual file
        success = os.execute("dot -T" .. string.sub(filetype, 2) .. " -o " .. outputLocation .. " " .. filehead)
    elseif codeType == "tex" then
        -- Note: outputLocation is the directory
        success = os.execute("pdflatex -output-directory " .. outputLocation .. " " ..
            filehead)
    end
    if success then
        print('Successfully typeset ' .. filehead .. '.')
    else
        print('ERROR: Could not typeset ' .. filehead .. '.')
    end
end


function HandleImages(image)
    -- This will check if an image is online, and will download it; if it is a
    -- .tex or .dot file, it will typeset it. Having done this, it will convert
    -- to the proper filetype for desired output. pandoc.Image =
    -- {{"identifier", "classes", "attributes"}, "caption", {"src", "title"}}
    local filetype = ".png"
    if IsLaTeX(FORMAT) then
        filetype = ".pdf"
    end
    local imageFile = image.src
    local imageBaseName, imageExtension
    _, _, imageBaseName, imageExtension = imageFile:find("([^/]*)(%.%a-)$")
    if imageBaseName == nil then  -- Cannot find file extension
        print('WARNING: Cannot find extension for ' .. imageFile .. '. Assuming ' .. filetype .. '.')
        imageBaseName = imageFile
        imageExtension = filetype
        imageFile = imageBaseName .. imageExtension
    end
    if imageFile:find("^https?://") then
        -- It's an online image; need to download to IMAGE_PATH
        imageBaseName = IMAGE_PATH .. imageBaseName
        if fileExists(imageBaseName .. imageExtension) then
            print(imageFile .. " already exists.")
        else
            print("Downloading " .. imageFile .. " to " .. imageBaseName ..
                imageExtension .. ".")
            if os.execute("wget --quiet " .. imageFile .. " --output-document=" ..
                    imageBaseName .. imageExtension) then
                print('Successfully downloaded ' .. imageFile .. '.')
            else
                print('ERROR: Could not download ' .. imageFile .. '.')
            end
            -- Because sometimes the downloaded file is old, this prevents it
            -- from being automatically deleted.
            os.execute("touch " .. imageBaseName .. imageExtension)
        end
        -- Convert image if necessary....
        if imageExtension ~= filetype and
                not fileExists(imageBaseName .. filetype) then
            ConvertImage(imageBaseName .. imageExtension, imageBaseName .. filetype)
        end
    else  --Local image.
        -- Pandoc gives filename with spaces represented by '%20'. Need to
        -- correct this on both input and output for local files.
        -- FIXME: Probably need to do this with other special characters!
        imageFile = string.gsub(imageFile, '%%20', ' ')
        -- Substitute full path for home directory
        if YAML_VARS.processimage == false then
            imageBaseName = image.src
            filetype = ""
            print("Not processing image " .. imageFile .. ".")
        else
            imageFile = string.gsub(imageFile, '^~/', os.getenv("HOME") .. '/')
            if not fileExists(imageFile) then
                print('ERROR: Cannot find ' .. imageFile .. '.')
                return {
                    pandoc.Math("InlineMath", "\\Longrightarrow"),
                    pandoc.Str(" ERROR: Cannot find "),
                    pandoc.Code(imageFile),
                    pandoc.Str("! "),
                    pandoc.Math("InlineMath", "\\Longleftarrow")
                    }
            end
            local newImageExtension = imageExtension
            if imageExtension == ".tex" then
                -- Update this because typesetting LaTeX produces .pdf
                newImageExtension = ".pdf"
            elseif imageExtension == ".dot" then
                -- dot will automatically produce right image type when typeset
                newImageExtension = filetype
            end
            imageBaseName = string.gsub(imageBaseName, "%%20", "_")
            local newImageFile = IMAGE_PATH .. imageBaseName .. newImageExtension
            -- Typeset image if necessary, or copy to IMAGE_PATH
            if not fileExists(newImageFile) or ImageOutdated(imageFile,
                    newImageFile) then
                if imageExtension == ".tex" then  -- i.e., if it's LaTeX file...
                    Typeset(IMAGE_PATH, imageFile, filetype, "tex")
                elseif imageExtension == ".dot" then
                    Typeset(newImageFile, imageFile, filetype, "dot")
                else
                    if os.execute('cp -f "' .. imageFile .. '" "' .. newImageFile
                            .. '"') then
                        print('Successfully copied file ' .. imageFile .. '.')
                    else
                        print('ERROR: Could not copy ' .. imageFile .. ' to ' ..
                            newImageFile .. '.')
                    end
                end
            end
            imageFile = newImageFile
            imageBaseName = IMAGE_PATH .. imageBaseName
            -- Convert image if necessary....
            if newImageExtension ~= filetype and (not fileExists(imageBaseName ..
                    filetype) or ImageOutdated(imageFile, imageBaseName .. filetype))
                    then
                ConvertImage(imageFile, imageBaseName .. filetype)
            end
        end
    end
    local attr = pandoc.Attr(image.identifier, image.classes, image.attributes)
    return pandoc.Image(image.caption, imageBaseName .. filetype, image.title,
        attr)
end


function Tikz2image(tikz, filetype, outfile)
    -- Given text of a TikZ LaTeX image, create an image of given filetype in
    -- given location.
    local tmphead = os.tmpname()
    local tmpdir = tmphead:match("^(.*[\\/])") or "."
    local f = io.open(tmphead .. ".tex", 'w')
    f:write(tikz)
    f:close()
    Typeset(tmpdir, tmphead, filetype, "tex")
    if filetype == '.pdf' then
        os.rename(tmphead .. ".pdf", outfile)
    else
        ConvertImage(tmphead .. '.pdf', outfile)
    end
    os.remove(tmphead .. ".tex")
    os.remove(tmphead .. ".pdf")
end


function Dot2Image(dot, filetype, outfile)
    -- Given text of a GraphViz image, create an image of given filetype in
    -- given location.
    local tmpfile = os.tmpname()
    local f = io.open(tmpfile, 'w')
    f:write(dot)
    f:close()
    Typeset(outfile, tmpfile, filetype, "dot")
    if filetype ~= '.pdf' then
        os.rename(tmpfile .. ".pdf", outfile)
    else
        ConvertImage(tmpfile .. '.pdf', outfile)
    end
    os.remove(tmpfile)
    os.remove(tmpfile .. ".pdf")
end


function GenerateImage(code, format)
    local font = ''
    if format == 'tikz' then
        font = DEFAULT_FONT
        if YAML_VARS.fontfamily then
            font = YAML_VARS.fontfamily[1].text
        end
    end
    local filetype = ".png"
    if IsLaTeX(FORMAT) then
        filetype = ".pdf"
    end
    local outfile = IMAGE_PATH .. pandoc.sha1(code.text .. font) .. filetype
    local caption = code.attributes.caption or ""
    local formattedCaption = pandoc.read(caption).blocks
    if formattedCaption[1] then
        formattedCaption = formattedCaption[1].text
    else
        formattedCaption = {}
    end
    if not fileExists(outfile) then
        if format == 'tikz' then
            local library = code.attributes.tikzlibrary or ""
            local codeHeader = "\\documentclass{standalone}\n" ..
                               "\\usepackage{" .. font .. "}\n" ..
                               "\\usepackage{tikz}\n"
            if library then
                codeHeader = codeHeader .. "\\usetikzlibrary{" .. library .. "}\n"
            end
            codeHeader = codeHeader .. "\\begin{document}\n"
            local codeFooter = "\n\\end{document}\n"
            Tikz2image(codeHeader .. code.text .. codeFooter, filetype, outfile)
        elseif format == 'dot' then
            Dot2Image(code.text, filetype, outfile)
        end
        print('Created image ' .. outfile)
    else
        print(outfile .. ' already exists.')
    end
    local title = code.attributes.title or ""
    -- Undocumented "feature" in pandoc: figures (as opposed to inline images)
    -- are created only if the title starts with "fig:", so this adds it if
    -- it's not already there. (See
    -- <https://groups.google.com/d/msg/pandoc-discuss/6GdEFG0N-VA/v3ayZPveEQAJ>.)
    begin, finish = title:find('fig:')
    if begin ~= 1 then
        title = 'fig:' .. title
    end
    -- code.attributes.caption = nil
    -- code.attributes.tikzlibrary = nil
    -- code.attributes.title = nil
    -- code.classes[1] = nil
    local attr = pandoc.Attr(code.identifier, code.classes, code.attributes)
    return pandoc.Para({pandoc.Image(formattedCaption, outfile, title, attr)})
end


function HandleCode(code)
    if code.classes[1] == 'tikz' then
        return GenerateImage(code, 'tikz')
    elseif code.classes[1] == 'dot' then
        return GenerateImage(code, 'dot')
    end
end


function HandleBlocks(block)
    if FORMAT == "markdown" then  -- Don't change anything if translating to .md
        return
    elseif IsCommentBlock(block.classes[1]) then
        if block.classes[1] == "comment" then
            if pandoc.utils.stringify(YAML_VARS[block.classes[1]]) == 'hide' then
                return {}
            elseif pandoc.utils.stringify(YAML_VARS[block.classes[1]]) == 'print' then
                return block.content
            end
        end
        if IsLaTeX(FORMAT) then
            if block.classes[1] == "box" then
                BOX_USED = true
            end
            -- FIXME: I have problems with the nesting of comments in LaTeX,
            -- which requires constantly refreshing the existing colors in
            -- nested block or inline contexts. Perhaps what I should do is
            -- take block.content and run it through further Block and Inline
            -- filters, keeping track of colors and applying them as
            -- appropriate.
            return
                {pandoc.Plain({LATEX_TEXT["block_" .. block.classes[1]].Open})} ..
                block.content ..
                {pandoc.Plain({LATEX_TEXT["block_" .. block.classes[1]].Close})}
        elseif IsHTML(FORMAT) then
            return
                {pandoc.Plain({HTML_TEXT["block_" .. block.classes[1]].Open})} ..
                block.content ..
                {pandoc.Plain({HTML_TEXT["block_" .. block.classes[1]].Close})}
        elseif FORMAT == "revealjs" then
            return
                {pandoc.Plain({HTML_TEXT["block_" .. block.classes[1]].Open})} ..
                block.content ..
                {pandoc.Plain({HTML_TEXT["block_" .. block.classes[1]].Close})}
        elseif FORMAT == "docx" then
            return
                {pandoc.Plain({DOCX_TEXT["block_" .. block.classes[1]].Open})} ..
                block.content ..
                {pandoc.Plain({DOCX_TEXT["block_" .. block.classes[1]].Close})}
        end
    end
end


-- function HandleMacros(math)
--     if YAML_VARS.macros then
--         for key, value in pairs(YAML_VARS.macros[1]) do
--             if math.text == key then
--                 return value
--             end
--         end
--     end
-- end


function HandleInlines(span)
    if FORMAT == "markdown" then  -- Don't change anything if translating to .md
        return
    end
    local spanType = span.classes[1]
    if spanType == "comment" or spanType == "margin" or
            spanType == "fixme" or spanType == "highlight" then
        -- Process comments ...
        if pandoc.utils.stringify(YAML_VARS[spanType]) == 'hide' then
            return {}
        elseif pandoc.utils.stringify(YAML_VARS[spanType]) == 'print' then
            return span.content
        end
        -- In this case, we want to print with draft markup
        if IsLaTeX(FORMAT) then
            return
                {LATEX_TEXT[spanType].Open} ..
                span.content ..
                {LATEX_TEXT[spanType].Close}
        elseif IsHTML(FORMAT) then
            return
                {HTML_TEXT[spanType].Open} ..
                span.content ..
                {HTML_TEXT[spanType].Close}
        elseif FORMAT == "revealjs" then
            return
                {REVEALJS_TEXT[spanType].Open} ..
                span.content ..
                {REVEALJS_TEXT[spanType].Close}
        elseif FORMAT == "docx" then
            return
                {DOCX_TEXT[spanType].Open} ..
                span.content ..
                {DOCX_TEXT[spanType].Close}
        end
    elseif spanType == "smcaps" then
        return pandoc.SmallCaps(span.content)
    elseif spanType == "i" then
        -- Process indexing ...
        if IsLaTeX(FORMAT) then
            return {Latex("\\index{" .. pandoc.utils.stringify(span) .. "}")}
        elseif FORMAT == 'docx' then
            print(span.content)
            local indexItem = pandoc.utils.stringify(span.content)
            indexItem = string.gsub(indexItem, '!', ':')  -- Subheadings
            -- Need to do other things here to identify ranges of pages,
            -- "See" and "See also" cross references, etc.
            return docx(
                DOCX_TEXT.i.Open ..
                indexItem ..
                DOCX_TEXT.i.Close)
        else
            return {}
        end
    elseif spanType == "l" or spanType == "r" or spanType == "rp" then
        -- Process cross-references ...
        content = pandoc.utils.stringify(span.content)
        if IsLaTeX(FORMAT) then
            return {Latex(
                LATEX_TEXT[spanType].Open ..
                content ..
                LATEX_TEXT[spanType].Close)}
        elseif IsHTML(FORMAT) then
            return {html(
                HTML_TEXT[spanType].Open ..
                content ..
                HTML_TEXT[spanType].Close)}
        elseif FORMAT == "revealjs" then
            return {html(
                REVEALJS_TEXT[spanType].Open ..
                content ..
                REVEALJS_TEXT[spanType].Close)}
        elseif FORMAT == "docx" then
            return {docx(
                DOCX_TEXT[spanType].Open ..
                content ..
                DOCX_TEXT[spanType].Close)}
        end
    end
end


function HandleNotes(note)
    return pandoc.walk_inline(note, {
        Str = function(string)
            if IsWord(string.text) then
                NOTE_COUNT = NOTE_COUNT + 1
            end
            return
        end})
end


function HandleStrings(string)
    if IsWord(string.text) then  -- If string contains non-punctuation chars
        WORD_COUNT = WORD_COUNT + 1  -- ... count it.
    end
    return
end

-- local inspect = require 'inspect'

function HandleQuotes(qstring)
    -- FIXME: This doesn't handle nested quotes. I think I need to walk the
    -- inline content of the quote, and assign all subsequent quotes to
    -- `\enquote{}` rather than `\blockquote{}`, but I can't figure out the
    -- syntax of it.
    if IsLaTeX(FORMAT) then
        print(qstring.content[1].text)
        print(qstring.counter)
        -- print(inspect(qstring.content))
        if qstring.level == 1 then
            table.insert(qstring.content, 1, Latex("\\enquote{"))
        else
            table.insert(qstring.content, 1, Latex("\\blockquote{"))
        end
        table.insert(qstring.content, Latex("}"))
        qstring.level = 1
        value = pandoc.walk_inline(qstring, {Quoted = HandleQuotes})
                -- { Quoted = function(qstring)
                --     table.remove(qstring.content,1)
                --     -- table.insert(qstring.content, 1, Latex("\\enquote*{"))
                --     table.insert(qstring.content, 1, Latex("\\enquote{"))
                --     return qstring.content
                -- end })
        return value.content
    else
        return
    end
end


function Inlines(inlines)
    local counter = 0
    for i = 1, #inlines do
        if inlines[i] and inlines[i].t == "Quoted" then
            if inlines[i].content:includes("Quoted", 1) then
                print(">" .. inlines[i].content[1].text)
            end
            -- counter = counter + 1
            -- print(":" .. inlines[i].content[1].text)
            -- print(counter)
            -- -- print(":" .. inspect(inlines[i].content[1]))
            -- inlines[i].counter = counter
            -- -- print(inspect(inlines[i]))
            -- table.insert(inlines[i].content, pandoc.Space())
            -- table.insert(inlines[i].content, pandoc.Str(tostring(counter)))
        end
    end
    return inlines
end


-- Order matters here!
local COMMENT_FILTER = {
    {Meta = GetYAML},             -- This comes first to read metadata values
    {Para = HandleTransclusion},  -- Transclusion before other filters
    {Para = HandleNoIndent},      -- Non-indented paragraphs (after transclusion)
    {CodeBlock = HandleCode},     -- Convert TikZ images (before Image)
    {Div = HandleBlocks},         -- Comment blocks (before inlines)
    -- {Inlines = Inlines},
    {Image = HandleImages},       -- Images (so captions get inline filters)
    -- {Math = HandleMacros},        -- Replace macros from YAML data
    -- {Quoted = HandleQuotes},      -- LaTeX: auto use csquotes' `\blockquote`
    {Span = HandleInlines},       -- Comment and cross-ref inlines
    {Note = HandleNotes},         -- Count words
    {Str = HandleStrings},        -- Count words
    {Meta = SetYAML}              -- This comes last to rewrite YAML
}

return COMMENT_FILTER
