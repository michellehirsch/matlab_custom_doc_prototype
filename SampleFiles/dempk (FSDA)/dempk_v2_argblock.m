function out = dempk_v2_argblock(Y, k, g, opts)
% dempk  Merge components found by tkmeans.
%
% Performs either a hierarchical merging of the `k` components found by
% `tkmeans` (giving `g` clusters), or a threshold-based merging using
% pairwise overlap values. The merging rule depends on the value of `g`:
%
% - If `g` is an integer $\geq 1$, hierarchical clustering reduces the
%   `k` components to `g` groups
% - If `0 < g < 1`, components with pairwise overlap above the threshold
%   `g` ($\omega^*$) are merged (same algorithm as `overlapmap`)
%
% ## Syntax
%
% `out = dempk(Y, k, g)` merges the `k` components found by `tkmeans`
% into `g` groups using hierarchical clustering, or merges all component
% pairs with pairwise overlap above the threshold `g`.
%
% `out = dempk(Y, k, g, Name=Value)` specifies additional options using
% one or more name-value arguments. For example,
% `dempk(Y, 50, 3, Alpha=0.1, Plots="contourf")` trims 10% of the data
% and displays filled contour plots.
%
% ## Output Arguments
%
% `out` — Results structure with the following fields:
%
% - `PairOver` — Pairwise overlap triangular matrix (sum of
%   misclassification probabilities) among components found by `tkmeans`
% - `mergID` — Label vector with $n$ elements assigning each unit to a
%   merged group. A value of `0` denotes trimmed units.
% - `tkmeansOut` — Output from `tkmeans`. Present only when
%   `TkmeansOut=true`.
% - `Y` — Original data matrix. Present only when `Ysave=true`.
%
% ## Examples
%
% ### Hierarchical merging of simulated clusters
%
% Generate 10 homogeneous spherical clusters in 2-D and merge 50
% `tkmeans` components into 3 groups.
%
% ```matlab
% rng(100, "twister");
% out = MixSim(10, 2, sph=true, hom=true, int=[0 10], ...
%     Display="off", BarOmega=0.05);
% [X, id] = simdataset(5000, out.Pi, out.Mu, out.S);
% gscatter(X(:,1), X(:,2), id)
%
% DEMP = dempk(X, 50, 3, Plots="contourf");
% ```
%
% ### Threshold-based merging
%
% Use an overlap threshold instead of specifying the number of groups.
%
% ```matlab
% DEMP2 = dempk(X, 50, 0.01, Plots="contour");
% ```
%
% ### Merging with trimming for noisy data
%
% Generate 3 elliptical clusters with 10% uniform noise, then merge
% with trimming.
%
% ```matlab
% rng(500, "twister");
% out = MixSim(3, 2, sph=false, restrfactor=30, int=[0 10], ...
%     Display="off", MaxOmega=0.005);
% [X, id] = simdataset(5000, out.Pi, out.Mu, out.S, noiseunits=500);
% gscatter(X(:,1), X(:,2), id)
%
% % Hierarchical merging with trimming
% DEMP = dempk(X, 18, 3, Alpha=0.1, Plots="contourf");
%
% % Threshold merging with trimming
% DEMP2 = dempk(X, 18, 0.025, Alpha=0.1, Plots="contourf");
% ```
%
% ### Custom tkmeans options and linkage method
%
% Pass additional `tkmeans` settings via `TkmeansOpt` and change the
% hierarchical linkage method.
%
% ```matlab
% tkOpt = struct;
% tkOpt.reftol = 0.0001;
% tkOpt.msg = 1;
%
% DEMP = dempk(X, 18, 3, TkmeansOpt=tkOpt, ...
%     Linkage="weights", Plots="ellipse");
% ```
%
% ## Algorithms
%
% The algorithm proceeds in two stages:
%
% 1. **Component finding** — `tkmeans` identifies `k` components with
%    optional trimming level $\alpha$.
% 2. **Overlap computation** — The pairwise overlap matrix is computed
%    from the empirical component parameters (means, covariances, sizes)
%    using the `overlap` function.
%
% The merging strategy then depends on `g`:
%
% - **Hierarchical merging** ($g \geq 1$, integer): The overlap matrix
%   is converted to a dissimilarity matrix ($1 - \text{overlap}$) and
%   passed to a hierarchical clustering algorithm with the specified
%   linkage method, producing `g` groups.
% - **Threshold merging** ($0 < g < 1$): Components are iteratively
%   merged by selecting the pair with maximum overlap, continuing to
%   adjacent components until no remaining pair exceeds $\omega^* = g$.
%
% ## References
%
% Melnykov, V., Michael, S. (2020), Clustering Large Datasets by Merging
% K-Means Solutions, _Journal of Classification_, Vol. 37, pp. 97-123.
% [doi:10.1007/s00357-019-09314-8](https://doi.org/10.1007/s00357-019-09314-8)
%
% Melnykov, V. (2016), Merging Mixture Components for Clustering Through
% Pairwise Overlap, _Journal of Computational and Graphical Statistics_,
% Vol. 25, pp. 66-90.
%
% See also tkmeans, clusterdata, overlapmap

arguments
    % Input data, specified as an $n \times v$ matrix where rows are
    % observations and columns are variables. Missing values (`NaN`) and
    % infinite values (`Inf`) are allowed; rows containing them are
    % automatically excluded from computations.
    Y                (:,:) double                                   % Input data (n-by-v)

    % Number of components searched by the `tkmeans` algorithm.
    k                (1,1) double {mustBePositive, mustBeInteger}   % Number of tkmeans components

    % Merging rule. When `g` is an integer $\geq 1$, hierarchical
    % clustering reduces components to `g` groups. When `0 < g < 1`,
    % `g` is interpreted as the pairwise overlap threshold $\omega^*$
    % for merging.
    g                (1,1) double {mustBePositive}                  % Merging rule

    % Global trimming level. When `Alpha=0` (default), `tkmeans`
    % reduces to k-means.
    opts.Alpha       (1,1) double {mustBeInRange( ...
                     opts.Alpha, 0, 0.5)} = 0                       % Global trimming level

    % Plot specification. Controls what is displayed after merging.
    % Specify as one of:
    %
    % - `0` *(default)* — No plot
    % - `1` — Scatter plot (histogram for 1-D, bivariate scatter for
    %   2-D, scatter matrix for higher dimensions)
    % - `"contourf"` — Bivariate scatter with filled contour background
    % - `"contour"` — Bivariate scatter with contour lines
    % - `"ellipse"` — Bivariate scatter with 95% confidence ellipses
    % - `"boxplotb"` — Bivariate scatter with bivariate boxplots
    %
    % Alternatively, pass a struct with a `type` field set to one of
    % the strings above, plus optional fields: `cmap` (colormap as an
    % RGB matrix) or `conflev` (confidence level for ellipses, between
    % 0 and 1).
    %
    % > [!NOTE]
    % > Labels $\leq 0$ are automatically excluded from the overlay
    % > phase, treating them as outliers.
    opts.Plots       = 0                                            % Plot specification

    % Optional arguments for `tkmeans`, specified as a structure whose
    % field names correspond to `tkmeans` name-value arguments. See
    % `tkmeans` for details.
    opts.TkmeansOpt  (1,1) struct = struct()                        % tkmeans optional arguments

    % When `true`, the `tkmeans` output structure is saved into the
    % output. Default is `false`.
    opts.TkmeansOut  (1,1) logical = false                          % Save tkmeans output

    % Linkage method for hierarchical clustering. Default is `"single"`.
    % See the MATLAB `linkage` function for valid methods.
    opts.Linkage     (1,:) char = 'single'                          % Linkage method

    % When `true`, the input matrix `Y` is saved into the output
    % structure. Default is `false`.
    opts.Ysave       (1,1) logical = false                          % Save input Y
end

[~, v] = size(Y);

% Extract options into local variables
alpha      = opts.Alpha;
plots      = opts.Plots;
tkmeansOut = opts.TkmeansOut;
tkmeansOpt = opts.TkmeansOpt;
linkagearg = opts.Linkage;
Ysave      = opts.Ysave;

%% Calling tkmeans (with default or optional arguments)

if isempty(fieldnames(tkmeansOpt))
    % default
    clu = tkmeans(Y, k, alpha);
else
    % add optional arguments to tkmeans
    tkmeansOptNames = fieldnames(tkmeansOpt);
    tkmeansOptCell = cell(1,2*length(tkmeansOptNames));
    for i = 1:numel(tkmeansOptNames)
        first=(i-1)*2+1;
        tkmeansOptCell{first}=tkmeansOptNames{i};
        tkmeansOptCell{first+1} = tkmeansOpt.(tkmeansOptNames{i});
    end
    clu = tkmeans(Y, k, alpha, tkmeansOptCell{:});
end


if isstruct(clu.emp)
    % change the output used. Use the empirical values when the clustering
    % algorithm did not converge
    clu.muopt = clu.emp.muemp;
    clu.sigmaopt =  clu.emp.sigmaemp;
    clu.siz = clu.emp.sizemp;
    clu.idx = clu.emp.idxemp;
end

% index the real clusters found
% Eliminate any empty component or outliers
clu.siz = clu.siz(clu.siz(:,1)>0,:);   % exclude outliers and NaN in clu.siz
% Eliminate any empty component (NaN)
if sum(isnan(clu.muopt(:,1)))>0
    indd = ~isnan(clu.muopt(:,1));
    clu.muopt = clu.muopt(indd,:);
    clu.sigmaopt = clu.sigmaopt(:,:,indd);
end

% Empirical values obtained by tkmeans
[clu.OmegaMap, ~, ~, ~, ~] = overlap(k, v, clu.siz(:,3), clu.muopt, clu.sigmaopt);

% Sum of all pairs of misclassification probaility to obtain an overlap matrix
overM = triu(clu.OmegaMap,1)+(tril(clu.OmegaMap,-1))';
overMsave = overM; % to save it

%% DEMP-K algorithm with hierarchical merging (if g is an integer scalar)

if g >= 1 && mod(g, 1)==0 && g<=k
    % transform the triangular overlaps matrix in a similarities vector
    candInt = triu(overM)'+ overM; % obtain a symmetrical overlap matrix
    candVec = squareform(candInt); % vector form

    % trasform the similarity measure (i.e. overlap) in a dissimilarity one
    % (i.e. similar to a distance)
    candVec = 1-candVec; % distance vector

    % hieararchical clustering
    if ~any(strcmp(linkagearg, {'single', 'nearest'; ...
            'complete', 'farthest'; ...
            'average',  'upgma'; ...
            'weighted', 'wpgma'; ...
            'centroid', 'upgmc'; ...
            'median',   'wpgmc'; ...
            'ward''s',  'incremental'}))
        linkagearg = 'single';
    end

    % Construct clusters from the overlap "distance" vector
    Z    = linkage_dempk(candVec,linkagearg);
    Hier = cluster(Z,'maxclust',g);

    % initialize mergID with components found by tkmeans (to preserve
    % trimmed units)
    mergID = clu.idx;
    % update mergID with the new merged labels
    for i = 1:max(Hier)
        ids_i = find(Hier==i);
        merges_i = ismember(mergID, ids_i);
        mergID(merges_i) = i+10000;
    end

    % restore proper ID values
    mergID(mergID~=0) = mergID(mergID~=0)-10000;

elseif 0<g && g<1
    %% merging components using a cut-off if 0<g<1 (i.e. omegastar)

    omegaStar = g;

    % Merging phase
    % set to nan elements below the main diagonal of overM
    d1 = size(overM, 1);
    In = logical(tril(ones(d1)));
    overM(In) = nan;

    % find max pairwise overlap in overM
    mas = max(overM(:));
    [r,c] = find(overM==mas);

    % initialize mergMat (merging matrix)
    mergMat = zeros(k*(k-1)/2 - sum(overM(:)==0), 3);

    % save the max pairwise overlap value and its indexes,
    mergMat(1,1) = overM(r, c);
    mergMat(1,2) = r;
    mergMat(1,3) = c;
    % exclude it setting it equal to NaN
    overM(r,c) = nan;

    % initialize cand0: filled with groups closer to some component
    % already included in mergMat(:, 2:3)
    cand0 = nan(size(overM));
    cand0(r,:) = overM(r,:);
    cand0(:,c) = overM(:,c);
    cand0(:,r) = overM(:,r);
    cand0(c,:) = overM(c,:);

    i = 2;
    totRC = 1:length(overM);

    % overlap values sorted and saved according to nearest groups already
    % found (i.e. with greater overlap)
    while ~all(isnan(overM(:)) | overM(:) == 0)

        if any(cand0(:))~=0
            % find max values and indexes according to cand0
            mas = max(cand0(:));
            [rr,cc] = find(cand0==mas);

            % save the results and exclude the corresponding values from overM
            mergMat(i,1) = mas;
            mergMat(i,2) = rr;
            mergMat(i,3) = cc;
            overM(rr,cc) = nan;

            % update indexes
            r = ind2sub(totRC, unique([r rr]));
            c = ind2sub(totRC, unique([c cc]));

            % update cand0
            cand0(r,:) = overM(r,:);
            cand0(:,r) = overM(:,r);
            cand0(:,c) = overM(:,c);
            cand0(c,:) = overM(c,:);

            i=i+1;

        else
            mas = max(overM(:));
            [rr,cc] = find(overM==mas);

            % add an empty row to distinguish disjoint groups
            mergMat(i,:) = 0;
            i = i+1;

            % save the results and delete the values from cand
            mergMat(i,1) = mas;
            mergMat(i,2) = rr;
            mergMat(i,3) = cc;
            overM(rr,cc) = nan;

            % update indexes
            r = ind2sub(totRC, unique([r rr]));
            c = ind2sub(totRC, unique([c cc]));

            % update cand0
            cand0(r,:) = overM(r,:);
            cand0(:,r) = overM(:,r);
            cand0(:,c) = overM(:,c);
            cand0(c,:) = overM(c,:);

            i=i+1;
        end
    end

    % Index of the pairs of components above the threshold
    ind = mergMat(:,1) >= omegaStar;

    % Initialize variables to obtain a vector labelling each cluster
    ng = 0;
    ind_Prev = 0;
    groups = zeros(length(ind), 1);

    % Assign merged groups with progressive enumeration
    for iii = 1:length(ind)
        ind_i = ind(iii);
        if ind_i == 0
            groups(iii) = 0;
        elseif  ind_i == ind_Prev
            groups(iii) = groups(iii-1);
        else
            ng = ng + 1;
            groups(iii) = ng;
        end
        ind_Prev = ind_i;
    end

    % Get unique values of the components to merge and store them in label cell array
    label = cell(max(groups),1);
    for iii = 1:max(groups)
        labelSol = unique(mergMat(groups==iii, 2:3));
        if size(labelSol, 1) == 1
            labelSol = labelSol';
        end
        label{iii} = {labelSol};
    end

    % Find possible non-merged clusters
    singleOnes = 1:k;
    for iii = 1:max(groups)
        eachMergClu = cell2mat(label{iii});
        singleOnes = setdiff(singleOnes, eachMergClu, 'sorted');
    end

    % assign singleOnes at the end of labels array
    if ~isempty(singleOnes)
        label{max(groups)+length(singleOnes)} = [];
        label(max(groups)+1:max(groups)+length(singleOnes)) = num2cell(singleOnes);
    end

    % get labels for the merged groups referred to original units
    mergID = clu.idx;
    for j = 1:length(label)
        if iscell(label{j})
            mergID(ismember(clu.idx, cell2mat(label{j}))) = j;
        else
            mergID(ismember(clu.idx, label{j})) = j;
        end
    end

    % Check for errors in g
elseif g >= 1 && g<=k && mod(g, 1)~=0
    error('FSDA:dempk:wrongInputs','For hierarchical clustering the argument ''g'' has to be an integer.')
elseif g>k
    error('FSDA:dempk:wrongInputs','The argument g has to be smaller than the number of components k.')
end


%% Plotting phase

if ~(isscalar(plots) && plots==0)

    if v == 1
        % Univariate case: plot the histogram
        histFS(Y(mergID>0), length(Y(mergID>0)), mergID(mergID>0));
        str = sprintf('Histograms of the merged components');
        title(str,'Interpreter','Latex');
        legend(num2str(unique(mergID(mergID>0))))

    elseif v >= 2

        % Bivariate plot, optionally with confidence ellipses, density
        % contours or bivariate boxplot
        if ischar(plots)
            overlay.type = plots;
        elseif isstruct(plots)
            overlay = plots;
        elseif plots==1
            overlay ='';
        end

        % exclude outliers if present (when plots is char or struct)
        if any(mergID<=0) && ~isempty(overlay)
            overlay.include = true(length(unique(mergID)), 1);
            overlay.include(unique(mergID)<=0) = false;
        end

        plo.labeladd=1;

        % start with a black color when there are some outliers
        if any(mergID<=0)
            plo.clr = 'kbrmgcykbrmgcykbrmgcykbrmgcykbrmgcykbrmgcykbrmgcykbrmgcykbrmgcykbrmgcykbrmgcykbrmgcykbrmgcykbrmgcykbrmgcykbrmgcykbrmgcykbrmgcy';
            plo.clr = plo.clr(1:length(unique(mergID)));
        end

        if v==2
            undock = [2 1];
        else
            undock = '';
        end

        if g>1
            str = sprintf('Scatter plot of the merged components using hierarchical clustering');
        else
            str = sprintf('Scatter plot of the merged components using the threshold %s=%.4f', '$\omega^*$', g);
        end

        spmplot(Y, 'group', mergID, 'plo', plo, 'undock', undock, 'overlay', overlay);
        title(str,'Interpreter','Latex');
    end
end


%% Store outputs

out = struct;
out.PairOver = overMsave;
out.mergID = mergID;

if tkmeansOut
    out.tkmeansOut = clu;
end

if Ysave
    out.Y = Y;
end

end

%%

function Z = linkage_dempk(Y, method)
% linkage_dempk  Create hierarchical cluster tree.
%
% Modified version of the MATLAB `linkage` function. See the MATLAB
% help page for additional information.

method = method(1:2);

n = size(Y,2);
m = ceil(sqrt(2*n));
if isa(Y,'single')
    Z = zeros(m-1,3,'single');
else
    Z = zeros(m-1,3);
end

N = zeros(1,2*m-1);
N(1:m) = 1;
n = m;
R = 1:n;

if any(strcmp(method,{'ce' 'me' 'wa'}))
    Y = Y .* Y;
end

for s = 1:(n-1)
    if strcmp(method,'av')
        p = (m-1):-1:2;
        I = zeros(m*(m-1)/2,1);
        I(cumsum([1 p])) = 1;
        I = cumsum(I);
        J = ones(m*(m-1)/2,1);
        J(cumsum(p)+1) = 2-p;
        J(1)=2;
        J = cumsum(J);
        W = N(R(I)).*N(R(J));
        [v, k] = min(Y./W);
    else
        [v, k] = min(Y);
    end

    i = floor(m+1/2-sqrt(m^2-m+1/4-2*(k-1)));
    j = k - (i-1)*(m-i/2)+i;

    Z(s,:) = [R(i) R(j) v];

    I1 = 1:(i-1); I2 = (i+1):(j-1); I3 = (j+1):m;
    U = [I1 I2 I3];
    I = [I1.*(m-(I1+1)/2)-m+i i*(m-(i+1)/2)-m+I2 i*(m-(i+1)/2)-m+I3];
    J = [I1.*(m-(I1+1)/2)-m+j I2.*(m-(I2+1)/2)-m+j j*(m-(j+1)/2)-m+I3];

    switch method
        case 'si' % single linkage
            Y(I) = min(Y(I),Y(J));
        case 'co' % complete linkage
            Y(I) = max(Y(I),Y(J));
        case 'av' % average linkage
            Y(I) = Y(I) + Y(J);
        case 'we' % weighted average linkage
            Y(I) = (Y(I) + Y(J))/2;
        case 'ce' % centroid linkage
            K = N(R(i))+N(R(j));
            Y(I) = (N(R(i)).*Y(I)+N(R(j)).*Y(J)-(N(R(i)).*N(R(j))*v)./K)./K;
        case 'me' % median linkage
            Y(I) = (Y(I) + Y(J))/2 - v /4;
        case 'wa' % Ward's linkage
            Y(I) = ((N(R(U))+N(R(i))).*Y(I) + (N(R(U))+N(R(j))).*Y(J) - ...
                N(R(U))*v)./(N(R(i))+N(R(j))+N(R(U)));
    end
    J = [J i*(m-(i+1)/2)-m+j]; %#ok<AGROW>
    Y(J) = [];

    m = m-1;
    N(n+s) = N(R(i)) + N(R(j));
    R(i) = n+s;
    R(j:(n-1))=R((j+1):n);
end

if any(strcmp(method,{'ce' 'me' 'wa'}))
    Z(:,3) = sqrt(Z(:,3));
end

Z(:,[1 2])=sort(Z(:,[1 2]),2);

end
