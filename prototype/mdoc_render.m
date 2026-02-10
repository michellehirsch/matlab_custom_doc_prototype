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
if info.Description ~= ""
    parts{end+1} = '<h2>Description</h2>';
    parts{end+1} = blockMd(info.Description);
end

% Input Arguments
if ~isempty(info.InputArgs)
    parts{end+1} = '<h2>Input Arguments</h2>';
    parts{end+1} = renderArguments(info.InputArgs);
end

% Name-Value Arguments
if ~isempty(info.NameValueArgs)
    parts{end+1} = '<h2>Name-Value Arguments</h2>';
    parts{end+1} = '<p>Specify optional pairs of arguments as <code>Name1=Value1,...,NameN=ValueN</code>.</p>';
    parts{end+1} = renderArguments(info.NameValueArgs);
end

% Output Arguments
if ~isempty(info.OutputArgs)
    parts{end+1} = '<h2>Output Arguments</h2>';
    parts{end+1} = renderOutputArguments(info.OutputArgs);
end

% Remaining sections in spec order
sectionOrder = ["Examples", "Tips", "Algorithms", "Version History", ...
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
end

function s = renderArguments(args)
parts = {};
for k = 1:numel(args)
    a = args(k);
    parts{end+1} = '<div class="arg-entry">'; %#ok<AGROW>
    parts{end+1} = '<div class="arg-header">'; %#ok<AGROW>
    parts{end+1} = sprintf('<span class="arg-name">%s</span>', esc(a.Name)); %#ok<AGROW>

    meta = {};
    if a.Size ~= ""
        meta{end+1} = char(a.Size);
    end
    if a.Class ~= ""
        meta{end+1} = char(a.Class);
    end
    if a.Default ~= ""
        meta{end+1} = "default: " + a.Default;
    end
    if ~isempty(meta)
        parts{end+1} = sprintf('<span class="arg-meta">%s</span>', ...
            esc(strjoin(string(meta), " · "))); %#ok<AGROW>
    end
    parts{end+1} = '</div>'; %#ok<AGROW>

    desc = a.ShortDesc;
    if isfield(a, 'LongDesc') && a.LongDesc ~= ""
        desc = a.LongDesc;
    end
    if desc ~= ""
        parts{end+1} = '<div class="arg-desc">'; %#ok<AGROW>
        parts{end+1} = char(blockMd(desc)); %#ok<AGROW>
        parts{end+1} = '</div>'; %#ok<AGROW>
    end
    parts{end+1} = '</div>'; %#ok<AGROW>
end
s = strjoin(string(parts), newline);
end

function s = renderOutputArguments(outArgs)
parts = {};
for k = 1:numel(outArgs)
    a = outArgs(k);
    parts{end+1} = '<div class="arg-entry">'; %#ok<AGROW>
    parts{end+1} = sprintf('<div class="arg-header"><span class="arg-name">%s</span></div>', ...
        esc(a.Name)); %#ok<AGROW>
    if a.LongDesc ~= ""
        parts{end+1} = '<div class="arg-desc">'; %#ok<AGROW>
        parts{end+1} = char(blockMd(a.LongDesc)); %#ok<AGROW>
        parts{end+1} = '</div>'; %#ok<AGROW>
    end
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

%% ==== CSS ====

function css = cssStyles()
css = [...
    ':root {' newline ...
    '  --blue: #0076a8;' newline ...
    '  --dark-blue: #00547a;' newline ...
    '  --light-bg: #f7f7f7;' newline ...
    '  --border: #e0e0e0;' newline ...
    '  --text: #333;' newline ...
    '  --code-bg: #f4f4f4;' newline ...
    '}' newline ...
    'body {' newline ...
    '  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;' newline ...
    '  color: var(--text);' newline ...
    '  line-height: 1.6;' newline ...
    '  margin: 0; padding: 0;' newline ...
    '}' newline ...
    '.doc-page { max-width: 900px; margin: 0 auto; padding: 24px 32px; }' newline ...
    'h1.func-name {' newline ...
    '  color: var(--dark-blue); font-size: 1.8em;' newline ...
    '  border-bottom: 2px solid var(--blue);' newline ...
    '  padding-bottom: 8px; margin-bottom: 4px;' newline ...
    '}' newline ...
    'p.synopsis { font-size: 1.1em; color: #555; margin-top: 0; margin-bottom: 24px; }' newline ...
    'h2 {' newline ...
    '  color: var(--dark-blue); font-size: 1.3em; margin-top: 32px;' newline ...
    '  border-bottom: 1px solid var(--border); padding-bottom: 6px;' newline ...
    '}' newline ...
    'h3 { color: var(--dark-blue); font-size: 1.1em; }' newline ...
    '.syntax-block {' newline ...
    '  background: var(--light-bg); border: 1px solid var(--border);' newline ...
    '  border-radius: 4px; padding: 12px 16px;' newline ...
    '  font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;' newline ...
    '  font-size: 0.9em; overflow-x: auto;' newline ...
    '}' newline ...
    '.arg-entry {' newline ...
    '  background: var(--light-bg); border: 1px solid var(--border);' newline ...
    '  border-radius: 4px; margin: 12px 0; padding: 12px 16px;' newline ...
    '}' newline ...
    '.arg-header {' newline ...
    '  display: flex; justify-content: space-between; align-items: baseline;' newline ...
    '  flex-wrap: wrap; gap: 8px;' newline ...
    '}' newline ...
    '.arg-name { font-family: monospace; font-weight: bold; font-size: 1.05em; color: var(--dark-blue); }' newline ...
    '.arg-meta { font-size: 0.85em; color: #666; }' newline ...
    '.arg-desc { margin-top: 8px; }' newline ...
    'pre { margin: 8px 0; }' newline ...
    'pre code {' newline ...
    '  background: var(--code-bg); display: block; padding: 12px;' newline ...
    '  border-radius: 4px; overflow-x: auto; font-size: 0.9em;' newline ...
    '}' newline ...
    'code { background: var(--code-bg); padding: 1px 4px; border-radius: 3px; font-size: 0.9em; }' newline ...
    'pre code { padding: 12px; }' newline ...
    '.callout { border-left: 4px solid; padding: 12px 16px; margin: 12px 0; border-radius: 0 4px 4px 0; }' newline ...
    '.callout-note { border-color: #0076a8; background: #e8f4f8; }' newline ...
    '.callout-warning { border-color: #e6a800; background: #fff8e1; }' newline ...
    '.callout-important { border-color: #d32f2f; background: #fde8e8; }' newline ...
    '.callout-title { font-weight: bold; margin-bottom: 4px; }' newline ...
    '.see-also a { color: var(--blue); text-decoration: none; }' newline ...
    '.see-also a:hover { text-decoration: underline; }' newline ...
    'img { max-width: 100%; margin: 8px 0; }' newline ...
    ];
end
