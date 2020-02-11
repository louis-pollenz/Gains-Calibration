clc
clear all

%addpath('E:\Synchropet\Gain Calibration Procedure\PETshop scripts')
input_folder='E:\Synchropet\Data\Ring 16\Ge68 DAC 100-10-500 HV=460 10-23-19 using script with 15sec pause and 30sec acqT\Iteration 2';

global DataSource
global DataStream
Cfg.Src.MACHINE_FORMAT = 'ieee-be';
Words2Read = 100e6;
DataStream = uint16(zeros(Words2Read,1));

%%
fn=dir([input_folder,'\*.evt']);

for k=1:length(fn)
        
    tic;
    curfilename=fullfile(fn(k).folder,fn(k).name);
    
    curfilesize = subsref(dir(curfilename), substruct('.','bytes'));
    Words2Read = ceil(curfilesize/2);
    fprintf('Processing %s with %d words: ', fn(k).name, Words2Read)
   
    [DataSource, msg] = fopen(curfilename,'r',Cfg.Src.MACHINE_FORMAT);
   
    DataLength = PETwin_acquisition('acquire_file',Words2Read,Cfg.Src.MACHINE_FORMAT);
    [easic, echan, etime, NumberEvents, DropRate, EventRate, Fidelity] = PETwin_extract_events(DataStream,DataLength);
    
%     sino = zeros(Cfg.bnl.sinolength,1);
%     PETwin_sinogram_calc(Cfg.sinomatrix.sinoindex,etime,easic,echan,int32(Cfg.coinc.in_time)',Cfg.device.timezero,sino);
        
    coinc_filename = [curfilename(1:end-4),'.coinc'];
    
    fclose(DataSource);
    
    dro(k) = DropRate;
    nevt(k) = NumberEvents;
    fid(k) = Fidelity;
    
    q=regexp(char(fn(k).name),'\s(\d\d\d)\.evt','tokens');
    dac(k) = str2num(char(q{1}));

%MATLAB replacement for C++: slow    
%     na = uint8(0);
%     nc = uint8(0);
%     for na=0:23
%         for nc=0:31
%             curevtrate = sum(easic==na & echan==nc);
%             era(na+1, nc+1, k) = curevtrate;
%         end
%         disp('.')
%     end
    
    era_temp=zeros(24*32,1);
    PETwin_individual_event_rates(easic,echan,era_temp);
    
    era(:,:,k) = reshape(era_temp,32,[]);
    
    
    fprintf(' done in %4.1f seconds\n',toc)

    
end

numdif=numel(dac)-1;
ne=shiftdim(era,2);
raw=ne;
%% Curve Fit
% Polyfit, interp1, fit
fitted=cell(32,24);
for k=1:24
    for m=1:32
        fitted{m,k}=fit(dac', ne(:,m,k), 'smoothingspline','SmoothingParam',.0001);
        ne(:,m,k)=fitted{m,k}(dac);
    end
end


%% Statistic Half 1

%Peak Offset 
peaks=zeros(32,12);
ind=zeros(32,12);
offset=zeros(32,12);
for k=1:24
    for L=1:32
        [peaks(L,k), ind(L,k)]=max(diff(ne(:,L,k)));
        offset(L,k)=dac(ind(L,k));
    end
end

Iteration=1;

save('E:\\Synchropet\\Data\\Ring 16\\Ge68 DAC 100-10-500 HV=460 10-23-19 using script with 15sec pause and 30sec acqT\\Iteration 2\Offset_Vector','offset')

save('Offset_Vector', 'offset')


