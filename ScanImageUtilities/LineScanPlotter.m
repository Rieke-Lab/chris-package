function varargout = LineScanPlotter(varargin)
% LINESCANPLOTTER MATLAB code for LineScanPlotter.fig
%      LINESCANPLOTTER, by itself, creates a new LINESCANPLOTTER or raises the existing
%      singleton*.
%
%      H = LINESCANPLOTTER returns the handle to a new LINESCANPLOTTER or the handle to
%      the existing singleton*.
%
%      LINESCANPLOTTER('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in LINESCANPLOTTER.M with the given input arguments.
%
%      LINESCANPLOTTER('Property','Value',...) creates a new LINESCANPLOTTER or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before LineScanPlotter_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to LineScanPlotter_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help LineScanPlotter

% Last Modified by GUIDE v2.5 02-Oct-2017 13:45:58

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @LineScanPlotter_OpeningFcn, ...
                   'gui_OutputFcn',  @LineScanPlotter_OutputFcn, ...
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

% --- Executes just before LineScanPlotter is made visible.
function LineScanPlotter_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to LineScanPlotter (see VARARGIN)

% Choose default command line output for LineScanPlotter
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% This sets up the initial plot - only do when we are invisible
% so window can get raised using LineScanPlotter.
if strcmp(get(hObject,'Visible'),'off')
    plot(nan(5));
end

% UIWAIT makes LineScanPlotter wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = LineScanPlotter_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

% --- Executes on button press in pushbutton1.
function pushbutton1_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

axes(handles.axes1);
cla;

% % dataDir = '~/Dropbox/CurrentData/CalciumImaging/';
dataDir = 'C:\Users\scientifica\Documents\ScanImageData\';

popup_selection = handles.popupmenu1.String(handles.popupmenu1.Value);
cd([dataDir,popup_selection{1}]);

%load file to plot
cellID = handles.edit1.String{1};
trialsToPull = eval(handles.edit2.String{1});

accum_data = [];
for tt = 1:length(trialsToPull)
    currentTrial_str = num2str(trialsToPull(tt));
    switch length(currentTrial_str)
        case 1
            fileName = [cellID,'_0000',currentTrial_str];
        case 2
            fileName = [cellID,'_000',currentTrial_str];
        case 3
            fileName = [cellID,'_00',currentTrial_str];
    end
    if tt == 1
        metaFileName= fileName;
    end
    [~, pmtData, ~, roiGroup] = readLineScanDataFiles_riekeLab(fileName,metaFileName);
    noROIs = size(roiGroup.rois,2);
    plotLen = size(pmtData,1) / noROIs;
    
    for ii = 1:noROIs
        plotStart = plotLen * (ii-1) + 1;
        plotEnd = plotLen * ii;
        %Picking channel 1 out of pmtData:
        accum_data(tt,:,ii) = mean(squeeze(pmtData(plotStart:plotEnd,1,:)));
    end
end

%plot new data:
hold on; colors = hsv(noROIs);
for ii = 1:noROIs
plot(mean(accum_data(:,:,ii),1),'Color',colors(ii,:))
end
title('Channel 1')

% --------------------------------------------------------------------
function FileMenu_Callback(hObject, eventdata, handles)
% hObject    handle to FileMenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function OpenMenuItem_Callback(hObject, eventdata, handles)
% hObject    handle to OpenMenuItem (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
file = uigetfile('*.fig');
if ~isequal(file, 0)
    open(file);
end

% --------------------------------------------------------------------
function PrintMenuItem_Callback(hObject, eventdata, handles)
% hObject    handle to PrintMenuItem (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
printdlg(handles.figure1)

% --------------------------------------------------------------------
function CloseMenuItem_Callback(hObject, eventdata, handles)
% hObject    handle to CloseMenuItem (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
selection = questdlg(['Close ' get(handles.figure1,'Name') '?'],...
                     ['Close ' get(handles.figure1,'Name') '...'],...
                     'Yes','No','Yes');
if strcmp(selection,'No')
    return;
end

delete(handles.figure1)


% --- Executes on selection change in popupmenu1.
function popupmenu1_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = get(hObject,'String') returns popupmenu1 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu1


% --- Executes during object creation, after setting all properties.
function popupmenu1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
     set(hObject,'BackgroundColor','white');
end
%populate popup menu 1 with data directory names
% % dataDir = '~/Dropbox/CurrentData/CalciumImaging/';
dataDir = 'C:\Users\scientifica\Documents\ScanImageData\';
cd(dataDir);

tempDir = dir; 
tempInd = find(vertcat(tempDir.isdir));
directories = tempDir(tempInd);
directories = directories(~cellfun('isempty', {directories.date})); %exclude invalid entries
nameList = {}; ct = 0;
for dd = 1:length(directories)
    if strcmp(directories(dd).name,'.')
        continue
    elseif strcmp(directories(dd).name,'..')
        continue
    end
    ct = ct + 1;
    nameList{ct} = directories(dd).name;
end

set(hObject, 'String', nameList);


function edit1_Callback(hObject, eventdata, handles)
% hObject    handle to edit1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit1 as text
%        str2double(get(hObject,'String')) returns contents of edit1 as a double


% --- Executes during object creation, after setting all properties.
function edit1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit2_Callback(hObject, eventdata, handles)
% hObject    handle to edit2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit2 as text
%        str2double(get(hObject,'String')) returns contents of edit2 as a double


% --- Executes during object creation, after setting all properties.
function edit2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
