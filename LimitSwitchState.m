%LIMITSWITCHSTATE LimitSwitchState enumeration 

% $Date: 2016-04-11 15:31:22 -0700 (Mon, 11 Apr 2016) $
% $Revision: 21 $
% $Author: plane $
% $HeadURL: http://cisvn.bccrc.ca/ENSC460/trunk/Matlab/LimitSwitchState.m $

classdef LimitSwitchState
    enumeration
        Unknown, Inactive, ZeroActive, EndActive
    end
    
    methods(Static)
        
        function obj = CreateFromStatusByte(statusByte)
            
            switch(statusByte)
                case '@'
                    obj = LimitSwitchState.Inactive;
                case 'A'
                    obj = LimitSwitchState.ZeroActive;
                case 'D'
                    obj = LimitSwitchState.EndActive;
                otherwise
                    obj = LimitSwitchState.Unknown;
            end;
            
        end
        
    end
end

