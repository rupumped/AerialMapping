function flights = fillGraph(g, paths)
flights = paths(1);
flights(1) = [];
discovered = [];
while ~isequal(discovered, 1:height(g.Nodes))
    flights(end+1) = paths(1);
    paths(1) = [];
    discovered = unique([discovered, flights(end).Nodes],'sorted');
    
    scores = zeros(size(paths));
    for p = 1:length(paths)
        for n = paths(p).Nodes
            scores(p) = scores(p) + sum(discovered == n);
        end
        paths(p).Score = scores(p);
    end
    [~,ind] = sort(scores);
    paths = paths(ind);
end
end