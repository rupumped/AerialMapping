function panorama = stitcher(buildingDir)
%STITCHER generates a panoramic images of labelled, ordered images in
%BUILDINGDIR
%   PANORAMA = STITCHER(BUILDINGDIR), is the panoramic image of the
%   labelled, ordered images stored in the directory BUILDINGDIR
% For more information, visit http://www.mathworks.com/help/vision/examples/feature-based-panoramic-image-stitching.html

%% Load images
buildingScene = imageSet(buildingDir);
if buildingScene.Count <= 4
    %% Terminating Condition: Four or fewer images
    % Read the first image from the image set.
    I = read(buildingScene, 1);
    % Initialize features for I(1)
    grayImage = rgb2gray(I);
    points = detectSURFFeatures(grayImage);
    [features, points] = extractFeatures(grayImage, points);
    % Initialize all the transforms to the identity matrix. Note that the
    % projective transform is used here because the building images are fairly
    % close to the camera. Had the scene been captured from a further distance,
    % an affine transform would suffice.
    tforms(buildingScene.Count) = projective2d(eye(3));
    % Iterate over remaining image pairs
    for n = 2:buildingScene.Count
        % Store points and features for I(n-1).
        pointsPrevious = points;
        featuresPrevious = features;
        % Read I(n).
        I = read(buildingScene, n);
        % Detect and extract SURF features for I(n).
        grayImage = rgb2gray(I);
        points = detectSURFFeatures(grayImage);
        [features, points] = extractFeatures(grayImage, points);
        % Find correspondences between I(n) and I(n-1).
        indexPairs = matchFeatures(features, featuresPrevious, 'Unique', true);
        matchedPoints = points(indexPairs(:,1), :);
        matchedPointsPrev = pointsPrevious(indexPairs(:,2), :);
        % Estimate the transformation between I(n) and I(n-1).
        tforms(n) = estimateGeometricTransform(matchedPoints, matchedPointsPrev,...
            'projective', 'Confidence', 99.9, 'MaxNumTrials', 2000);
        % Compute T(1) * ... * T(n-1) * T(n)
        tforms(n).T = tforms(n-1).T * tforms(n).T;
    end
    imageSize = size(I);  % all the images are the same size
    % Compute the output limits  for each transform
    for i = 1:numel(tforms)
        [xlim(i,:), ylim(i,:)] = outputLimits(tforms(i), [1 imageSize(2)], [1 imageSize(1)]);
    end
    avgXLim = mean(xlim, 2);
    [~, idx] = sort(avgXLim);
    centerIdx = floor((numel(tforms)+1)/2);
    centerImageIdx = idx(centerIdx);
    Tinv = invert(tforms(centerImageIdx));
    for i = 1:numel(tforms)
        tforms(i).T = Tinv.T * tforms(i).T;
    end
    for i = 1:numel(tforms)
        [xlim(i,:), ylim(i,:)] = outputLimits(tforms(i), [1 imageSize(2)], [1 imageSize(1)]);
    end
    % Find the minimum and maximum output limits
    xMin = min([1; xlim(:)]);
    xMax = max([imageSize(2); xlim(:)]);
    yMin = min([1; ylim(:)]);
    yMax = max([imageSize(1); ylim(:)]);
    % Width and height of panorama.
    width  = round(xMax - xMin);
    height = round(yMax - yMin);
    % Initialize the "empty" panorama.
    panorama = zeros([height width 3], 'like', I);
    blender = vision.AlphaBlender('Operation', 'Binary mask', ...
        'MaskSource', 'Input port');
    % Create a 2-D spatial reference object defining the size of the panorama.
    xLimits = [xMin xMax];
    yLimits = [yMin yMax];
    panoramaView = imref2d([height width], xLimits, yLimits);
    % Create the panorama.
    for i = 1:buildingScene.Count
        I = read(buildingScene, i);
        % Transform I into the panorama.
        warpedImage = imwarp(I, tforms(i), 'OutputView', panoramaView);
        % Overlay the warpedImage onto the panorama.
        panorama = step(blender, panorama, warpedImage, warpedImage(:,:,1));
    end
else
    %% Recursive Step
    % Calculate indeces of current set of images
    toks=regexp(buildingScene.ImageLocation,'(\d+),(\d+)','tokens');
    inds = zeros(numel(toks),2);
    for t=1:numel(toks)
        inds(t,1) = str2double(toks{t}{1}{1});
        inds(t,2) = str2double(toks{t}{1}{2});
    end
    % Find limits on rows and columns
    minRow = min(inds(:,1),[],1);
    maxRow = max(inds(:,1),[],1);
    minCol = min(inds(:,2),[],1);
    maxCol = max(inds(:,2),[],1);
    % Create masks of quadrants
    ULm = inds(:,1)>= minRow           & inds(:,1)<=(maxRow+minRow)/2 & inds(:,2)>= minCol           & inds(:,2)<=(maxCol+minCol)/2;
    URm = inds(:,1)>= minRow           & inds(:,1)<=(maxRow+minRow)/2 & inds(:,2)> (maxCol+minCol)/2 & inds(:,2)<= maxCol          ;
    BLm = inds(:,1)> (maxRow+minRow)/2 & inds(:,1)<=maxRow            & inds(:,2)>= minCol           & inds(:,2)<=(maxCol+minCol)/2;
    BRm = inds(:,1)> (maxRow+minRow)/2 & inds(:,1)<=maxRow            & inds(:,2)> (maxCol+minCol)/2 & inds(:,2)<= maxCol          ;
    % Create a folder of each quadrant
    mkdir(buildingDir,'UL');
    mkdir(buildingDir,'UR');
    mkdir(buildingDir,'BL');
    mkdir(buildingDir,'BR');
    % Fill folders with photos
    cellfun(@(fn) copyfile(fn,[buildingDir '\UL']),buildingScene.ImageLocation(ULm))
    cellfun(@(fn) copyfile(fn,[buildingDir '\UR']),buildingScene.ImageLocation(URm))
    cellfun(@(fn) copyfile(fn,[buildingDir '\BL']),buildingScene.ImageLocation(BLm))
    cellfun(@(fn) copyfile(fn,[buildingDir '\BR']),buildingScene.ImageLocation(BRm))
    % Create panoramas of each quadrant
    UL = stitcher([buildingDir '\UL']);
    UR = stitcher([buildingDir '\UR']);
    BL = stitcher([buildingDir '\BL']);
    BR = stitcher([buildingDir '\BR']);
    % Create panorama of quadrants
    mkdir(buildingDir,'Pano');
    imwrite(UL,[buildingDir '\Pano\UL.png'],'png')
    imwrite(UR,[buildingDir '\Pano\UR.png'],'png')
    imwrite(BL,[buildingDir '\Pano\BL.png'],'png')
    imwrite(BR,[buildingDir '\Pano\BR.png'],'png')
    panorama=stitcher([buildingDir '\Pano']);
end
end