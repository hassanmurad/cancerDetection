%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ENSC 460: Cancer Imaging - 2nd Method Accounting Backlash
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
movement = 'LTR';           %start with left to right 
zMovement = 'TTB';          %stat with top to bottom
x_delta = 334;
xOverlap = 0.8;
x_overlapDelta = round(xOverlap*x_delta);

y_delta = 267;
yOverlap = 0.8;
y_overlapDelta = round(yOverlap*y_delta);

rows = 40;% y; 90;
columns = 40;%x; 140;

p = [stage.PositionX stage.PositionY stage.PositionZ]; % initial position
M = 5;                     % Number of images above/below focus
N = 2*M+1;                  % Total number of images
z_delta = 150;              % Distance between images [steps] conversion 40.11 steps/um
z_offset = z_delta*(-M:M)'; % Vector of offsets to acquire at [steps]


%% Set Video settings
src = getselectedsource(vidobj);
src.ExposureTime = 10;
preview(vidobj);
p = [startPosition]; % initial position
stage.MoveAbsolute(p);
%% All the way up
p = p - [0, 0, M*z_delta];
stage.MoveAbsolute(p);

%% Grabing pictures
tic
for row = 1:2%rows
    
    for column = 1%:columns
        
        pause(0.2)
        % Take image
        s = getsnapshot(vidobj);
        
        % find best focused picture and tell which style to move
        findFocus(stage, vidobj, zMovement, row, column);
        pause(0.2);
            
        % Move the stage left to right
        if strcmp(movement, 'LTR')
            stage.MoveRelative([-x_overlapDelta, 0, 0]);
        % Move the stage right to left
        elseif strcmp(movement, 'RTL')
            stage.MoveRelative([x_overlapDelta, 0, 0]);
        end
        
        % Display a status message
        mess = sprintf('Current Position %s %d, %d', movement, row, column);
        disp(mess);
        
        %set zMovement state to TTB or BTT
        if strcmp(zMovement, 'TTB')
            zMovement = 'BTT';
        elseif strcmp(zMovement, 'BTT')
            zMovement = 'TTB';
        end
    end
    
    %when we reach the end of a column
    
    %move down y-axis (backlash doesn't matter since we're always moving
    %down
    
    %set movement state to LTR or RTL
    if strcmp(movement, 'LTR')
        movement = 'RTL';
    elseif strcmp(movement, 'RTL')
        movement = 'LTR';
    end
    
    stage.MoveRelative([0, -y_overlapDelta,0]);
end
toc
%% Image Processing 
tic
imgPath = './pictures/';
imgType = '*.tif'; % change based on image type
images  = dir([imgPath imgType]);
megaCellWithSolidity = {};
for k = 1:numel(images)
    filename = sprintf('./pictures/%s', images(k).name);
    megaCellWithSolidity{k} = imageProcessing(filename);
    disp(filename)
end
toc

%% IOD and Other info
megaIOD = []; 
junk = [];
for i = 1:1600%numel(images)
    for j = 1:length(megaCell{i})
        if (size(megaCell{i}{j},2) > 1)
            iod(j) = megaCell{i}{j}{3};
            %iod(2, j) = megaCell{i}{j}{2}; 
            %iod(3,j) = megaCell{i}{j}{4};
        else
           disp('empty cell') 
           junk = cat(1, junk, i);
        end
    end
    megaIOD = cat(2, megaIOD, iod(1,:));
end
ultimateIOD=[];
figure(18), h = histogram(megaIOD, 5000); xlim([0 5000])
for i=1:length(megaIOD)
    if ((megaIOD(i) < 550) && (megaIOD(i) > 350))
        ultimateIOD = [ultimateIOD megaIOD(i)];
    end
end

tetraploid =[];
for i=1:length(megaIOD)
    if ((megaIOD(i) < 1075) && (megaIOD(i) > 850))
        tetraploid = [tetraploid megaIOD(i)];
    end
end

tetraCV = std(tetraploid)/mean(tetraploid);

figure(19),histogram(ultimateIOD, 100)
newmeanIOD = megaIOD./mean(ultimateIOD);
meanIOD = mean(ultimateIOD);
stdIOD = std(ultimateIOD);
CV = stdIOD/meanIOD

figure(17), histogram(newmeanIOD.*2, 10000), xlim([0 6])

cancerous =[];
for i=1:length(newmeanIOD)
    if ((newmeanIOD(i) > 5))
        cancerous = [cancerous newmeanIOD(i)];
    end
end
length(cancerous)
length(megaIOD)

%%

%% IOD and Other info
megaIOD = []; 
junk = [];
for i = 1:1600%numel(images)
    for j = 1:length(megaCellWithSolidity{i})
        if (size(megaCellWithSolidity{i}{j},2) > 1)
            iod(j) = megaCellWithSolidity{i}{j}{3};
            %iod(2, j) = megaCell{i}{j}{2}; 
            %iod(3,j) = megaCell{i}{j}{4};
        else
           disp('empty cell') 
           junk = cat(1, junk, i);
        end
    end
    megaIOD = cat(2, megaIOD, iod(1,:));
end
ultimateIOD=[];
figure(14), h = histogram(megaIOD, 5000); xlim([0 5000])
for i=1:length(megaIOD)
    if ((megaIOD(i) < 550) && (megaIOD(i) > 350))
        ultimateIOD = [ultimateIOD megaIOD(i)];
    end
end

tetraploid =[];
for i=1:length(megaIOD)
    if ((megaIOD(i) < 1075) && (megaIOD(i) > 850))
        tetraploid = [tetraploid megaIOD(i)];
    end
end

tetraCV = std(tetraploid)/mean(tetraploid);

figure(15),histogram(ultimateIOD, 100)
newmeanIOD = megaIOD./mean(ultimateIOD);
meanIOD = mean(ultimateIOD);
stdIOD = std(ultimateIOD);
CV = stdIOD/meanIOD

figure(16), histogram(newmeanIOD.*2, 10000), xlim([0 6])

cancerous =[];
for i=1:length(newmeanIOD)
    if ((newmeanIOD(i) > 5))
        cancerous = [cancerous newmeanIOD(i)];
    end
end
length(cancerous)
length(megaIOD)


%% Clean up
delete(vidobj);
delete(stage);