close all
clear all
clc
tic
%%
imgPath = './pictures/';
imgType = '*.tif'; % change based on image type
images  = dir([imgPath imgType]);

%get all images
%iterate over their size each one
%pass that into the image analysis script?
%does analysis of that image and finds good cells and bad cells

%stats = cells(numel(images), 1); 
s8 = zeros(1024, 1280, numel(images));
for k = 1:numel(images)
    filename = sprintf('./pictures/%s', images(k).name);
    s8 = imread(filename);

    s = im2double(s8);
    %figure(1), imshow(s)
    % Find Threshold, Invert and Clear the Border of the Image


    doubleS = im2double(s);       %turn int8 to doubles
    [T,EM] = graythresh(doubleS); %find the thresh 
    bw_s = ~im2bw(doubleS, T);    %apply threshold and invert
    noBorder_s = imclearborder(bw_s); %clear the border
    %figure(3);imhist(bw_s);
    %figure(4); imshow(noBorder_s); impixelinfo

    % Perform Opening (get rid of specks)
    cleaned_s = bwareaopen(noBorder_s, 60); %get rid of small specks
    %figure(5); imshow(cleaned_s);


    % Closing
    se = strel('disk', 1);
    cleaned_s = imclose(cleaned_s, se);
    %figure(6); imshow(cleaned_s)
    % Colour Map
    cc = bwconncomp(cleaned_s);         
    lm = labelmatrix(cc);
    cmap_s = cool(cc.NumObjects);
    cmap_s(1,:) = [0 0 0];

    figure(k), imshow(lm,cmap_s); impixelinfo

    % RegionProps
    stats = regionprops(cleaned_s, 'All');
    Circularity = 4*pi*[stats.Area] ./ ([stats.Perimeter].^2);
    for n=1:numel(Circularity)
        stats(n).Circularity = Circularity(n);
    end
    % Manually divide into two groups
    cellObjects = [stats.Area]>400 & [stats.Circularity]>0.65;
    junkObjects = ~cellObjects;
    figure(8);
    set(gcf, 'Name', 'Junk Objects');
    showgallary(s,stats(junkObjects),'Circularity');
    figure(9);
    set(gcf, 'Name', 'Cell Objects');
    showgallary(s,stats(cellObjects),'Circularity');
end
%%
figure(10)
plot( ...
    [stats(junkObjects).Circularity], [stats(junkObjects).Area], 'rx', ...
    [stats(cellObjects).Circularity], [stats(cellObjects).Area], 'b+' ...
    );
xlabel('Circularity'); ylabel('Area'); 
legend('Junk','Cells');

% Save data for later
save('example2.mat','stats', 'cellObjects', 'junkObjects', 's');

%%
filename = 'background.tif';
b8 = imread(filename);

% Convert to double on [0,1]
b = im2double(b8);
% Get the cell object indices
objectIndices = find(cellObjects);
for k = 1:length(objectIndices)

 % Get the linear indices into the image (background) object k
 idx = stats(k).PixelIdxList;

 OD = -log(s(idx)./b(idx));
 IOD(k) = sum(OD);

end
% Plot a histogram
figure(11), hist(IOD)

%%
%CV 
%%
toc