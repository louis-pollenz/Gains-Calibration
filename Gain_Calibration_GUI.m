function varargout = Gain_Calibration_GUI(varargin)
% GAIN_CALIBRATION_GUI MATLAB code for Gain_Calibration_GUI.fig
%      GAIN_CALIBRATION_GUI, by itself, creates a new GAIN_CALIBRATION_GUI or raises the existing
%      singleton*.
%
%      H = GAIN_CALIBRATION_GUI returns the handle to a new GAIN_CALIBRATION_GUI or the handle to
%      the existing singleton*.
%
%      GAIN_CALIBRATION_GUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in GAIN_CALIBRATION_GUI.M with the given input arguments.
%
%      GAIN_CALIBRATION_GUI('Property','Value',...) creates a new GAIN_CALIBRATION_GUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before Gain_Calibration_GUI_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to Gain_Calibration_GUI_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help Gain_Calibration_GUI

% Last Modified by GUIDE v2.5 31-Oct-2019 15:14:22

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @Gain_Calibration_GUI_OpeningFcn, ...
                   'gui_OutputFcn',  @Gain_Calibration_GUI_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before Gain_Calibration_GUI is made visible.
function Gain_Calibration_GUI_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to Gain_Calibration_GUI (see VARARGIN)



% Choose default command line output for Gain_Calibration_GUI
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes Gain_Calibration_GUI wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = Gain_Calibration_GUI_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



%%  RUN ACQUISITION 
function run_acquisition_Callback(hObject, eventdata, handles)
% hObject    handle to run_acquisition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


%javaaddpath(fullfile(pwd,'udpnetwork.jar'));
import com.syncropet.udp.*

OutputFolder = uigetdir('','Choose where to save data')

CurTimeStamp= datestr(now,30)

acquisition_time = str2num(get(handles.acquisition_time,'String'))
dac_start = str2num(get(handles.dac_start,'String'))
dac_step = str2num(get(handles.dac_step,'String'))
dac_stop = str2num(get(handles.dac_stop,'String'))
pause_time = str2num(get(handles.pause_time,'String'))

for curdac = dac_start:dac_step:dac_stop
    curfilename = fullfile(OutputFolder,sprintf('calibr %s %03d.evt',CurTimeStamp, curdac))
    curdac
    fprintf('### Setting DAC to: %g\n### Location: %s\n',curdac,curfilename)
    
    set_dac_levels(0,curdac)
    pause(pause_time)
    run_one_java_acquisition(acquisition_time*1000, curdac,curfilename);
    pause(pause_time)  
end


% --- Executes on button press in select_data.
function select_data_Callback(hObject, eventdata, handles)
% hObject    handle to select_data (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

selpath = uigetdir;

set(handles.input_folder, 'String', selpath)

guidata(hObject,handles);


% --- Executes on button press in select_previous_iterations_gains.
function select_previous_iterations_gains_Callback(hObject, eventdata, handles)
% hObject    handle to select_previous_iterations_gains (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
[file, path] = uigetfile('*.mat','Select the previous iteration gains file');

set(handles.previous_gain_file, 'String', file)

guidata(hObject,handles);


%% PROCESS 
function process_Callback(hObject, eventdata, handles)
% hObject    handle to process (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global DataSource
global DataStream
Cfg.Src.MACHINE_FORMAT = 'ieee-be';
Words2Read = 100e6;
DataStream = uint16(zeros(Words2Read,1));

input_folder = get(handles.input_folder,'String')


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
    
        
    coinc_filename = [curfilename(1:end-4),'.coinc'];
    
    fclose(DataSource);
    
    dro(k) = DropRate;
    nevt(k) = NumberEvents;
    fid(k) = Fidelity;
    
    q=regexp(char(fn(k).name),'\s(\d\d\d)\.evt','tokens');
    handles.dac(k) = str2num(char(q{1}));

    era_temp=zeros(24*32,1);
    PETwin_individual_event_rates(easic,echan,era_temp);
    
    handles.era(:,:,k) = reshape(era_temp,32,[]);
    
    
    fprintf(' done in %4.1f seconds\n',toc)
    
    
end

numdif=numel(handles.dac)-1;
handles.ne=shiftdim(handles.era,2);
handles.raw=handles.ne;
%ne = number of events

% Curve Fit
% Polyfit, interp1, fit
fitted=cell(32,24);
for k=1:24
    for m=1:32
        fitted{m,k}=fit(handles.dac', handles.ne(:,m,k), 'smoothingspline','SmoothingParam',.0001);
        handles.ne(:,m,k)=fitted{m,k}(handles.dac);
    end
end

guidata(hObject, handles);

%% GENERATE GRAPHS
function generate_graphs_Callback(hObject, eventdata, handles)
% hObject    handle to generate_graphs (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

fig_num = 1;

%Counts vs. DACS

if get(handles.counts_vs_dac,'Value') == 1
    figure(fig_num)
    fig_num = fig_num + 1;
for k=1:12
    subplot(12,2,k)
    plot(handles.dac, handles.ne(:,:,k))
    set(gca,'xticklabel',[])
    set(gca,'yticklabel',[])
end
sgtitle('Plot of DAC vs Number of Counts')
end

%Photopeaks
if get(handles.photopeaks,'Value') == 1
    figure(fig_num)
    fig_num = fig_num + 1;
for k=1:12
    
    subplot(12,2,k)
    plot(handles.dac(1:end-1), diff(handles.ne(:,:,k)))
    %plot(dac(1:58), diff(ne(1:59,:,k)))
    %plot( (dac(1:end-1)+dac(2:end))/2, diff(ne(:,:,k),1)),
    set(gca,'xticklabel',[])
    set(gca,'yticklabel',[])
end
sgtitle('Plot of DAC vs Delta of Events')
end

%Individual ASIC Counts vs. DACS
if get(handles.individual_counts_vs_dacs,'Value') == 1
ymax=max(handles.era,[],'all');
for k=1:1:12
    figure(fig_num)
    fig_num = fig_num + 1;
    hold on
    plot(handles.dac,handles.ne(:,:,k));
    plot(handles.dac,handles.raw(:,:,k),'.');
    hold off
    title(sprintf('ASIC:%g All Channels', k))
    xlabel('DAC')
    ylabel('Counts (kCps)')
    ylim([0 ymax])
end
end

%Individual ASIC Photopeaks
if get(handles.individual_photopeaks,'Value') == 1
difference=zeros(1,12);
for k=1:1:12
    difference(k)=max(diff((handles.ne(:,:,k))),[],'all');
end
ymaxd=max(difference);
for k=1:1:12
    
    figure(fig_num)
    fig_num = fig_num + 1;
    plot(handles.dac(1:end-1), diff(handles.ne(:,:,k)))
    title(sprintf('ASIC:%g All Channels \\Delta', k))
    xlabel('DAC')
    ylabel('\Delta Counts (kCps)')
    %ylim([0 ymaxd])

end
end

%Histogram of DAC Peak Offsets
if get(handles.histogram_of_deac_peak_offsets,'Value') == 1
peaks=zeros(32,12);
index=zeros(32,12);
for k=1:12
    for L=1:32
        [peaks(L,k), index(L,k)]=max(diff(ne(:,L,k)));
    end
end

figure(fig_num)
fig_num = fig_num + 1;

histogram(dac(index))
title('Histogram of DAC Peak Offsets')
xlabel('DAC')
ylabel('Frequency')
end

%Histogram of Peak Magnitudes
if get(handles.histogram_of_peak_magnitudes,'Value') == 1
for k=1:12
    for L=1:32
        peaks(L,k)=max(diff(ne(:,L,k)));
    end
end

figure(fig_num)
fig_num = fig_num + 1;
histogram(peaks)
filename='Histogram of Peak Magnitudes';
title(filename)
xlabel('Magnitude (\Delta kcps)')
ylabel('Frequency')
end

% % GAIN GEN SCRIPT START
% TDAC = str2num(get(handles.tdac,'String'));
% 
% dDacdGain = str2num(get(handles.ddacdgain,'String'));
% 
% dac = offset(:); 
% 
% if Iteration == 1
%     ring.g = zeros([768,4])
%     ring.p = zeros([24,2])
%     ring.e = zeros([291840,1])
%     ring.t = zeros([768,1])
% else
%     load(strcat(handles.path,handles.file));
% end

%% GENERATE GAINS
function generate_gain_file_Callback(hObject, eventdata, handles)
% hObject    handle to generate_gain_file (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)






% Statistic Half 1

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

Iteration = str2num(get(handles.iteration,'String'));




% GAIN GEN SCRIPT START
TDAC = str2num(get(handles.tdac,'String'));

dDacdGain = str2num(get(handles.ddacdgain,'String'));

dac = offset(:); 

if Iteration == 1
    ring.g = zeros([768,4])
    ring.p = zeros([24,2])
    ring.e = zeros([291840,1])
    ring.t = zeros([768,1])
else
    load(strcat(handles.path,handles.file));
end
% gains as they were read from file
gains = ring.g(:,4); 

%figure(1), plot(dac,'x')

newgains = gains + (TDAC-dac)/dDacdGain;
newgains(find(newgains<0)) = 0;
newgains(find(newgains>31)) = 31;
ring.g(:,4)= round(newgains);
[min(ring.g(:,4)), max(ring.g(:,4))]

save(sprintf('%s\\Iteration %g NewG to TDac %4.1f with dDdG %4.1f gen on %s.mat', save_folder, Iteration, TDAC, -dDacdGain, datestr(now,30)));

msgbox(sprintf('Gains generated for Iteration %g. Load file onto ring using PETshop',Iteration));

figure(1), 
sgtitle(sprintf('Wrist Ring 14 Iteration %g Gain Generation',Iteration))
subplot(211), plot(dac,'x'), grid
xlabel('Channel')
ylabel('DAC Photopeak Location')
subplot(212), plot(ring.g(:,4),'x'), grid
xlabel('Channel')
ylabel('New Gains')

figure(2)
error=abs(ring.g(:,4)-gains);
figure(2)
plot(error,'*')
%title('Gain Difference Between Iteration i and i-1')
xlabel('Channel')
ylabel('Absolute Gain Difference')

figure(3)
plot(ring.g(:,4),'x'), grid
xlabel('Channel')
ylabel('Gains')

%%
function acquisition_time_Callback(hObject, eventdata, handles)
% hObject    handle to acquisition_time (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of acquisition_time as text
%        str2double(get(hObject,'String')) returns contents of acquisition_time as a double


% --- Executes during object creation, after setting all properties.
function acquisition_time_CreateFcn(hObject, eventdata, handles)
% hObject    handle to acquisition_time (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function offset_folder_Callback(hObject, eventdata, handles)
% hObject    handle to offset_folder (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of offset_folder as text
%        str2double(get(hObject,'String')) returns contents of offset_folder as a double


% --- Executes during object creation, after setting all properties.
function offset_folder_CreateFcn(hObject, eventdata, handles)
% hObject    handle to offset_folder (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function dac_start_Callback(hObject, eventdata, handles)
% hObject    handle to dac_start (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of dac_start as text
%        str2double(get(hObject,'String')) returns contents of dac_start as a double


% --- Executes during object creation, after setting all properties.
function dac_start_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dac_start (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function dac_step_Callback(hObject, eventdata, handles)
% hObject    handle to dac_step (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of dac_step as text
%        str2double(get(hObject,'String')) returns contents of dac_step as a double


% --- Executes during object creation, after setting all properties.
function dac_step_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dac_step (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end  



function dac_stop_Callback(hObject, eventdata, handles)
% hObject    handle to dac_stop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of dac_stop as text
%        str2double(get(hObject,'String')) returns contents of dac_stop as a double


% --- Executes during object creation, after setting all properties.
function dac_stop_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dac_stop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function input_folder_Callback(hObject, eventdata, handles)
% hObject    handle to input_folder (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of input_folder as text
%        str2double(get(hObject,'String')) returns contents of input_folder as a double


% --- Executes during object creation, after setting all properties.
function input_folder_CreateFcn(hObject, eventdata, handles)
% hObject    handle to input_folder (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function iteration_Callback(hObject, eventdata, handles)
% hObject    handle to iteration (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of iteration as text
%        str2double(get(hObject,'String')) returns contents of iteration as a double


% --- Executes during object creation, after setting all properties.
function iteration_CreateFcn(hObject, eventdata, handles)
% hObject    handle to iteration (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function tdac_Callback(hObject, eventdata, handles)
% hObject    handle to tdac (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of tdac as text
%        str2double(get(hObject,'String')) returns contents of tdac as a double


% --- Executes during object creation, after setting all properties.
function tdac_CreateFcn(hObject, eventdata, handles)
% hObject    handle to tdac (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function ddacdgain_Callback(hObject, eventdata, handles)
% hObject    handle to ddacdgain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ddacdgain as text
%        str2double(get(hObject,'String')) returns contents of ddacdgain as a double


% --- Executes during object creation, after setting all properties.
function ddacdgain_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ddacdgain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function previous_gain_file_Callback(hObject, eventdata, handles)
% hObject    handle to previous_gain_file (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of previous_gain_file as text
%        str2double(get(hObject,'String')) returns contents of previous_gain_file as a double


% --- Executes during object creation, after setting all properties.
function previous_gain_file_CreateFcn(hObject, eventdata, handles)
% hObject    handle to previous_gain_file (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function pause_time_Callback(hObject, eventdata, handles)
% hObject    handle to pause_time (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of pause_time as text
%        str2double(get(hObject,'String')) returns contents of pause_time as a double


% --- Executes during object creation, after setting all properties.
function pause_time_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pause_time (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end





% --- Executes on button press in photopeaks.
function photopeaks_Callback(hObject, eventdata, handles)
% hObject    handle to photopeaks (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of photopeaks


% --- Executes on button press in individual_counts_vs_dacs.
function individual_counts_vs_dacs_Callback(hObject, eventdata, handles)
% hObject    handle to individual_counts_vs_dacs (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of individual_counts_vs_dacs


% --- Executes on button press in counts_vs_dac.
function counts_vs_dac_Callback(hObject, eventdata, handles)
% hObject    handle to counts_vs_dac (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of counts_vs_dac


% --- Executes on button press in individual_photopeaks.
function individual_photopeaks_Callback(hObject, eventdata, handles)
% hObject    handle to individual_photopeaks (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of individual_photopeaks


% --- Executes on button press in checkbox5.
function checkbox5_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox5


% --- Executes on button press in histogram_of_dac_peak_offsets.
function histogram_of_dac_peak_offsets_Callback(hObject, eventdata, handles)
% hObject    handle to histogram_of_dac_peak_offsets (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of histogram_of_dac_peak_offsets


% --- Executes on button press in checkbox7.
function checkbox7_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox7


% --- Executes on button press in histogram_of_peak_magnitudes.
function histogram_of_peak_magnitudes_Callback(hObject, eventdata, handles)
% hObject    handle to histogram_of_peak_magnitudes (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of histogram_of_peak_magnitudes


% --- Executes on button press in checkbox9.
function checkbox9_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox9 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox9
