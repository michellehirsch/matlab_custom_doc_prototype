function mdoc(name)
% mdoc  Display rich HTML documentation for a MATLAB function.
%
% mdoc name parses the specified function's .m file and opens a styled
% HTML documentation page in the MATLAB web browser.
%
% mdoc(name) also accepts a file path as a string.
%
% This is a prototype stand-in for MATLAB's built-in doc command,
% demonstrating the custom documentation framework.

arguments
    name (1,1) string
end

% Parse the source file
info = mdoc_parse(name);

% Render to HTML
html = mdoc_render(info);

% Write to temp file and open
outPath = fullfile(tempdir, "mdoc_" + info.Name + ".html");
fid = fopen(outPath, 'w', 'n', 'UTF-8');
fwrite(fid, char(html), 'char');
fclose(fid);

% Open in MATLAB browser
web(char(outPath));

end
