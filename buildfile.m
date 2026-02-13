function plan = buildfile
import matlab.buildtool.tasks.*

plan = buildplan(localfunctions);

plan("doc").Description = "Generate HTML documentation for all SampleFiles";

plan.DefaultTasks = "doc";
end

function docTask(context) %#ok<INUSD>
% Build HTML documentation site from SampleFiles into docs/ for GitHub Pages

% Add prototype folder to path so mbuilddoc and its dependencies are available
prjRoot = fileparts(mfilename("fullpath"));
addpath(fullfile(prjRoot, "prototype"));

sourceFolder = fullfile(prjRoot, "SampleFiles");
outputFolder = fullfile(prjRoot, "docs");

fprintf("Building documentation...\n");
fprintf("  Source: %s\n", sourceFolder);
fprintf("  Output: %s\n\n", outputFolder);

mbuilddoc(sourceFolder, outputFolder);

fprintf("\nDocumentation build complete.\n");
end
