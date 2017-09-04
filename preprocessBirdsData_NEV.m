function [ppData, ppDataFile] = preprocessBirdsData_NEV(ptID,rawDataDir)
% PREPROCESSBIRDSDATA preprocesses data from the birds task.
% 	preprocesses both the unit and LFP data for the birds task, placing the
% 	data in tensors []
%
%	[preprocessedData, preprocessedDataFile] = preprocessBirdsData(ptID,rawDataDir) will preprocess
% 		the data for the patient specified in ptID.
%

% author:: EHS20170725

%dir stuff here.
dirList = dir([rawDataDir '/*.nev']);

cd(rawDataDir)
cd('..')
if ~exist('./processedData','dir')
    mkdir('processedData')
end

nNevFiles = length(dirList);
% loading data
for fl = 1:nNevFiles
    clear tmpLFP 
    %% loading and saving digital data
    display('loading digital Data...')
    NEV = openNEV(fullfile(rawDataDir,dirList(fl).name));
    
    % Saving choice variables.
    tmp(fl).timeSamps = NEV.Data.SerialDigitalIO.TimeStamp;
    tmp(fl).timeSecs = NEV.Data.SerialDigitalIO.TimeStampSec;
    tmp(fl).triggers = NEV.Data.SerialDigitalIO.UnparsedData';
    tmp(fl).durationSamps = NEV.MetaTags.DataDuration;
    tmp(fl).durationSecs = NEV.MetaTags.DataDurationSec;
    tmp(fl).Fs = double(NEV.Data.SerialDigitalIO.TimeStamp(end))./double(NEV.Data.SerialDigitalIO.TimeStampSec(end));
    
    
    %% saving event markers and unsorted unit data.
    if isequal(fl,1)
        % saving digital data.
        ppData.Event.trigTimes = tmp(fl).timeSamps;
        ppData.Event.trigs = tmp(fl).triggers;
        ppData.Comments = NEV.MetaTags.Comment;
        
        % saving unsorted unit data.
        display('saving multiunit data...')
        ppData.unsortedUnits.times = NEV.Data.Spikes.TimeStamp;
        ppData.unsortedUnits.electrodes = NEV.Data.Spikes.Electrode;
        ppData.unsortedUnits.waveforms = NEV.Data.Spikes.Waveform;
    else
        previousDataDurationSamps = sum([tmp(1:fl-1).durationSamps]);
        % concatenating event times.
        ppData.Event.trigTimes = [ppData.Event.trigTimes tmp(fl).timeSamps+previousDataDurationSamps];
        ppData.Event.trigs = cat(2,ppData.Event.trigs,tmp(fl).triggers);
        
        % saving sorted unit data.
        ppData.unsortedUnits.times = cat(2,ppData.unsortedUnits.times,NEV.Data.Spikes.TimeStamp+previousDataDurationSamps);
        ppData.unsortedUnits.electrodes = cat(2,ppData.unsortedUnits.electrodes,NEV.Data.Spikes.Electrode);
        ppData.unsortedUnits.waveforms = cat(2,ppData.unsortedUnits.waveforms,NEV.Data.Spikes.Waveform);
    end
    
    
    %% processing LFP data.
    if isequal(fl,1)
        % load analog data
        display('loading LFP Data...')
        [~,nevName,nevExt] = fileparts(dirList(fl).name);
        NS3 = openNSx(fullfile(rawDataDir,[nevName '.ns3'])); % could be more general in case of different sampling rates

		% saving data
        display('saving LFP data...')
        
        % in case of sampling rates > 2e3
        if isequal(NS3,-1)
            % loading and processing alternative LFP data.
            display('standard 2 kHz data was not found. Just trying 30 kHz data...')
			try
				NSX = openNSx(fullfile(rawDataDir,[nevName '.ns5'])); % could be more general in case of different Fs
            catch
				display('no 30 kHz data found. Looking for 1 kHz');
				NSX = openNSx(fullfile(rawDataDir,[nevName '.ns2'])); % could be more general in case of 
			end
	        if iscell(NS3.Data); NS3.Data = NS3.Data{end}; end
			Fs = NSX.MetaTags.SamplingFreq;
            nChans = size(NSX.Data,1);
            display(sprintf('data contains %d channels sampled at %d Hz.',nChans,Fs))
            display('Here are the channel labels:')
            {NSX.ElectrodesInfo.Label}
            display('^^^ These are the channel labels ^^^')
            % chansToSave = input(sprintf('Which of the %d channels would you like to downsample and save as LFP?',nChans));
     		chansToSave = 1:nChans;
	 		for ch = 1:nChans
                display(sprintf('downsampling LFP for channel %d of %d from %d to 2 kHz',ch,nChans,Fs))
                ppData.LFP.data(ch,:) = DownSampleLFP(NSX.Data(ch,:),Fs,2e3);
            end
            ppData.LFP.labels = {NSX.ElectrodesInfo.Label};
            ppData.LFP.labels = ppData.LFP.labels(chansToSave);
            ppData.LFP.sampleRate = 2e3; % could be more general in case of different sampling rates
            ppData.LFP.durationSamps = NSX.MetaTags.DataPoints/(Fs./2e3);
            ppData.LFP.durationSecs = NSX.MetaTags.DataDurationSec;
        else
	        if iscell(NS3.Data); NS3.Data = NS3.Data{2}; end	
            ppData.LFP.data = NS3.Data;
            ppData.LFP.labels = {NS3.ElectrodesInfo.Label};
            ppData.LFP.sampleRate = 2e3; % could be more general in case of different sampling rates
            ppData.LFP.durationSamps = NS3.MetaTags.DataPoints;
            ppData.LFP.durationSecs = NS3.MetaTags.DataDurationSec;
        end
    else
        % load analog data
        display('loading additional LFP Data...')
        [~,nevName,nevExt] = fileparts(dirList(fl).name);
        NS3 = openNSx(fullfile(rawDataDir,[nevName '.ns3'])); % could be more general in case of different sampling rates

        % saving data
        if isequal(NS3,-1)
            display('Since you mentioned there was not any 2 kHz data, please select the next appropriate LFP data file...')
           	try
				NSX = openNSx(fullfile(rawDataDir,[nevName '.ns5'])); % could be more general in case of different Fs
            catch
				display('no 30 kHz data found. Looking for 1 kHz');
				NSX = openNSx(fullfile(rawDataDir,[nevName '.ns2'])); % could be more general in case of 
			end
			if iscell(NSX.Data); NSX.Data = NSX.Data{end}; end
            for ch = 1:nChans
                display(sprintf('downsampling LFP for channel %d of %d from %d to 2 kHz',ch,nChans,Fs))
                tmpLFP(ch,:) = DownSampleLFP(NSX.Data(ch,:),Fs,2e3);
            end
            ppData.LFP.data = cat(2,ppData.LFP.data,tmpLFP);
            ppData.LFP.durationSamps = ppData.LFP.durationSamps+NSX.MetaTags.DataPoints/(Fs./2e3);
            ppData.LFP.durationSecs = ppData.LFP.durationSecs+NSX.MetaTags.DataDurationSec;
        else
  	        if iscell(NS3.Data); NS3.Data = NS3.Data{end}; end
 			display('concatenating additional LFP data...')
            ppData.LFP.data = cat(2,ppData.LFP.data,NS3.Data);
            ppData.LFP.durationSamps = ppData.LFP.durationSamps+NS3.MetaTags.DataPoints;
            ppData.LFP.durationSecs = ppData.LFP.durationSecs+NS3.MetaTags.DataDurationSec;
        end
    end
    
    
    %% finding sorted unit labels
	sortedUnits = 'n';
	if ~exist('sortedUnits','var')
		if isequal(fl,1)
			sortedUnits = input('have units been sorted for this patient? (y/n): ','s');
		end
	end
    if strcmp(sortedUnits,'y')
        display('saving single unit data...')
        if isequal(fl,1)
            % loading sorted unit data.
            [sortedFile, sortedPath, ~] = uigetfile({'*.nev', 'Pick the first sorted NEV file...'; '*.mat','...or a corresponding MAT file'});
            if strcmp(sortedFile(end-3:end),'.nev')
                sNEV = openNEV(fullfile(sortedPath,sortedFile));
            else
                load(fullfile(sortedPath,sortedFile))
                sNEV = NEV;
            end
            
            % saving sorted unit data
            ppData.sortedUnits.times = sNEV.Data.Spikes.TimeStamp;
            ppData.sortedUnits.electrodes = sNEV.Data.Spikes.Electrode;
            ppData.sortedUnits.unitNum = sNEV.Data.Spikes.Unit;
            ppData.sortedUnits.waveforms = sNEV.Data.Spikes.Waveform;
        else
            % loading sorted unit data.
            [sortedFile, sortedPath, ~] = uigetfile({'*.nev', 'Pick the next sorted NEV file...'; '*.mat','...or a corresponding MAT file'});
            if strcmp(sortedFile(end-3:end),'.nev')
                sNEV = openNEV(fullfile(sortedPath,sortedFile));
            else
                load(fullfile(sortedPath,sortedFile))
                sNEV = NEV;
            end
            
            % saving sorted unit data
            ppData.sortedUnits.times = cat(2,ppData.sortedUnits.times,sNEV.Data.Spikes.TimeStamp+tmp(fl-1).durationSamps);
            ppData.sortedUnits.electrodes = cat(2,ppData.sortedUnits.electrodes,sNEV.Data.Spikes.Electrode);
            ppData.sortedUnits.unitNum = cat(2,ppData.sortedUnits.unitNum,sNEV.Data.Spikes.Unit);
            ppData.sortedUnits.waveforms = cat(2,ppData.sortedUnits.waveforms,sNEV.Data.Spikes.Waveform);
        end
        sortedUnitsSuffix = '_withSortedUnits';
    else
        display('no sorted units, so you are all set!')
        sortedUnitsSuffix = '';
    end
end

%% applying notch filter or common-mode-removal to the LFP data.
% common-mode-removal
display('denoising using PCA...')
ppData.LFP.data = remove1stPC(double(ppData.LFP.data));
display('               ...done.')
% notch filtering.
display('denoising using 60 Hz notch...')
Wo = 60/(ppData.LFP.sampleRate/2);  BW = Wo/50;
[b,a] = iirnotch(Wo,BW);
%        freqz(b,a);
for c = 1:size(ppData.LFP.data,1)
    display(sprintf('applying notch filter to channel %d',c))
    ppData.LFP.data(c,:) = filtfilt(b,a,ppData.LFP.data(c,:));
%     ppData.LFP.data_commonModeRejected_andNotchFiltered(c,:) = filtfilt(b,a,ppData.LFP.data_commonModeRejected(c,:));
end
display('                       ...done.')


%% for high gamma and very downsampled data.
finalFs = 2e2;
[b,a] = butter(8,[70 150]./(2e3/2));
for cc = 1:size(ppData.LFP.data,1)
    display(sprintf('downsampling/filtering channel %d of %d.',cc,size(ppData.LFP.data,1)))
    tmpHG = hilbert(abs(filtfilt(b,a,double(ppData.LFP.data(cc,:)))));
    ppData.LFP.dsData(cc,:) = DownSampleLFP(double(ppData.LFP.data(cc,:)),2e3,finalFs);
    ppData.LFP.highGamma(cc,:) = DownSampleLFP(tmpHG,2e3,finalFs);
	clear tmpHG
end
ppData.LFP.sampleRate = finalFs;
ppData.LFP.durationSamps = size(ppData.LFP.dsData,2);


%% saving data
cd(rawDataDir)
cd('..')
cd('processedData')
ppDataFile = sprintf('%s_preprocessedData%s.mat',ptID,sortedUnitsSuffix);
display('saving...')
tic
save(ppDataFile,'ppData','-v7.3')
A = toc;
display(sprintf('saving took %d s',A))


end




