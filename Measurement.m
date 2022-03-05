classdef Measurement < matlab.mixin.SetGet
    properties (SetAccess = immutable)
        % Settings:
        vpp             % peak to peak voltage
        voff            % voltage offset
        imp             % output impedance 
        freq            % measured frequency matrix
        sampleDistr     % distribution of samples over frequency range
        enhScaling      % experimental auto-scaling
        ch1Att          % channel 1 attenuation
        ch2Att          % channel 2 attenuation 
        bandLim         % 20 MHz bandwith limit    

        % Data:
        vpp1            % Vpp measured at channel 1
        vpp2            % Vpp measured at channel 2
        rawPha          % unprocessed phase data
    end

    properties (Dependent = true)
        fstart          % lowest measured frequency
        fstop           % highest measured frequency
        samples         % number of samples
    end

    methods 
        function obj = Measurement(vpp, voff, z, fstart, fstop, samples,...
                distr, ch1At, ch2At, bLim, lock, enhSc)
            obj.vpp = vpp;
            obj.voff = voff;
            obj.imp = z;

        end

        function value = get.fstart(obj)
            value = obj.freq(1);
        end

        function value = get.fstop(obj)
            value = obj.freq(length(obj.freq));
        end

        function value = get.samples(obj)
            value = length(obj.freq);
        end
    end
end