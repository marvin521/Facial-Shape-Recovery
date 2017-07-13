function [f_lower, f_middle, f_upper] = T1fuzzifyPixel(y_us,z)
%%T1fuzzifyPixel generates the FOU for a single pixel of all images
% y_us = squeeze(Img(i,j,:)); %y_UnSmooth
% z = squeeze(freq(i,j,:));

x = (0:1:255)';
freq_normal = z/max(z);
freq_normal = smooth(freq_normal);
cla reset;

%% Step-1: Histogram Smoothing and Polynomial Fitting 
% Smoothen y
y = smooth(y_us);


F = fit(x,freq_normal,'smoothingspline');
figure;
title('Polynomial Fit for Lower/Upper Data points');
h = plot(F,x,freq_normal);
hold on;
X = h(2).XData;   % x-coordinates of the data points of the polynomial (1x1251)
Y = h(2).YData;   % y-coordinates of the data points of the polynomial (1x1251)
H_xcoord = x;      % x = [0 1 ... 255]
H_ycoord = F(x);   % the y values of the polynomial corresponding to x

%% Step-2: Find Prominent Peaks
% Find the location (& other parameters) of prominent peaks (lcs) and valleys
% using polyFit constraining the min peak prominence and min peak width
% parameters MP: Change the distance and width parameters if required

% Find peaks
[pks_max, lcs_max, w_max, p_max] = findpeaks(y_coord,x_coord,...
                              'MinPeakProminence',0.2, 'MinPeakWidth', 10);
peaks_max = cell(1,4);
signal = 1;
%FOR UNIMODAL:
[~, ind] = max(pks_max);
pks_max = pks_max(ind); lcs_max = lcs_max(ind);

% If no peaks and/or valleys have been found, it means the max/min of the
% polynomial occurs at the end points
if(~numel(pks_max))
    signal = 0;
    if(y_coord(1) > y_coord(end))
        pks_max = y_coord(1);
        lcs_max = x_coord(1);
    else
        pks_max = y_coord(end);
        lcs_max = x_coord(end);
    end
end

peaks_max{1} = pks_max; peaks_max{2} = lcs_max; 
peaks_max{3} = w_max; peaks_max{4} = p_max;
                                          
% Find valleys                                            
[pks_min, lcs_min, w_min, p_min] = findpeaks(-y_coord,x_coord,...
                              'MinPeakProminence',0.2, 'MinPeakWidth', 10);
                          
if(~numel(pks_min))
    signal = 0;
    if(-y_coord(1) > -y_coord(end))
        pks_min = -y_coord(1);
        lcs_min = x_coord(1);
    else
        pks_min = -y_coord(end);
        lcs_min = x_coord(end);
    end
end
                                                    
peaks_min = cell(1,4);
peaks_min{1} = pks_min; peaks_min{2} = lcs_min; 
peaks_min{3} = w_min; peaks_min{4} = p_min;



% Plot the peaks & valleys
plot(lcs_max,pks_max,'ro',lcs_min,-pks_min,'bx');
legend('Histogram','Polynomial Fit', 'Maxima','Minima');
%hold off;
%lim = max(abs(min(x_coord)), abs(max(x_coord)));
%xlim([-lim-1 lim+1]); ylim([min(y_coord)-10 max(y_coord)+10]);


%% Step-3: Initialize Gaussians
% Initialize the height, width and mean of the symmetric Gaussians

try
    if(signal)
        %f = fitData_improved(x,freq_normal,peaks_max,peaks_min);
        %f = fitData_improved(x_coord', y_coord', peaks_max, peaks_min);
        %f = histfit(y);   %% FCUK!!!!!
        f = fitData_improved(H_xcoord,H_ycoord',peaks_max,peaks_min);
    else
        %f = fit(x,z,'gauss1');
        %f = fit(x_coord', y_coord','gauss1');
        %f = histfit(y);
        f = fitData_improved(H_xcoord,H_ycoord','gauss1');
    end
catch
    [~, mini] = min(x_coord); [~, maxi] = max(x_coord);
    avg = mean([mini, maxi]);
    first = uint8(mean([mini,avg])) ;
    last = uint8(mean(avg,maxi)); 
    f = fit(x_coord(first:last)', y_coord(first:last)','gauss1');
end
[a, b, c] = assignValues(f,numel(lcs_max));
initial_params = [a; b; c];
%fprintf('Initial Cost = %d',computeCost(initial_params, x_coord, y_coord));
%fprintf('Initial Cost = %d',computeCost(initial_params, x, freq_normal));

% plot the initial fitting curve f on the data
 %plotFit(f,x_coord',y_coord'); 
 %plotFit(f,x,freq_normal);
plot(f,'y');
title('Initial Gaussian Fit');

% define legend
legend('Original Curve', 'Data Points', 'Initial Gaussian Fit');
hold off;

%% Step-4: Find Best Fit
% Use an optimisation algorithm to find the best Gaussian fit to the data.

% Try Gradient Descent
%{
[f, J_history] = gradientDescent(x_coord,y_coord, f, numel(lcs_max));
plotFit(f,x_coord',y_coord');
J_history;
plot(J_history);
%}

% Try fminsearch
options = optimset('LargeScale', 'on', 'GradObj', 'on', 'MaxFunEvals', ...
                    10000,'TolFun',1e-30, 'TolX',1e-30, 'MaxIter', 10000);
%[opt_params, cost, exitflag, output] = fminsearch(@(params)(computeCost(params, x_coord, y_coord)), ...
%                                                initial_params, options);
%[opt_params, cost, exitflag, output] = fminsearch(@(params)(computeCost(params, x, freq_normal)), ...
%                                                initial_params, options);
[opt_params, cost, exitflag, output] =  fminsearch(@(params)(computeCost(params, H_xcoord, H_ycoord)), ...
                                                initial_params, options);



f = assignParams(f,opt_params);

%plotFit(f,x_coord',y_coord'); 
%plotFit(f,x,freq_normal);
plotFit(f,x,freq_normal);
title('Best Gaussian Fit');
legend('Original Curve', 'Data Points', 'Best Gaussian Fit');
%ylim([min(y_coord)-0.2 max(y_coord) + 0.2]);

fprintf('Min Cost = %d\nExit Status:%d\n\n', cost, exitflag);

fprintf('Program paused. Press enter to continue\n\n');
pause;
close all;


%{
%% Step-5: Extract upper and lower data and construct their Gaussians

% UPPER AND LOWER GAUSSIANS USING HISTOGRAM DATA
freq_actual = H_ycoord;
freq_predicted = f(x);
% Indices where raw data </> predicted value (from the Gaussian fit)
lower_ind = find(freq_actual<freq_predicted);
upper_ind = find(freq_actual>freq_predicted);

% lower_ind is the set of indices of histogram values (from 1 to 256) where the
% actual frequency of pixel intensities is less than their predicted
% values. Similarly, we have upper_ind

% Define upper and lower data using these indices
x_lower = x(lower_ind);           % Pixel intensities whose actual frequencies are less than their predicted values
z_lower = H_ycoord(lower_ind); % Actual frequencies corresponding to them
[f_lower, status_lower] = T1fuzzifyPixel_child(x_lower,z_lower); % Repeat the fuzzifcation process for the lower data

% if no lower data
if(~status_lower)
    f_lower = f;
end


x_upper =  x(upper_ind);          % Pixel intensities whose actual frequencies are more than their predicted values
z_upper = H_ycoord(upper_ind); % Actual frequencies corresponding to them
[f_upper, status_upper] = T1fuzzifyPixel_child(x_upper,z_upper); % Repeat the fuzzifcation process for the upper data


% if no upper data
if(~status_upper)
    f_upper = f;
end
f_middle = f;

% UPPER AND LOWER GAUSSIANS USING POLYNOMIAL DATA
%{
lower_ind = find(y_coord'<f(x_coord));
upper_ind = find(y_coord'>f(x_coord));
x_lower = x_coord(lower_ind); y_lower = y_coord(lower_ind);
x_upper = x_coord(upper_ind); y_upper = y_coord(upper_ind);
% Find best fits to the upper and lower data
f_lower = fuzzifyPixel_child(x_lower, y_lower);
f_upper = fuzzifyPixel_child(x_upper, y_upper);
%}


%{
% UPPER AND LOWER GAUSSIANS USING ORIGINAL DATA
freq_actual = freq_normal;
freq_predicted = f(x);
% Indices where raw data </> predicted value (from the Gaussian fit)
lower_ind = find(freq_actual<freq_predicted);
upper_ind = find(freq_actual>freq_predicted);

% lower_ind is the set of indices of freq(i,j,:) (from 1 to 256) where the
% actual frequency of pixel intensities is less than their predicted
% values. Similarly, we have upper_ind

% Define upper and lower data using these indices
x_lower = x(lower_ind);           % Pixel intensities whose actual frequencies are less than their predicted values
z_lower = freq_normal(lower_ind); % Actual frequencies corresponding to them
[f_lower, status_lower] = T1fuzzifyPixel_child(x_lower,z_lower); % Repeat the fuzzifcation process for the lower data

% if no lower data
if(~status_lower)
    f_lower = f;
end


x_upper =  x(upper_ind);          % Pixel intensities whose actual frequencies are more than their predicted values
z_upper = freq_normal(upper_ind); % Actual frequencies corresponding to them
[f_upper, status_upper] = T1fuzzifyPixel_child(x_upper,z_upper); % Repeat the fuzzifcation process for the upper data


% if no upper data
if(~status_upper)
    f_upper = f;
end
f_middle = f;
%}

% Plot the results
figure;

%plot(x,freq_normal,'r');            % ORIGINAL DATA OPTION
hold on;
 plot(x,H_ycoord,                                    % HISTOGRAM OPTION
    %plot(x_lower,z_lower,'c');
    %plot(x_upper,z_upper,'k');
plot(f_middle,'m');
plot(f_lower,'g');
plot(f_upper,'b');

xlabel('Pixel Intensities');
ylabel('Normalised Frequency');
legend('Complete Original Curve', 'Lower Gaussian','Upper Gaussian');
% 'Middle Gaussian', 'Lower Data', 'Upper Data', 
%hold off;

%}
