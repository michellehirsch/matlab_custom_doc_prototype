function mhelp(name)
% mhelp  Display plain-text help for a MATLAB function.
%
% mhelp name displays the help comment block from the specified function's
% .m file with Markdown formatting stripped for clean command-window output.
%
% mhelp(name) also accepts a file path as a string.
%
% This is a prototype stand-in for MATLAB's built-in help command,
% demonstrating the custom documentation framework.

arguments
    name (1,1) string
end

info = mdoc_parse(name);

if isempty(info.HelpLines)
    fprintf("  No help found for %s.\n", info.Name);
    return
end

% Build output: function name as header, then stripped help lines
fprintf("  <strong>%s</strong>", info.Name);
if info.Synopsis ~= ""
    fprintf(" — %s", stripMarkdown(info.Synopsis));
end
fprintf("\n\n");

% Print each help line with markdown stripped
lines = info.HelpLines;
% Skip the first line (synopsis, already printed above)
if numel(lines) > 1
    body = lines(2:end);

    % Strip leading blank lines
    while ~isempty(body) && strtrim(body(1)) == ""
        body(1) = [];
    end

    inCodeBlock = false;
    for k = 1:numel(body)
        line = body(k);

        % Track fenced code blocks
        if startsWith(strtrim(line), "```")
            inCodeBlock = ~inCodeBlock;
            if inCodeBlock
                fprintf("\n");
            end
            continue
        end

        if inCodeBlock
            fprintf("    %s\n", line);
        else
            fprintf("  %s\n", stripMarkdown(line));
        end
    end
end

fprintf("\n");
end

function out = stripMarkdown(text)
% Strip Markdown formatting for plain-text display

out = text;

% ## Heading → HEADING (uppercase)
tok = regexp(out, '^(#{2,3})\s+(.*)', 'tokens');
if ~isempty(tok)
    out = upper(tok{1}{2});
    return
end

% > [!NOTE] / [!WARNING] / [!IMPORTANT] → NOTE: / WARNING: / IMPORTANT:
out = regexprep(out, '^>\s*\[!(NOTE|WARNING|IMPORTANT)\]', '${upper($1)}:');
% > blockquote prefix
out = regexprep(out, '^>\s?', '  ');

% Bold: **text** → text
out = regexprep(out, '\*\*(.+?)\*\*', '$1');

% Italic: _text_ → text  (careful not to match snake_case)
out = regexprep(out, '(?<![a-zA-Z])_([^_]+?)_(?![a-zA-Z])', '$1');

% Inline code: `code` → CODE
out = regexprep(out, '`([^`]+?)`', '$1');

% Links: [text](url) → text
out = regexprep(out, '\[([^\]]+?)\]\([^)]+?\)', '$1');

% Images: ![alt](path) → (alt)
out = regexprep(out, '!\[([^\]]*?)\]\([^)]+?\)', '($1)');

% Display math: $$...$$ → keep as-is (no good plain-text rendering)
% Inline math: $...$ → keep as-is

end
