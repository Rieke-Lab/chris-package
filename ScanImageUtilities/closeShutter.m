function closeShutter(~, evnt, varargin)
    hSI = evnt.Source.hSI;
    hSI.hShutters.shuttersTransition(1,false);
%     fprintf('\nShutter Close\n');
end