function acquisitionShutterControl(src, evnt, varargin)

    hSI = evnt.Source.hSI;
    
    switch evnt.EventName
        case 'acqStart'
            hSI.hShutters.shuttersTransition(1,true);
%             fprintf('\nShutters Open\n');
        case {'acqDone' 'acqAbort'}
            hSI.hShutters.shuttersTransition(1,false);
%             fprintf('\nShutters Close\n');
        otherwise
            % Do Nothing.
    end

end