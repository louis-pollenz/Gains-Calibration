%%
% gain generation
%%
%clear all, close all
% Target DAC - this is where we want to have all photopeaks
TDAC = 250;
% Linear coefficient of delta DAC divided by delta GAINS
dDacdGain = -30;
Iteration=3; %CHANGE TIME STAMP in RINGCALFILE
%addpath(sprintf('C:\\Users\\Alex\\Documents\\Data\\LIHTI\\Gain Calibration Wirst Ring 14 HV 430 DAC 100-10-500 AcqT 60s IntrAcq 30s\\Iteration_%g',Iteration-1))

%RingCalFile = sprintf('Iteration %g NewG to TDac 250.0 with dDdG 30.0 gen on 20190617T095032.mat',Iteration-1);
%RingResultsFile = sprintf('Offset_Vector_Iteration_%g.mat',Iteration-1);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%load(RingCalFile);
%load(RingResultsFile);

dac = offset(:); % make a vector from 2D array, make sure channels go in first dim
%clear offset

% gains as they were read from file
%gains = ring.g(:,4); 


%figure(1), plot(dac,'x')
gains = ring.g(1:384,4);
newgains = gains + (TDAC-dac)/dDacdGain;
newgains(find(newgains<0)) = 0;
newgains(find(newgains>31)) = 31;
ring.g(1:384,4)= round(newgains);
[min(ring.g(1:384,4)), max(ring.g(1:384,4))]

newcalfile = sprintf('Iteration %g NewG to TDac %4.1f with dDdG %4.1f gen on %s.mat', Iteration, TDAC, -dDacdGain, datestr(now,30));
%save(sprintf('C:\\Users\\Alex\\Documents\\Data\\LIHTI\\Gain Calibration Wirst Ring 14 HV 430 DAC 100-10-500 AcqT 60s IntrAcq 30s\\Iteration_%g\\%s',Iteration,newcalfile),'ring')
save(sprintf('E:\\Synchropet\\Data\\Ring 16\\Ge68 DAC 100-10-500 HV=460 10-23-19 using script with 15sec pause and 30sec acqT\\Iteration 1\\%s',newcalfile),'ring')

figure(1), 
sgtitle(sprintf('Wrist Ring 16 Iteration %g Gain Generation',Iteration))
subplot(211), plot(dac,'x'), grid
xlabel('Channel')
ylabel('DAC Photopeak Location')
subplot(212), plot(ring.g(:,4),'x'), grid
xlabel('Channel')
ylabel('New Gains')

figure(2)
error=abs(ring.g(1:384,4)-gains);
figure(2)
plot(error,'*')
%title('Gain Difference Between Iteration i and i-1')
xlabel('Channel')
ylabel('Absolute Gain Difference')

figure(3)
plot(ring.g(:,4),'x'), grid
xlabel('Channel')
ylabel('Gains')

