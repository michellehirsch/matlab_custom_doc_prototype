function info = mdoc_parse(name)
% mdoc_parse  Parse a MATLAB .m file into structured documentation data.
%
% info = mdoc_parse(name) parses the function or class file identified by
% name and returns a struct containing the help comment block, arguments
% block metadata, function signature, and all recognized documentation
% sections.
%
% name can be a function name (resolved via which()) or a file path.

arguments
    name (1,1) string
end

%% Resolve file path
filepath = resolveFile(name);
raw = string(fileread(filepath));
lines = splitlines(raw);

%% Join continuation lines (... at end of line)
lines = joinContinuationLines(lines);

%% Find function or classdef declaration
[funcLine, funcIdx] = findDeclaration(lines);
if startsWith(strtrim(funcLine), "classdef ")
    info.Type = "classdef";
    [info.Name, info.Signature] = parseClassdefDeclaration(funcLine);
    info.OutputArgNames = string.empty;
else
    info.Type = "function";
    [info.Name, info.Signature, info.OutputArgNames] = parseFunctionDeclaration(funcLine);
end

%% Extract help comment block (contiguous % lines after declaration)
[helpLines, helpEndIdx] = extractHelpBlock(lines, funcIdx);

%% Parse help block
info.Synopsis = parseSynopsis(helpLines, info.Name);
[info.Description, info.Sections, info.SeeAlso] = parseHelpBody(helpLines);

%% Extract long-form argument descriptions from sections
inputArgLong = extractArgDescriptions(info.Sections, "Input Arguments");
outputArgLong = extractArgDescriptions(info.Sections, "Output Arguments");

%% Parse arguments block (if present)
[parsedArgs, parsedNVArgs] = parseArgumentsBlock(lines, helpEndIdx);

%% Merge inline and long-form descriptions
info.InputArgs = mergeArgDescriptions(parsedArgs, inputArgLong);
info.NameValueArgs = mergeArgDescriptions(parsedNVArgs, inputArgLong);

%% Build output arguments from long-form descriptions and function signature
info.OutputArgs = buildOutputArgs(info.OutputArgNames, outputArgLong);

%% Classdef-specific parsing
if info.Type == "classdef"
    % Parse properties, methods, events blocks
    hasPropsSection = any(arrayfun(@(s) s.Heading == "Properties", info.Sections));
    info.Properties = parsePropertiesBlocks(lines, hasPropsSection, info.Sections);
    [info.Methods, constructorRange] = parseMethodsBlocks(lines, info.Name);
    info.Events = parseEventsBlocks(lines);

    % Parse constructor fully (like a function)
    if ~isempty(constructorRange)
        info.Constructor = parseConstructorMethod(lines, constructorRange, info.Name);
    else
        % Auto-generate minimal constructor info
        info.Constructor = generateDefaultConstructor(info.Name, info.Properties);
    end

    % Fully parse each public method (for standalone method pages)
    info.MethodInfos = {};
    for mi = 1:numel(info.Methods)
        m = info.Methods(mi);
        if isfield(m, 'Range') && ~isempty(m.Range)
            mInfo = parseMethodFull(lines, m.Range, m.Name, info.Name);
            mInfo.Group = m.Group;
            mInfo.IsStatic = m.IsStatic;
            info.MethodInfos{end+1} = mInfo;
        end
    end

    % Classes don't use top-level syntax entries
    info.SyntaxEntries = struct("Form", {}, "Description", {});
    info.SyntaxSource = "classdef";
    info.InputArgs = struct("Name", {}, "Size", {}, "Class", {}, ...
        "Default", {}, "Validators", {}, "ShortDesc", {}, "LongDesc", {});
    info.NameValueArgs = info.InputArgs;
    info.OutputArgs = struct("Name", {}, "LongDesc", {});
else
    %% Build syntax entries (three-priority model) — functions only
    % Priority 1: ## Syntax section is the sole source
    syntaxContent = "";
    for k = 1:numel(info.Sections)
        if info.Sections(k).Heading == "Syntax"
            syntaxContent = string(info.Sections(k).Content);
            break
        end
    end

    if syntaxContent ~= ""
        info.SyntaxEntries = parseSyntaxSection(syntaxContent, info.Name);
        info.SyntaxSource = "syntax_section";
    else
        % Priority 2: Calling-form paragraphs in description
        entries = extractCallingForms(info.Description, info.Name);
        if ~isempty(entries)
            info.SyntaxEntries = entries;
            info.SyntaxSource = "description";
        elseif ~isempty(parsedArgs) || ~isempty(parsedNVArgs)
            % Priority 3: Auto-generate from parsed arguments
            info.SyntaxEntries = generateAutoSyntax(info.Name, ...
                info.OutputArgNames, parsedArgs, parsedNVArgs);
            info.SyntaxSource = "auto";
        else
            % Legacy fallback: strip function keyword from declaration
            display = regexprep(info.Signature{1}, '^function\s+', '');
            info.SyntaxEntries = struct("Form", string(display), ...
                "Description", "");
            info.SyntaxSource = "legacy";
        end
    end
end

%% Store raw help lines for mhelp
info.HelpLines = helpLines;

end

%% ---- Local Functions ----

function filepath = resolveFile(name)
% Try as file path first, then use which()
if isfile(name)
    filepath = name;
    return
end
% Try appending .m
if isfile(name + ".m")
    filepath = name + ".m";
    return
end
% Use which
filepath = string(which(char(name)));
if filepath == "" || filepath.startsWith("built-in")
    error("mdoc_parse:FileNotFound", "Cannot find file for '%s'.", name);
end
end

function lines = joinContinuationLines(lines)
% Join CODE lines ending with ... (MATLAB continuation).
% Skip comment lines — ... in a comment is just an ellipsis, not continuation.
k = 1;
while k < numel(lines)
    stripped = strtrim(lines(k));
    if ~startsWith(stripped, "%") && endsWith(stripped, "...")
        % Remove the ... and join with next line
        lines(k) = extractBefore(stripped, strlength(stripped) - 2) + " " + strtrim(lines(k+1));
        lines(k+1) = [];
    else
        k = k + 1;
    end
end
end

function [funcLine, funcIdx] = findDeclaration(lines)
% Find the first function or classdef declaration line
funcIdx = 0;
funcLine = "";
for k = 1:numel(lines)
    stripped = strtrim(lines(k));
    if startsWith(stripped, "function ")
        funcLine = stripped;
        funcIdx = k;
        return
    elseif startsWith(stripped, "classdef ")
        funcLine = stripped;
        funcIdx = k;
        return
    end
end
error("mdoc_parse:NoDeclaration", "No function or classdef declaration found.");
end

function [name, signature, outputArgNames] = parseFunctionDeclaration(funcLine)
% Parse: function [out1, out2] = name(in1, in2, opts)
% or:    function out = name(in1, in2)
% or:    function name(in1)
sig = funcLine;
body = extractAfter(sig, "function ");
body = strtrim(body);

% Check for output arguments
outputArgNames = string.empty;
if contains(body, "=")
    parts = split(body, "=");
    outPart = strtrim(parts(1));
    remainder = strtrim(join(parts(2:end), "="));

    % Parse output args: could be [a, b] or just a
    outPart = strip(outPart);
    if startsWith(outPart, "[")
        outStr = extractBetween(outPart, "[", "]");
        outputArgNames = strip(split(outStr, ","));
    else
        outputArgNames = strip(outPart);
    end
else
    remainder = body;
end

% Extract function name (before parentheses)
if contains(remainder, "(")
    name = extractBefore(remainder, "(");
else
    name = remainder;
end
name = strtrim(name);

% Build clean signature string
signature = {char(sig)};
end

function [name, signature] = parseClassdefDeclaration(funcLine)
% Parse: classdef ClassName
% or:    classdef ClassName < SuperClass1 & SuperClass2
% or:    classdef (Sealed, Abstract) ClassName < SuperClass
sig = funcLine;
body = extractAfter(sig, "classdef ");
body = strtrim(body);

% Strip optional attributes: (Sealed, Abstract, ...)
if startsWith(body, "(")
    closeIdx = strfind(body, ")");
    if ~isempty(closeIdx)
        body = strtrim(extractAfter(body, closeIdx(1)));
    end
end

% Strip superclass list: ClassName < Super1 & Super2
if contains(body, "<")
    name = strtrim(extractBefore(body, "<"));
else
    name = strtrim(body);
end

signature = {char(sig)};
end

function [helpLines, helpEndIdx] = extractHelpBlock(lines, startIdx)
% Extract contiguous comment lines starting from startIdx+1
helpLines = string.empty;
helpEndIdx = startIdx;
for k = (startIdx + 1):numel(lines)
    stripped = strtrim(lines(k));
    if startsWith(stripped, "%")
        % Strip leading % and optional single space
        content = extractAfter(stripped, "%");
        if startsWith(content, " ")
            content = extractAfter(content, " ");
        end
        helpLines(end+1) = content; %#ok<AGROW>
        helpEndIdx = k;
    elseif stripped == ""
        % Blank line inside help block? Check if next line is still a comment
        if k + 1 <= numel(lines) && startsWith(strtrim(lines(k+1)), "%")
            helpLines(end+1) = ""; %#ok<AGROW>
            helpEndIdx = k;
        else
            break
        end
    else
        break
    end
end
end

function synopsis = parseSynopsis(helpLines, funcName)
% First line: "funcName  One-line description" → extract description
synopsis = "";
if isempty(helpLines)
    return
end
firstLine = strtrim(helpLines(1));
% Strip leading function name (case-insensitive)
if startsWith(firstLine, funcName, "IgnoreCase", true)
    synopsis = strtrim(extractAfter(firstLine, strlength(funcName)));
else
    synopsis = firstLine;
end
end

function [description, sections, seeAlso] = parseHelpBody(helpLines)
% Parse the help block into description, sections, and see-also
description = "";
sections = struct("Heading", {}, "Content", {});
seeAlso = string.empty;

if isempty(helpLines)
    return
end

% Work with lines after the first (synopsis) line
bodyLines = helpLines(2:end);

% Extract See also (find last occurrence)
seeAlsoIdx = 0;
for k = numel(bodyLines):-1:1
    if startsWith(strtrim(bodyLines(k)), "See also", "IgnoreCase", true)
        seeAlsoIdx = k;
        break
    end
end

if seeAlsoIdx > 0
    seeAlsoLine = strtrim(bodyLines(seeAlsoIdx));
    afterPrefix = extractAfter(lower(seeAlsoLine), "see also");
    seeAlso = strip(split(afterPrefix, ","));
    seeAlso = seeAlso(seeAlso ~= "");
    bodyLines(seeAlsoIdx) = []; % Remove from body
end

% Split at ## headings
currentHeading = "";
currentContent = string.empty;
inDescription = true;

for k = 1:numel(bodyLines)
    line = bodyLines(k);
    if startsWith(strtrim(line), "## ")
        % Save previous content
        if inDescription
            description = strjoin(currentContent, newline);
            inDescription = false;
        elseif currentHeading ~= ""
            sections(end+1) = struct("Heading", currentHeading, ...
                "Content", strjoin(currentContent, newline)); %#ok<AGROW>
        end
        currentHeading = strtrim(extractAfter(strtrim(line), "## "));
        currentContent = string.empty;
    else
        currentContent(end+1) = line; %#ok<AGROW>
    end
end

% Save last section
if inDescription
    description = strjoin(currentContent, newline);
elseif currentHeading ~= ""
    sections(end+1) = struct("Heading", currentHeading, ...
        "Content", strjoin(currentContent, newline));
end

% Trim leading/trailing blank lines from description
description = strtrim(description);
end

function argDescs = extractArgDescriptions(sections, sectionName)
% Extract `argName` — description entries from a section
argDescs = containers.Map;
for k = 1:numel(sections)
    if sections(k).Heading == sectionName
        content = sections(k).Content;
        contentLines = splitlines(content);

        currentName = "";
        currentDesc = string.empty;

        for j = 1:numel(contentLines)
            line = contentLines(j);
            % Match `argName` or `opts.argName` — description pattern
            tok = regexp(line, '^\s*`(\S+?)`\s*[-\x{2014}]\s*(.*)', 'tokens');
            if ~isempty(tok)
                % Save previous
                if currentName ~= ""
                    argDescs(char(currentName)) = strtrim(strjoin(currentDesc, newline));
                end
                currentName = tok{1}{1};
                currentDesc = string(tok{1}{2});
            elseif currentName ~= "" && strtrim(line) ~= ""
                currentDesc(end+1) = line; %#ok<AGROW>
            elseif currentName ~= "" && strtrim(line) == ""
                % Blank line — could be paragraph break within description
                currentDesc(end+1) = ""; %#ok<AGROW>
            end
        end
        % Save last
        if currentName ~= ""
            argDescs(char(currentName)) = strtrim(strjoin(currentDesc, newline));
        end
        break
    end
end
end

function [posArgs, nvArgs] = parseArgumentsBlock(lines, searchFrom)
% Find and parse the first arguments block after searchFrom
posArgs = struct("Name", {}, "Size", {}, "Class", {}, "Default", {}, ...
    "Validators", {}, "ShortDesc", {}, "LongDesc", {});
nvArgs = struct("Name", {}, "Size", {}, "Class", {}, "Default", {}, ...
    "Validators", {}, "ShortDesc", {}, "LongDesc", {});

% Find 'arguments' keyword
argBlockStart = 0;
for k = (searchFrom + 1):numel(lines)
    stripped = strtrim(lines(k));
    if stripped == "arguments" || startsWith(stripped, "arguments ")
        % Skip arguments (Output) etc. for now
        if contains(stripped, "Output") || contains(stripped, "Repeating")
            continue
        end
        argBlockStart = k;
        break
    end
    % Stop if we hit actual code (not blank lines or comments)
    if stripped ~= "" && ~startsWith(stripped, "%")
        break
    end
end

if argBlockStart == 0
    return
end

% Parse lines until 'end', accumulating preceding comments as LongDesc
pendingComments = string.empty;
for k = (argBlockStart + 1):numel(lines)
    stripped = strtrim(lines(k));
    if stripped == "end"
        break
    end
    if stripped == ""
        % Blank line resets accumulated comments
        pendingComments = string.empty;
        continue
    end
    if startsWith(stripped, "%")
        % Accumulate comment lines (strip leading "% " or "%")
        commentText = regexprep(stripped, '^\%\s?', '');
        pendingComments(end+1) = commentText; %#ok<AGROW>
        continue
    end

    arg = parseOneArgumentLine(stripped);
    if arg.Name == ""
        pendingComments = string.empty;
        continue
    end

    % Attach accumulated preceding comments as LongDesc
    if ~isempty(pendingComments)
        arg.LongDesc = strjoin(pendingComments, newline);
    else
        arg.LongDesc = "";
    end
    pendingComments = string.empty;

    if startsWith(arg.Name, "opts.") || startsWith(arg.Name, "options.")
        % Name-value argument: strip prefix for display name
        dotIdx = strfind(arg.Name, ".");
        displayName = extractAfter(arg.Name, dotIdx(1));
        arg.Name = displayName;
        nvArgs(end+1) = arg; %#ok<AGROW>
    else
        posArgs(end+1) = arg; %#ok<AGROW>
    end
end
end

function arg = parseOneArgumentLine(line)
% Parse a single argument line from an arguments block
% Format: name (size) class {validators} = default  % comment
arg = struct("Name", "", "Size", "", "Class", "", "Default", "", ...
    "Validators", "", "ShortDesc", "");

% Extract inline comment first
commentIdx = strfind(line, "%");
if ~isempty(commentIdx)
    % Be careful: % inside strings/validators shouldn't count
    % Simple heuristic: take last % that's followed by a space or is at end
    for ci = numel(commentIdx):-1:1
        idx = commentIdx(ci);
        if idx == strlength(line) || extractBetween(line, idx+1, idx+1) == " "
            arg.ShortDesc = strtrim(extractAfter(line, idx));
            line = strtrim(extractBefore(line, idx));
            break
        end
    end
end

% Extract default value (after =)
eqIdx = strfind(line, "=");
if ~isempty(eqIdx)
    % Take the last = that's not inside braces/parens
    % Simple approach: find = not inside {} or ()
    depth_paren = 0;
    depth_brace = 0;
    lastEq = 0;
    chars = char(line);
    for ci = 1:numel(chars)
        switch chars(ci)
            case '(', depth_paren = depth_paren + 1;
            case ')', depth_paren = depth_paren - 1;
            case '{', depth_brace = depth_brace + 1;
            case '}', depth_brace = depth_brace - 1;
            case '='
                if depth_paren == 0 && depth_brace == 0
                    lastEq = ci;
                end
        end
    end
    if lastEq > 0
        arg.Default = strtrim(string(chars(lastEq+1:end)));
        line = strtrim(string(chars(1:lastEq-1)));
    end
end

% Extract validators {mustBe...}
tok = regexp(line, '(\{[^}]+\})', 'tokens');
if ~isempty(tok)
    arg.Validators = string(tok{end}{1});
    line = strtrim(regexprep(line, '\{[^}]+\}', ''));
end

% Extract size constraint (in parentheses)
tok = regexp(line, '(\([^)]+\))', 'tokens');
if ~isempty(tok)
    arg.Size = string(tok{1}{1});
    line = strtrim(regexprep(line, '\([^)]+\)', '', 1));
end

% Remaining: name [class]
parts = split(strtrim(line));
parts = parts(parts ~= "");
if ~isempty(parts)
    arg.Name = parts(1);
    if numel(parts) > 1
        arg.Class = strjoin(parts(2:end), " ");
    end
end
end

function args = mergeArgDescriptions(parsedArgs, longDescMap)
% Merge long-form descriptions into parsed argument structs
% Priority: ## Input/Output Arguments section > preceding comments > empty
args = parsedArgs;
for k = 1:numel(args)
    lookupName = char(args(k).Name);
    % Try with opts. prefix too
    if longDescMap.isKey(lookupName)
        args(k).LongDesc = string(longDescMap(lookupName));
    elseif longDescMap.isKey(['opts.' lookupName])
        args(k).LongDesc = string(longDescMap(['opts.' lookupName]));
    end
    % Otherwise keep LongDesc from preceding comments (already set by
    % parseArgumentsBlock), which may be "" if there were none.
end
end

function outArgs = buildOutputArgs(outputArgNames, longDescMap)
% Build output argument info from function signature and long descriptions
outArgs = struct("Name", {}, "LongDesc", {});
for k = 1:numel(outputArgNames)
    name = strtrim(outputArgNames(k));
    if name == ""
        continue
    end
    desc = "";
    if longDescMap.isKey(char(name))
        desc = string(longDescMap(char(name)));
    end
    outArgs(end+1) = struct("Name", name, "LongDesc", desc); %#ok<AGROW>
end
end

%% ---- Syntax Extraction ----

function entries = extractCallingForms(description, funcName)
% Extract calling-form paragraphs from description text.
% A calling-form paragraph starts with a backtick-wrapped expression
% containing funcName followed by (.
% Returns a struct array with fields Form (string) and Description (string).
entries = struct("Form", {}, "Description", {});

if description == ""
    return
end

paragraphs = splitParagraphs(description);
for k = 1:numel(paragraphs)
    para = strtrim(paragraphs(k));
    if para == "" || ~startsWith(para, "`")
        continue
    end

    % Extract first backtick-wrapped expression
    tok = regexp(para, '^`([^`]+)`', 'tokens');
    if isempty(tok)
        continue
    end

    form = string(tok{1}{1});

    % Check if form contains funcName( (case-insensitive)
    if ~contains(lower(form), lower(funcName) + "(")
        continue
    end

    % Description is everything after the closing backtick
    desc = strtrim(regexprep(para, '^`[^`]+`\s*', '', 'once'));

    entries(end+1) = struct("Form", form, "Description", desc); %#ok<AGROW>
end
end

function entries = parseSyntaxSection(content, funcName)
% Parse a ## Syntax section for calling forms and descriptions.
% Handles fenced code blocks (forms only) and calling-form paragraphs
% (forms with descriptions). funcName is used only for validation of
% calling-form paragraphs; fenced code block lines are accepted as-is.
entries = struct("Form", {}, "Description", {});

if content == ""
    return
end

lines = splitlines(string(content));
i = 1;
while i <= numel(lines)
    stripped = strtrim(lines(i));

    % --- Fenced code block: each non-empty line is a form ---
    if startsWith(stripped, "```")
        i = i + 1;
        while i <= numel(lines) && ~startsWith(strtrim(lines(i)), "```")
            formLine = strtrim(lines(i));
            if formLine ~= ""
                entries(end+1) = struct("Form", formLine, ...
                    "Description", ""); %#ok<AGROW>
            end
            i = i + 1;
        end
        if i <= numel(lines), i = i + 1; end % skip closing ```
        continue
    end

    % --- Blank line ---
    if stripped == ""
        i = i + 1;
        continue
    end

    % --- Calling-form paragraph ---
    if startsWith(stripped, "`")
        % Collect full paragraph (consecutive non-blank lines)
        paraLines = string.empty;
        while i <= numel(lines) && strtrim(lines(i)) ~= ""
            paraLines(end+1) = lines(i); %#ok<AGROW>
            i = i + 1;
        end
        para = strtrim(strjoin(paraLines, newline));

        % Extract form from first backtick expression
        tok = regexp(para, '^`([^`]+)`', 'tokens');
        if ~isempty(tok)
            form = string(tok{1}{1});
            desc = strtrim(regexprep(para, '^`[^`]+`\s*', '', 'once'));
            entries(end+1) = struct("Form", form, ...
                "Description", desc); %#ok<AGROW>
        end
        continue
    end

    % --- Skip non-matching lines ---
    i = i + 1;
end
end

function entries = generateAutoSyntax(funcName, outputArgNames, posArgs, nvArgs)
% Generate progressive calling forms from parsed argument metadata.
% Uses text-parsed argument info. When metafunction (R2026a) is available,
% this can be replaced with introspection-based generation.
entries = struct("Form", {}, "Description", {});

% Classify positional args as required (no default) or optional
reqNames = string.empty;
optNames = string.empty;
for k = 1:numel(posArgs)
    if posArgs(k).Default == ""
        reqNames(end+1) = posArgs(k).Name; %#ok<AGROW>
    else
        optNames(end+1) = posArgs(k).Name; %#ok<AGROW>
    end
end

% Build output prefix
if isempty(outputArgNames)
    outSingle = "";
    outAll = "";
elseif numel(outputArgNames) == 1
    outSingle = outputArgNames(1) + " = ";
    outAll = "";
else
    outSingle = outputArgNames(1) + " = ";
    outAll = "[" + strjoin(outputArgNames, ", ") + "] = ";
end

% 1. Required-only form
reqStr = strjoin(reqNames, ", ");
entries(end+1) = struct("Form", ...
    outSingle + funcName + "(" + reqStr + ")", "Description", "");

% 2. Progressive optionals
for k = 1:numel(optNames)
    allArgs = [reqNames, optNames(1:k)];
    argStr = strjoin(allArgs, ", ");
    entries(end+1) = struct("Form", ...
        outSingle + funcName + "(" + argStr + ")", ...
        "Description", ""); %#ok<AGROW>
end

% 3. Name-value indicator
if ~isempty(nvArgs)
    if outSingle ~= ""
        nvPrefix = "___ = ";
    else
        nvPrefix = "";
    end
    entries(end+1) = struct("Form", ...
        nvPrefix + funcName + "(___, Name=Value)", ...
        "Description", ""); %#ok<AGROW>
end

% 4. Multiple outputs
if outAll ~= ""
    entries(end+1) = struct("Form", ...
        outAll + funcName + "(___)", ...
        "Description", ""); %#ok<AGROW>
end
end

function paragraphs = splitParagraphs(text)
% Split text into paragraphs at blank lines.
lines = splitlines(string(text));
paragraphs = string.empty;
current = string.empty;
for k = 1:numel(lines)
    if strtrim(lines(k)) == ""
        if ~isempty(current)
            paragraphs(end+1) = strjoin(current, newline); %#ok<AGROW>
            current = string.empty;
        end
    else
        current(end+1) = lines(k); %#ok<AGROW>
    end
end
if ~isempty(current)
    paragraphs(end+1) = strjoin(current, newline);
end
end

%% ---- Classdef Parsing ----

function props = parsePropertiesBlocks(lines, hasPropsSection, sections)
% Parse all properties blocks from a classdef file.
% Returns struct array with: Name, Size, Class, Default, ShortDesc, Group,
% ReadOnly, Dependent, Constant, Abstract
props = struct("Name", {}, "Size", {}, "Class", {}, "Default", {}, ...
    "ShortDesc", {}, "LongDesc", {}, "Group", {}, "ReadOnly", {}, ...
    "Dependent", {}, "Constant", {}, "Abstract", {});

% If ## Properties section exists, use it (correctly separates short/long)
if hasPropsSection
    props = parsePropertiesFromSection(sections);
end

% Always parse actual property blocks for metadata, flags, and inline comments
blockProps = parsePropertiesBlocksRaw(lines);

if ~isempty(blockProps)
    if isempty(props)
        % No ## Properties section — use block-parsed properties directly
        props = blockProps;
    else
        % Merge block metadata (Size, Class, Default, flags) into section-defined props.
        % If section-parsed LongDesc is empty, use inline comment LongDesc.
        for bp = 1:numel(blockProps)
            for sp = 1:numel(props)
                if props(sp).Name == blockProps(bp).Name
                    props(sp).Size = blockProps(bp).Size;
                    props(sp).Class = blockProps(bp).Class;
                    props(sp).Default = blockProps(bp).Default;
                    props(sp).Group = blockProps(bp).Group;
                    props(sp).ReadOnly = blockProps(bp).ReadOnly;
                    props(sp).Dependent = blockProps(bp).Dependent;
                    props(sp).Constant = blockProps(bp).Constant;
                    props(sp).Abstract = blockProps(bp).Abstract;
                    if props(sp).LongDesc == "" && blockProps(bp).LongDesc ~= ""
                        props(sp).LongDesc = blockProps(bp).LongDesc;
                    end
                    break
                end
            end
        end
    end
end
end

function props = parsePropertiesBlocksRaw(lines)
% Parse all properties blocks from source, capturing inline comments as LongDesc.
% Returns struct array with full metadata for each visible property.
props = struct("Name", {}, "Size", {}, "Class", {}, "Default", {}, ...
    "ShortDesc", {}, "LongDesc", {}, "Group", {}, "ReadOnly", {}, ...
    "Dependent", {}, "Constant", {}, "Abstract", {});

k = 1;
while k <= numel(lines)
    stripped = strtrim(lines(k));

    % Match properties keyword (with optional attributes and comment)
    if startsWith(stripped, "properties") && ...
            (stripped == "properties" || ...
             startsWith(stripped, "properties ") || ...
             startsWith(stripped, "properties("))

        % Parse block attributes
        attrs = parseBlockAttributes(stripped, "properties");

        % Determine visibility
        if ~isPropertyBlockVisible(attrs)
            k = skipToEnd(lines, k);
            continue
        end

        % Extract group heading from trailing comment
        group = extractTrailingComment(stripped);

        % Determine property flags from attributes
        readOnly = isReadOnly(attrs);
        dependent = hasAttribute(attrs, "Dependent");
        constant = hasAttribute(attrs, "Constant");
        abstract = hasAttribute(attrs, "Abstract");

        % Parse property lines until 'end', accumulating preceding comments
        k = k + 1;
        pendingComments = string.empty;
        while k <= numel(lines)
            pStripped = strtrim(lines(k));
            if pStripped == "end"
                k = k + 1;
                break
            end
            if pStripped == ""
                % Blank line resets accumulated comments
                pendingComments = string.empty;
                k = k + 1;
                continue
            end
            if startsWith(pStripped, "%")
                % Accumulate comment lines (strip leading "% " or "%")
                commentText = regexprep(pStripped, '^\%\s?', '');
                pendingComments(end+1) = commentText; %#ok<AGROW>
                k = k + 1;
                continue
            end

            % Parse property line
            prop = parseOnePropertyLine(pStripped);
            if prop.Name ~= ""
                prop.Group = group;
                prop.ReadOnly = readOnly;
                prop.Dependent = dependent;
                prop.Constant = constant;
                prop.Abstract = abstract;
                % Attach accumulated preceding comments as LongDesc
                if ~isempty(pendingComments)
                    prop.LongDesc = strjoin(pendingComments, newline);
                end
                props(end+1) = prop; %#ok<AGROW>
            end
            pendingComments = string.empty;
            k = k + 1;
        end
    else
        k = k + 1;
    end
end
end

function props = parsePropertiesFromSection(sections)
% Build property list from ## Properties section content.
% Each property is listed as `name` — short description, followed by
% optional continuation lines that form the long description.
props = struct("Name", {}, "Size", {}, "Class", {}, "Default", {}, ...
    "ShortDesc", {}, "LongDesc", {}, "Group", {}, "ReadOnly", {}, ...
    "Dependent", {}, "Constant", {}, "Abstract", {});
for s = 1:numel(sections)
    if sections(s).Heading == "Properties"
        contentLines = splitlines(string(sections(s).Content));
        currentName = "";
        currentShort = "";
        currentLong = string.empty;

        for j = 1:numel(contentLines)
            tok = regexp(contentLines(j), '^\s*`(\S+?)`\s*[-\x{2014}]\s*(.*)', 'tokens');
            if ~isempty(tok)
                % Save previous property
                if currentName ~= ""
                    props(end+1) = makeEmptyProp(currentName, currentShort, ...
                        strtrim(strjoin(currentLong, newline))); %#ok<AGROW>
                end
                currentName = string(tok{1}{1});
                currentShort = strtrim(string(tok{1}{2}));
                currentLong = string.empty;
            elseif currentName ~= ""
                % Continuation line for current property
                currentLong(end+1) = contentLines(j); %#ok<AGROW>
            end
        end
        % Save last property
        if currentName ~= ""
            props(end+1) = makeEmptyProp(currentName, currentShort, ...
                strtrim(strjoin(currentLong, newline))); %#ok<AGROW>
        end
        break
    end
end
end

function p = makeEmptyProp(name, shortDesc, longDesc)
% Create a property struct with minimal metadata.
p = struct("Name", name, "Size", "", "Class", "", "Default", "", ...
    "ShortDesc", shortDesc, "LongDesc", longDesc, "Group", "", ...
    "ReadOnly", false, "Dependent", false, "Constant", false, "Abstract", false);
end

function prop = parseOnePropertyLine(line)
% Parse a property declaration line: name (size) class = default  % comment
prop = struct("Name", "", "Size", "", "Class", "", "Default", "", ...
    "ShortDesc", "", "LongDesc", "", "Group", "", "ReadOnly", false, ...
    "Dependent", false, "Constant", false, "Abstract", false);

% Extract inline comment
commentIdx = strfind(line, "%");
if ~isempty(commentIdx)
    for ci = numel(commentIdx):-1:1
        idx = commentIdx(ci);
        if idx == strlength(line) || extractBetween(line, idx+1, idx+1) == " "
            prop.ShortDesc = strtrim(extractAfter(line, idx));
            line = strtrim(extractBefore(line, idx));
            break
        end
    end
end

% Extract default value
eqIdx = strfind(line, "=");
if ~isempty(eqIdx)
    depth_paren = 0; depth_brace = 0; lastEq = 0;
    chars = char(line);
    for ci = 1:numel(chars)
        switch chars(ci)
            case '(', depth_paren = depth_paren + 1;
            case ')', depth_paren = depth_paren - 1;
            case '{', depth_brace = depth_brace + 1;
            case '}', depth_brace = depth_brace - 1;
            case '='
                if depth_paren == 0 && depth_brace == 0
                    lastEq = ci;
                end
        end
    end
    if lastEq > 0
        prop.Default = strtrim(string(chars(lastEq+1:end)));
        line = strtrim(string(chars(1:lastEq-1)));
    end
end

% Extract validators {mustBe...}
tok = regexp(line, '(\{[^}]+\})', 'tokens');
if ~isempty(tok)
    line = strtrim(regexprep(line, '\{[^}]+\}', ''));
end

% Extract size constraint
tok = regexp(line, '(\([^)]+\))', 'tokens');
if ~isempty(tok)
    prop.Size = string(tok{1}{1});
    line = strtrim(regexprep(line, '\([^)]+\)', '', 1));
end

% Remaining: name [class]
parts = split(strtrim(line));
parts = parts(parts ~= "");
if ~isempty(parts)
    prop.Name = parts(1);
    if numel(parts) > 1
        prop.Class = strjoin(parts(2:end), " ");
    end
end
end

function [methods, constructorRange] = parseMethodsBlocks(lines, className)
% Parse all methods blocks. Returns method info and constructor line range.
methods = struct("Name", {}, "Synopsis", {}, "Group", {}, "IsStatic", {}, "Range", {});
constructorRange = []; % [startLine endLine] of constructor function

k = 1;
while k <= numel(lines)
    stripped = strtrim(lines(k));

    if startsWith(stripped, "methods") && ...
            (stripped == "methods" || ...
             startsWith(stripped, "methods ") || ...
             startsWith(stripped, "methods("))

        attrs = parseBlockAttributes(stripped, "methods");

        if ~isMethodBlockVisible(attrs)
            k = skipToEnd(lines, k);
            continue
        end

        group = extractTrailingComment(stripped);
        isStatic = hasAttribute(attrs, "Static");

        % Scan for functions within this methods block
        k = k + 1;
        blockDepth = 1; % track nested end statements
        while k <= numel(lines) && blockDepth > 0
            fStripped = strtrim(lines(k));

            if fStripped == "end"
                blockDepth = blockDepth - 1;
                if blockDepth == 0
                    k = k + 1;
                    break
                end
                k = k + 1;
                continue
            end

            if startsWith(fStripped, "function ")
                % Parse function name
                funcName = extractMethodName(fStripped);
                funcStart = k;

                if funcName == className
                    % Constructor — record its range, skip adding to methods list
                    funcEnd = findFunctionEnd(lines, k);
                    constructorRange = [funcStart, funcEnd];
                    k = funcEnd + 1;
                else
                    % Regular method — extract synopsis and record range
                    synopsis = extractMethodSynopsis(lines, k);
                    funcEnd = findFunctionEnd(lines, k);
                    methods(end+1) = struct("Name", funcName, ...
                        "Synopsis", synopsis, "Group", group, ...
                        "IsStatic", isStatic, ...
                        "Range", [funcStart, funcEnd]); %#ok<AGROW>
                    k = funcEnd + 1;
                end
                continue
            end

            k = k + 1;
        end
    else
        k = k + 1;
    end
end
end

function events = parseEventsBlocks(lines)
% Parse all events blocks.
events = struct("Name", {}, "Description", {});

k = 1;
while k <= numel(lines)
    stripped = strtrim(lines(k));

    if startsWith(stripped, "events") && ...
            (stripped == "events" || ...
             startsWith(stripped, "events ") || ...
             startsWith(stripped, "events("))

        attrs = parseBlockAttributes(stripped, "events");
        if hasAttribute(attrs, "Hidden") || ...
                hasAttributeValue(attrs, "Access", "private") || ...
                hasAttributeValue(attrs, "Access", "protected")
            k = skipToEnd(lines, k);
            continue
        end

        k = k + 1;
        while k <= numel(lines)
            eStripped = strtrim(lines(k));
            if eStripped == "end"
                k = k + 1;
                break
            end
            if eStripped == "" || startsWith(eStripped, "%")
                k = k + 1;
                continue
            end
            % Parse event line: EventName  % Description
            desc = "";
            eLine = eStripped;
            cIdx = strfind(eLine, "%");
            if ~isempty(cIdx)
                desc = strtrim(extractAfter(eLine, cIdx(1)));
                eLine = strtrim(extractBefore(eLine, cIdx(1)));
            end
            eName = strtrim(eLine);
            if eName ~= ""
                events(end+1) = struct("Name", eName, "Description", desc); %#ok<AGROW>
            end
            k = k + 1;
        end
    else
        k = k + 1;
    end
end
end

function ctorInfo = parseConstructorMethod(lines, range, className)
% Parse constructor method fully, like a standalone function.
% range = [startLine endLine]
ctorLines = lines(range(1):range(2));

% Extract output variable name from constructor signature
funcLine = strtrim(ctorLines(1));
[~, ~, outArgNames] = parseFunctionDeclaration(funcLine);
if isempty(outArgNames)
    outArgNames = "obj";
end

% Extract help block
[helpLines, helpEndIdx] = extractHelpBlock(ctorLines, 1);

% Parse help
ctorInfo.Synopsis = parseSynopsis(helpLines, className);
[ctorInfo.Description, ctorInfo.Sections, ~] = parseHelpBody(helpLines);

% Extract argument descriptions from help sections
inputArgLong = extractArgDescriptions(ctorInfo.Sections, "Input Arguments");

% Parse arguments block within constructor
[parsedArgs, parsedNVArgs] = parseArgumentsBlock(ctorLines, helpEndIdx);
ctorInfo.InputArgs = mergeArgDescriptions(parsedArgs, inputArgLong);
ctorInfo.NameValueArgs = mergeArgDescriptions(parsedNVArgs, inputArgLong);

% Build syntax entries
syntaxContent = "";
for s = 1:numel(ctorInfo.Sections)
    if ctorInfo.Sections(s).Heading == "Syntax"
        syntaxContent = string(ctorInfo.Sections(s).Content);
        break
    end
end

if syntaxContent ~= ""
    ctorInfo.SyntaxEntries = parseSyntaxSection(syntaxContent, className);
    ctorInfo.SyntaxSource = "syntax_section";
else
    entries = extractCallingForms(ctorInfo.Description, className);
    if ~isempty(entries)
        ctorInfo.SyntaxEntries = entries;
        ctorInfo.SyntaxSource = "description";
    elseif ~isempty(parsedArgs) || ~isempty(parsedNVArgs)
        ctorInfo.SyntaxEntries = generateAutoSyntax(className, ...
            outArgNames, parsedArgs, parsedNVArgs);
        ctorInfo.SyntaxSource = "auto";
    else
        ctorInfo.SyntaxEntries = struct("Form", ...
            outArgNames(1) + " = " + className, "Description", "");
        ctorInfo.SyntaxSource = "legacy";
    end
end
end

function mInfo = parseMethodFull(lines, range, methodName, className)
% Parse a regular method fully, producing a function-like info struct.
% range = [startLine endLine]
mLines = lines(range(1):range(2));

% Parse function declaration
funcLine = strtrim(mLines(1));
[~, sig, outArgNames] = parseFunctionDeclaration(funcLine);
mInfo.Type = "method";
mInfo.Name = string(methodName);
mInfo.ClassName = string(className);
mInfo.Signature = sig;
mInfo.OutputArgNames = outArgNames;

% Extract help block
[helpLines, helpEndIdx] = extractHelpBlock(mLines, 1);

% Parse help
mInfo.Synopsis = parseSynopsis(helpLines, methodName);
[mInfo.Description, mInfo.Sections, mInfo.SeeAlso] = parseHelpBody(helpLines);

% Extract argument descriptions from help sections
inputArgLong = extractArgDescriptions(mInfo.Sections, "Input Arguments");
outputArgLong = extractArgDescriptions(mInfo.Sections, "Output Arguments");

% Parse arguments block
[parsedArgs, parsedNVArgs] = parseArgumentsBlock(mLines, helpEndIdx);
mInfo.InputArgs = mergeArgDescriptions(parsedArgs, inputArgLong);
mInfo.NameValueArgs = mergeArgDescriptions(parsedNVArgs, inputArgLong);
mInfo.OutputArgs = buildOutputArgs(outArgNames, outputArgLong);

% Build syntax entries (same three-priority model as functions)
syntaxContent = "";
for s = 1:numel(mInfo.Sections)
    if mInfo.Sections(s).Heading == "Syntax"
        syntaxContent = string(mInfo.Sections(s).Content);
        break
    end
end

if syntaxContent ~= ""
    mInfo.SyntaxEntries = parseSyntaxSection(syntaxContent, methodName);
    mInfo.SyntaxSource = "syntax_section";
else
    entries = extractCallingForms(mInfo.Description, methodName);
    if ~isempty(entries)
        mInfo.SyntaxEntries = entries;
        mInfo.SyntaxSource = "description";
    elseif ~isempty(parsedArgs) || ~isempty(parsedNVArgs)
        mInfo.SyntaxEntries = generateAutoSyntax(methodName, ...
            outArgNames, parsedArgs, parsedNVArgs);
        mInfo.SyntaxSource = "auto";
    else
        display = regexprep(sig{1}, '^function\s+', '');
        mInfo.SyntaxEntries = struct("Form", string(display), ...
            "Description", "");
        mInfo.SyntaxSource = "legacy";
    end
end

mInfo.HelpLines = helpLines;
end

function ctorInfo = generateDefaultConstructor(className, props)
% Generate minimal constructor info when no explicit constructor exists.
ctorInfo.Synopsis = "";
ctorInfo.Description = "";
ctorInfo.Sections = struct("Heading", {}, "Content", {});
ctorInfo.InputArgs = struct("Name", {}, "Size", {}, "Class", {}, ...
    "Default", {}, "Validators", {}, "ShortDesc", {}, "LongDesc", {});
ctorInfo.NameValueArgs = ctorInfo.InputArgs;

% Check if there are public settable properties
hasSettable = false;
for k = 1:numel(props)
    if ~props(k).ReadOnly && ~props(k).Constant && ~props(k).Dependent
        hasSettable = true;
        break
    end
end

if hasSettable
    ctorInfo.SyntaxEntries = struct("Form", ...
        {"obj = " + className, "obj = " + className + "(Name=Value)"}, ...
        "Description", {"", ""});
else
    ctorInfo.SyntaxEntries = struct("Form", "obj = " + className, "Description", "");
end
ctorInfo.SyntaxSource = "auto";
end

%% ---- Classdef Block Helpers ----

function attrs = parseBlockAttributes(line, keyword)
% Parse attributes from a block declaration like 'properties(SetAccess=private, Hidden)'
% Returns a containers.Map of attribute name -> value (or "true" for flags)
attrs = containers.Map;
tok = regexp(line, [keyword '\s*\(([^)]*)\)'], 'tokens');
if isempty(tok)
    return
end
attrStr = string(tok{1}{1});
parts = split(attrStr, ",");
for k = 1:numel(parts)
    part = strtrim(parts(k));
    if contains(part, "=")
        kv = split(part, "=");
        attrs(char(strtrim(lower(kv(1))))) = char(strtrim(kv(2)));
    else
        % Flag attribute like Hidden, Dependent
        attrs(char(strtrim(lower(part)))) = 'true';
    end
end
end

function visible = isPropertyBlockVisible(attrs)
% Determine if a properties block should appear in docs (spec §5)
visible = true;
if attrs.isKey('access')
    val = lower(string(attrs('access')));
    if val == "private" || val == "protected"
        visible = false; return
    end
end
if attrs.isKey('getaccess')
    val = lower(string(attrs('getaccess')));
    if val == "private"
        visible = false; return
    end
end
if attrs.isKey('hidden')
    visible = false; return
end
end

function visible = isMethodBlockVisible(attrs)
% Determine if a methods block should appear in docs
visible = true;
if attrs.isKey('access')
    val = lower(string(attrs('access')));
    if val == "private" || val == "protected"
        visible = false; return
    end
end
if attrs.isKey('hidden')
    visible = false; return
end
end

function ro = isReadOnly(attrs)
% Check if SetAccess is private or protected
ro = false;
if attrs.isKey('setaccess')
    val = lower(string(attrs('setaccess')));
    if val == "private" || val == "protected"
        ro = true;
    end
end
end

function tf = hasAttribute(attrs, name)
% Check if attribute exists (case-insensitive)
tf = attrs.isKey(char(lower(name)));
end

function tf = hasAttributeValue(attrs, name, value)
% Check if attribute has a specific value
tf = false;
key = char(lower(name));
if attrs.isKey(key)
    tf = lower(string(attrs(key))) == lower(value);
end
end

function comment = extractTrailingComment(line)
% Extract trailing % comment from a block declaration line
comment = "";
idx = strfind(line, "%");
if ~isempty(idx)
    comment = strtrim(extractAfter(line, idx(end)));
end
end

function endIdx = skipToEnd(lines, startIdx)
% Skip from a block start to its matching 'end', handling nesting
depth = 1;
endIdx = startIdx + 1;
while endIdx <= numel(lines)
    s = strtrim(lines(endIdx));
    % Count nested blocks
    if startsWith(s, "properties") || startsWith(s, "methods") || ...
            startsWith(s, "events") || startsWith(s, "enumeration") || ...
            startsWith(s, "function ") || ...
            startsWith(s, "arguments") && (s == "arguments" || startsWith(s, "arguments ") || startsWith(s, "arguments(")) || ...
            startsWith(s, "if ") || s == "if" || ...
            startsWith(s, "for ") || s == "for" || ...
            startsWith(s, "while ") || s == "while" || ...
            startsWith(s, "switch ") || startsWith(s, "try")
        depth = depth + 1;
    end
    if s == "end"
        depth = depth - 1;
        if depth == 0
            endIdx = endIdx + 1;
            return
        end
    end
    endIdx = endIdx + 1;
end
end

function name = extractMethodName(funcLine)
% Extract function name from a method declaration line
body = extractAfter(funcLine, "function ");
body = strtrim(body);
if contains(body, "=")
    parts = split(body, "=");
    body = strtrim(parts(2));
end
if contains(body, "(")
    name = strtrim(extractBefore(body, "("));
else
    name = strtrim(body);
end
end

function synopsis = extractMethodSynopsis(lines, funcIdx)
% Extract the synopsis (first help comment line) for a method
synopsis = "";
for k = (funcIdx + 1):numel(lines)
    s = strtrim(lines(k));
    if startsWith(s, "%")
        content = extractAfter(s, "%");
        if startsWith(content, " ")
            content = extractAfter(content, " ");
        end
        % Synopsis is the description part after the function name
        content = strtrim(content);
        % Strip leading function name
        words = split(content);
        if ~isempty(words)
            % Check if first word looks like the function name
            firstWord = words(1);
            remaining = strtrim(extractAfter(content, strlength(firstWord)));
            if remaining ~= ""
                synopsis = remaining;
            else
                synopsis = content;
            end
        end
        return
    elseif s == ""
        continue
    else
        return % hit code, no help comment
    end
end
end

function endIdx = findFunctionEnd(lines, funcIdx)
% Find the 'end' that closes a function starting at funcIdx
depth = 1;
endIdx = funcIdx + 1;
while endIdx <= numel(lines)
    s = strtrim(lines(endIdx));
    % Track nesting of control structures, arguments blocks, and nested functions
    if startsWith(s, "function ") || ...
            startsWith(s, "arguments") && (s == "arguments" || startsWith(s, "arguments ") || startsWith(s, "arguments(")) || ...
            startsWith(s, "if ") || s == "if" || ...
            startsWith(s, "for ") || s == "for" || ...
            startsWith(s, "while ") || s == "while" || ...
            startsWith(s, "switch ") || ...
            startsWith(s, "try") || ...
            startsWith(s, "parfor ")
        depth = depth + 1;
    end
    if s == "end"
        depth = depth - 1;
        if depth == 0
            return
        end
    end
    endIdx = endIdx + 1;
end
endIdx = numel(lines); % fallback
end
