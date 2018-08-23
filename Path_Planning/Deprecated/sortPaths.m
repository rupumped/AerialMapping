function [paths, scores] = sortPaths(paths)
nodes = {paths.Nodes};
scores = cellfun(@(p) numel(unique(p)), nodes);
[scores,ind] = sort(scores,'descend');
paths = paths(ind);
end