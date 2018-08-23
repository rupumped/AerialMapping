function paths = sortPathsAndFilter(paths)
%% Remove all paths that are do not have the maximum number of unique nodes
nodes = {paths.Nodes};
scores = cellfun(@(p) numel(unique(p)), nodes); % Number of unique nodes in path
paths(scores ~= max(scores)) = [];

%% Remove effectively duplicate paths
h = waitbar(0,'Removing effectively duplicate paths...');
% ind = [];
% for op = 1:length(paths)
%     for p = op+1:length(paths)
%         if all(paths(op).Nodes == paths(p).Nodes(end:-1:1))
%             ind(end+1) = op;
%             break;
%         end
%     end
% end
% paths(ind) = [];

ind = [];
for op = 1:length(paths)
%     paths(find(arrayfun(@(pa) all(ismember([paths(op).Nodes],[pa.Nodes])), paths(op+1:end)))+op) = [];
%     ind = [ind, find(arrayfun(@(pa) all(ismember([paths(op).Nodes],[pa.Nodes])), paths(op+1:end)), 1, 'first')];
    for p = op+1:length(paths)
        if all(sort(paths(op).Nodes) == sort(paths(p).Nodes))
            ind(end+1) = op;
            break;
        end
    end
    waitbar(op/length(paths),h);
end
paths(ind) = [];

%% Sort by how many nodes are hit that other paths miss
waitbar(0,h,'Sorting remaining paths...');
scores = zeros(size(paths));                    % Number of nodes repeated by other paths (how mainstream is this path?)
for p = 1:length(paths)
    for n = paths(p).Nodes
        scores(p) = scores(p) + sum([paths([1:p-1, p+1:end]).Nodes] == n);
    end
    paths(p).Score = scores(p);
    waitbar(p/length(paths),h);
end
[~,ind] = sort(scores);
paths = paths(ind);
end