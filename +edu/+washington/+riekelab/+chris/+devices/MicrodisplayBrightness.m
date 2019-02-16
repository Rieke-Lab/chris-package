classdef MicrodisplayBrightness < uint8
    
    enumeration
        MAXIMUM     (23)
        HIGH        (25)
        MEDIUM      (73)
        LOW         (120)
        MINIMUM     (229)
    end
    
    methods
    
        function c = char(obj)
            import edu.washington.riekelab.devices.MicrodisplayBrightness;
            
            switch obj
                case MicrodisplayBrightness.MAXIMUM
                    c = 'maximum';
                case MicrodisplayBrightness.HIGH
                    c = 'high';
                case MicrodisplayBrightness.MEDIUM
                    c = 'medium';
                case MicrodisplayBrightness.LOW
                    c = 'low';
                case MicrodisplayBrightness.MINIMUM
                    c = 'minimum';
                otherwise
                    c = 'unknown';
            end
        end
        
    end
    
end

