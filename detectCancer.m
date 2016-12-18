%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ENSC 460: Cancer Imaging
% 
% Hassan Murad, Amir Hadjifaradji, Farbod Faridi
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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

%%
startPosition = [stage.PositionX stage.PositionY stage.PositionZ]
%startPosition = [28581 19634 485616]
% 28581       19634      485616
% Entire x axis 38635 -> 144 steps
% Entire y axis 20093 -> 94 steps
%% Define the focus positions for image acquisition
M = 10;     % Number of images above/below focus
N = 2*M+1;  % Total number of images
z_delta = 150; % Distance between images [steps] conversion 40.11 steps/um
z_offset = z_delta*(-M:M)'; % Vector of offsets to acquire at [steps]

x_delta = 334;
xOverlap = 0.8;
x_overlapDelta = round(xOverlap*x_delta);

y_delta = 267;
yOverlap = 0.8;
y_overlapDelta = round(yOverlap*y_delta);

rows = 50;% y; 90;
columns = 100;%x; 140;

%% Save the starting position
src = getselectedsource(vidobj);
src.ExposureTime = 10;
preview(vidobj);
p = [startPosition]; % initial position
stage.MoveAbsolute(p);
%% All the way up
p = p - [0, 0, M*z_delta];
stage.MoveAbsolute(p);
%% Acquire images from top to bottom
for n=1:N
    
    % Absolute move to the next offset
    if (n > 1) %don't move for top position
        p = p + [0 0 z_delta];
        stage.MoveAbsolute(p);
    end
    
    % Wait to stabilize
    pause(0.5)
    
    % Grab a frame and save to disk for easy reviewing later
    s = getsnapshot(vidobj);
    filename = sprintf('C:\\Users\\ahadjifa\\Desktop\\project\\pictures\\ImageFromTop%d.tif', n);
    imwrite(s, filename);
    
    %Focus analysis - calculate focus metrics
    img = im2double(s);
    [r,c] = size(s);
    Fmaxmin(1,n) = max(img(:)) - min(img(:));
    Fmodemin(1, n) = mode(img(:)) - min(img(:));
    Fvar(1,n) = calcFvar(img, r, c);
    Fbrenner(1,n) = calcFbrenner(img, r, c);
    
    mess = sprintf('Going from Top to Bottom: %d', n);
    disp(mess);
    
end
%% Acquire images from bottom to top
for n=N:-1:1
    
    % Absolute move to the next offset
    if (n < size(z_offset,1)) %don't move for bottom position
        p = p - [0 0 z_delta];
        stage.MoveAbsolute(p);
    end
    
    % Wait to stabilize
    pause(0.5)
    
    % Grab a frame and save to disk for easy reviewing later
    s = getsnapshot(vidobj);
    filename = sprintf('C:\\Users\\ahadjifa\\Desktop\\project\\pictures\\ImageFromBottom%d.tif', n);
    imwrite(s, filename);
    imageAnalysis(s)
    %Focus analysis - calculate focus metrics
    img = im2double(s);
    [r,c] = size(s);
    Fmaxmin(2,n) = max(img(:)) - min(img(:));
    Fmodemin(2, n) = mode(img(:)) - min(img(:));
    Fvar(2,n) = calcFvar(img, r, c);
    Fbrenner(2,n) = calcFbrenner(img, r, c);
    
    mess = sprintf('Going from Bottom to Top: %d', n);
    disp(mess);
end
%%
% Plot focus metric(s) versus offset
figure(1)
subplot(4,2,1); plot(z_offset, Fmaxmin(1,:)); title('Fmaxmin T->B')
subplot(4,2,2); plot(z_offset, Fmaxmin(2,:)); title('Fmaxmin B->T')

subplot(4,2,3); plot(z_offset, Fmodemin(1,:)); title('Fmodemin T->B')
subplot(4,2,4); plot(z_offset, Fmodemin(2,:)); title('Fmodemin B->T')

subplot(4,2,5); plot(z_offset, Fvar(1,:)); title('Fvar T->B')
subplot(4,2,6); plot(z_offset, Fvar(2,:)); title('Fvar B->T')

subplot(4,2,7); plot(z_offset, Fbrenner(1,:)); title('Fbrenner T->B')
subplot(4,2,8); plot(z_offset, Fbrenner(2,:)); title('Fbrenner B->T')

print(gcf, '-djpeg', 'subplotBacklash05um'); %saves subplot in current directory
backlashHysteresis = max(Fbrenner(2,:)) - max(Fbrenner(1,:))

%%
mappedT2BFocus = cat(2, z_offset, Fbrenner(1,:)');
[row1, col1] = find(mappedT2BFocus == max(mappedT2BFocus(:,2)));
focusT2B = z_offset(row1)
mappedB2TFocus = cat(2, z_offset, Fbrenner(2,:)');
[row2, col2] = find(mappedB2TFocus == max(mappedB2TFocus(:,2)));
focusB2T = z_offset(row2)
mean = (focusB2T + focusT2B) / 2

%% Grabing pictures

for row = 1:rows
    
    for column = 1:columns
        pause(0.2)
        % Take image
        s = getsnapshot(vidobj);
        hImage.CData = s;
        hHistogram.YData = imhist(s);
        drawnow; % process callbacks
        % Capture an image frame and save it to disk
        findFocus(stage, vidobj);
        s = getsnapshot(vidobj);
        filename = sprintf('C:\\Users\\ahadjifa\\Desktop\\project\\pictures\\ImageRow%dCol%d.tif', row, column);
        imwrite(s, filename);
        
        pause(0.2);  
        % Move the stage forward
        stage.MoveRelative([-x_overlapDelta, 0, 0]);
        % Display a status message
        mess = sprintf('Current Position %d, %d', row, column);
        disp(mess);

    end
    stage.MoveAbsolute([startPosition(1), startPosition(2)-y_overlapDelta*(row-1),startPosition(3)]);
    stage.MoveRelative([0, -y_overlapDelta, 0]);
end
%% Clean up
delete(vidobj);
delete(stage);