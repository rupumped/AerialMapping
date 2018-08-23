function paths = getPetals(g, home, wallet)
paths = calcEveryPathFromHere(g, home, wallet, home, struct('Nodes',home));
end

function [paths] = calcEveryPathFromHere(g, home, wallet, thisNode, paths)
for n = neighbors(g,thisNode)'
    if distances(g,n,home) <= wallet-1
        paths(end).Nodes(end+1) = n;
        if n == home
            paths(end+1) = paths(end);
        else
            [paths] = calcEveryPathFromHere(g, home, wallet-1, n, paths);
        end
        paths(end).Nodes(end) = [];
%             h = plot(g,'b');
%             highlight(h,paths(end).Nodes,'NodeColor','g','EdgeColor','m','LineWidth',3,'MarkerSize',5)
% %             if holding, hold on; end
%             pause(eps)
    end
end
end