function mdoc(name)
% mdoc  Display rich HTML documentation for a MATLAB function or class.
%
% mdoc name parses the specified function or class .m file and opens a
% styled HTML documentation page in the system browser.
%
% mdoc(name) also accepts a file path as a string.
%
% mdoc ClassName.methodName opens the documentation page for a specific
% method of a class. The class must have been viewed with mdoc first, or
% a file path to the class must be provided.
%
% This is a prototype stand-in for MATLAB's built-in doc command,
% demonstrating the custom documentation framework.

arguments
    name (1,1) string % I used {mustBeFile} to get easy tab completion, but that requires .m extension. Fix Tab completion!
end

% Check if this is a ClassName.methodName request
if contains(name, ".") && ~isfile(name) && ~isfile(name + ".m")
    % Try to open a previously generated method page
    methodPath = fullfile(tempdir, "mdoc_" + name + ".html");
    if isfile(methodPath)
        web(char(methodPath), '-browser');
        return
    end
    % If not found, try to resolve the class and generate
    parts = split(name, ".");
    className = parts(1);
    % Try to find and parse the class file
    try
        info = mdoc_parse(className);
        if info.Type == "classdef"
            generateClassPages(info, className);
            if isfile(methodPath)
                web(char(methodPath), '-browser');
                return
            end
        end
    catch
        error("mdoc:NotFound", "Cannot find documentation for '%s'.", name);
    end
    error("mdoc:NotFound", "Cannot find method page for '%s'.", name);
end

% Parse the source file
info = mdoc_parse(name);

% Derive a unique file stem from the source file name so that different
% source files for the same function (e.g. rescale_v3_help vs rescale_v5)
% each open in their own browser tab.
[~, fileStem] = fileparts(name);

% Render to HTML
html = mdoc_render(info);

% Write to temp file and open
outPath = fullfile(tempdir, "mdoc_" + fileStem + ".html");
fid = fopen(outPath, 'w', 'n', 'UTF-8');
fwrite(fid, char(html), 'char');
fclose(fid);

% For class files, also generate method pages
if info.Type == "classdef"
    generateClassPages(info, fileStem);
    % Rewrite method links in class page to point to local files
    html = rewriteMethodLinks(html, fileStem);
    fid = fopen(outPath, 'w', 'n', 'UTF-8');
    fwrite(fid, char(html), 'char');
    fclose(fid);
end

% Open in system browser
web(char(outPath), '-browser');

end

function generateClassPages(info, fileStem)
% Generate method pages for a classdef file.
if ~isfield(info, 'MethodInfos')
    return
end
for k = 1:numel(info.MethodInfos)
    mInfo = info.MethodInfos{k};
    methodHtml = mdoc_render(mInfo);
    % Rewrite class back-link to point to local file
    methodHtml = strrep(string(methodHtml), ...
        "matlab:mdoc('" + info.Name + "')", ...
        "mdoc_" + fileStem + ".html");
    methodPath = fullfile(tempdir, "mdoc_" + fileStem + "." + mInfo.Name + ".html");
    fid = fopen(methodPath, 'w', 'n', 'UTF-8');
    fwrite(fid, char(methodHtml), 'char');
    fclose(fid);
end
end

function html = rewriteMethodLinks(html, fileStem)
% Rewrite matlab:mdoc('ClassName.method') links to local file paths.
html = string(html);
[tokens, matches] = regexp(char(html), ...
    'matlab:mdoc\(''[^'']+\.([^'']+''\))', 'tokens', 'match');
for k = 1:numel(tokens)
    methodName = regexprep(string(tokens{k}{1}), '''\)$', '');
    html = strrep(html, string(matches{k}), ...
        "mdoc_" + fileStem + "." + methodName + ".html");
end
end
