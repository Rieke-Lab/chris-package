classdef SingleConeStimuli < symphonyui.ui.Module
    properties (Access = private)
        tabPanel
        
        fittingPanel
        typingPanel
        stimulusPanel
        
        controller
    end
    
    properties (Constant)
        POSITION = [1000 600];
    end
    
    methods
        function createUi(obj, figureHandle)
            import appbox.*;
            import edu.washington.riekelab.baudin.modules.*;
            
            set(figureHandle, ...
                'Name', 'Single Cone Identifier', ...
                'Position', screenCenter(obj.POSITION(1), obj.POSITION(2)), ...
                'Resize', 'off');
            
            % make tabs
            obj.tabPanel = uix.TabPanel('Parent', figureHandle, ...
                'TabWidth', 130);
            fittingTab = uix.HBox('Parent', obj.tabPanel);
            typingTab = uix.HBox('Parent', obj.tabPanel);
            stimulusTab = uix.HBox('Parent', obj.tabPanel);
            obj.tabPanel.TabTitles = {'Create Map', 'Type Cones', 'Generate Stimulus'};
            obj.tabPanel.FontSize = 12;
            obj.tabPanel.TabEnables = {'on', 'off', 'off'};
            
            obj.controller = SingleConeStimuli.Controller(obj);
            
            % create panel objects
            obj.fittingPanel = SingleConeStimuli.Panels.FittingPanel(fittingTab, obj.tabPanel, obj.controller);
            obj.typingPanel = SingleConeStimuli.Panels.TypingPanel(typingTab, obj.tabPanel, obj.controller);
            obj.stimulusPanel = SingleConeStimuli.Panels.StimulusPanel(stimulusTab, obj.tabPanel, obj.controller);
        end
        
        function setTabFunctionality(obj, tabId, funct)
            if ischar(tabId)
                switch tabId
                    case 'fitting'
                        tabId = 1;
                    case 'typing'
                        tabId = 2;
                    case 'stimulus'
                        tabId = 3;s
                end
            end
            obj.tabPanel.TabEnables{tabId} = funct;
        end
        
        function activatePanel(obj, tabId)
            switch tabId
                case 'typing'
                    obj.setTabFunctionality(2, 'on');
                    obj.typingPanel.activate();
                case 'stimulus'
                    obj.setTabFunctionality(3, 'on');
                    obj.stimulusPanel.activate();
            end
        end
    end
end