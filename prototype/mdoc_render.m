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

% Title and synopsis (with page-level expand/collapse all)
parts{end+1} = '<div class="title-bar">';
parts{end+1} = sprintf('<h1 class="func-name">%s</h1>', esc(info.Name));
parts{end+1} = '<span class="collapse-toggle page-toggle" onclick="toggleAllPage()">collapse all</span>';
parts{end+1} = '</div>';
if info.Synopsis ~= ""
    parts{end+1} = sprintf('<p class="synopsis">%s</p>', inlineMd(info.Synopsis));
end

% Branch on type: class pages, method pages, or function pages
if isfield(info, 'Type') && info.Type == "classdef"
    parts = [parts, renderClassPage(info)];
elseif isfield(info, 'Type') && info.Type == "method"
    % Add class context subtitle and back-link
    parts{end+1} = sprintf('<p class="method-subtitle"><a href="matlab:mdoc(''%s'')">%s</a> method</p>', ...
        char(esc(info.ClassName)), char(esc(info.ClassName)));
    parts = [parts, renderFunctionPage(info)];
else
    parts = [parts, renderFunctionPage(info)];
end

parts{end+1} = '</div>';
parts{end+1} = collapseScript();
parts{end+1} = mathScript();
parts{end+1} = '</body></html>';

html = strjoin(string(parts), newline);
end

%% ==== Page Type Renderers ====

function parts = renderFunctionPage(info)
% Render the body of a function documentation page.
parts = {};

% Syntax
parts{end+1} = renderSyntax(info);

% Description (with argument-name cross-links)
syntaxSource = "";
if isfield(info, 'SyntaxSource')
    syntaxSource = info.SyntaxSource;
end
argNames = collectArgNames(info);

if syntaxSource == "syntax_section"
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
            parts{end+1} = renderSyntaxDescriptions(info.SyntaxEntries, argNames);
        end
        if info.Description ~= ""
            parts{end+1} = linkifyArgNames(blockMd(info.Description), argNames);
        end
        parts{end+1} = '</div>';
    end
else
    if info.Description ~= ""
        parts{end+1} = '<h2>Description</h2>';
        parts{end+1} = '<div class="description-body">';
        parts{end+1} = descriptionBlockMd(info.Description, argNames);
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
parts = [parts, renderRemainingSections(info)];
end

function parts = renderClassPage(info)
% Render the body of a class documentation page.
parts = {};

% Description (simple block Markdown, no calling-form logic)
if info.Description ~= ""
    parts{end+1} = '<h2>Description</h2>';
    parts{end+1} = '<div class="description-body">';
    parts{end+1} = char(blockMd(info.Description));
    parts{end+1} = '</div>';
end

% Creation section (from constructor)
if isfield(info, 'Constructor') && ~isempty(info.Constructor.SyntaxEntries)
    parts{end+1} = '<h2>Creation</h2>';

    % Syntax block (built as single string to avoid extra newlines)
    ctorArgNames = collectCtorArgNames(info.Constructor);
    syntaxHtml = "<div class=""syntax-block""><pre>";
    for k = 1:numel(info.Constructor.SyntaxEntries)
        form = esc(info.Constructor.SyntaxEntries(k).Form);
        if info.Constructor.SyntaxEntries(k).Description ~= ""
            syntaxHtml = syntaxHtml + "<a href=""#ctor-desc-" + k + """ class=""syntax-link"">" + form + "</a>";
        else
            syntaxHtml = syntaxHtml + form;
        end
        if k < numel(info.Constructor.SyntaxEntries)
            syntaxHtml = syntaxHtml + newline;
        end
    end
    syntaxHtml = syntaxHtml + "</pre></div>";
    parts{end+1} = char(syntaxHtml);

    % Constructor description
    if info.Constructor.Description ~= ""
        parts{end+1} = '<div class="description-body">';
        parts{end+1} = char(descriptionBlockMd(info.Constructor.Description, ctorArgNames));
        parts{end+1} = '</div>';
    end

    % Constructor input arguments
    if ~isempty(info.Constructor.InputArgs)
        parts{end+1} = char(renderCollapsibleArgSection("Input Arguments", ...
            "section-ctor-args", renderArguments(info.Constructor.InputArgs)));
    end

    % Constructor name-value arguments
    if ~isempty(info.Constructor.NameValueArgs)
        nvContent = "<p class=""nv-intro"">Specify optional pairs of arguments as <code>Name1=Value1,...,NameN=ValueN</code>.</p>" ...
            + newline + string(renderArguments(info.Constructor.NameValueArgs));
        parts{end+1} = char(renderCollapsibleArgSection("Name-Value Arguments", ...
            "section-ctor-nv-args", nvContent));
    end
end

% Properties section
if isfield(info, 'Properties') && ~isempty(info.Properties)
    parts{end+1} = renderPropertiesSection(info.Properties);
end

% Object Functions section
if isfield(info, 'Methods') && ~isempty(info.Methods)
    parts{end+1} = renderObjectFunctions(info.Methods, info.Name);
end

% Events section
if isfield(info, 'Events') && ~isempty(info.Events)
    parts{end+1} = renderEventsSection(info.Events);
end

% Examples and remaining sections
examplesContent = findSectionContent(info.Sections, "Examples");
if examplesContent ~= ""
    parts{end+1} = renderExamples(examplesContent);
end

parts = [parts, renderRemainingSections(info)];
end

function parts = renderRemainingSections(info)
% Render Tips, Algorithms, Version History, etc. and See Also.
parts = {};
sectionOrder = ["Tips", "Algorithms", "Version History", ...
    "References", "More About"];
for s = sectionOrder
    content = findSectionContent(info.Sections, s);
    if content ~= ""
        parts{end+1} = sprintf('<h2>%s</h2>', esc(s)); %#ok<AGROW>
        parts{end+1} = char(blockMd(content)); %#ok<AGROW>
    end
end

% See Also
if ~isempty(info.SeeAlso)
    parts{end+1} = '<h2>See Also</h2>';
    links = {};
    for k = 1:numel(info.SeeAlso)
        name = strtrim(info.SeeAlso(k));
        links{k} = sprintf('<a href="matlab:mdoc(''%s'')">%s</a>', ...
            char(esc(name)), char(esc(name)));
    end
    parts{end+1} = sprintf('<p class="see-also">%s</p>', strjoin(string(links), " | "));
end
end

function s = renderPropertiesSection(props)
% Render the Properties section using collapsible argument-style entries.
parts = {};

% Wrap in a collapsible section with expand/collapse toggle
parts{end+1} = '<div class="section" id="section-properties">';
parts{end+1} = '<div class="section-header">';
parts{end+1} = '<h2>Properties</h2>';
parts{end+1} = '<span class="collapse-toggle" onclick="toggleAll(''section-properties'')">collapse all</span>';
parts{end+1} = '</div>';

% Check if any properties have groups
hasGroups = any(arrayfun(@(p) p.Group ~= "", props));

if hasGroups
    currentGroup = string(missing);
    for k = 1:numel(props)
        p = props(k);
        if ismissing(currentGroup) || p.Group ~= currentGroup
            currentGroup = p.Group;
            if currentGroup ~= ""
                parts{end+1} = sprintf('<h3 class="prop-group-heading">%s</h3>', char(esc(currentGroup))); %#ok<AGROW>
            end
        end
        parts{end+1} = renderPropertyEntry(p); %#ok<AGROW>
    end
else
    for k = 1:numel(props)
        parts{end+1} = renderPropertyEntry(props(k)); %#ok<AGROW>
    end
end

parts{end+1} = '</div>';
s = strjoin(string(parts), newline);
end

function s = renderPropertyEntry(p)
% Render a single property as a collapsible entry (like input arguments).
parts = {};
parts{end+1} = sprintf('<div class="arg-entry collapsible" id="prop-%s">', char(p.Name));

% Heading line: <code>name</code> [badges] — short description
heading = sprintf('<code>%s</code>', char(esc(p.Name)));

% Add badges
badges = string.empty;
if p.ReadOnly, badges(end+1) = "read-only"; end
if p.Dependent, badges(end+1) = "dependent"; end
if p.Constant, badges(end+1) = "constant"; end
if p.Abstract, badges(end+1) = "abstract"; end
for k = 1:numel(badges)
    heading = heading + sprintf(' <span class="prop-badge">%s</span>', char(badges(k)));
end

if p.ShortDesc ~= ""
    heading = heading + " &mdash; " + char(inlineMd(p.ShortDesc));
end
parts{end+1} = sprintf('<h3 class="arg-heading collapsible-toggle" onclick="toggleItem(this.parentElement)">%s</h3>', ...
    char(string(heading)));

% Collapsible body
parts{end+1} = '<div class="collapsible-body">';

% Long description
if isfield(p, 'LongDesc') && p.LongDesc ~= ""
    parts{end+1} = '<div class="arg-desc">';
    parts{end+1} = char(blockMd(p.LongDesc));
    parts{end+1} = '</div>';
end

% Type/default metadata
if p.Class ~= ""
    parts{end+1} = sprintf('<p class="arg-datatypes"><code>%s</code></p>', char(esc(p.Class)));
end
if p.Default ~= ""
    parts{end+1} = sprintf('<p class="arg-default">Default: <code>%s</code></p>', char(esc(p.Default)));
end

parts{end+1} = '</div>'; % end collapsible-body
parts{end+1} = '</div>'; % end arg-entry
s = strjoin(string(parts), newline);
end

function s = renderObjectFunctions(methods, className)
% Render the Object Functions section with optional grouping.
parts = {};
parts{end+1} = '<h2>Object Functions</h2>';

hasGroups = any(arrayfun(@(m) m.Group ~= "", methods));

if hasGroups
    currentGroup = string(missing);
    for k = 1:numel(methods)
        m = methods(k);
        if ismissing(currentGroup) || m.Group ~= currentGroup
            if ~ismissing(currentGroup)
                parts{end+1} = '</tbody></table>'; %#ok<AGROW>
            end
            currentGroup = m.Group;
            if currentGroup ~= ""
                parts{end+1} = sprintf('<h3 class="method-group-heading">%s</h3>', char(esc(currentGroup))); %#ok<AGROW>
            end
            parts{end+1} = '<table class="method-table"><tbody>'; %#ok<AGROW>
        end
        parts{end+1} = renderMethodRow(m, className); %#ok<AGROW>
    end
    parts{end+1} = '</tbody></table>';
else
    parts{end+1} = '<table class="method-table"><tbody>';
    for k = 1:numel(methods)
        parts{end+1} = renderMethodRow(methods(k), className); %#ok<AGROW>
    end
    parts{end+1} = '</tbody></table>';
end

s = strjoin(string(parts), newline);
end

function s = renderMethodRow(m, className)
% Render a single method table row with linked method name.
if m.IsStatic
    displayName = className + "." + m.Name;
else
    displayName = m.Name;
end
% Link to method page via mdoc (rewritten by mbuilddoc for static sites)
linkTarget = className + "." + m.Name;
s = sprintf('<tr><td class="method-name"><a href="matlab:mdoc(''%s'')"><code>%s</code></a></td><td class="method-desc">%s</td></tr>', ...
    char(esc(linkTarget)), char(esc(displayName)), char(inlineMd(m.Synopsis)));
end

function s = renderEventsSection(events)
% Render the Events section as a simple table.
parts = {};
parts{end+1} = '<h2>Events</h2>';
parts{end+1} = '<table class="event-table"><tbody>';
for k = 1:numel(events)
    e = events(k);
    parts{end+1} = sprintf('<tr><td class="event-name"><code>%s</code></td><td class="event-desc">%s</td></tr>', ...
        char(esc(e.Name)), char(inlineMd(e.Description))); %#ok<AGROW>
end
parts{end+1} = '</tbody></table>';
s = strjoin(string(parts), newline);
end

function argNames = collectCtorArgNames(ctorInfo)
% Collect argument names from constructor info.
argNames = string.empty;
for k = 1:numel(ctorInfo.InputArgs)
    argNames(end+1) = ctorInfo.InputArgs(k).Name; %#ok<AGROW>
end
for k = 1:numel(ctorInfo.NameValueArgs)
    argNames(end+1) = ctorInfo.NameValueArgs(k).Name; %#ok<AGROW>
end
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

function html = descriptionBlockMd(md, argNames)
% Render the Description section with <hr> separators before paragraphs
% that start with inline code (syntax-description pairs).
% Backtick-starting chunks get anchor IDs for syntax block links.
% Argument names in syntax forms are linked to their definitions.
chunks = splitDescriptionChunks(md);
out = {};
syntaxIdx = 0;
for k = 1:numel(chunks)
    chunk = strtrim(chunks(k));
    if chunk == ""
        continue
    end
    isSyntax = startsWith(chunk, "`");
    % Insert <hr> before syntax paragraphs (start with backtick), skip first
    if k > 1 && isSyntax
        out{end+1} = '<hr class="desc-sep">'; %#ok<AGROW>
    end
    if isSyntax
        syntaxIdx = syntaxIdx + 1;
        out{end+1} = sprintf('<div id="syntax-desc-%d" class="desc-entry">', syntaxIdx); %#ok<AGROW>

        % Extract form from backticks and linkify; render rest as markdown
        tok = regexp(chunk, '^`([^`]+)`([\s\S]*)', 'tokens', 'once');
        if ~isempty(tok)
            formHtml = linkifyForm(string(tok{1}), argNames);
            descText = strtrim(string(tok{2}));
            if descText ~= ""
                descHtml = blockMd(descText);
                out{end+1} = char(mergeFormIntoDesc(formHtml, descHtml)); %#ok<AGROW>
            else
                out{end+1} = char("<p>" + formHtml + "</p>"); %#ok<AGROW>
            end
        else
            out{end+1} = char(blockMd(chunk)); %#ok<AGROW>
        end

        out{end+1} = '</div>'; %#ok<AGROW>
    else
        out{end+1} = char(blockMd(chunk)); %#ok<AGROW>
    end
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
    form = esc(info.SyntaxEntries(k).Form);
    if info.SyntaxEntries(k).Description ~= ""
        s = s + string(sprintf('<a href="#syntax-desc-%d" class="syntax-link">%s</a>', k, form));
    else
        s = s + form;
    end
    if k < numel(info.SyntaxEntries)
        s = s + newline;
    end
end
s = s + "</pre></div>";
end

function s = renderSyntaxDescriptions(entries, argNames)
% Render syntax-description pairs from SyntaxEntries.
% Each entry gets an anchor id matching the syntax block links.
% Argument names in the syntax form are linked to their definitions.
out = {};
hasContent = false;
for k = 1:numel(entries)
    e = entries(k);
    if e.Description == ""
        continue
    end
    if hasContent
        out{end+1} = '<hr class="desc-sep">'; %#ok<AGROW>
    end
    out{end+1} = sprintf('<div id="syntax-desc-%d" class="desc-entry">', k); %#ok<AGROW>

    % Build linked syntax form directly, then render description via blockMd
    formHtml = linkifyForm(e.Form, argNames);
    descHtml = blockMd(e.Description);
    % Merge form into the first <p> of the description
    descHtml = mergeFormIntoDesc(formHtml, descHtml);
    out{end+1} = char(linkifyArgNames(descHtml, argNames)); %#ok<AGROW>

    out{end+1} = '</div>'; %#ok<AGROW>
    hasContent = true;
end
s = strjoin(string(out), newline);
end

function s = renderArguments(args)
parts = {};
for k = 1:numel(args)
    a = args(k);
    parts{end+1} = sprintf('<div class="arg-entry collapsible" id="arg-%s">', char(a.Name)); %#ok<AGROW>

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
    parts{end+1} = sprintf('<div class="arg-entry collapsible" id="arg-%s">', char(a.Name)); %#ok<AGROW>

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
    '  updatePageToggle();' newline ...
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
    '  updatePageToggle();' newline ...
    '}' newline ...
    'function toggleAllPage() {' newline ...
    '  var items = document.querySelectorAll(".collapsible");' newline ...
    '  var toggle = document.querySelector(".page-toggle");' newline ...
    '  var allCollapsed = Array.from(items).every(function(i) {' newline ...
    '    return i.classList.contains("collapsed");' newline ...
    '  });' newline ...
    '  items.forEach(function(item) {' newline ...
    '    if (allCollapsed) item.classList.remove("collapsed");' newline ...
    '    else item.classList.add("collapsed");' newline ...
    '  });' newline ...
    '  document.querySelectorAll(".section").forEach(function(sec) {' newline ...
    '    updateToggleText(sec);' newline ...
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
    'function updatePageToggle() {' newline ...
    '  var items = document.querySelectorAll(".collapsible");' newline ...
    '  var toggle = document.querySelector(".page-toggle");' newline ...
    '  if (!toggle) return;' newline ...
    '  var allCollapsed = Array.from(items).every(function(i) {' newline ...
    '    return i.classList.contains("collapsed");' newline ...
    '  });' newline ...
    '  toggle.textContent = allCollapsed ? "expand all" : "collapse all";' newline ...
    '}' newline ...
    '/* Auto-expand collapsed argument when navigating via anchor link */' newline ...
    'document.addEventListener("click", function(e) {' newline ...
    '  var link = e.target.closest("a.arg-ref, a.syntax-link");' newline ...
    '  if (!link) return;' newline ...
    '  var hash = link.getAttribute("href");' newline ...
    '  if (!hash || hash[0] !== "#") return;' newline ...
    '  var target = document.querySelector(hash);' newline ...
    '  if (!target) return;' newline ...
    '  if (target.classList.contains("collapsed")) {' newline ...
    '    target.classList.remove("collapsed");' newline ...
    '    updateToggleText(target.closest(".section"));' newline ...
    '    updatePageToggle();' newline ...
    '  }' newline ...
    '});' newline ...
    '</script>'];
end

%% ==== CSS ====

function css = cssStyles()
css = [...
    'html { scroll-behavior: smooth; }' newline ...
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
    '  line-height: 1.5;' newline ...
    '  margin: 0; padding: 0;' newline ...
    '  background: #fff;' newline ...
    '}' newline ...
    '.doc-page { max-width: 960px; margin: 0 auto; padding: 32px 40px; }' newline ...
    'h1.func-name {' newline ...
    '  color: var(--heading-color); font-size: 1.75em; font-weight: 700;' newline ...
    '  border-bottom: none; padding-bottom: 0;' newline ...
    '  margin-bottom: 2px; margin-top: 0;' newline ...
    '}' newline ...
    '.doc-page p { margin: 0 0 6px 0; }' newline ...
    '.doc-page ul, .doc-page ol { margin: 4px 0 6px 0; }' newline ...
    'p.synopsis { font-size: 1.05em; color: #555; margin-top: 4px; margin-bottom: 16px; }' newline ...
    'h2 {' newline ...
    '  color: var(--heading-color); font-size: 1.35em; font-weight: 600;' newline ...
    '  margin-top: 20px; margin-bottom: 6px;' newline ...
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
    '  margin: 0 0 8px 0; padding: 0 0 8px 0;' newline ...
    '  border-bottom: 1px solid var(--arg-separator);' newline ...
    '  background: none;' newline ...
    '}' newline ...
    '.arg-entry:last-child { border-bottom: none; margin-bottom: 0; padding-bottom: 0; }' newline ...
    '.arg-heading { font-size: 1.15em; font-weight: 700; margin: 0 0 4px 0; color: var(--heading-color); }' newline ...
    '.arg-heading code { font-weight: 700; font-size: inherit; background: none; padding: 0; }' newline ...
    '.arg-desc { margin-top: 4px; }' newline ...
    '.arg-datatypes { margin-top: 6px; font-size: 0.92em; color: #555; }' newline ...
    '.arg-datatypes code { background: none; padding: 0; font-size: 0.95em; }' newline ...
    'pre { margin: 8px 0; }' newline ...
    'pre code {' newline ...
    '  background: var(--code-bg); display: block; padding: 10px 14px;' newline ...
    '  border: 1px solid var(--border); border-radius: 3px;' newline ...
    '  overflow-x: auto; font-size: 0.9em; line-height: 1.5;' newline ...
    '}' newline ...
    'code {' newline ...
    '  background: var(--code-bg); padding: 2px 5px; border-radius: 3px;' newline ...
    '  font-size: 0.9em;' newline ...
    '  font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;' newline ...
    '}' newline ...
    '.callout { border-left: 4px solid; padding: 10px 14px; margin: 10px 0; border-radius: 0 3px 3px 0; }' newline ...
    '.callout-note { border-color: #0076a8; background: #e8f4f8; }' newline ...
    '.callout-warning { border-color: #e6a800; background: #fff8e1; }' newline ...
    '.callout-important { border-color: #d32f2f; background: #fde8e8; }' newline ...
    '.callout-title { font-weight: 600; margin-bottom: 4px; }' newline ...
    '.nv-intro { color: #555; font-size: 0.95em; margin-bottom: 10px; }' newline ...
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
    '.arg-values { margin-top: 6px; font-size: 0.92em; color: #555; }' newline ...
    '.arg-values code { background: none; padding: 0; font-size: 0.95em; }' newline ...
    '.arg-default { margin-top: 4px; font-size: 0.92em; color: #555; }' newline ...
    '.arg-default code { background: none; padding: 0; font-size: 0.95em; }' newline ...
    '.title-bar { display: flex; justify-content: space-between; align-items: baseline; }' newline ...
    '.title-bar .page-toggle { margin-top: 8px; }' newline ...
    '.syntax-link { color: var(--mw-link-color); }' newline ...
    '.arg-ref { color: var(--mw-link-color); }' newline ...
    '.arg-ref code { color: inherit; background: none; padding: 0; }' newline ...
    '.desc-entry { scroll-margin-top: 16px; }' newline ...
    '.arg-entry { scroll-margin-top: 16px; }' newline ...
    '.prop-table, .method-table, .event-table { width: 100%; border-collapse: collapse; margin: 8px 0; }' newline ...
    '.prop-table td, .method-table td, .event-table td { padding: 6px 12px; border-bottom: 1px solid var(--border); vertical-align: top; }' newline ...
    '.prop-name, .method-name, .event-name { white-space: nowrap; width: 1%; font-weight: 500; }' newline ...
    '.prop-name code, .method-name code, .event-name code { background: none; padding: 0; font-weight: 600; }' newline ...
    '.prop-desc, .method-desc, .event-desc { color: var(--text); }' newline ...
    '.prop-meta { font-size: 0.85em; color: #777; margin-top: 2px; }' newline ...
    '.prop-meta code { background: none; padding: 0; font-size: 0.95em; }' newline ...
    '.prop-badge { display: inline-block; font-size: 0.75em; padding: 1px 6px; margin-left: 6px; border-radius: 3px; background: #e8f4f8; color: #0076a8; font-weight: 500; vertical-align: middle; }' newline ...
    '.prop-group-heading, .method-group-heading { font-size: 1.05em; font-weight: 600; margin: 16px 0 4px 0; color: var(--heading-color); }' newline ...
    '.method-subtitle { font-size: 0.95em; color: #555; margin-top: 0; margin-bottom: 12px; }' newline ...
    ];
end

%% ==== Cross-Reference Helpers ====

function argNames = collectArgNames(info)
% Collect all known argument names (inputs, name-values, outputs).
argNames = string.empty;
for k = 1:numel(info.InputArgs)
    argNames(end+1) = info.InputArgs(k).Name; %#ok<AGROW>
end
for k = 1:numel(info.NameValueArgs)
    argNames(end+1) = info.NameValueArgs(k).Name; %#ok<AGROW>
end
for k = 1:numel(info.OutputArgs)
    argNames(end+1) = info.OutputArgs(k).Name; %#ok<AGROW>
end
end

function html = linkifyForm(formText, argNames)
% Build <code> HTML for a syntax form with argument names linked
% to their definitions. Operates on raw text before HTML conversion,
% so no complex HTML parsing is needed.
html = esc(formText);
if isempty(argNames)
    html = "<code>" + html + "</code>";
    return
end
% Sort by length descending so longer names match first
[~, order] = sort(strlength(argNames), 'descend');
sorted = argNames(order);
for k = 1:numel(sorted)
    name = sorted(k);
    eName = regexptranslate('escape', char(name));
    html = regexprep(html, ['\b' eName '\b'], ...
        char('<a href="#arg-' + name + '" class="arg-ref">' + name + '</a>'));
end
html = "<code>" + html + "</code>";
end

function html = mergeFormIntoDesc(formHtml, descHtml)
% Merge a linked syntax-form <code> element into the first <p> of
% rendered description HTML, so they appear on the same line.
descHtml = string(descHtml);
if startsWith(strtrim(descHtml), "<p>")
    html = regexprep(descHtml, '<p>', char("<p>" + formHtml + " "), 'once');
else
    html = "<p>" + formHtml + "</p>" + newline + descHtml;
end
end

function html = linkifyArgNames(html, argNames)
% Post-process HTML to link standalone <code>name</code> references
% in body text to their definitions in the argument sections.
if isempty(argNames)
    return
end
html = string(html);
% Sort by length descending so longer names match first
[~, order] = sort(strlength(argNames), 'descend');
argNames = argNames(order);
for k = 1:numel(argNames)
    name = argNames(k);
    html = strrep(html, ...
        "<code>" + name + "</code>", ...
        "<a href=""#arg-" + name + """ class=""arg-ref""><code>" + name + "</code></a>");
end
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
