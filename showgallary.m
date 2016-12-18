function showgallary(s, stats, propname)

% display a gallary of cells
% Argument propname is optional. If supplied it displays the value of that
% propery with each image object, otherwisem, the object numebr is
% displayed
ignore = 0;

if(~isfield(stats,'PixelList'))
    error('stats stuct must have a PixelList field.');
end


% Build array of objects and masks
N = length(stats);
objectImage = cell(N,1);
objectMask = cell(N,1);
strLabels = cell(N,1);

for n = 1:N
    
    r = stats(n).PixelList(:,2);
    c = stats(n).PixelList(:,1);
    
    rows = min(r):max(r);
    cols = min(c):max(c);
    
    % Pull out objest
    objectImage{n} = s(rows,cols);

    % Build the mask
    mask = zeros(size(objectImage{n}));
    index = sub2ind(size(mask), r-rows(1)+1, c-cols(1)+1);
    mask(index) = true;
    objectMask{n} = mask;

    % Make lables for each object
    if(nargin<3)
        strLabels{n} = num2str(n);
    else
        strLabels{n} = sprintf('%f', stats(n).(propname));
    end
    
end

% Build 4D array of RGB images
[nrows, ncols] = cellfun(@size, objectImage);
maxsize = max([nrows ncols]);

if numel(maxsize)>1
    imageGallary = zeros(maxsize(1), maxsize(2), 3, N);
else 
    ignore = 1;
    mess = sprintf('Skipped in show gallary!')
    disp(mess)
    
end

if ~ignore
    for n = 1:N

        padsize = maxsize - size(objectImage{n});
        paddedImage = padarray(objectImage{n}, padsize, 0, 'post');
        paddedMask = padarray(objectMask{n}, padsize, 0, 'post');

        %imageGallary(:,:,:,n) = cat(3, paddedImage, paddedImage, paddedImage);
        %imageGallary(:,:,:,n) = cat(3, paddedMask, paddedMask, paddedMask);
        imageGallary(:,:,:,n) = cat(3, paddedImage+bwperim(paddedMask), paddedImage, paddedImage);

    end
end

% Show the gallary
%h=montage(imageGallary);

% Add the text labels
%set(gca, 'Units', 'pixels');
%x = mod((0:N-1)*maxsize(2),size(h.CData,2)) + 0.95*maxsize(2);
%y = maxsize(1)*floor((0:N-1)*maxsize(2)/size(h.CData,2)) + 0.95*maxsize(1);
%text(x,y, strLabels,'color','red', 'HorizontalAlignment','right','VerticalAlignment','bottom');

% Make it re-sizeable again
%set(gca, 'Units', 'normalized', 'Position', [0 0 1 1]);

end

