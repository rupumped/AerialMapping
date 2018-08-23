function visualizePaths(g,paths,Hz,holding)
close all
for p=paths
    h = plot(g,'b');
    highlight(h,p.Nodes,'NodeColor','g','EdgeColor','m','LineWidth',3,'MarkerSize',5)
    if holding, hold on; end
    pause(1/Hz)
end
end