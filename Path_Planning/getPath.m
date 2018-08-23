function [lon,lat] = getPath(wallet, illustrate)
%GETPATH generates CSVs of every flight taken by a drone given the drone's
%wallet
%
% Inputs (2):
% - wallet (double): the distance the drone can travel in radians. To 
%   convert from linear distance, use the arc length formula s=r*theta
% - illustrate (logical): true => plot results
% Outputs (2):
% - lon (double): a vector of waypoint longitudes
% - lat (double): a vector of waypoint latitudes
%
% The function also writes a CSV file for each path of size M-by-3 where M
% is the number of waypoints in the path. The first column is the
% latitudes. The second column is the longitudes. The third column is a 1
% where the location marks a photo waypoint and a zero where the location
% marks a navigation waypoint.

close all;format long
global waypoints unit_lat unit_lon precision

%% Preprocessing
waypoints = csvread('waypoints.csv');
home = waypoints(end,[2,1]);
waypoints(end,:)=[];
lat = waypoints(:,1);   % Latitudes
lon = waypoints(:,2);   % Longitudes
waypoints = struct('Lat'       ,num2cell(lat), ... waypoint latitude
                   'Lon'       ,num2cell(lon), ... waypoint longitude
                   'Border'    ,false        , ... if the waypoint is on a border
                   'Discovered',false        , ... if the waypoint has been discovered
                   'Type'      ,-1           );  % -1=undetermined, 0=navigation, 1=photo
homeWP = waypoints(lat==home(2) & lon==home(1));
unit_lat = min(abs(lat(1)-lat(lat~=lat(1))));
unit_lon = min(abs(lon(1)-lon(lon~=lon(1))));
precision = -floor(log10(min([unit_lat,unit_lon])));
for i=1:numel(waypoints)
    if isequal(goNorth(waypoints(i)),-1) || isequal(goEast(waypoints(i)),-1) || isequal(goSouth(waypoints(i)),-1) || isequal(goWest(waypoints(i)),-1)
        waypoints(i).Border = true;
    end
end
radius = 2*max(sqrt((lon-homeWP.Lon).^2+(lat-homeWP.Lat).^2));

%% Calculate all paths
flightNum = 1;
delta_th = .1;
th1 = 0;
th2 = th1+delta_th;
while ~all([waypoints.Discovered])
    flag = false;
    thisPathFinished=false;
    thisWallet = wallet;
    while ~thisPathFinished
        %% Construct polygon encompassing this flight
        thSpace=linspace(th1,th2,9)';
        polygon = [home;
            home(1)+radius*cos(thSpace), home(2)+radius*sin(thSpace)];
        flightMask = inpolygon(lon,lat,polygon(:,1),polygon(:,2)) & ~[waypoints.Discovered]';
        flight = waypoints(flightMask);
        if ~any([flight.Lon]==homeWP.Lon & [flight.Lat]==homeWP.Lat), flight(end+1)=homeWP; end
        border1 = flight(inpolygon([flight.Lon],[flight.Lat],polygon([1,2,1],1),polygon([1,2,1],2)));
        border2 = flight(inpolygon([flight.Lon],[flight.Lat],polygon([1,end,1],1),polygon([1,end,1],2)));
        %% Begin path by taking smartest route to border
        if numel(border1) > numel(border2) && any([border1.Border])
            [~,sortFlight] = sort(distance(homeWP.Lat,homeWP.Lon,[border1.Lat],[border1.Lon]));
            sortFlight = border1(sortFlight);
        elseif numel(border1) < numel(border2) && any([border2.Border])
            [~,sortFlight] = sort(distance(homeWP.Lat,homeWP.Lon,[border2.Lat],[border2.Lon]));
            sortFlight = border2(sortFlight);
        else
            [~,sortFlight] = max(distance(homeWP.Lat,homeWP.Lon,[flight.Lat],[flight.Lon]));
            sortFlight = flight(sortFlight);
        end
        [flight,sortFlightInd,thisWallet] = nextPass(flight,find([flight.Lat]==homeWP.Lat & [flight.Lon]==homeWP.Lon),sortFlight,thisWallet);
        flight(lat==home(2) & lon==home(1)).Discovered = true;
        %% If not already there, fly to flight waypoint furthest from home
        [~,furthestPointInd] = max(distance([flight.Lat],[flight.Lon],homeWP.Lat,homeWP.Lon));
        if furthestPointInd~=sortFlightInd(end)
            sortFlight = flight(inpolygon([flight.Lat],[flight.Lon], ...
                [flight(sortFlightInd(end)).Lat,flight(furthestPointInd).Lat], ...
                [flight(sortFlightInd(end)).Lon,flight(furthestPointInd).Lon]));
            dist = distance([sortFlight.Lat],[sortFlight.Lon],flight(furthestPointInd).Lat,flight(furthestPointInd).Lon);
            [~,ind] = sort(dist,'descend');
            sortFlight = sortFlight(ind);
            [flight,sortFlightInd,thisWallet] = nextPass(flight,sortFlightInd,sortFlight,thisWallet);
        end
        %% Go to next furthest point that has not yet been discovered
        if illustrate, displayProgress(sortFlightInd,flight,polygon); end
        while any(~[flight.Discovered])
            currentWP = flight(sortFlightInd(end));
            % Consider only undiscovered waypoints
            newWPs = flight(~[flight.Discovered]);
            % Sort undiscovered waypoints by increasing distance from me
            [~,choices] = sort(distance(currentWP.Lat,currentWP.Lon,[newWPs.Lat],[newWPs.Lon]));
            % Calculate the distance from the closest waypoint to me to home
            choice1Dist2Home = distance(homeWP.Lat,homeWP.Lon,newWPs(choices(1)).Lat,newWPs(choices(1)).Lon);
            % If there is a second-closest waypoint to consider,
            if numel(choices) > 1
                % If the choice is between a nearest neighbor and a diagonal,
                % choose the nearest neighbor
                if distance(currentWP.Lat,currentWP.Lon,newWPs(choices(1)).Lat,newWPs(choices(1)).Lon) > .9*sqrt(unit_lat^2+unit_lon^2) && distance(currentWP.Lat,currentWP.Lon,newWPs(choices(1)).Lat,newWPs(choices(1)).Lon) < 1.1*sqrt(unit_lat^2+unit_lon^2) && ...
                        distance(currentWP.Lat,currentWP.Lon,newWPs(choices(2)).Lat,newWPs(choices(2)).Lon) > .9*min([unit_lat,unit_lon]) && distance(currentWP.Lat,currentWP.Lon,newWPs(choices(2)).Lat,newWPs(choices(2)).Lon) < 1.1*max([unit_lat,unit_lon])
                    choice2Dist2Home = 360;
                elseif distance(currentWP.Lat,currentWP.Lon,newWPs(choices(2)).Lat,newWPs(choices(2)).Lon) > .9*sqrt(unit_lat^2+unit_lon^2) && distance(currentWP.Lat,currentWP.Lon,newWPs(choices(2)).Lat,newWPs(choices(1)).Lon) < 1.1*sqrt(unit_lat^2+unit_lon^2) && ...
                        distance(currentWP.Lat,currentWP.Lon,newWPs(choices(1)).Lat,newWPs(choices(1)).Lon) > .9*min([unit_lat,unit_lon]) && distance(currentWP.Lat,currentWP.Lon,newWPs(choices(1)).Lat,newWPs(choices(1)).Lon) < 1.1*max([unit_lat,unit_lon])
                    choice1Dist2Home = 360;
                    choice2Dist2Home = 0;
                else
                    % Otherwise, record the distance from the second choice to
                    % home
                    choice2Dist2Home = distance(homeWP.Lat,homeWP.Lon,newWPs(choices(2)).Lat,newWPs(choices(2)).Lon);
                end
            else
                choice2Dist2Home = 0;
            end
            % Go to whichever one of the waypoints closest to me is furthest
            % from home.
            if choice1Dist2Home >= choice2Dist2Home
                sortFlightInd(end+1) = choices(1);
            else
                sortFlightInd(end+1) = choices(2);
            end
            sortFlightInd(end)= find(newWPs(sortFlightInd(end)).Lat==[flight.Lat] & newWPs(sortFlightInd(end)).Lon==[flight.Lon]);
            thisWallet = thisWallet-distance(flight(sortFlightInd(end-1)).Lat,flight(sortFlightInd(end-1)).Lon,flight(sortFlightInd(end)).Lat,flight(sortFlightInd(end)).Lon);
            flight(sortFlightInd(end)).Discovered = true;
            if illustrate
                plot(flight(sortFlightInd(end)).Lon,flight(sortFlightInd(end)).Lat,'c^')
                drawnow
            end
        end
        if flag                 % If this run is to be recorded as a flight
            flight = flight(sortFlightInd);
            for ind=1:numel(flight)
                waypoints([waypoints.Lat]==flight(ind).Lat & [waypoints.Lon]==flight(ind).Lon).Discovered = [waypoints([waypoints.Lat]==flight(ind).Lat & [waypoints.Lon]==flight(ind).Lon).Discovered] | flight(ind).Discovered;
                if ind==1 || ind==numel(flight)
                    flight(ind).Type=0;
                elseif (areSameWP(goNorth(flight(ind-1)),flight(ind)) && areSameWP(goNorth(flight(ind)),flight(ind+1))) || ...
                       (areSameWP(goEast (flight(ind-1)),flight(ind)) && areSameWP(goEast (flight(ind)),flight(ind+1))) || ...
                       (areSameWP(goSouth(flight(ind-1)),flight(ind)) && areSameWP(goSouth(flight(ind)),flight(ind+1))) || ...
                       (areSameWP(goWest (flight(ind-1)),flight(ind)) && areSameWP(goWest (flight(ind)),flight(ind+1)))
                    flight(ind).Type=1;
                else
                    flight(ind).Type=0;
                end
            end
            dlmwrite(sprintf('flight%02d.csv',flightNum),[[flight([1:end,1]).Lat]',[flight([1:end,1]).Lon]',[flight([1:end,1]).Type]'],'precision','%.13f');
            flightNum=flightNum+1;
            thisPathFinished = true;
        elseif thisWallet < 0   % If this run exhausted my wallet
            th2 = th2-delta_th;
            flag = true;
        elseif th2 >= 2*pi      % If I have completed the full circle
            thisWallet=wallet;
            flag = true;
        else                    % If this flight was not the largest run I can do
            thisWallet=wallet;
            th2 = th2+delta_th;
        end
        if illustrate, hold off; end
    end
    th1=th2;
    th2=th1+delta_th;
end
end

function [flight,sortFlightInd,thisWallet] = nextPass(flight,sortFlightInd,sortFlight,thisWallet)
sortFlightInd(end) = [];
sortFlightInd = [sortFlightInd, zeros(1,numel(sortFlight))];
for i=numel(sortFlightInd)-numel(sortFlight)+1:numel(sortFlightInd)
    sortFlightInd(i) = find(arrayfun(@(wp) isequal(sortFlight(1),wp), flight));
    sortFlight(1) = [];
    flight(sortFlightInd(i)).Discovered = true;
    if i>1, thisWallet = thisWallet-distance(flight(sortFlightInd(i-1)).Lat,flight(sortFlightInd(i-1)).Lon,flight(sortFlightInd(i)).Lat,flight(sortFlightInd(i)).Lon); end
end
end

function wp1 = goNorth(wp)
global waypoints unit_lat precision
north = round([waypoints.Lat],precision) == round(wp.Lat+unit_lat,precision) & ...
    [waypoints.Lon] == wp.Lon;
if any(north)
    wp1 = waypoints(north);
    if numel(wp1)>1
        warning('Confusion going North');
    end
else
    wp1 = -1;
end
end

function wp = goSouth(wp)
global waypoints unit_lat precision
south = round([waypoints.Lat],precision) == round(wp.Lat-unit_lat,precision) & ...
    [waypoints.Lon] == wp.Lon;
if any(south)
    wp = waypoints(south);
    if numel(wp)>1, warning('Confusion going South'); end
else
    wp = -1;
end
end

function wp = goEast(wp)
global waypoints unit_lon precision
east = round([waypoints.Lon],precision) == round(wp.Lon+unit_lon,precision) & ...
    [waypoints.Lat] == wp.Lat;
if any(east)
    wp = waypoints(east);
    if numel(wp)>1, warning('Confusion going East'); end
else
    wp = -1;
end
end

function wp = goWest(wp)
global waypoints unit_lon precision
west = round([waypoints.Lon],precision) == round(wp.Lon-unit_lon,precision) & ...
    [waypoints.Lat] == wp.Lat;
if any(west)
    wp = waypoints(west);
    if numel(wp)>1, warning('Confusion going West'); end
else
    wp = -1;
end
end

function displayProgress(sortFlightInd,flight,polygon)
global waypoints
plot([waypoints.Lon],[waypoints.Lat],'k.',polygon([1:end,1],1),polygon([1:end,1],2),'b-')
hold on
for i=sortFlightInd
    plot(flight(i).Lon,flight(i).Lat,'m^')
    drawnow
end
end

function eq = areSameWP(wp1,wp2)
if ~isstruct(wp1) || ~isstruct(wp2)
    eq=false;
else
    eq=wp1.Lon==wp2.Lon && wp1.Lat==wp2.Lat;
end
end