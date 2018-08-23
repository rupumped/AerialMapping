clear;clc;close all hidden

load('pathData1,5.mat');

%% User Input
% m = 7;
% n = 7;
% home = round(m*n/2);
% wallet = 18;

%% Calculations
% g = mapGraph(m,n);
h = waitbar(1/4,'Calculating Petals...');
% paths = getBestPetals(g,home,wallet);
waitbar(3/4,h,'Sorting and Filtering...');
paths = sortPathsAndFilter(paths);
waitbar(4/4,h,'Calculating Flights...');
flights = fillGraph(g,paths);
close(h)

%% Visualization
visualizePaths(g,flights,1,false)