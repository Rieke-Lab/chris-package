function openShutter(~, evnt, varargin)
    hSI = evnt.Source.hSI;
    hSI.hShutters.shuttersTransition(1,true);
%     fprintf('\nShutter Open\n');
end