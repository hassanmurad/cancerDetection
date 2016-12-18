%LANGMCL3 LangMCL3 class 

% $Date: 2016-04-15 18:37:53 -0700 (Fri, 15 Apr 2016) $
% $Revision: 29 $
% $Author: plane $
% $HeadURL: http://cisvn.bccrc.ca/ENSC460/trunk/Matlab/LangMCL3.m $

classdef LangMCL3 < handle
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        
        DefaultPort = 'COM1';
       
    end
    
    events
        ReadyStateChanged
        CommandStateChanged
    end
    
    properties (Dependent)
        
        PositionX
        PositionY
        PositionZ
       
        Ready
        Status
        ComStatus
        Port
        
    end
    
    %properties (SetAccess=private, GetAccess=private)
    properties
        
        ReadAddressBase = 64;
        WriteAddressBase = 0;
        
        WaitObject;
        SerialPortObject;
        
        DefaultCommandTimeout = 60;
        JoystickEnabled = false;

        LastAsyncResponse = [];
        LastAsyncCommandAborted = false;
        LastAsyncCommandTimeout = false;        
        AsyncCommandActive = false;   
       
    end
    
    methods
        
        function obj = LangMCL3()
            
            obj.SerialPortObject = serial('COM1', ...
                'BaudRate',9600, ...
                'Parity','none', ...
                'StopBits',2 ...
                );
            
            % Use 'CR' (0xD=13) for read and write terminator
            set(obj.SerialPortObject, 'Terminator', 'CR');
            
            % Set COM timeout in seconds
             set(obj.SerialPortObject, 'Timeout', 5);
             
            % Execute callback when terminator recived. Async read only
            obj.SerialPortObject.BytesAvailableFcnMode = 'Terminator';
            obj.SerialPortObject.BytesAvailableFcn = '';
            
            obj.SerialPortObject.PinStatusFcn = @obj.PinStatusChanged;
            
            % Timer object
            obj.WaitObject = timer;

            % Try to open on default port
            obj.Open();
            
        end
        
        function delete(obj)
                        
            obj.Close();
            
            if(strcmp(obj.WaitObject.Running,'on'))
                warning('Async command still pending...');
                obj.WaitObject.TimerFcn = '';
                stop(obj.WaitObject);
            end
            delete(obj.WaitObject);
            
            % Cleanup serial port object
            obj.SerialPortObject.PinStatusFcn = '';
            obj.SerialPortObject.BytesAvailableFcn = '';
            delete(obj.SerialPortObject);

        end
        

        
        function Open(obj, port)
            
            if(strcmp(obj.SerialPortObject.Status, 'open'))
                % Already open
                return;
            end
            
            if(nargin<2 || isempty(port))
                port = obj.DefaultPort;
            end
            
            set(obj.SerialPortObject, 'Port', port);
            fopen(obj.SerialPortObject);
            
            if(strcmp(obj.SerialPortObject.Status, 'open'))
                
                obj.FlushReadBuffer();
            end

        end
        
        function Close(obj)
            
            if(strcmp(obj.SerialPortObject.Status, 'closed'))
                % Already open
                return;
            end
            
            if(obj.JoystickEnabled)
                DisableJoystick(obj);
            end
            
            fclose(obj.SerialPortObject);

        end
        
        function PinStatusChanged(obj, portObject, eventaData)
            
            notify(obj, 'ReadyStateChanged');          
        end
        
        function EnableJoystick(obj)
            
            if(~obj.JoystickEnabled)
                
                obj.ValidateReady();
                
                obj.WriteRegister(12, '0');     % No delay of MCL echos
                obj.WriteRegister(7, 'j');      % Set command
                
                % Start joystick mode but don't wait for a reply
                % Status message comes when joystick mode is stopped
                obj.ReadRegisterBase(16);
                
                obj.JoystickEnabled = true;
                
            else
                warning('Joystick already enabled.');
                
            end
            
        end
        
        function limitSwitchState = DisableJoystick(obj)
            
            if(obj.JoystickEnabled)
                
                obj.ValidateReady();
                
                % Disable joystick mode
                % MCL responds with current status
                fprintf(obj.SerialPortObject, '%s\n', 'j', 'sync');
                
                % Get the current status
                statusMessage = fscanf(obj.SerialPortObject);
                limitSwitchState = obj.CreateLimitSwitchState(statusMessage);
                obj.IssueLimitSwitchWarinings(limitSwitchState);
                
                obj.JoystickEnabled = false;
                
            else
                warning('Joystick already disabled.');
                limitSwitchState = [];
            end
            
            
        end
        
        function stringValue = WaitForAsyncCompletion(obj, timeout)
           
            % Set the timeout for this async command
            if(nargin<2)
                timeout = obj.DefaultCommandTimeout;
            end
            
            % Configure timer and start
            obj.LastAsyncCommandTimeout = false;
            obj.LastAsyncCommandAborted = false;
            obj.WaitObject.StartDelay = timeout;
            obj.WaitObject.TimerFcn = @obj.WaitFunctionCallback;
            start(obj.WaitObject);
            
            % Wait here till done
            % Timer is stopped in ReadRegisterAsyncComplete callback to
            % signal wait object
            wait(obj.WaitObject);
            
            % Check if we timed out
            if(obj.LastAsyncCommandTimeout)
                
                % Throw an exception
                ME = MException('LangMCL3:Timeout', 'Command took longer than %d seconds to complete.', timeout);
                throw(ME)
            end
 
            % get the status message
            stringValue =  obj.LastAsyncResponse;
            
        end
        
       
       function WaitFunctionCallback(obj, waitObject, eventData)
           % If we end up here a time out has occuered
           obj.LastAsyncCommandTimeout = true;
       end
        
       
        function limitSwitchState = Calibrate(obj, timeout)
            
            % Set the timeout for this async command
            if(nargin<2)
                timeout = obj.DefaultCommandTimeout;
            end
           
            obj.ValidateReady();         
            obj.WriteRegister(7, 'c');     % Set command
            obj.ReadRegisterAsync(16);     % Start asynchronously
            
            % Wait for calibrtion to finish. Throws exception on timout
            statusMessage = obj.WaitForAsyncCompletion(timeout);
            limitSwitchState = obj.CreateLimitSwitchState(statusMessage);
            
            % All zero limit switches should be active after calibration
            assert(limitSwitchState(1)==LimitSwitchState.ZeroActive, ...
                'Zero limit switch on X axis is not active');
            assert(limitSwitchState(2)==LimitSwitchState.ZeroActive, ...
                'Zero limit switch on Y axis is not active');
            assert(limitSwitchState(3)==LimitSwitchState.ZeroActive, ...
                'Zero limit switch on Z axis is not active');
           
        end
        
        
        function limitSwitchState = Measure(obj, timeout)
        
            % WARNING - End limit switches for X, Y, and Z must be working
        
            % Set the timeout for this async command
            if(nargin<2)
                timeout = obj.DefaultCommandTimeout;
            end
            
            obj.ValidateReady();
            obj.WriteRegister(7, 'l');     % Set command
            obj.ReadRegisterAsync(16);     % Start asynchronously
            
            % Wait for measure to finish
            statusMessage = obj.WaitForAsyncCompletion(timeout);
            limitSwitchState = obj.CreateLimitSwitchState(statusMessage);
        
            % All end limit switches should be active after calibration
            assert(limitSwitchState(1)==LimitSwitchState.EndActive, ...
                'End limit switch on X axis is not active');
            assert(limitSwitchState(2)==LimitSwitchState.EndActive, ...
                'End limit switch on Y axis is not active');
            assert(limitSwitchState(3)==LimitSwitchState.EndActive, ...
                'End limit switch on Z axis is not active');
            
        end

        function limitSwitchState = MoveRelative(obj, vector, timeout)
            
            % Set the timeout
            if(nargin<3)
                timeout = obj.DefaultCommandTimeout;
            end
            
            MoveRelativeAsync(obj, vector)
            
            % Wait for move to finish
            statusMessage = obj.WaitForAsyncCompletion(timeout);
            limitSwitchState = obj.CreateLimitSwitchState(statusMessage);
            
            obj.IssueLimitSwitchWarinings(limitSwitchState);
        end
        
        
        function MoveRelativeAsync(obj, vector)
            
            obj.ValidateReady();
            
            % Move vector in steps
            if(length(vector)~=3 || nargin<2)
                error('First agument must be a length-3 vector [x, y, z].')
            end
            x = vector(1);
            y = vector(2);
            z = vector(3);
           
            % Relative vector internal clock
            obj.WriteRegister(7, 'v');                  % Set command
            obj.WriteRegister(0, int2str(x));           % X Axis
            obj.WriteRegister(1, int2str(y));           % Y Axis
            obj.WriteRegister(2, int2str(z));           % Z Axis
            obj.ReadRegisterAsync(16);                  % Start asynchronously
          
        end
        
        function limitSwitchState = MoveAbsolute(obj, position, timeout)
            
            % Set the timeout
            if(nargin<3)
                timeout = obj.DefaultCommandTimeout;
            end
            
            MoveAbsoluteAsync(obj, position)
            
            % Wait for move to finish
            statusMessage = obj.WaitForAsyncCompletion(timeout);
            limitSwitchState = obj.CreateLimitSwitchState(statusMessage);
            
            obj.IssueLimitSwitchWarinings(limitSwitchState);
        end
        
        
        
        function MoveAbsoluteAsync(obj, position)
            
            obj.ValidateReady();
            
            % Move position in steps
            if(length(position)~=3 || nargin<2)
                error('First agument must be a length-3 position [x, y, z].')
            end
            x = position(1);
            y = position(2);
            z = position(3);
            
            % Relative vector internal clock
            obj.WriteRegister(7, 'r');                  % Set command
            obj.WriteRegister(0, int2str(x));           % X Axis
            obj.WriteRegister(1, int2str(y));           % Y Axis
            obj.WriteRegister(2, int2str(z));           % Z Axis
            obj.ReadRegisterAsync(16);                  % Start asynchronously
            
        end
        
        
        function Abort(obj)
            % Abort active command
            % Can only be used with move commands
            obj.LastAsyncCommandAborted = true;
            fprintf(obj.SerialPortObject,'a');
        end
        
        
        function value = get.PositionX(obj)
            
            obj.ValidateReady();
            
            % Get absoluto position in microns
            stringValue = ReadRegister(obj, 3);
            value = str2double(stringValue);
        end
        
        
        function value = get.PositionY(obj)
            
            obj.ValidateReady();
            
            % Get absoluto position in microns
            stringValue = ReadRegister(obj, 4);
            value = str2double(stringValue);
        end
        
        function value = get.PositionZ(obj)
            
            obj.ValidateReady();
            
            % Get absoluto position in microns
            stringValue = ReadRegister(obj, 5);
            value = str2double(stringValue);
        end
        
        function value = get.Ready(obj)
            pinStatus = get(obj.SerialPortObject,'PinStatus');
            value = strcmp(pinStatus.ClearToSend,'on');
        end
        
        function value = get.Port(obj)
            value = obj.SerialPortObject.Port;
        end
        
        function value = get.ComStatus(obj)
            value = obj.SerialPortObject.Status;
        end
        
        
        function value = get.Status(obj)
            
            obj.ValidateReady();
            
            if(obj.JoystickEnabled)
                ME = MException('LangMCL3:JoystickEnabled', 'Can not get status when joystick is enabled.');
                throw(ME)
            end
            
            statusMessage = obj.ReadRegister(6);     % Status
            
            if(isempty(statusMessage))
                
                % Emply message
                value = 'Empty status message.';
                
            elseif(length(statusMessage)==6)
                
                % Expected length is 5 characters plus termination
                value = obj.DecodeStatusMessage(statusMessage);
            else
                
                % Unexpected length
                value = sprintf('Status message ("%s") has unexpected length.', deblank(statusMessage));
            end
        end
        
        
        
        function value = GetLimitSwitchState(obj)
            
            obj.ValidateReady();
            
            % Relative vector internal clock
            obj.WriteRegister(7, 'v');                      % Set command
            obj.WriteRegister(0, '0');                      % X Axis
            obj.WriteRegister(1, '0');                      % Y Axis
            obj.WriteRegister(2, '0');                      % Z Axis
            statusMessage = obj.ReadRegister(16);           % Start
            
            value = obj.CreateLimitSwitchState(statusMessage);
        end
        
    end
    
    
    
    methods(Access=protected)
        
        function ValidateReady(obj)
            
            if ~strcmp(obj.ComStatus,'open')
                ME = MException('LangMCL3:NotOpen', 'MCL3 stage object is not open. Open object before executing commands.');
                throw(ME)
            end
            
            if ~obj.Ready
                ME = MException('LangMCL3:NotReady', 'MCL stage object is not connected, in manual mode, or busy.');
                throw(ME)
            end
            
        end
        
        function stringValue = FlushReadBuffer(obj)
           
            bytesAvailable = get(obj.SerialPortObject, 'BytesAvailable');
            
            if(bytesAvailable>0)
                stringValue = fscanf(obj.SerialPortObject, '%c', bytesAvailable);
                bytesAvailable = get(obj.SerialPortObject, 'BytesAvailable');
                assert(bytesAvailable==0, 'Additional bytes in buffer.')
            else
                stringValue = '';
            end
            
        end
        
        
        
        function stringValue = ReadRegister(obj, register)

            % Async read
            ReadRegisterBase(obj, register)

            % Wait for the result and read when avaialble
            stringValue = fscanf(obj.SerialPortObject);
        end
        
        
        function ReadRegisterAsync(obj, register)
            
             obj.AsyncCommandActive = true;
             notify(obj, 'CommandStateChanged'); 
            
            % Hook the callback
            obj.SerialPortObject.BytesAvailableFcn = @obj.ReadRegisterAsyncComplete;            
            
            % Async read
            ReadRegisterBase(obj, register)
        end
        
        
        function ReadRegisterBase(obj, register)
            
            % Reset state
            obj.FlushReadBuffer();
            obj.LastAsyncCommandTimeout = false;
            obj.LastAsyncCommandAborted = false;
            
            readAddress = uint8(obj.ReadAddressBase + register);
            
            % Send register to read
            fwrite(obj.SerialPortObject, 'U', 'uchar', 'sync');                % 'U'
            fwrite(obj.SerialPortObject, readAddress, 'uint8', 'sync');        % read address
            fprintf(obj.SerialPortObject, '%s\n', '', 'sync');                 % termintion only

        end
        
        
        function ReadRegisterAsyncComplete(obj, port, eventaData)
           
            % disp('ReadRegisterAsyncComplete');
               
            % Unhook callback
            obj.SerialPortObject.BytesAvailableFcn = '';
            
            % Read the status returned
            obj.LastAsyncResponse = fscanf(obj.SerialPortObject);
            
            % Check length
            if(length(obj.LastAsyncResponse)~=6)
                warning('Status message ("%s") in async completion callback has unexpected length.', ...
                    deblank(obj.LastAsyncResponse));
            end
            
            statusMessage = DecodeStatusMessage(obj, obj.LastAsyncResponse);
            
            % notify 
            obj.AsyncCommandActive = false;
            notify(obj, 'CommandStateChanged'); 
            
            waitingOnAsyncCommand = strcmp(get(obj.WaitObject, 'Running'), 'on');
            if(waitingOnAsyncCommand)
                
                % Signal waiting threads to proceed
                stop(obj.WaitObject);
                
            elseif(obj.LastAsyncCommandTimeout)
                
                % Time out
                fprintf('Timed-out command just completed: %s\n', statusMessage);
                
            elseif(obj.LastAsyncCommandAborted)
                
                % Command was aborted
                fprintf('Move command was aborted: %s\n', statusMessage);
                
            else
                
                % Async command finished
                fprintf('Async command just completed: %s\n', statusMessage);
                
            end
            
        end
        
         
        function WriteRegister(obj, register, stringValue)
            
            writeAddress = uint8(obj.WriteAddressBase + register);
            
            fwrite(obj.SerialPortObject, 'U', 'uchar', 'sync');                 % 'U'
            fwrite(obj.SerialPortObject, writeAddress, 'uint8', 'sync');        % write address
            fprintf(obj.SerialPortObject, '%s\n', stringValue, 'sync');         % value string + termintion
            
        end
        
        
        function value = CreateLimitSwitchState(obj, statusMessage)
            
            if length(statusMessage)~=6 || ~strcmp(statusMessage(4:5),'-.')
                ME = MException('LangMCL3:UnexpectedStatusMessageFormat', ...
                    'The status message returned by the stage has an unpected format or length.');
                throw(ME);
            end
            
            value(1)= LimitSwitchState.CreateFromStatusByte(statusMessage(1));
            value(2) = LimitSwitchState.CreateFromStatusByte(statusMessage(2));
            value(3) = LimitSwitchState.CreateFromStatusByte(statusMessage(3));
            
            if any(value==LimitSwitchState.Unknown)
                ME = MException('LangMCL3:UnexpectedLimitSwitchState', ...
                    'The limitswitch status message contains un unexpected state character ("%s").', ...
                    statusMessage(1:end-1));
                throw(ME);
            end
        end
        
        
        
        function value = DecodeStatusMessage(obj, statusMessage)
            
            assert(length(statusMessage)==6);
            
            if(strcmp(statusMessage(1:5),'OK...'))
                
                % All is good but we don't know limit switch state
                value = 'Status is OK.';
                
            else
                
                try
                    
                    % Assume message encodes limit switch state
                    limitSwitchState = obj.CreateLimitSwitchState(statusMessage);
                    value = sprintf('Limit switch state is (%s, %s, %s).', ...
                        char(limitSwitchState(1)), ...
                        char(limitSwitchState(2)), ...
                        char(limitSwitchState(3)) ...
                        );
                    
                catch ex
                    
                    % Can't decode
                    value = sprintf('Unknown status message ("%s").',statusMessage(1:end-1));
                end
                
                
            end
            
        end
        
        
        function IssueLimitSwitchWarinings(obj, limitSwitchState)
            
            % X Axis
            switch(limitSwitchState(1))
                case LimitSwitchState.ZeroActive
                    warning('Zero limit switch on X axis activated during move.');
                case LimitSwitchState.EndActive
                    warning('End limit switch on X axis activated during move.');
            end
            
            % Y Axis
            switch(limitSwitchState(2))
                case LimitSwitchState.ZeroActive
                    warning('Zero limit switch on Y axis activated during move.');
                case LimitSwitchState.EndActive
                    warning('End limit switch on Y axis activated during move.');
            end
            
            % Z Axis
            switch(limitSwitchState(3))
                case LimitSwitchState.ZeroActive
                    warning('Zero limit switch on Z axis activated during move.');
                case LimitSwitchState.EndActive
                    warning('End limit switch on Z axis activated during move.');
            end
            
        end
        
        
        
    end
    
    methods (Static)
        
        
        
    end
    
    
    
    
    
    
end

