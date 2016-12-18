function findFocus(stage, vidobj, zMovement, row, col)
%findFocus finds the best focus and adjust the microscope to that focus
%   Finds the best focus scanning from top to bottom then bottom to top. 

p = [stage.PositionX stage.PositionY stage.PositionZ]; % initial position
M = 10;                     % Number of images above/below focus
N = 2*M+1;                  % Total number of images
z_delta = 100;              % Distance between images [steps] conversion 40.11 steps/um
z_offset = z_delta*(-M:M)'; % Vector of offsets to acquire at [steps]
picture = cell(N);
% All the way up
%p = p - [0, 0, M*z_delta ];
%stage.MoveAbsolute(p);

switch zMovement
    
    case 'TTB'
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
            picture{n,1} = s;
            %filename = sprintf('C:\\Users\\ahadjifa\\Desktop\\project\\pictures\\ImageFromTop%d.tif', n);
            %imwrite(s, filename);

            %Focus analysis - calculate focus metrics
            img = im2double(s);
            [r,c] = size(s);
%             Fmaxmin(1,n) = max(img(:)) - min(img(:));
%             Fmodemin(1, n) = mode(img(:)) - min(img(:));
%             Fvar(1,n) = calcFvar(img, r, c);
             Fbrenner(1,n) = calcFbrenner(img, r, c);

            mess = sprintf('Going from Top to Bottom: %d', n);
            disp(mess);

        end
        
   %Go from bottom to top
   case 'BTT' 
        % Acquire images from bottom to top
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
            %filename = sprintf('C:\\Users\\ahadjifa\\Desktop\\project\\pictures\\ImageFromBottom%d.tif', n);
            %imwrite(s, filename);
            %Focus analysis - calculate focus metrics
            img = im2double(s);
            picture{n,1} = s;
            [r,c] = size(s);
%             Fmaxmin(2,n) = max(img(:)) - min(img(:));
%             Fmodemin(2, n) = mode(img(:)) - min(img(:));
%             Fvar(2,n) = calcFvar(img, r, c);
             Fbrenner(2,n) = calcFbrenner(img, r, c);

            mess = sprintf('Going from Bottom to Top: %d', n);
            disp(mess);
        end
        
        
end


if strcmp(zMovement, 'TTB')
    mappedT2BFocus = cat(2, z_offset, Fbrenner(1,:)');
    [row1, col1] = find(mappedT2BFocus == max(mappedT2BFocus(:,2)));
    focusT2B = z_offset(row1);
    figure(1), plot(z_offset, Fbrenner(1,:)); title('Fbrenner T->B')
    image = picture{row1};
    filename = sprintf('C:\\Users\\ahadjifa\\Desktop\\project\\pictures\\%d,%d.tif', row, col);

    %imwrite(image, filename);
elseif strcmp(zMovement, 'BTT')
    mappedB2TFocus = cat(2, z_offset, Fbrenner(2,:)');
    [row2, col2] = find(mappedB2TFocus == max(mappedB2TFocus(:,2)));
    focusB2T = z_offset(row2);
    figure(2), plot(z_offset, Fbrenner(2,:)); title('Fbrenner B->T')
    image = picture{row2};
    filename = sprintf('C:\\Users\\ahadjifa\\Desktop\\project\\pictures\\%d,%d.tif', row, col);
    %imwrite(image, filename);
end    



% mean = (focusB2T + focusT2B) / 2
% z_movement = z_offset(21) - mean
% % moved to that position
% stage.MoveRelative([0, 0, z_movement]);
%     
% %Plot focus metric(s) versus offset
% figure(1)
% subplot(4,2,1); plot(z_offset, Fmaxmin(1,:)); title('Fmaxmin T->B')
% subplot(4,2,2); plot(z_offset, Fmaxmin(2,:)); title('Fmaxmin B->T')
% 
% subplot(4,2,3); plot(z_offset, Fmodemin(1,:)); title('Fmodemin T->B')
% subplot(4,2,4); plot(z_offset, Fmodemin(2,:)); title('Fmodemin B->T')
% 
% subplot(4,2,5); plot(z_offset, Fvar(1,:)); title('Fvar T->B')
% subplot(4,2,6); plot(z_offset, Fvar(2,:)); title('Fvar B->T')
% 
% subplot(4,2,7); plot(z_offset, Fbrenner(1,:)); title('Fbrenner T->B')
% subplot(4,2,8); plot(z_offset, Fbrenner(2,:)); title('Fbrenner B->T')

%print(gcf, '-djpeg', 'subplotBacklash05um'); %saves subplot in current directory
% backlashHysteresis = max(Fbrenner(2,:)) - max(Fbrenner(1,:))
     
end

