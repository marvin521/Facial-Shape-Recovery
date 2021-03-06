function [f_lower, f_middle, f_upper] = T1fuzzifyPixel_ori(y_us,z)
%%T1fuzzifyPixel_ri generates the FOU for a single pixel of all images by
%%gaussian fitting to the original data

x = (0:1:255)';
freq_normal = z/max(z);
freq_normal = smooth(freq_normal);
cla reset;

%% Step-1: Histogram Smoothing and Polynomial Fitting 
% Smoothen y
y = smooth(y_us);

% polyFit is the polynomial fitted to the histogram of the data
% h is the handle to the smoothened histogram
% centers contains the x-coordinates of the centers of the bins of the
% histogram
polyFit  = hist_smoothen_ori(y);

% Remove duplicates
x_coord = polyFit(1,:);  
y_coord = polyFit(2,:);
[~, ind] = unique(x_coord); 
clear polyFit;
polyFit(1,:) = x_coord(ind);  
polyFit(2,:) = y_coord(ind);
x_coord = polyFit(1,:);  
y_coord = polyFit(2,:);


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
hold off;
%lim = max(abs(min(x_coord)), abs(max(x_coord)));
%xlim([-lim-1 lim+1]); ylim([min(y_coord)-10 max(y_coord)+10]);


%% Step-3: Initialize Gaussians
% Initialize the height, width and mean of the symmetric Gaussians

try
    if(signal)
        f = fitData_improved(x,freq_normal,peaks_max,peaks_min);
    else
        f = fit(x,freq_normal,'gauss1');
    end
catch
    try
        [~, mini] = min(x_coord); [~, maxi] = max(x_coord);
        avg = mean([mini, maxi]);
        first = uint8(mean([mini,avg])) ;
        last = uint8(mean(avg,maxi));
        f = fit(x_coord(first:last)', y_coord(first:last)','gauss1');
    catch
        load('default.mat');
        f = f1071;
    end
end
[a, b, c] = assignValues(f,numel(lcs_max));
initial_params = [a; b; c];
fprintf('Initial Cost = %d',computeCost(initial_params, x, freq_normal));

% plot the initial fitting curve f on the data
plotFit(f,x,freq_normal);
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
thresh = 10^(-10);
threshold = ones(256,1) * thresh;


% Try fminsearch
options = optimset('LargeScale', 'on', 'GradObj', 'on', 'MaxFunEvals', ...
                    20000,'TolFun',1e-30, 'TolX',1e-30, 'MaxIter', 10000);

[opt_params, cost, exitflag] = fminsearch(@(params)(computeCost(params, x, freq_normal)), ...
                                                initial_params, options);
% Construct the best fit using the optimal parameters
f = assignParams(f,opt_params);

if(norm(f(x)) < norm(threshold))
    load('default.mat');
    f = f1071;
    initial_params = [f.a1; f.b1; f.c1];
    [opt_params, cost, exitflag] = fminsearch(@(params)(computeCost(params, x, freq_normal)),initial_params, options);
    f = assignParams(f,opt_params);
    %{
    while(norm(f(x)) < norm(threshold))
    [opt_params, cost, exitflag] = fminsearch(@(params)(computeCost(params, x, freq_normal)),initial_params, options);
    f = assignParams(f,opt_params);
    end
    %}
end
% Plot the best fit
plotFit(f,x,freq_normal);
title('Best Gaussian Fit');
legend('Original Curve', 'Data Points', 'Best Gaussian Fit');
%ylim([min(y_coord)-0.2 max(y_coord) + 0.2]);

fprintf('Min Cost = %d\nExit Status:%d\n\n', cost, exitflag);

fprintf('Program paused. Press enter to continue\n\n');
%pause;
close all;

f_middle = f;

%% Step-5: Extract upper and lower data and construct their Gaussians

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
fprintf('Lower Data\n');
[f_lower, status_lower] = T1fuzzifyPixel_child(x_lower,z_lower,f); % Repeat the fuzzifcation process for the lower data

% if no lower data
if(~status_lower)
    f_lower = f;
end


x_upper =  x(upper_ind);          % Pixel intensities whose actual frequencies are more than their predicted values
z_upper = freq_normal(upper_ind); % Actual frequencies corresponding to them
fprintf('Upper Data\n');
[f_upper, status_upper] = T1fuzzifyPixel_child(x_upper,z_upper,f); % Repeat the fuzzifcation process for the upper data


% if no upper data
if(~status_upper)
    f_upper = f;
end

% Plot the results
figure;

plot(x,freq_normal,'r');            % ORIGINAL DATA OPTION
hold on;
%plot(f_middle,'m');
plot(f_lower,'g');
plot(f_upper,'b');

xlabel('Pixel Intensities');
ylabel('Normalised Frequency');
legend('Complete Original Curve', 'Lower Gaussian','Upper Gaussian');
% 'Middle Gaussian',
hold off;

%pause;


