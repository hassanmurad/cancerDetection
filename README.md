# Cancer Detection Using Matlab

This repository includes code to analyze a cancer slide using an automated stage that was embedded onto a Nikon
microscope. We first the essentials of calibrating, tuning and characterizing the system – by
automating the procedure to find the best focus, adjust the system parameters until it was Kohler
illuminated as well as measure the backlash in the stage movement and etc. After tuning the system, we
began analyzing a matrix of 40x40 (x & y) and obtain 1600 well-focused images for image processing. In the
image processing, we used Matlab’s Image Processing Toolbox in order to filter and detect cell
characteristics – picking the best threshold using Otsu’s method, converting an image to grayscale, getting
rid of chopped off cells on the border, using morphological operations to filter out small specks, detecting
number of cells as well as their Area, Centroid, Circularity, Solidity, Eccentricity, Euler’s number and etc.
After obtaining these essential elements we apply our discriminant thresholds to classify cell objects vs. junk
objects after which a Ploidy analysis is conducted to determine the integrated optical density of a cell object.
After running these processes on the 1600 images, we developed a histogram of cells which showed two
major peaks of diploid and tetraploid cells (normal cells) and classified the 5c+ cells as abnormal (cancerous)
cells.


Regards,

# Hassan Murad
