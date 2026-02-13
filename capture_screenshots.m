% capture_screenshots  Generate HTML and open pages for screenshot capture.
%
% Renders each sample file used in the GettingStarted walkthrough and
% saves the HTML to the images/ folder.  Each page is opened in the
% MATLAB browser — take a screenshot of each window manually or use
% macOS screencapture.
%
% Usage:
%   Run this script from the project root directory.

addpath('prototype');

% Create images directory if needed
if ~isfolder('images')
    mkdir('images');
end

% Files to render and their screenshot names
samples = {
    'SampleFiles/rescale/rescale_v0_bare.m',     'rescale_v0'
    'SampleFiles/rescale/rescale_v1_args.m',      'rescale_v1'
    'SampleFiles/rescale/rescale_v2_plain.m',     'rescale_v2'
    'SampleFiles/rescale/rescale_v3_help.m',      'rescale_v3'
    'SampleFiles/rescale/rescale_v4_argdoc.m',    'rescale_v4'
    'SampleFiles/rescale/rescale_v5_sections.m',  'rescale_v5'
    'SampleFiles/rescale/rescale_v6_override.m',  'rescale_v6'
    'SampleFiles/Sensor/Sensor_v1_plain.m',       'Sensor_v1'
    'SampleFiles/Sensor/Sensor_v3_full.m',        'Sensor_v3'
};

for i = 1:size(samples, 1)
    mfile = samples{i, 1};
    name  = samples{i, 2};

    % Parse and render
    info = mdoc_parse(mfile);
    html = mdoc_render(info);

    % Save HTML to images folder for reference
    htmlPath = fullfile('images', name + ".html");
    fid = fopen(htmlPath, 'w', 'n', 'UTF-8');
    fwrite(fid, char(html), 'char');
    fclose(fid);

    fprintf('Saved: %s\n', htmlPath);

    % Open in system browser
    web(char(fullfile(pwd, htmlPath)), '-browser');
    pause(1);  % Brief pause between pages
end

fprintf('\nAll pages opened.  Take screenshots and save as:\n');
for i = 1:size(samples, 1)
    fprintf('  images/%s.png\n', samples{i, 2});
end
