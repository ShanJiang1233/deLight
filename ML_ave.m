clear all
clc

spectrum_range = [400, 900];        % unit: nm, use [0,0] if need the entire spectrum
% color = 'red';                      % Switch between 'red', 'yellow', 'green', 'blue' and 'cyan'
% switch color
%     case 'red'
%         max_range = [645, 655];             % unit: nm, specify the spectrum range for max value for normalization
%         min_range = [400, 450];             % unit: nm, specify the spectrum range for min value for normalization
%     case 'yellow'
%         max_range = [570, 580];             % unit: nm, specify the spectrum range for max value for normalization
%         min_range = [750, 800];             % unit: nm, specify the spectrum range for min value for normalization
%     case 'green'
%         max_range = [530, 540];             % unit: nm, specify the spectrum range for max value for normalization
%         min_range = [750, 850];             % unit: nm, specify the spectrum range for min value for normalization
%     case 'blue'
%         max_range = [465, 475];             % unit: nm, specify the spectrum range for max value for normalization
%         min_range = [700, 800];             % unit: nm, specify the spectrum range for min value for normalization
%     case 'cyan'
%         max_range = [482, 492];             % unit: nm, specify the spectrum range for max value for normalization
%         min_range = [700, 800];             % unit: nm, specify the spectrum range for min value for normalization
% end

[file,path] = uigetfile('*.*', 'Select the ML trace File');
cd(path)
data = readmatrix (file); 
data = data(:,3:end)';
wavelength = data (:,1);
signal = data (:,2:end);
ave = mean(signal);
figure;plot(ave)

baseline = mean(signal(:,end-5:end)')';

prompt_NoP = 'Number of peaks? ';
NoP = input(prompt_NoP);

for ii = 1:1:NoP
%     prompt_baseline = 'Frame index for the baseline: ';
%     baseline_ind = input(prompt_baseline);
    prompt_ML = 'Frame index for the ML: ';
    ML_ind = input(prompt_ML);
    ML_corrected(:,ii) = signal(:,ML_ind) - baseline;
%     ML_corrected (:,ii) = signal(:,ML_ind) - signal(:,baseline_ind);
end

if spectrum_range == [0,0]
    spec_start = 1;
    spec_end = length(wavelength);
else
    [uesless, spec_start] = min(abs(wavelength-spectrum_range(1)));
    [uesless, spec_end] = min(abs(wavelength-spectrum_range(2)));
end

confined_spectrum = ML_corrected(spec_start:spec_end,:);
confined_wavelength = wavelength (spec_start:spec_end,1);
sum_spectrum = sum(confined_spectrum,2);
ave_spectrum = sum_spectrum./NoP;
figure; plot(confined_wavelength, confined_spectrum)
if NoP ~= 1
    figure; plot(confined_wavelength, ave_spectrum)
end
% nor_spectrum = zeros(spec_end-spec_start+1, NoP);
% [useless, max_initial] = min(abs(confined_wavelength-max_range(1)));
% [useless, max_final] = min(abs(confined_wavelength-max_range(2)));
% [useless, min_initial] = min(abs(confined_wavelength-min_range(1)));
% [useless, min_final] = min(abs(confined_wavelength-min_range(2)));
% 
% for jj = 1:1:NoP
%     max_intensity = mean (confined_spectrum(max_initial:max_final,jj));
%     min_intensity = mean (confined_spectrum(min_initial:min_final,jj));
% %     nor_spectrum(:,jj) = (confined_spectrum(:,jj) - min(confined_spectrum(:,jj)))./(max(confined_spectrum(:,jj))-min(confined_spectrum(:,jj)));
%     nor_spectrum(:,jj) = (confined_spectrum(:,jj) - min_intensity)./(max_intensity-min_intensity);
% end
% 
% ave_nor_spectrum = mean(nor_spectrum,2);
% 
% figure
% plot (confined_wavelength, ave_nor_spectrum)
