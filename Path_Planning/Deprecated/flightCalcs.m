clear;clc

flightTime = 12*60; %[s]
grid = 2e3;         %[m]
nodeSpace = 30.48;  %[m]
totalNodes = ceil((grid/nodeSpace))^2;
pathEfficiency = .8;
speed = 25*0.447;  %[m/s]
nps = speed / nodeSpace; %[node/s]
npf = floor(nps*flightTime*pathEfficiency);
flights = ceil(totalNodes / npf)