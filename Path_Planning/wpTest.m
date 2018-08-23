close all
fn='flight';
files=dir;
hold on
for i=1:sum(cellfun(@(file) ~isempty(strfind(file,fn)),{files.name}))
    waypoints = csvread(sprintf('%s%02d.csv',fn,i));
    for j=1:length(waypoints)
        switch waypoints(j,3)
            case -1
                style='rh';
            case 0
                style='k+';
            case 1
                style='ko';
        end
        plot(waypoints(j,2),waypoints(j,1),style)
        if j~=1
            quiver(waypoints(j-1,2),waypoints(j-1,1),waypoints(j,2)-waypoints(j-1,2),waypoints(j,1)-waypoints(j-1,1),0,'k');
        end
    end
end
hold off