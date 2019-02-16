% will serve as the back-end for the Single Cone Stimuli symphony module
classdef Controller < handle
    properties
        module
        
        baseMap
        stixelSize
        
        userDefinedConeLocations
        fitCones
        
        potentialFitCones
    end
    
    properties (Constant)
        CONE_TYPE_COLOR_LOOKUP = edu.washington.riekelab.baudin.modules.SingleConeStimuli.Utils.coneTypeColorLookup();
    end
    
    properties (Dependent)
       numCones 
    end
    
    events
        updatedTyping
    end
    
    methods
        % CONSTRUCTION AND RESETTING
        function obj = Controller(module)
            obj.module = module;
            obj.userDefinedConeLocations = {};
            obj.fitCones = {};
        end
        
        function reset(obj)
            obj.baseMap = [];
            obj.stixelSize = [];
            obj.resetConeLocations();
        end
        
        function resetConeLocations(obj)
            obj.userDefinedConeLocations = {};
            obj.fitCones = {};
        end
        
        % CONE MAP VISUALIZATION
        function imArray = getConeMap(obj)
            imArray = obj.baseMap;
        end
        
        function imArray = getConeMapWithCones(obj)
            if isempty(obj.fitCones)
                cones = obj.potentialFitCones;
            else
                cones = obj.fitCones;
            end
            
            imArray = obj.baseMap;
            for i = 1:numel(cones)
                imArray = insertShape(imArray, 'circle', ...
                    cones{i}.getCirclePositionForPlot(), ...
                    'LineWidth', 2, ...
                    'Color', obj.CONE_TYPE_COLOR_LOOKUP(cones{i}.type));
            end
        end
        
        % CONE FITTING TAB
        function loadConeMap(obj, fullFilePath)
            obj.reset();
            imData = load(fullFilePath);
            obj.baseMap = imData.coneMap;
            obj.stixelSize = imData.stixelSize;
        end
        
        function addUserDefinedConeLocations(obj, locations)
            obj.userDefinedConeLocations = locations;
        end
        
        function acceptFit(obj)
            obj.fitCones = obj.potentialFitCones;
            obj.module.activatePanel('typing');
        end
        
        function runConeLocationFit(obj)
            if edu.washington.riekelab.baudin.modules.SingleConeStimuli.Development.Debug()
                obj.potentialFitCones = ...
                    edu.washington.riekelab.baudin.modules.SingleConeStimuli.Development.DebugConeFits();
                return;
            end
            
            disp('Add call to actual fitting function');
        end
        
        % CONE TYPING TAB        
        function performTyping(obj)
            acqSer = obj.module.acquisitionService;
            acqSer.selectProtocol('edu.washington.riekelab.baudin.protocols.SingleConeTyping');
            [centers, radii] = obj.constructConeLocationMatrices();
            acqSer.setProtocolProperty('coneCenters', centers);
            acqSer.setProtocolProperty('coneRadii', radii);
            resultsFileName = tempname();
            acqSer.setProtocolProperty('tempFileName', resultsFileName);
            acqSer.viewOnly();
            
            analysisResults = load(resultFileName);
            delete(resultsFileName);
            
            notify(obj, 'updatedTyping');
        end
        
        function [centers, radii] = constructConeLocationMatrices(obj)
            centers = zeros(obj.numCones, 2);
            radii = zeros(1, obj.numCones);
            for i = 1:obj.numCones
                centers(i, :) = obj.fitCones{i}.getCenterPosition();
                radii(i) = obj.fitCones{i}.getRadius();
            end
        end
        
        function generateTypingStimulus(obj)
            
        end
        
        function runTypingStimulus(obj)
            
        end
        
        function evaluateTypingResponses(obj)
            
        end
        
        function tf =  conesAreTyped(obj)
            tf = false;
            for i = 1:numel(obj.fitCones)
               if ~strcmp(obj.fitCones{i}.type, 'unknown')
                   tf = true;
                   return;
               end
            end
        end
        
        % STIMULUS GENERATION TAB
        function types = getConeTypes(obj)
           types = cell(1, obj.numCones);
           for i = 1:obj.numCones
              types{i} = obj.fitCones{i}.type; 
           end          
        end
        
        function deliverStimulus(obj, centers, radii, types)
            acqSer = obj.module.acquisitionService;
            acqSer.setProtocolProperty('centers', center);
            acqSer.setProtocolProperty('radii', radii);
            acqSer.setProtocolProperty('types', types);
            acqSer.record();
        end
    end
    
    methods
        function value = get.numCones(obj)
            value = numel(obj.fitCones);
        end
    end
end