function html = mdoc_render(info)
% mdoc_render  Render parsed documentation info as a self-contained HTML page.
%
% html = mdoc_render(info) takes the struct returned by mdoc_parse and
% generates a complete HTML string styled to approximate MATLAB doc pages.
% All Markdown rendering is done in MATLAB — no external JavaScript
% dependencies are required. KaTeX (CDN) is included as optional
% progressive enhancement for LaTeX math.

arguments
    info (1,1) struct
end

parts = {};
parts{end+1} = htmlHead(info.Name);
parts{end+1} = '<body><div class="doc-page">';

% Title and synopsis
parts{end+1} = sprintf('<h1 class="func-name">%s</h1>', esc(info.Name));
if info.Synopsis ~= ""
    parts{end+1} = sprintf('<p class="synopsis">%s</p>', inlineMd(info.Synopsis));
end

% Syntax
parts{end+1} = renderSyntax(info);

% Description
syntaxSource = "";
if isfield(info, 'SyntaxSource')
    syntaxSource = info.SyntaxSource;
end

if syntaxSource == "syntax_section"
    % Syntax descriptions come from ## Syntax entries; Description is
    % intro prose only (rendered without <hr> syntax separators).
    hasDescriptions = false;
    if isfield(info, 'SyntaxEntries')
        for sd = 1:numel(info.SyntaxEntries)
            if info.SyntaxEntries(sd).Description ~= ""
                hasDescriptions = true;
                break
            end
        end
    end
    if hasDescriptions || info.Description ~= ""
        parts{end+1} = '<h2>Description</h2>';
        parts{end+1} = '<div class="description-body">';
        if hasDescriptions
            parts{end+1} = renderSyntaxDescriptions(info.SyntaxEntries);
        end
        if info.Description ~= ""
            parts{end+1} = blockMd(info.Description);
        end
        parts{end+1} = '</div>';
    end
else
    % For "description", "auto", and "legacy" sources, render the
    % description text as-is. descriptionBlockMd adds <hr> separators
    % before backtick-starting paragraphs, preserving the traditional
    % calling-form-paragraph layout.
    if info.Description ~= ""
        parts{end+1} = '<h2>Description</h2>';
        parts{end+1} = '<div class="description-body">';
        parts{end+1} = descriptionBlockMd(info.Description);
        parts{end+1} = '</div>';
    end
end

% Examples (before Input Arguments, matching MathWorks order)
examplesContent = findSectionContent(info.Sections, "Examples");
if examplesContent ~= ""
    parts{end+1} = renderExamples(examplesContent);
end

% Input Arguments
if ~isempty(info.InputArgs)
    parts{end+1} = renderCollapsibleArgSection("Input Arguments", ...
        "section-input-args", renderArguments(info.InputArgs));
end

% Name-Value Arguments
if ~isempty(info.NameValueArgs)
    nvContent = "<p class=""nv-intro"">Specify optional pairs of arguments as <code>Name1=Value1,...,NameN=ValueN</code>.</p>" ...
        + newline + string(renderArguments(info.NameValueArgs));
    parts{end+1} = renderCollapsibleArgSection("Name-Value Arguments", ...
        "section-nv-args", nvContent);
end

% Output Arguments
if ~isempty(info.OutputArgs)
    parts{end+1} = renderCollapsibleArgSection("Output Arguments", ...
        "section-output-args", renderOutputArguments(info.OutputArgs));
end

% Remaining sections in spec order (Examples handled above)
sectionOrder = ["Tips", "Algorithms", "Version History", ...
    "References", "More About"];
for s = sectionOrder
    content = findSectionContent(info.Sections, s);
    if content ~= ""
        parts{end+1} = sprintf('<h2>%s</h2>', esc(s)); %#ok<AGROW>
        parts{end+1} = blockMd(content); %#ok<AGROW>
    end
end

% See Also
if ~isempty(info.SeeAlso)
    parts{end+1} = '<h2>See Also</h2>';
    links = {};
    for k = 1:numel(info.SeeAlso)
        name = strtrim(info.SeeAlso(k));
        links{k} = sprintf('<a href="matlab:mdoc(''%s'')">%s</a>', ...
            esc(name), esc(name));
    end
    parts{end+1} = sprintf('<p class="see-also">%s</p>', strjoin(string(links), " | "));
end

parts{end+1} = '</div>';
parts{end+1} = collapseScript();
parts{end+1} = mathScript();
parts{end+1} = '</body></html>';

html = strjoin(string(parts), newline);
end

%% ==== Markdown-to-HTML Engine ====

function html = blockMd(md)
% Convert a block of Markdown text to HTML.
% Handles: fenced code blocks, callouts, headings, lists, paragraphs.
lines = splitlines(string(md));
out = {};
i = 1;
while i <= numel(lines)
    line = lines(i);
    stripped = strtrim(line);

    % --- Fenced code block ---
    if startsWith(stripped, "```")
        lang = strtrim(extractAfter(stripped, "```"));
        if lang == "", lang = "matlab"; end
        codeLines = {};
        i = i + 1;
        while i <= numel(lines) && ~startsWith(strtrim(lines(i)), "```")
            codeLines{end+1} = char(esc(lines(i))); %#ok<AGROW>
            i = i + 1;
        end
        if i <= numel(lines), i = i + 1; end  % skip closing ```
        out{end+1} = sprintf('<pre><code class="language-%s">%s</code></pre>', ...
            char(lang), strjoin(string(codeLines), newline)); %#ok<AGROW>
        continue
    end

    % --- Callout: > [!NOTE] / > [!WARNING] / > [!IMPORTANT] ---
    tok = regexp(stripped, '^>\s*\[!(NOTE|WARNING|IMPORTANT)\]', 'tokens');
    if ~isempty(tok)
        ctype = lower(string(tok{1}{1}));
        bodyParts = {};
        i = i + 1;
        while i <= numel(lines) && startsWith(strtrim(lines(i)), ">")
            cline = regexprep(lines(i), '^\s*>\s?', '');
            bodyParts{end+1} = char(inlineMd(cline)); %#ok<AGROW>
            i = i + 1;
        end
        out{end+1} = sprintf(['<div class="callout callout-%s">' ...
            '<div class="callout-title">%s</div><p>%s</p></div>'], ...
            char(ctype), upper(char(ctype)), strjoin(string(bodyParts), " ")); %#ok<AGROW>
        continue
    end

    % --- Heading (### only — ## is handled as section splits by the parser) ---
    if startsWith(stripped, "### ")
        out{end+1} = sprintf('<h3>%s</h3>', char(inlineMd(extractAfter(stripped, "### ")))); %#ok<AGROW>
        i = i + 1;
        continue
    end

    % --- Unordered list ---
    if startsWith(stripped, "- ")
        items = {};
        while i <= numel(lines)
            s = strtrim(lines(i));
            if startsWith(s, "- ")
                items{end+1} = char(inlineMd(extractAfter(s, "- "))); %#ok<AGROW>
                i = i + 1;
                % Collect continuation lines (indented, not starting with -)
                while i <= numel(lines)
                    ns = lines(i);
                    nstripped = strtrim(ns);
                    if nstripped == "" || startsWith(nstripped, "- ") || ...
                            startsWith(nstripped, "```") || startsWith(nstripped, "### ") || ...
                            startsWith(nstripped, "> [!")
                        break
                    end
                    % Must be indented continuation
                    if startsWith(ns, "  ") || startsWith(ns, char(9))
                        items{end} = [items{end} ' ' char(inlineMd(nstripped))];
                        i = i + 1;
                    else
                        break
                    end
                end
            else
                break
            end
        end
        listHtml = "<ul>" + newline;
        for li = 1:numel(items)
            listHtml = listHtml + "  <li>" + string(items{li}) + "</li>" + newline;
        end
        listHtml = listHtml + "</ul>";
        out{end+1} = char(listHtml); %#ok<AGROW>
        continue
    end

    % --- Ordered list ---
    if ~isempty(regexp(stripped, '^\d+\.\s+', 'once'))
        items = {};
        while i <= numel(lines)
            t = regexp(strtrim(lines(i)), '^\d+\.\s+(.*)', 'tokens');
            if ~isempty(t)
                items{end+1} = char(inlineMd(string(t{1}{1}))); %#ok<AGROW>
                i = i + 1;
            else
                break
            end
        end
        listHtml = "<ol>" + newline;
        for li = 1:numel(items)
            listHtml = listHtml + "  <li>" + string(items{li}) + "</li>" + newline;
        end
        listHtml = listHtml + "</ol>";
        out{end+1} = char(listHtml); %#ok<AGROW>
        continue
    end

    % --- Blank line ---
    if stripped == ""
        i = i + 1;
        continue
    end

    % --- Paragraph: consecutive non-blank, non-block lines ---
    paraLines = {};
    while i <= numel(lines)
        s = strtrim(lines(i));
        if s == "" || startsWith(s, "```") || startsWith(s, "### ") || ...
                startsWith(s, "- ") || startsWith(s, "> [!") || ...
                ~isempty(regexp(s, '^\d+\.\s+', 'once'))
            break
        end
        paraLines{end+1} = char(inlineMd(lines(i))); %#ok<AGROW>
        i = i + 1;
    end
    if ~isempty(paraLines)
        out{end+1} = sprintf('<p>%s</p>', strjoin(string(paraLines), newline)); %#ok<AGROW>
    end
end

html = strjoin(string(out), newline);
end

function html = descriptionBlockMd(md)
% Render the Description section with <hr> separators before paragraphs
% that start with inline code (syntax-description pairs).
chunks = splitDescriptionChunks(md);
out = {};
for k = 1:numel(chunks)
    chunk = strtrim(chunks(k));
    if chunk == ""
        continue
    end
    % Insert <hr> before syntax paragraphs (start with backtick), skip first
    if k > 1 && startsWith(chunk, "`")
        out{end+1} = '<hr class="desc-sep">'; %#ok<AGROW>
    end
    out{end+1} = char(blockMd(chunk)); %#ok<AGROW>
end
html = strjoin(string(out), newline);
end

function chunks = splitDescriptionChunks(md)
% Split markdown text into chunks separated by blank lines.
lines = splitlines(string(md));
chunks = string.empty;
current = string.empty;
for k = 1:numel(lines)
    if strtrim(lines(k)) == ""
        if ~isempty(current)
            chunks(end+1) = strjoin(current, newline); %#ok<AGROW>
            current = string.empty;
        end
    else
        current(end+1) = lines(k); %#ok<AGROW>
    end
end
if ~isempty(current)
    chunks(end+1) = strjoin(current, newline);
end
end

function s = inlineMd(text)
% Convert inline Markdown to HTML. HTML-escapes first, then applies
% formatting patterns so user content is safe.
s = esc(text);

% Bold: **text**
s = regexprep(s, '\*\*(.+?)\*\*', '<strong>$1</strong>');

% Italic: _text_ (not inside identifiers)
s = regexprep(s, '(?<![a-zA-Z0-9])_([^_]+?)_(?![a-zA-Z0-9])', '<em>$1</em>');

% Inline code: `code`
s = regexprep(s, '`([^`]+?)`', '<code>$1</code>');

% Images: ![alt](path)  — must come before links
s = regexprep(s, '!\[([^\]]*?)\]\(([^)]+?)\)', '<img src="$2" alt="$1" style="max-width:100%">');

% Links: [text](url)
s = regexprep(s, '\[([^\]]+?)\]\(([^)]+?)\)', '<a href="$2">$1</a>');
end

function s = esc(text)
% HTML-escape special characters
s = string(text);
s = strrep(s, "&", "&amp;");
s = strrep(s, "<", "&lt;");
s = strrep(s, ">", "&gt;");
s = strrep(s, '"', "&quot;");
end

%% ==== Page Structure Renderers ====

function s = htmlHead(funcName)
s = sprintf([...
    '<!DOCTYPE html>\n' ...
    '<html lang="en">\n' ...
    '<head>\n' ...
    '<meta charset="UTF-8">\n' ...
    '<meta name="viewport" content="width=device-width, initial-scale=1.0">\n' ...
    '<title>%s</title>\n' ...
    '<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css">\n' ...
    '<style>\n%s</style>\n' ...
    '</head>'], esc(funcName), cssStyles());
end

function s = renderSyntax(info)
% Render the compact syntax block from SyntaxEntries.
if ~isfield(info, 'SyntaxEntries') || isempty(info.SyntaxEntries)
    % Fallback for legacy info structs without SyntaxEntries
    s = '<h2>Syntax</h2><div class="syntax-block"><pre>';
    for k = 1:numel(info.Signature)
        sig = info.Signature{k};
        display = regexprep(sig, '^function\s+', '');
        s = s + esc(string(display));
        if k < numel(info.Signature)
            s = s + newline;
        end
    end
    s = s + "</pre></div>";
    return
end

s = '<h2>Syntax</h2><div class="syntax-block"><pre>';
for k = 1:numel(info.SyntaxEntries)
    s = s + esc(info.SyntaxEntries(k).Form);
    if k < numel(info.SyntaxEntries)
        s = s + newline;
    end
end
s = s + "</pre></div>";
end

function s = renderSyntaxDescriptions(entries)
% Render syntax-description pairs from SyntaxEntries.
% Reconstructs Markdown text and renders via descriptionBlockMd so that
% <hr> separators and inline formatting are applied consistently.
mdLines = string.empty;
for k = 1:numel(entries)
    e = entries(k);
    if e.Description == ""
        continue
    end
    % Reconstruct: `form` description (may be multi-line)
    mdLines(end+1) = "`" + e.Form + "` " + e.Description; %#ok<AGROW>
    mdLines(end+1) = ""; %#ok<AGROW> % blank line between entries
end
md = strtrim(strjoin(mdLines, newline));
if md ~= ""
    s = descriptionBlockMd(md);
else
    s = "";
end
end

function s = renderArguments(args)
parts = {};
for k = 1:numel(args)
    a = args(k);
    parts{end+1} = '<div class="arg-entry collapsible">'; %#ok<AGROW>

    % Heading line: <code>name</code> — short description
    heading = sprintf('<code>%s</code>', char(esc(a.Name)));
    if a.ShortDesc ~= ""
        heading = heading + " &mdash; " + char(inlineMd(a.ShortDesc));
    end
    parts{end+1} = sprintf('<h3 class="arg-heading collapsible-toggle" onclick="toggleItem(this.parentElement)">%s</h3>', ...
        char(string(heading))); %#ok<AGROW>

    % Collapsible body: description + data types
    parts{end+1} = '<div class="collapsible-body">'; %#ok<AGROW>

    % Long description
    if isfield(a, 'LongDesc') && a.LongDesc ~= ""
        parts{end+1} = '<div class="arg-desc">'; %#ok<AGROW>
        parts{end+1} = char(blockMd(a.LongDesc)); %#ok<AGROW>
        parts{end+1} = '</div>'; %#ok<AGROW>
    end

    % Allowed values / Data Types / Default
    memberValues = extractMustBeMemberValues(a.Validators);
    if ~isempty(memberValues)
        % Show allowed option values with default marked
        defaultStripped = strip(a.Default, '"');
        valParts = string.empty;
        for vi = 1:numel(memberValues)
            v = memberValues(vi);
            if defaultStripped ~= "" && v == defaultStripped
                valParts(end+1) = sprintf('<code>"%s"</code> (default)', ...
                    char(esc(v))); %#ok<AGROW>
            else
                valParts(end+1) = sprintf('<code>"%s"</code>', ...
                    char(esc(v))); %#ok<AGROW>
            end
        end
        parts{end+1} = sprintf('<p class="arg-values">%s</p>', ...
            char(strjoin(valParts, " | "))); %#ok<AGROW>
    else
        % Data Types line
        if a.Class ~= ""
            parts{end+1} = sprintf('<p class="arg-datatypes"><code>%s</code></p>', ...
                char(esc(a.Class))); %#ok<AGROW>
        end
        % Default value
        if a.Default ~= ""
            parts{end+1} = sprintf('<p class="arg-default">Default: <code>%s</code></p>', ...
                char(esc(a.Default))); %#ok<AGROW>
        end
    end

    parts{end+1} = '</div>'; %#ok<AGROW> % end collapsible-body
    parts{end+1} = '</div>'; %#ok<AGROW> % end arg-entry
end
s = strjoin(string(parts), newline);
end

function s = renderOutputArguments(outArgs)
parts = {};
for k = 1:numel(outArgs)
    a = outArgs(k);
    parts{end+1} = '<div class="arg-entry collapsible">'; %#ok<AGROW>

    % Heading line: <code>name</code> — first line of description
    heading = sprintf('<code>%s</code>', char(esc(a.Name)));
    if a.LongDesc ~= ""
        descLines = splitlines(string(a.LongDesc));
        firstLine = strtrim(descLines(1));
        if firstLine ~= ""
            heading = heading + " &mdash; " + char(inlineMd(firstLine));
        end
    end
    parts{end+1} = sprintf('<h3 class="arg-heading collapsible-toggle" onclick="toggleItem(this.parentElement)">%s</h3>', ...
        char(string(heading))); %#ok<AGROW>

    % Collapsible body: full description
    parts{end+1} = '<div class="collapsible-body">'; %#ok<AGROW>
    if a.LongDesc ~= ""
        parts{end+1} = '<div class="arg-desc">'; %#ok<AGROW>
        parts{end+1} = char(blockMd(a.LongDesc)); %#ok<AGROW>
        parts{end+1} = '</div>'; %#ok<AGROW>
    end
    parts{end+1} = '</div>'; %#ok<AGROW> % end collapsible-body

    parts{end+1} = '</div>'; %#ok<AGROW>
end
s = strjoin(string(parts), newline);
end

function content = findSectionContent(sections, heading)
content = "";
for k = 1:numel(sections)
    if sections(k).Heading == heading
        content = string(sections(k).Content);
        return
    end
end
end

function s = renderCollapsibleArgSection(heading, sectionId, contentHtml)
% Wrap an argument section in a collapsible container with "collapse all" link.
% Uses string concatenation (not sprintf) to avoid issues with % in content.
s = '<div class="section" id="' + string(sectionId) + '">' + newline ...
    + '<div class="section-header">' + newline ...
    + '<h2>' + esc(heading) + '</h2>' + newline ...
    + '<span class="collapse-toggle" onclick="toggleAll(''' + string(sectionId) ...
    + ''')">collapse all</span>' + newline ...
    + '</div>' + newline ...
    + string(contentHtml) + newline ...
    + '</div>';
end

function s = renderExamples(content)
% Render the Examples section with collapsible individual examples.
% Splits content at ### boundaries into collapsible subsections.
lines = splitlines(string(content));

% Split into subsections at ### headings
subsections = {};
currentTitle = "";
currentLines = string.empty;
for k = 1:numel(lines)
    stripped = strtrim(lines(k));
    if startsWith(stripped, "### ")
        % Save previous subsection
        if currentTitle ~= ""
            subsections{end+1} = struct("Title", currentTitle, ...
                "Content", strjoin(currentLines, newline)); %#ok<AGROW>
        elseif ~isempty(currentLines)
            % Content before first ### (preamble)
            subsections{end+1} = struct("Title", "", ...
                "Content", strjoin(currentLines, newline)); %#ok<AGROW>
        end
        currentTitle = extractAfter(stripped, "### ");
        currentLines = string.empty;
    else
        currentLines(end+1) = lines(k); %#ok<AGROW>
    end
end
% Save last subsection
if currentTitle ~= ""
    subsections{end+1} = struct("Title", currentTitle, ...
        "Content", strjoin(currentLines, newline));
elseif ~isempty(currentLines)
    subsections{end+1} = struct("Title", "", ...
        "Content", strjoin(currentLines, newline));
end

% Build HTML
parts = {};
parts{end+1} = '<div class="section" id="section-examples">';
parts{end+1} = '<div class="section-header">';
parts{end+1} = '<h2>Examples</h2>';
parts{end+1} = '<span class="collapse-toggle" onclick="toggleAll(''section-examples'')">collapse all</span>';
parts{end+1} = '</div>';

for k = 1:numel(subsections)
    sub = subsections{k};
    if sub.Title ~= ""
        % Collapsible example with title
        parts{end+1} = '<div class="collapsible">'; %#ok<AGROW>
        parts{end+1} = sprintf('<h3 class="collapsible-toggle" onclick="toggleItem(this.parentElement)">%s</h3>', ...
            char(inlineMd(sub.Title))); %#ok<AGROW>
        parts{end+1} = '<div class="collapsible-body">'; %#ok<AGROW>
        parts{end+1} = char(blockMd(sub.Content)); %#ok<AGROW>
        parts{end+1} = '</div></div>'; %#ok<AGROW>
    else
        % Preamble content (no title, not collapsible)
        body = strtrim(sub.Content);
        if body ~= ""
            parts{end+1} = char(blockMd(body)); %#ok<AGROW>
        end
    end
end

parts{end+1} = '</div>';
s = strjoin(string(parts), newline);
end

%% ==== Math Script (optional KaTeX enhancement) ====

function s = mathScript()
s = [...
    '<script src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"></script>' newline ...
    '<script>' newline ...
    'document.addEventListener("DOMContentLoaded", function() {' newline ...
    '  document.querySelectorAll("p, li, .arg-desc").forEach(function(el) {' newline ...
    '    var html = el.innerHTML;' newline ...
    '    html = html.replace(/\$\$([^$]+?)\$\$/g, function(m, tex) {' newline ...
    '      try { return katex.renderToString(tex, {displayMode:true}); }' newline ...
    '      catch(e) { return m; }' newline ...
    '    });' newline ...
    '    html = html.replace(/\$([^$]+?)\$/g, function(m, tex) {' newline ...
    '      try { return katex.renderToString(tex, {displayMode:false}); }' newline ...
    '      catch(e) { return m; }' newline ...
    '    });' newline ...
    '    el.innerHTML = html;' newline ...
    '  });' newline ...
    '});' newline ...
    '</script>'];
end

function s = collapseScript()
s = [...
    '<script>' newline ...
    'function toggleItem(el) {' newline ...
    '  el.classList.toggle("collapsed");' newline ...
    '  updateToggleText(el.closest(".section"));' newline ...
    '}' newline ...
    'function toggleAll(sectionId) {' newline ...
    '  var section = document.getElementById(sectionId);' newline ...
    '  var items = section.querySelectorAll(".collapsible");' newline ...
    '  var toggle = section.querySelector(".collapse-toggle");' newline ...
    '  var allCollapsed = Array.from(items).every(function(i) {' newline ...
    '    return i.classList.contains("collapsed");' newline ...
    '  });' newline ...
    '  items.forEach(function(item) {' newline ...
    '    if (allCollapsed) item.classList.remove("collapsed");' newline ...
    '    else item.classList.add("collapsed");' newline ...
    '  });' newline ...
    '  toggle.textContent = allCollapsed ? "collapse all" : "expand all";' newline ...
    '}' newline ...
    'function updateToggleText(section) {' newline ...
    '  if (!section) return;' newline ...
    '  var items = section.querySelectorAll(".collapsible");' newline ...
    '  var toggle = section.querySelector(".collapse-toggle");' newline ...
    '  if (!toggle) return;' newline ...
    '  var allCollapsed = Array.from(items).every(function(i) {' newline ...
    '    return i.classList.contains("collapsed");' newline ...
    '  });' newline ...
    '  toggle.textContent = allCollapsed ? "expand all" : "collapse all";' newline ...
    '}' newline ...
    '</script>'];
end

%% ==== CSS ====

function css = cssStyles()
css = [...
    ':root {' newline ...
    '  --mw-link-color: #0076a8;' newline ...
    '  --heading-color: #1a1a1a;' newline ...
    '  --text: #333;' newline ...
    '  --light-bg: #f5f5f5;' newline ...
    '  --border: #e0e0e0;' newline ...
    '  --code-bg: #f5f5f5;' newline ...
    '  --arg-separator: #ddd;' newline ...
    '}' newline ...
    'body {' newline ...
    '  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;' newline ...
    '  color: var(--text);' newline ...
    '  line-height: 1.65;' newline ...
    '  margin: 0; padding: 0;' newline ...
    '  background: #fff;' newline ...
    '}' newline ...
    '.doc-page { max-width: 960px; margin: 0 auto; padding: 32px 40px; }' newline ...
    'h1.func-name {' newline ...
    '  color: var(--heading-color); font-size: 1.75em; font-weight: 700;' newline ...
    '  border-bottom: none; padding-bottom: 0;' newline ...
    '  margin-bottom: 2px; margin-top: 0;' newline ...
    '}' newline ...
    'p.synopsis { font-size: 1.05em; color: #555; margin-top: 4px; margin-bottom: 28px; }' newline ...
    'h2 {' newline ...
    '  color: var(--heading-color); font-size: 1.35em; font-weight: 600;' newline ...
    '  margin-top: 24px; margin-bottom: 10px;' newline ...
    '  border-bottom: 1px solid var(--border); padding-bottom: 4px;' newline ...
    '}' newline ...
    'h3 { color: var(--heading-color); font-size: 1.1em; font-weight: 600; margin-top: 12px; margin-bottom: 4px; }' newline ...
    '.syntax-block {' newline ...
    '  background: var(--light-bg); border: 1px solid var(--border);' newline ...
    '  border-radius: 3px; padding: 14px 18px;' newline ...
    '  font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;' newline ...
    '  font-size: 0.9em; overflow-x: auto; line-height: 1.7;' newline ...
    '}' newline ...
    '.syntax-block pre { margin: 0; }' newline ...
    '.arg-entry {' newline ...
    '  margin: 0 0 12px 0; padding: 0 0 12px 0;' newline ...
    '  border-bottom: 1px solid var(--arg-separator);' newline ...
    '  background: none;' newline ...
    '}' newline ...
    '.arg-entry:last-child { border-bottom: none; margin-bottom: 0; padding-bottom: 0; }' newline ...
    '.arg-heading { font-size: 1.15em; font-weight: 700; margin: 0 0 8px 0; color: var(--heading-color); }' newline ...
    '.arg-heading code { font-weight: 700; font-size: inherit; background: none; padding: 0; }' newline ...
    '.arg-desc { margin-top: 8px; }' newline ...
    '.arg-datatypes { margin-top: 10px; font-size: 0.92em; color: #555; }' newline ...
    '.arg-datatypes code { background: none; padding: 0; font-size: 0.95em; }' newline ...
    'pre { margin: 12px 0; }' newline ...
    'pre code {' newline ...
    '  background: var(--code-bg); display: block; padding: 14px 16px;' newline ...
    '  border: 1px solid var(--border); border-radius: 3px;' newline ...
    '  overflow-x: auto; font-size: 0.9em; line-height: 1.5;' newline ...
    '}' newline ...
    'code {' newline ...
    '  background: var(--code-bg); padding: 2px 5px; border-radius: 3px;' newline ...
    '  font-size: 0.9em;' newline ...
    '  font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;' newline ...
    '}' newline ...
    '.callout { border-left: 4px solid; padding: 12px 16px; margin: 16px 0; border-radius: 0 3px 3px 0; }' newline ...
    '.callout-note { border-color: #0076a8; background: #e8f4f8; }' newline ...
    '.callout-warning { border-color: #e6a800; background: #fff8e1; }' newline ...
    '.callout-important { border-color: #d32f2f; background: #fde8e8; }' newline ...
    '.callout-title { font-weight: 600; margin-bottom: 4px; }' newline ...
    '.nv-intro { color: #555; font-size: 0.95em; margin-bottom: 16px; }' newline ...
    'a { color: var(--mw-link-color); text-decoration: none; }' newline ...
    'a:hover { text-decoration: underline; }' newline ...
    '.see-also { margin-top: 8px; }' newline ...
    'img { max-width: 100%; margin: 8px 0; }' newline ...
    '.description-body p { margin: 0; }' newline ...
    'hr.desc-sep { border: none; border-top: 1px solid var(--border); margin: 8px 0; }' newline ...
    '.section-header { display: flex; justify-content: space-between; align-items: baseline; }' newline ...
    '.section-header h2 { margin-bottom: 8px; }' newline ...
    '.collapse-toggle { font-size: 0.85em; color: var(--mw-link-color); cursor: pointer; white-space: nowrap; }' newline ...
    '.collapse-toggle:hover { text-decoration: underline; }' newline ...
    '.collapsible.collapsed .collapsible-body { display: none; }' newline ...
    '.collapsible-toggle { cursor: pointer; }' newline ...
    '.arg-values { margin-top: 10px; font-size: 0.92em; color: #555; }' newline ...
    '.arg-values code { background: none; padding: 0; font-size: 0.95em; }' newline ...
    '.arg-default { margin-top: 4px; font-size: 0.92em; color: #555; }' newline ...
    '.arg-default code { background: none; padding: 0; font-size: 0.95em; }' newline ...
    ];
end

%% ==== Argument Metadata Helpers ====

function values = extractMustBeMemberValues(validators)
% Extract allowed values from mustBeMember validator.
% Returns string array of values, or empty if not found.
values = string.empty;
if validators == ""
    return
end
tok = regexp(validators, 'mustBeMember\([^,]+,\s*\[([^\]]+)\]\)', 'tokens');
if isempty(tok)
    return
end
raw = string(tok{1}{1});
parts = split(raw, ",");
for k = 1:numel(parts)
    v = strtrim(parts(k));
    v = strip(v, '"');
    v = strip(v, '''');
    if v ~= ""
        values(end+1) = v; %#ok<AGROW>
    end
end
end
