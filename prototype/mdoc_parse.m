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

%% Find function declaration
[funcLine, funcIdx] = findDeclaration(lines);
info.Type = "function";
[info.Name, info.Signature, info.OutputArgNames] = parseFunctionDeclaration(funcLine);

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
% Join lines ending with ... (MATLAB continuation)
k = 1;
while k < numel(lines)
    stripped = strtrim(lines(k));
    if endsWith(stripped, "...")
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
% Extract **argName** — description entries from a section
argDescs = containers.Map;
for k = 1:numel(sections)
    if sections(k).Heading == sectionName
        content = sections(k).Content;
        contentLines = splitlines(content);

        currentName = "";
        currentDesc = string.empty;

        for j = 1:numel(contentLines)
            line = contentLines(j);
            % Match **argName** or **opts.argName** pattern
            tok = regexp(line, '^\s*\*\*(\S+?)\*\*\s*[-\x{2014}]\s*(.*)', 'tokens');
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
    "Validators", {}, "ShortDesc", {});
nvArgs = struct("Name", {}, "Size", {}, "Class", {}, "Default", {}, ...
    "Validators", {}, "ShortDesc", {});

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

% Parse lines until 'end'
for k = (argBlockStart + 1):numel(lines)
    stripped = strtrim(lines(k));
    if stripped == "end"
        break
    end
    if stripped == "" || startsWith(stripped, "%")
        continue
    end

    arg = parseOneArgumentLine(stripped);
    if arg.Name == ""
        continue
    end

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
args = parsedArgs;
for k = 1:numel(args)
    lookupName = char(args(k).Name);
    % Try with opts. prefix too
    if longDescMap.isKey(lookupName)
        args(k).LongDesc = string(longDescMap(lookupName));
    elseif longDescMap.isKey(['opts.' lookupName])
        args(k).LongDesc = string(longDescMap(['opts.' lookupName]));
    else
        args(k).LongDesc = "";
    end
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
