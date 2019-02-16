classdef NatImageDynamicClamp < edu.washington.riekelab.protocols.RiekeLabProtocol
    
    properties
        gExcMultiplier = 1
        gInhMultiplier = 1
        ConductanceSet = 'ONparasol_20160112Ec1'
        ExcConductance = 'Image' %Constant, overridden by interleaves below
        InhConductance = 'Image' %Constant, overridden by interleaves below
        InterleaveImage = false; %{image-image / disc-disc / image-disc / disc-image}
        InterleaveTonic = false; %{image-image / image-tonic / tonic-image}
        ExcReversal = 10;
        InhReversal = -70;
        MeanConductanceTrace = true %Average conductance trace (over trials) or randomly choose individual trials
        
        amp                             % Input amplifier
        numberOfAverages = uint16(5)    % Number of epochs
        interpulseInterval = 0.2          % Duration between pulses (s)
    end
    
    properties (Hidden)
        ampType
        ConductanceSetType = symphonyui.core.PropertyType('char', 'row',...
            {'ONparasol_20160112Ec1','ONparasol_20160112Ec3','ONparasol_20160324Ec2',...
            'OFFparasol_20160112Ec2','OFFparasol_20160324Ec4'})
        ExcConductanceType = symphonyui.core.PropertyType('char', 'row', {'Image', 'Disc', 'Tonic'})
        InhConductanceType = symphonyui.core.PropertyType('char', 'row', {'Image', 'Disc', 'Tonic'})
        
        stimSequence %struct with fields .exc and .inh (vals cell array of strings, image, disc, or tonic)
        imageSequence %image ids
        currentImageIndex
        
        currentConductanceStim %struct with fields .exc and .inh (vals str: image, disc, or tonic)
        currentConductanceTrial %struct with fields .exc and .inh (vals int)
        
        resourcesDir
    end
    
    properties (Hidden, Transient)
        analysisFigure
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            obj.resourcesDir = 'C:\Users\Public\Documents\turner-package\resources\gClampStims\NIFgClampTraces\';
            fileID = [obj.ConductanceSet,'.mat'];
            load(fullfile(obj.resourcesDir, fileID));   
            obj.imageSequence = res.imageIndex;
            
            %create conductance label sequence
            if obj.InterleaveImage
                %will cycle through to apply to both sequences
                %to get all the appropriate pairings
                obj.stimSequence.exc = {'Image', 'Image', 'Disc', 'Disc'};
                obj.stimSequence.inh = {'Image', 'Disc','Image','Disc'};
            elseif obj.InterleaveTonic
               obj.stimSequence.exc = {'Image', 'Tonic', 'Image'};
               obj.stimSequence.inh = {'Image', 'Image', 'Tonic'};
            else
                obj.stimSequence.exc = {obj.ExcConductance};
                obj.stimSequence.inh = {obj.InhConductance};
            end

            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.turner.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp),'groupBy',{'currentImageIndex'});
            obj.showFigure('edu.washington.riekelab.turner.figures.DynamicClampFigure',...
                obj.rig.getDevice(obj.amp), obj.rig.getDevice('Excitatory conductance'),...
                obj.rig.getDevice('Inhibitory conductance'), obj.rig.getDevice('Injected current'),...
                obj.ExcReversal, obj.InhReversal);
            
            % custom figure handler
            if isempty(obj.analysisFigure) || ~isvalid(obj.analysisFigure)
                obj.analysisFigure = obj.showFigure('symphonyui.builtin.figures.CustomFigure', @obj.NIFgClamp);
                f = obj.analysisFigure.getFigureHandle();
                set(f, 'Name', 'NIF gClamp');
                obj.analysisFigure.userData.iiCount = 0;
                obj.analysisFigure.userData.ddCount = 0;
                obj.analysisFigure.userData.idCount = 0;
                obj.analysisFigure.userData.diCount = 0;
                obj.analysisFigure.userData.axesHandle = axes('Parent', f,...
                    'FontName', get(f, 'DefaultUicontrolFontName'),...
                    'FontSize', get(f, 'DefaultUicontrolFontSize'), ...
                    'XTickMode', 'auto');
                xlabel(obj.analysisFigure.userData.axesHandle, 'Image');
                ylabel(obj.analysisFigure.userData.axesHandle, 'Disc');
            end
            
            %set the backgrounds on the conductance commands
            %0.05 V command per 1 nS conductance
            excBackground = mean(mean(res.exc.image{1}(:,1:res.stimStart))) .* 0.05;
            inhBackground = mean(mean(res.inh.image{1}(:,1:res.stimStart))) .* 0.05;
            obj.rig.getDevice('Excitatory conductance').background = symphonyui.core.Measurement(excBackground, 'V');
            obj.rig.getDevice('Inhibitory conductance').background = symphonyui.core.Measurement(inhBackground, 'V');
        end
        
        function NIFgClamp(obj, ~, epoch) %online analysis function
            response = epoch.getResponse(obj.rig.getDevice(obj.amp));
            Vdata = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            
            axesHandle = obj.analysisFigure.userData.axesHandle;
            iiCount = obj.analysisFigure.userData.iiCount;
            ddCount = obj.analysisFigure.userData.ddCount;
            idCount = obj.analysisFigure.userData.idCount;
            diCount = obj.analysisFigure.userData.diCount;
            
            fileID = [obj.ConductanceSet,'.mat'];
            load(fullfile(obj.resourcesDir, fileID));
            
            %get iClamp spikes
            threshold = -20; %mV - hardcoded for now, could be param?
            spikesUp=edu.washington.riekelab.turner.utils.getThresCross(Vdata,threshold,1);
            spikesDown=edu.washington.riekelab.turner.utils.getThresCross(Vdata,threshold,-1);
            newSpikeCount = length(spikesUp(spikesUp>res.stimStart & spikesUp<res.stimEnd));

            if strcmp(obj.currentConductanceStim.exc,'Image')
                if strcmp(obj.currentConductanceStim.inh,'Image')
                    iiCount(obj.currentImageIndex) = newSpikeCount;
                elseif strcmp(obj.currentConductanceStim.inh,'Disc')
                    idCount(obj.currentImageIndex) = newSpikeCount;
                end
            elseif strcmp(obj.currentConductanceStim.exc,'Disc')
                if strcmp(obj.currentConductanceStim.inh,'Image')
                    diCount(obj.currentImageIndex) = newSpikeCount;
                elseif strcmp(obj.currentConductanceStim.inh,'Disc')
                    ddCount(obj.currentImageIndex) = newSpikeCount;
                end
            end
            
            hd = line(res.spikes.image,res.spikes.disc,'Parent',axesHandle);
            set(hd,'Color','g','LineStyle','none','Marker','x')
            yUp = 1.3*max([res.spikes.image,res.spikes.disc]);
            hu = line([0 yUp],[0 yUp],'Parent',axesHandle);
            set(hu,'Color','k','LineStyle','--')
            
            if length(iiCount) == length(ddCount)
                hd = line(iiCount,ddCount,'Parent',axesHandle);
                set(hd,'Color','k','LineStyle','none','Marker','o')
            end
            
            obj.analysisFigure.userData.axesHandle = axesHandle;
            obj.analysisFigure.userData.iiCount = iiCount;
            obj.analysisFigure.userData.ddCount = ddCount;
            obj.analysisFigure.userData.idCount = idCount;
            obj.analysisFigure.userData.diCount = diCount;
        end
        
        function stim = createConductanceStimulus(obj,conductance)
            %conductance is string: 'exc' or 'inh'
            fileID = [obj.ConductanceSet,'.mat'];
            load(fullfile(obj.resourcesDir, fileID));   
            gen = symphonyui.builtin.stimuli.WaveformGenerator();
            gen.sampleRate = obj.sampleRate;
            gen.units = 'V';
            if strcmp(obj.currentConductanceStim.(conductance),'Image')
                if (obj.MeanConductanceTrace)
                    obj.currentConductanceTrial.(conductance) = [];
                    newConductanceTrace = mean(res.(conductance).image{obj.currentImageIndex});
                else
                    obj.currentConductanceTrial.(conductance) = ...
                        randsample(1:size(res.(conductance).image{obj.currentImageIndex},1),1);
                    newConductanceTrace = res.(conductance).image{obj.currentImageIndex}(obj.currentConductanceTrial.(conductance),:);
                end
            elseif strcmp(obj.currentConductanceStim.(conductance),'Disc')
                if (obj.MeanConductanceTrace)
                    obj.currentConductanceTrial.(conductance) = [];
                    newConductanceTrace = mean(res.(conductance).disc{obj.currentImageIndex});
                else
                    obj.currentConductanceTrial.(conductance) = ...
                        randsample(1:size(res.(conductance).disc{obj.currentImageIndex},1),1);
                    newConductanceTrace = res.(conductance).disc{obj.currentImageIndex}(obj.currentConductanceTrial.(conductance),:);
                end
            elseif strcmp(obj.currentConductanceStim.(conductance),'Tonic')
                if (obj.MeanConductanceTrace)
                    obj.currentConductanceTrial.(conductance) = [];
                    temp = mean(res.(conductance).image{obj.currentImageIndex});
                    newConductanceTrace = mean(temp(1:res.stimStart)) .* ones(size(temp));
                else
                    obj.currentConductanceTrial.(conductance) = ...
                        randsample(1:size(res.(conductance).image{obj.currentImageIndex},1),1);
                    temp = res.(conductance).image{obj.currentImageIndex}(obj.currentConductanceTrial.(conductance),:);
                    newConductanceTrace = mean(temp(1:res.stimStart)) .* ones(size(temp));
                end     
            end
            if strcmp(conductance,'exc')
                newConductanceTrace = obj.gExcMultiplier .* newConductanceTrace; %nS
            elseif strcmp(conductance,'inh')
                newConductanceTrace = obj.gInhMultiplier .* newConductanceTrace; %nS
            end

            %map conductance (nS) to DAC output (V) to match expectation of
            %Arduino...
            % 200 nS = 10 V, 1 nS = 0.05 V
            mappedConductanceTrace = newConductanceTrace .* 0.05;
            if any(mappedConductanceTrace > 10)
                mappedConductanceTrace = zeros(1,length(mappedConductanceTrace));
                error(['G_',conductance, ': voltage command out of range!'])
            end
            gen.waveshape = mappedConductanceTrace;
            stim = gen.generate();
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            %get image from sequence
            tempIndex = floor(obj.numEpochsCompleted / length(obj.stimSequence.exc));
            drawIndex = mod(tempIndex, length(obj.imageSequence)) + 1;
            % Randomize the image sequence order at the beginning of each image sequence
            if drawIndex == 1
                obj.imageSequence = randsample(obj.imageSequence, length(obj.imageSequence));
            end
            obj.currentImageIndex = drawIndex; %index of image in imageSequence of gClamp stim file
            
            % get conductance stim from sequence
            drawIndex = mod(obj.numEpochsCompleted,length(obj.stimSequence.exc)) + 1;
            obj.currentConductanceStim.exc = obj.stimSequence.exc{drawIndex};
            obj.currentConductanceStim.inh = obj.stimSequence.inh{drawIndex};
            
            epoch.addStimulus(obj.rig.getDevice('Excitatory conductance'), obj.createConductanceStimulus('exc'));
            epoch.addStimulus(obj.rig.getDevice('Inhibitory conductance'), obj.createConductanceStimulus('inh'));
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            epoch.addResponse(obj.rig.getDevice('Injected current'));
            
            epoch.addParameter('currentGexcStim', obj.currentConductanceStim.exc);
            epoch.addParameter('currentGinhStim', obj.currentConductanceStim.inh);
            
            epoch.addParameter('currentGexcTrial', obj.currentConductanceTrial.exc);
            epoch.addParameter('currentGinhTrial', obj.currentConductanceTrial.inh);
            epoch.addParameter('currentImageIndex', obj.currentImageIndex);
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            
            device = obj.rig.getDevice(obj.amp);
            interval.addDirectCurrentStimulus(device, device.background, obj.interpulseInterval, obj.sampleRate);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
        
    end
    
end

