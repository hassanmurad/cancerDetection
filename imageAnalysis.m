%%%%%%%%%%%%%%%
% ENSC 460: Cancer Imaging
% 
% Hassan Murad, Amir Hadjifaradji, Farbod Faridi
%%%%%%%%%%%%%%%%
%% Clean up
try
    delete(vidobj);
    delete(stage);
catch
    warning('idiots, you deleted yourself...');
end

clear; clc; close all;

%% Initialize Stage and Video Object
% Create and configure the video object
vidobj = videoinput('thorlabsimaq')
% Create the stage object- you should calibrate and measure the stage if its power has been cycled
stage = LangMCL3;
startPosition = [stage.PositionX stage.PositionY stage.PositionZ]
%% Define the focus positions for image acquisition

% Save the starting position
src = getselectedsource(vidobj);
src.ExposureTime = 10;
preview(vidobj);
%% Grab the image

pause(0.5)
% Grab a frame and save to disk for easy reviewing later
s = getsnapshot(vidobj);
%filename = sprintf('C:\\Users\\ahadjifa\\Desktop\\project\\pictures\\ImageFromTop%d.tif', n);
imwrite(s, 'cell5.jpeg'); imshow(s); figure(1);

%% Find Threshold, Invert and Clear the Border of the Image

doubleS = im2double(s);       %turn int8 to doubles
[T,EM] = graythresh(doubleS); %find the thresh 
bw_s = ~im2bw(doubleS, T);    %apply threshold and invert
noBorder_s = imclearborder(bw_s); %clear the border
figure(3);imhist(bw_s);
figure(4); imshow(noBorder_s); impixelinfo

%% Perform Opening (get rid of specks)
cleaned_s = bwareaopen(noBorder_s, 60) %get rid of small specks
figure(5); imshow(cleaned_s);


%% Closing
se = strel('disk', 1);
cleaned_s = imclose(cleaned_s, se);
figure(6); imshow(cleaned_s)
%% Colour Map
cc = bwconncomp(cleaned_s);         
lm = labelmatrix(cc);
cmap_s = cool(cc.NumObjects);
cmap_s(1,:) = [0 0 0];

figure(7), imshow(lm,cmap_s); impixelinfo

%% RegionProps
stats = regionprops(cleaned_s, 'All');
Circularity = 4*pi*[stats.Area] ./ ([stats.Perimeter].^2);
for n=1:numel(Circularity)
    stats.Circularity = Circularity(n);
end
%% Viscircles
centers = stats.Centroid;
diameters = mean([stats.MajorAxisLength stats.MinorAxisLength],2);
radii = diameters/2;
figure(6);
hold on
viscircles(centers,radii);
hold off


    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    