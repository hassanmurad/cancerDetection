%STAGEAPP StageApp 

% $Date: 2016-06-04 12:07:36 -0700 (Sat, 04 Jun 2016) $
% $Revision: 31 $
% $Author: plane $
% $HeadURL: http://cisvn.bccrc.ca/ENSC460/trunk/Matlab/StageApp.m $

function varargout = StageApp(varargin)
% STAGEAPP MATLAB code for StageApp.fig
%      STAGEAPP, by itself, creates a new STAGEAPP or raises the existing
%      singleton*.
%
%      H = STAGEAPP returns the handle to a new STAGEAPP or the handle to
%      the existing singleton*.
%
%      STAGEAPP('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in STAGEAPP.M with the given input arguments.
%
%      STAGEAPP('Property','Value',...) creates a new STAGEAPP or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before StageApp_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to StageApp_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help StageApp

% Last Modified by GUIDE v2.5 04-Jun-2016 11:51:10

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @StageApp_OpeningFcn, ...
                   'gui_OutputFcn',  @StageApp_OutputFcn, ...
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


% --- Executes just before StageApp is made visible.
function StageApp_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to StageApp (see VARARGIN)

% Choose default command line output for StageApp
handles.output = hObject;

% Version string
rev = sscanf('$Revision: 31 $', '$Revision: %d$');
set(handles.VersionText, 'String', sprintf('Version 1.0.%i', rev));

% Default State
handles.LoadPosition = [];
handles.FocusPosition = [];
handles.IsCalibrated = false;
handles.IsMeasured = false;
handles.StatusTimer = [];

try
    handles.Stage = LangMCL3;
catch ex
    % Dispay a warning message to the console
    warning(ex.message);
    
    % Flage a NULL stage so we can exit later
    handles.Stage = [];
end

if(~isempty(handles.Stage))
    
    % Add event listeners
    handles.ReadyStateChangedListener = addlistener( handles.Stage, 'ReadyStateChanged', ...
        @(src,eventdata)OnReadyStateChanged(src, eventdata, hObject));
    handles.CommandStateChangedListener = addlistener( handles.Stage, 'CommandStateChanged', ...
        @(src,eventdata)OnCommandStateChanged(src, eventdata, hObject));

    % Timer for regular status updates
    handles.StatusTimer = timer;
    handles.StatusTimer.TimerFcn = @(src,eventdata)OnTimer(src, eventdata, hObject);
    handles.StatusTimer.Period = 0.1;
    handles.StatusTimer.StartDelay = 0;
    handles.StatusTimer.ExecutionMode = 'fixedSpacing';

end

% Update handles structure
guidata(hObject, handles);



% UIWAIT makes StageApp wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = StageApp_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

% Check for a stage
if(isempty(handles.Stage))
    % No stage so exit
    delete(hObject);  
else
    start(handles.StatusTimer);
    EnableControls(handles);
end

% --- Executes during object deletion, before destroying properties.
function figure1_DeleteFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Timer clean up
if(~isempty(handles.StatusTimer))
    stop(handles.StatusTimer);
    delete(handles.StatusTimer);
end

% Stage controller clean up
if(~isempty(handles.Stage))

    % Remove listeners
    delete(handles.ReadyStateChangedListener);
    delete(handles.CommandStateChangedListener);
    
    handles.Stage.Close();
    delete(handles.Stage);
end

function OnReadyStateChanged(src, eventData, hObject)

handles = guidata(hObject);
disp('OnReadyStateChanged');

EnableControls(handles);


function OnCommandStateChanged(src, eventData, hObject)

handles = guidata(hObject);
disp('OnCommandStateChanged');

if(~handles.Stage.AsyncCommandActive)
    % A move command just finished
    UpdatePositionAndLimitSwitchState(handles);
end

EnableControls(handles);


function OnTimer(src, eventdata, hObject)

handles = guidata(hObject);

if(handles.Stage.Ready && handles.Stage.JoystickEnabled)

    % Update position as joystick moves
    pos = [ ...
        handles.Stage.PositionX, ...
        handles.Stage.PositionY, ...
        handles.Stage.PositionZ ...
        ];
    UpdatePosition(handles, pos)
    
    % Joystick Checkbox
    if(handles.Stage.Ready && ~handles.Stage.AsyncCommandActive)
        set(handles.JoystickEnableCheckbox, 'Enable', 'on');
    else
        set(handles.JoystickEnableCheckbox, 'Enable', 'off');
    end
    
end


function EnableControls(handles)

% Update LED indicator
if(handles.Stage.Ready)
    set(handles.ReadyLed, 'BackgroundColor', [0, 1, 0]);
else
    set(handles.ReadyLed, 'BackgroundColor', [1, 0, 0]);
end

% Joystick Checkbox
if(handles.Stage.Ready && ~handles.Stage.AsyncCommandActive)
    set(handles.JoystickEnableCheckbox, 'Enable', 'on');
else
    set(handles.JoystickEnableCheckbox, 'Enable', 'off');
end

% Commands
if(handles.Stage.Ready && ~handles.Stage.JoystickEnabled && ~handles.Stage.AsyncCommandActive)
    
     % Joystick is disabled.
     % All commands can be accepted
    set(handles.CalibratePushbutton, 'Enable', 'on');
    set(handles.UpdatePositionPushbutton, 'Enable', 'on');
else
    
    % Joystick is enabled.
    % The only valid command is to disable joystick mode
    set(handles.CalibratePushbutton, 'Enable', 'off');
    set(handles.UpdatePositionPushbutton, 'Enable', 'off');
end

% Measure Command
if(handles.Stage.Ready && ~handles.Stage.JoystickEnabled && handles.IsCalibrated && ~handles.Stage.AsyncCommandActive)
    set(handles.MeasurePushbutton, 'Enable', 'on');
else
    set(handles.MeasurePushbutton, 'Enable', 'off');
end

% Set Load Position Button
if(handles.Stage.Ready && handles.IsCalibrated && ~handles.Stage.AsyncCommandActive)
    set(handles.SetLoadPushbutton, 'Enable', 'on');
else
    set(handles.SetLoadPushbutton, 'Enable', 'off');
end

% Load Position Button
if(handles.Stage.Ready && ~handles.Stage.JoystickEnabled && handles.IsCalibrated && ~handles.Stage.AsyncCommandActive)
    set(handles.LoadPositionPushbutton, 'Enable', 'on');
else
    set(handles.LoadPositionPushbutton, 'Enable', 'off');
end

% Set Focus Position Button
if(handles.Stage.Ready && handles.IsMeasured && ~handles.Stage.AsyncCommandActive)
    set(handles.SetFocusPushbutton, 'Enable', 'on');
else
    set(handles.SetFocusPushbutton, 'Enable', 'off');
end

% Focus Position Button
if(handles.Stage.Ready && ~handles.Stage.JoystickEnabled && handles.IsMeasured && ~handles.Stage.AsyncCommandActive)
    set(handles.FocusPositionPushbutton, 'Enable', 'on');
else
    set(handles.FocusPositionPushbutton, 'Enable', 'off');
end

% Abort Button
if(handles.Stage.Ready && ~handles.Stage.JoystickEnabled && handles.Stage.AsyncCommandActive)
    set(handles.AbortPushbutton, 'Enable', 'on');
else
    set(handles.AbortPushbutton, 'Enable', 'off');
end

% Relative Move
if(handles.Stage.Ready && ~handles.Stage.JoystickEnabled && handles.IsMeasured && ~handles.Stage.AsyncCommandActive)
    set(handles.RelativeMinusPushbutton, 'Enable', 'on');
    set(handles.RelativePlusPushbutton, 'Enable', 'on');
else
    set(handles.RelativeMinusPushbutton, 'Enable', 'off');
    set(handles.RelativePlusPushbutton, 'Enable', 'off');
end


function UpdatePosition(handles, pos)

set(handles.PositionXText,'String', sprintf('%i', pos(1)));
set(handles.PositionYText,'String', sprintf('%i', pos(2)));
set(handles.PositionZText,'String', sprintf('%i', pos(3)));


function UpdateLimitSwitchLeds(handles, limitSwitchState)

activeColor = [1, 0, 0];
inactiveColor = [0.5, 0.5, 0.5];

% X Axis
switch(limitSwitchState(1))
    case LimitSwitchState.ZeroActive
        set(handles.LimitZeroXLed, 'BackgroundColor', activeColor);
        set(handles.LimitEndXLed, 'BackgroundColor', inactiveColor);
    case LimitSwitchState.EndActive
        set(handles.LimitZeroXLed, 'BackgroundColor', inactiveColor);
        set(handles.LimitEndXLed, 'BackgroundColor', activeColor);
    otherwise
        set(handles.LimitZeroXLed, 'BackgroundColor', inactiveColor);
        set(handles.LimitEndXLed, 'BackgroundColor', inactiveColor);
end

% Y Axis
switch(limitSwitchState(2))
    case LimitSwitchState.ZeroActive
        set(handles.LimitZeroYLed, 'BackgroundColor', activeColor);
        set(handles.LimitEndYLed, 'BackgroundColor', inactiveColor);
    case LimitSwitchState.EndActive
        set(handles.LimitZeroYLed, 'BackgroundColor', inactiveColor);
        set(handles.LimitEndYLed, 'BackgroundColor', activeColor);
    otherwise
        set(handles.LimitZeroYLed, 'BackgroundColor', inactiveColor);
        set(handles.LimitEndYLed, 'BackgroundColor', inactiveColor);
end

% Z Axis
switch(limitSwitchState(3))
    case LimitSwitchState.ZeroActive
        set(handles.LimitZeroZLed, 'BackgroundColor', activeColor);
        set(handles.LimitEndZLed, 'BackgroundColor', inactiveColor);
    case LimitSwitchState.EndActive
        set(handles.LimitZeroZLed, 'BackgroundColor', inactiveColor);
        set(handles.LimitEndZLed, 'BackgroundColor', activeColor);
    otherwise
        set(handles.LimitZeroZLed, 'BackgroundColor', inactiveColor);
        set(handles.LimitEndZLed, 'BackgroundColor', inactiveColor);
end


% --- Executes on button press in JoystickEnableCheckbox.
function JoystickEnableCheckbox_Callback(hObject, eventdata, handles)
% hObject    handle to JoystickEnableCheckbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

value = get(hObject,'Value');

if(value)
    handles.Stage.EnableJoystick();
else
    handles.Stage.DisableJoystick();
end

% Update state immediatley
EnableControls(handles);


% --- Executes on button press in CalibratePushbutton.
function CalibratePushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to CalibratePushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

limitSwitchState= handles.Stage.Calibrate();
UpdateLimitSwitchLeds(handles, limitSwitchState);

pos = [handles.Stage.PositionX, handles.Stage.PositionY, handles.Stage.PositionZ];
UpdatePosition(handles, pos);

% Allow load positions to be set
handles.IsCalibrated = true;
handles.LoadPosition = 0;
set(handles.LoadPositionText,'String', sprintf('%d', handles.LoadPosition));
guidata(hObject, handles);

EnableControls(handles);



% --- Executes on button press in MeasurePushbutton.
function MeasurePushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to MeasurePushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

limitSwitchState = handles.Stage.Measure();
UpdateLimitSwitchLeds(handles, limitSwitchState);

pos = [handles.Stage.PositionX, handles.Stage.PositionY, handles.Stage.PositionZ];
UpdatePosition(handles, pos);

% Allow focus positions to be set
handles.IsMeasured = true;
handles.FocusPosition = pos(3);
set(handles.FocusPositionText,'String', sprintf('%d', handles.FocusPosition));
guidata(hObject, handles);

EnableControls(handles)

% --- Executes on button press in UpdatePositionPushbutton.
function UpdatePositionPushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to UpdatePositionPushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
UpdatePositionAndLimitSwitchState(handles);


function UpdatePositionAndLimitSwitchState(handles)

limitSwitchState = handles.Stage.GetLimitSwitchState();
UpdateLimitSwitchLeds(handles, limitSwitchState);

% Get the position and update
pos = [ ...
    handles.Stage.PositionX, ...
    handles.Stage.PositionY, ...
    handles.Stage.PositionZ ...
    ];
UpdatePosition(handles, pos);

% --- Executes on button press in SetLoadPushbutton.
function SetLoadPushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to SetLoadPushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles.LoadPosition = handles.Stage.PositionZ;
set(handles.LoadPositionText, 'String',sprintf('%d', handles.LoadPosition));
guidata(hObject, handles);


% --- Executes on button press in SetFocusPushbutton.
function SetFocusPushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to SetFocusPushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles.FocusPosition = handles.Stage.PositionZ;
set(handles.FocusPositionText, 'String',sprintf('%d', handles.FocusPosition));
guidata(hObject, handles);


% --- Executes on button press in LoadPositionPushbutton.
function LoadPositionPushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to LoadPositionPushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

deltaZ = handles.LoadPosition - handles.Stage.PositionZ;
handles.Stage.MoveRelativeAsync([0, 0, deltaZ]);


% --- Executes on button press in FocusPositionPushbutton.
function FocusPositionPushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to FocusPositionPushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

deltaZ = handles.FocusPosition - handles.Stage.PositionZ;
handles.Stage.MoveRelativeAsync([0, 0, deltaZ]);


% --- Executes on button press in AbortPushbutton.
function AbortPushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to AbortPushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles.Stage.Abort();


% --- Executes on button press in RelativePlusPushbutton.
function RelativePlusPushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to RelativePlusPushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

delta = str2double(get(handles.RelativeDeltaText,'string'));
delta = round(delta);

axisIndex = handles.XYZuibuttongroup.SelectedObject.UserData;
pos = zeros(1,3);
pos(axisIndex) = delta;
handles.Stage.MoveRelativeAsync(pos);


% --- Executes on button press in RelativeMinusPushbutton.
function RelativeMinusPushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to RelativeMinusPushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

delta = str2double(get(handles.RelativeDeltaText,'string'));
delta = round(delta);

axisIndex = handles.XYZuibuttongroup.SelectedObject.UserData;
pos = zeros(1,3);
pos(axisIndex) = -delta;
handles.Stage.MoveRelativeAsync(pos);
