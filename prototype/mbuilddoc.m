function mbuilddoc(sourceFolder, outputFolder)
% mbuilddoc  Build HTML documentation site from a folder of MATLAB code.
%
% `mbuilddoc(sourceFolder)` generates HTML documentation for every `.m`
% file in `sourceFolder` and its subfolders. Output is written to
% `sourceFolder/doc/`.
%
% `mbuilddoc(sourceFolder, outputFolder)` writes to the specified folder.

arguments
    sourceFolder (1,1) string {mustBeFolder}
    outputFolder (1,1) string = ""
end

%% Resolve paths to absolute
oldDir = pwd;
cd(char(sourceFolder));
sourceFolder = string(pwd);
cd(oldDir);

if outputFolder == ""
    outputFolder = fullfile(sourceFolder, "doc");
elseif ~startsWith(outputFolder, filesep) && ...
        ~(strlength(outputFolder) > 1 && extractBetween(outputFolder,2,2) == ":")
    outputFolder = fullfile(string(pwd), outputFolder);
end

fprintf("Source:  %s\n", sourceFolder);
fprintf("Output:  %s\n\n", outputFolder);

%% 1. Discover .m files
[mFiles, contentsMap] = discoverFiles(sourceFolder, outputFolder);
fprintf("Found %d .m files to process.\n", numel(mFiles));

%% 2. Parse all files
names     = string.empty;
synopses  = string.empty;
htmlRels  = string.empty;
infos     = {};

for k = 1:numel(mFiles)
    fp = mFiles(k);
    relPath = relativeTo(fp, sourceFolder);

    try
        info = mdoc_parse(fp);
    catch
        fprintf("  Skipped (parse error): %s\n", relPath);
        continue
    end

    % Skip files where parsing returned an unusable name
    if ismissing(info.Name) || strtrim(string(info.Name)) == ""
        fprintf("  Skipped (no name): %s\n", relPath);
        continue
    end

    htmlRel = regexprep(relPath, '\.m$', '.html');
    names(end+1)    = string(info.Name);      %#ok<AGROW>
    synopses(end+1) = string(info.Synopsis);   %#ok<AGROW>
    htmlRels(end+1) = htmlRel;                 %#ok<AGROW>
    infos{end+1}    = info;                    %#ok<AGROW>
end

nEntries = numel(names);
if nEntries == 0
    fprintf("No parseable files found.\n");
    return
end
fprintf("Parsed %d files.\n\n", nEntries);

%% 3. Build name → htmlRel map for cross-references
nameMap = containers.Map;
for k = 1:nEntries
    nameMap(char(names(k))) = char(htmlRels(k));
end

[~, rootName] = fileparts(sourceFolder);

%% 4. Render and write each page
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

for k = 1:nEntries
    html = mdoc_render(infos{k});
    html = injectBreadcrumb(html, htmlRels(k), rootName);
    html = rewriteCrossRefs(html, htmlRels(k), nameMap);

    outPath = fullfile(outputFolder, htmlRels(k));
    ensureDir(fileparts(outPath));
    writeText(outPath, html);
end

%% 5. Generate index pages
generateIndexPages(names, synopses, htmlRels, contentsMap, ...
    sourceFolder, outputFolder, rootName);

fprintf("\nDone. Open:\n  %s\n", fullfile(outputFolder, "index.html"));
end

%% ================================================================
%%  Discovery
%% ================================================================

function [mFiles, contentsMap] = discoverFiles(sourceFolder, outputFolder)
% Recursively find .m files; separate Contents.m; apply exclusions.
allFiles = dir(fullfile(sourceFolder, '**', '*.m'));
mFiles = string.empty;
contentsMap = containers.Map;   % sourceFolderAbs → Contents.m path

excludeFolders = ["private", "test", "tests", "+internal"];

for k = 1:numel(allFiles)
    fp = string(fullfile(allFiles(k).folder, allFiles(k).name));

    % Skip anything under the output folder
    if startsWith(fp, outputFolder + filesep) || fp == outputFolder
        continue
    end

    % Check for excluded folder names in the relative path
    relPath = relativeTo(fp, sourceFolder);
    pathParts = split(relPath, filesep);
    skip = false;
    for j = 1:numel(pathParts)-1          % folder segments only
        if any(pathParts(j) == excludeFolders)
            skip = true;
            break
        end
    end
    if skip, continue; end

    % Separate Contents.m files
    if strcmpi(allFiles(k).name, 'Contents.m')
        contentsMap(char(string(allFiles(k).folder))) = char(fp);
        continue
    end

    mFiles(end+1) = fp; %#ok<AGROW>
end
end

%% ================================================================
%%  Breadcrumb Navigation
%% ================================================================

function html = injectBreadcrumb(html, htmlRel, rootName)
% Insert a breadcrumb nav bar at the top of the rendered page.
parts = split(htmlRel, filesep);
depth = numel(parts) - 1;              % folder depth

segs = {};

% Root link
rootHref = repeatStr("../", depth) + "index.html";
if depth == 0, rootHref = "index.html"; end
segs{end+1} = sprintf('<a href="%s">%s</a>', rootHref, h(rootName));

% Folder segments
for k = 1:depth
    levelsUp = depth - k;
    if levelsUp > 0
        href = repeatStr("../", levelsUp) + "index.html";
    else
        href = "index.html";
    end
    segs{end+1} = sprintf('<a href="%s">%s</a>', href, h(parts(k))); %#ok<AGROW>
end

% Current page (no link)
[~, pageName] = fileparts(parts(end));
segs{end+1} = char(h(pageName));

nav = sprintf( ...
    '<nav style="font-size:0.85em;color:#888;margin-bottom:12px;">%s</nav>', ...
    strjoin(string(segs), ' &gt; '));

replacement = "<div class=""doc-page"">" + newline + string(nav);
html = strrep(string(html), "<div class=""doc-page"">", replacement);
end

%% ================================================================
%%  Cross-Reference Rewriting
%% ================================================================

function html = rewriteCrossRefs(html, fromHtmlRel, nameMap)
% Replace matlab:mdoc('name') links with relative .html paths.
html = string(html);

% Match matlab:mdoc('name') — single quotes are literal in the HTML
[tokens, matches] = regexp(char(html), ...
    'matlab:mdoc\(''([^'']+)''\)', 'tokens', 'match');

for k = 1:numel(tokens)
    name = string(tokens{k}{1});
    if nameMap.isKey(char(name))
        targetRel = string(nameMap(char(name)));
        html = strrep(html, string(matches{k}), ...
            computeRelLink(fromHtmlRel, targetRel));
    else
        % Fall back to matlab:doc for names not in the site
        html = strrep(html, string(matches{k}), ...
            "matlab:doc('" + name + "')");
    end
end
end

function rel = computeRelLink(fromRel, toRel)
% Compute a relative href from one file to another (both relative to root).
fromParts = split(fromRel, filesep);
fromDir   = fromParts(1:end-1);
depth     = numel(fromDir);

prefix = repeatStr("../", depth);
rel = prefix + strjoin(split(toRel, filesep), "/");
end

%% ================================================================
%%  Index Page Generation
%% ================================================================

function generateIndexPages(names, synopses, htmlRels, contentsMap, ...
        sourceFolder, outputFolder, rootName)

%% Group entries by folder
folderToIdx = containers.Map;
allFolders  = string.empty;

for k = 1:numel(htmlRels)
    parts = split(htmlRels(k), filesep);
    if numel(parts) == 1
        folderRel = "";
    else
        folderRel = strjoin(parts(1:end-1), filesep);
    end

    key = char(folderRel);
    if folderMap_isKey(folderToIdx, key)
        folderToIdx(key) = [folderToIdx(key), k];
    else
        folderToIdx(key) = k;
        allFolders(end+1) = folderRel; %#ok<AGROW>
    end
end

%% Ensure ancestor folders exist in the set
extra = string.empty;
for k = 1:numel(allFolders)
    f = allFolders(k);
    while f ~= ""
        parts = split(f, filesep);
        if numel(parts) > 1
            parent = strjoin(parts(1:end-1), filesep);
        else
            parent = "";
        end
        if ~any(allFolders == parent) && ~any(extra == parent)
            extra(end+1) = parent; %#ok<AGROW>
        end
        f = parent;
    end
end
allFolders = unique([allFolders, extra]);

%% Generate one index per folder
for k = 1:numel(allFolders)
    folderRel = allFolders(k);
    key = char(folderRel);

    % Entries in this folder, sorted alphabetically
    if folderMap_isKey(folderToIdx, key)
        idx = folderToIdx(key);
        entryNames = names(idx);
        entrySynopses = synopses(idx);
        entryHtmlRels = htmlRels(idx);
        [~, order] = sort(lower(entryNames));
        entryNames    = entryNames(order);
        entrySynopses = entrySynopses(order);
        entryHtmlRels = entryHtmlRels(order);
    else
        entryNames    = string.empty;
        entrySynopses = string.empty;
        entryHtmlRels = string.empty;
    end

    % Direct child subfolders
    childFolders = string.empty;
    for j = 1:numel(allFolders)
        cand = allFolders(j);
        if cand == folderRel, continue; end
        if folderRel == ""
            if ~contains(cand, filesep)
                childFolders(end+1) = cand; %#ok<AGROW>
            end
        else
            pfx = folderRel + filesep;
            if startsWith(cand, pfx) && ~contains(extractAfter(cand, pfx), filesep)
                childFolders(end+1) = cand; %#ok<AGROW>
            end
        end
    end
    childFolders = sort(childFolders);

    % Title and description from Contents.m (if present)
    if folderRel == ""
        srcDir = sourceFolder;
        folderName = rootName;
    else
        srcDir = fullfile(sourceFolder, folderRel);
        parts = split(folderRel, filesep);
        folderName = parts(end);
    end
    title = string(folderName);
    description = "";
    if contentsMap.isKey(char(srcDir))
        [cTitle, cDesc] = parseContentsFile(string(contentsMap(char(srcDir))));
        if cTitle ~= "", title = cTitle; end
        description = cDesc;
    end

    % Build and write the index page
    indexHtml = buildIndexPage(title, description, folderRel, ...
        entryNames, entrySynopses, entryHtmlRels, childFolders, rootName);

    if folderRel == ""
        indexPath = fullfile(outputFolder, "index.html");
    else
        indexPath = fullfile(outputFolder, folderRel, "index.html");
    end
    ensureDir(fileparts(indexPath));
    writeText(indexPath, indexHtml);
end
end

function [title, description] = parseContentsFile(filepath)
% Read Contents.m and extract the title (first comment line) and description.
title = "";
description = "";
raw = string(fileread(filepath));
lines = splitlines(raw);

helpLines = string.empty;
for k = 1:numel(lines)
    stripped = strtrim(lines(k));
    if startsWith(stripped, "%")
        helpLines(end+1) = regexprep(stripped, '^\%\s?', ''); %#ok<AGROW>
    elseif stripped == "" && ~isempty(helpLines)
        if k+1 <= numel(lines) && startsWith(strtrim(lines(k+1)), "%")
            helpLines(end+1) = ""; %#ok<AGROW>
        else
            break
        end
    else
        break
    end
end

if ~isempty(helpLines)
    title = strtrim(helpLines(1));
    if numel(helpLines) > 1
        description = strtrim(strjoin(helpLines(2:end), newline));
    end
end
end

function html = buildIndexPage(title, description, folderRel, ...
        entryNames, entrySynopses, entryHtmlRels, childFolders, rootName)
% Generate a complete index.html page.
p = {};
p{end+1} = '<!DOCTYPE html>';
p{end+1} = '<html lang="en"><head>';
p{end+1} = '<meta charset="UTF-8">';
p{end+1} = '<meta name="viewport" content="width=device-width, initial-scale=1.0">';
p{end+1} = sprintf('<title>%s</title>', h(title));
p{end+1} = sprintf('<style>%s</style>', indexCss());
p{end+1} = '</head><body><div class="doc-page">';

% Breadcrumb (skip for root)
if folderRel ~= ""
    p{end+1} = char(buildIndexBreadcrumb(folderRel, rootName));
end

% Title
p{end+1} = sprintf('<h1>%s</h1>', h(title));

% Description
if description ~= ""
    descLines = splitlines(description);
    for dk = 1:numel(descLines)
        line = strtrim(descLines(dk));
        if line ~= ""
            p{end+1} = sprintf('<p class="description">%s</p>', h(line)); %#ok<AGROW>
        end
    end
end

% Subfolders
if ~isempty(childFolders)
    p{end+1} = '<h2>Folders</h2>';
    p{end+1} = '<table class="index-table">';
    for k = 1:numel(childFolders)
        cf = childFolders(k);
        cfParts = split(cf, filesep);
        childName = cfParts(end);
        href = childName + "/index.html";
        p{end+1} = sprintf( ...
            '<tr><td class="name-col"><a href="%s">%s/</a></td><td></td></tr>', ...
            href, h(childName)); %#ok<AGROW>
    end
    p{end+1} = '</table>';
end

% Entries
if ~isempty(entryNames)
    p{end+1} = '<h2>Functions and Classes</h2>';
    p{end+1} = '<table class="index-table">';
    for k = 1:numel(entryNames)
        % href is just the filename (index is in the same folder)
        fileParts = split(entryHtmlRels(k), filesep);
        href = fileParts(end);
        p{end+1} = sprintf( ...
            '<tr><td class="name-col"><a href="%s"><code>%s</code></a></td><td>%s</td></tr>', ...
            href, h(entryNames(k)), h(entrySynopses(k))); %#ok<AGROW>
    end
    p{end+1} = '</table>';
end

p{end+1} = '</div></body></html>';
html = strjoin(string(p), newline);
end

function html = buildIndexBreadcrumb(folderRel, rootName)
% Breadcrumb for an index page (not the root).
fParts = split(folderRel, filesep);
depth  = numel(fParts);
segs   = {};

% Root link
rootHref = repeatStr("../", depth) + "index.html";
segs{end+1} = sprintf('<a href="%s">%s</a>', rootHref, h(rootName));

% Intermediate folders
for k = 1:depth-1
    levelsUp = depth - k;
    href = repeatStr("../", levelsUp) + "index.html";
    segs{end+1} = sprintf('<a href="%s">%s</a>', href, h(fParts(k))); %#ok<AGROW>
end

% Current folder (no link)
segs{end+1} = char(h(fParts(end)));

html = sprintf( ...
    '<nav style="font-size:0.85em;color:#888;margin-bottom:12px;">%s</nav>', ...
    strjoin(string(segs), ' &gt; '));
end

function css = indexCss()
css = [...
    'body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;' ...
    ' color: #333; margin: 0; padding: 0; background: #fff; line-height: 1.6; }' newline ...
    '.doc-page { max-width: 960px; margin: 0 auto; padding: 32px 40px; }' newline ...
    'h1 { color: #1a1a1a; font-size: 1.75em; margin-top: 0; margin-bottom: 8px; }' newline ...
    'h2 { color: #1a1a1a; font-size: 1.35em; border-bottom: 1px solid #e0e0e0;' ...
    ' padding-bottom: 4px; margin-top: 28px; margin-bottom: 12px; }' newline ...
    '.description { color: #555; margin-bottom: 4px; }' newline ...
    'a { color: #0076a8; text-decoration: none; }' newline ...
    'a:hover { text-decoration: underline; }' newline ...
    '.index-table { border-collapse: collapse; width: 100%; }' newline ...
    '.index-table td { padding: 6px 16px 6px 0; border-bottom: 1px solid #eee; vertical-align: top; }' newline ...
    '.index-table .name-col { white-space: nowrap; }' newline ...
    'code { font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace; font-size: 0.95em; }' newline ...
    ];
end

%% ================================================================
%%  Utility Functions
%% ================================================================

function rel = relativeTo(filepath, baseFolder)
% Return filepath relative to baseFolder.
rel = extractAfter(string(filepath), baseFolder + filesep);
end

function s = repeatStr(str, n)
% Concatenate str repeated n times into a single string.
s = "";
for k = 1:n
    s = s + str;
end
end

function s = h(text)
% HTML-escape special characters.
s = string(text);
s = strrep(s, "&", "&amp;");
s = strrep(s, "<", "&lt;");
s = strrep(s, ">", "&gt;");
s = strrep(s, '"', "&quot;");
end

function ensureDir(d)
% Create directory if it does not exist.
if ~isfolder(d)
    mkdir(d);
end
end

function writeText(filepath, text)
% Write text to a file with UTF-8 encoding.
fid = fopen(filepath, 'w', 'n', 'UTF-8');
fwrite(fid, char(text), 'char');
fclose(fid);
end

function tf = folderMap_isKey(map, key)
% Safe isKey check (containers.Map).
tf = map.isKey(key);
end
