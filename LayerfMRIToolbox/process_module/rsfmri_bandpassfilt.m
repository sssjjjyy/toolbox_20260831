function output_img=rsfmri_bandpassfilt(input_img_path,TR,order,low_cutoff,high_cutoff,brainmask)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% test code:
% load ampoutput1.mat
% Fs=1/TR;
% NFFT = length(y);
%[P,F] = periodogram(y,[],NFFT,Fs,'power');
% helperFrequencyAnalysisPlot2(F,10*log10(P),'Frequency in Hz','Power spectrum (dBW)',[],[],[-0.5 100])
% y=ratrsfmri_bandpassfilt(y,1/3600,4,20,80);
% [P,F] = periodogram(y,[],NFFT,Fs,'power');
% helperFrequencyAnalysisPlot2(F,10*log10(P),'Frequency in Hz','Power spectrum (dBW)',[],[],[-0.5 100])
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
output_img=zeros(size(input_img_path));
NyqF=(1/TR)/2;
Wn=[low_cutoff high_cutoff]/NyqF;
[bfilter, afilter] = butter(order/2, Wn,'bandpass');
brain_index=find(brainmask>0);
[x,y,z]=ind2sub(size(brainmask),brain_index);
for n=1:length(brain_index)
    output_img(x(n),y(n),z(n),:)=filtfilt(bfilter, afilter, squeeze(input_img_path(x(n),y(n),z(n),:)));
end
end