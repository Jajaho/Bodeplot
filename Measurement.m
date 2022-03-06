classdef Measurement < matlab.mixin.SetGet
    properties (SetAccess = immutable)
        % Settings (except 'lock frontpanel'):
        vpp             % peak to peak voltage
        voff            % voltage offset
        imp             % output impedance 
        freq            % measured frequency matrix
        sampleDistr     % distribution of samples over frequency range
        enhScaling      % experimental auto-scaling
        ch1Att          % channel 1 attenuation
        ch2Att          % channel 2 attenuation 
        bwLimit         % 20 MHz bandwith limit    

        dateTime

        % Calculated data:  
        mag
        magdB
        attdB
        phase
        omega

        % Data:
        ch1Vpp          % Vpp measured at channel 1
        ch2Vpp          % Vpp measured at channel 2
        rawPhase        % unprocessed phase data in degree
    end

    properties
        %name
        aborted = false;
    end

    properties (SetAccess = private)
        progress = 0;
    end

    properties (Dependent = true)
        fstart          % lowest measured frequency
        fstop           % highest measured frequency
        samples         % number of samples
    end

    methods 
        function obj = Measurement(scopeIp, fgenIp, vpp, voff, z, fstart, fstop, samples,...
                distr, ch1Att, ch2Att, bwLimit, lockPanels, enhancedScaling)
            if nargin == 0
                scopeIp = '192.168.0.151';
                fgenIp = '192.168.0.163';
                vpp = 1;
                voff = 0;
                z = 'HighZ';
                ch1Att = 1;
                ch2Att = 1;
                bwLimit = false;
                lockPanels = false;
                enhancedScaling = true;
                fstart = 50;
                fstop = 50000;
                samples = 10;
                distr = 'log';
            end
            if ~isnumeric(fstart)
                error('fstart must be of type numeric.')
            end
            if ~isnumeric(fstop)
                error('fstop must be of type numeric.')
            end
            if ~(isnumeric(samples) && samples > 0 && mod(samples, 1) == 0)
                error('samples must be a natural number > 0 of type numeric.')
            end
            if ~(isequal(distr, 'log') || isequal(distr, 'linear'))
                error('distr must be of either log or linear.')
            end

            %obj = obj@matlab.mixin.SetGet;     % implicitly called instead
            obj.dateTime = datetime;
            obj.vpp = vpp;
            obj.voff = voff;
            obj.imp = z;
            obj.sampleDistr = distr;
            obj.ch1Att = ch1Att;
            obj.ch2Att = ch2Att;
            obj.bwLimit = bwLimit;
            obj.enhScaling = enhancedScaling;
            obj.freq = Measurement.makeFreq(fstart, fstop, samples, distr);

            scope = Measurement.visaObj(scopeIp);
            fgen = Measurement.visaObj(fgenIp);
            scope.InputBufferSize = 2048;       % useless?!?!
            fopen(scope);
            fopen(fgen);
            Measurement.setupInstr(scope, fgen, lockPanels, z, ch1Att, ch2Att, bwLimit)
            [obj.ch1Vpp, obj.ch2Vpp, obj.rawPhase] = sweep(obj, scope, fgen, obj.freq, samples, vpp, voff, enhancedScaling);
            [obj.mag, obj.magdB, obj.attdB, obj.phase, obj.omega] = Measurement.processData(obj.ch1Vpp, obj.ch2Vpp, obj.rawPhase, obj.freq);
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

        function [ch1Vpp, ch2Vpp, phase] = sweep(obj, scope, fgen, freq, samples, vpp, voff, eas)
            ch1Vpp = zeros(1, samples);
            ch2Vpp = zeros(1, samples);
            phase = zeros(1, samples);
            for k = 1:samples
                if obj.aborted
                    break
                end
    
                pause(0.1);
                fprintf(fgen, ':OUTP1 OFF' );
                % set CH1 wafeform to sinusoidal with the specified frequency, amplitude, offset 
                fprintf(fgen, append(':SOUR1:APPL:SIN ', int2str(freq(k)), ',', int2str(vpp), ',', int2str(voff), ',0'));
                pause(0.1); % pause needed, otherwise new setting would not affect output signal
                fprintf(fgen, ':OUTP1 ON' );
    
                if eas  % enhanced auto-scaling
                    if k == 1
                        fprintf(scope, ':AUToscale' );
                        pause(9); % auto-scale takes about 9 sec
                        fprintf(scope, ':CHAN1:OFFS 0' );
                        fprintf(scope, ':CHAN2:OFFS 0' );
                        
                        fprintf(scope, ':MEAS:ITEM? VPP,CHAN1' );
                        ch1Vpp(1) = str2double(fscanf(scope, '%s' ));
                        fprintf(scope, append(':CHAN1:SCAL ', sprintf('%0.7e', Measurement.calcVScale(ch1Vpp(k)))));
                    end
                    period = 1/freq(k);
                    nP = 2; % number of periods on the screen
                    timescale = round(period/12*nP, 9);
                    fprintf(scope, append(':TIM:MAIN:SCAL ', sprintf('%0.7e', timescale)));
                    
                    pause(0.1)

                    fprintf(scope, ':MEAS:ITEM? VPP,CHAN1' );
                    ch1Vpp(k) = str2double(fscanf(scope, '%s' ));
                    fprintf(scope, ':MEAS:ITEM? VPP,CHAN2' );
                    ch2Vpp(k) = str2double(fscanf(scope, '%s' ));
                    
                    fprintf(scope, append(':CHAN2:SCAL ', sprintf('%0.7e', Measurement.calcVScale(ch2Vpp(k)))));
                    pause(1.5)
                else
                    fprintf(scope, ':AUToscale' );
                    pause(9);  % auto-scale takes about 8.6 sec
                    fprintf(scope, ':MEAS:ITEM? VPP,CHAN1' );
                    ch1Vpp(k) = str2double(fscanf(scope, '%s' ));
                    fprintf(scope, ':MEAS:ITEM? VPP,CHAN2' );
                    ch2Vpp(k) = str2double(fscanf(scope, '%s' ));
                end
                fprintf(scope, ':MEAS:ITEM? RPH' );
                phase(k) = str2double(fscanf(scope, '%s' ));
                obj.progress = k;
            end
            Measurement.cleanup(scope, fgen)
        end
    end

    methods (Static)

        function instr = visaObj(ip)
            % Find VISA-TCPIP objects.
            instr = instrfind('Type', 'visa-tcpip', 'RsrcName', append('TCPIP0::', ip, '::inst0::INSTR'), 'Tag', '');
            % Create the VISA-TCPIP object if it does not exist
            % otherwise use the object that was found.
            if isempty(instr)
                instr = visa('NI', append('TCPIP0::', ip, '::inst0::INSTR'));
            else
                fclose(instr);
                instr = instr(1);
            end
        end

        function setupInstr(scope, fgen, lockPanels, z, ch1Att, ch2Att, bwLimit)
            % lock frontpanels
            if(lockPanels)
                fprintf(fgen, ':SYSTEM:KLOCK ALL ON' );
                fprintf(scope, ':SYST:LOCK ON' );
            else
                fprintf(fgen, ':SYSTEM:KLOCK ALL OFF' );
                fprintf(scope, ':SYST:LOCK OFF' );
            end
            % set CH1 output impedance
            if isequal(z, 'HighZ')
                fprintf(fgen, ':OUTP1:IMP INF' );    
            else
                fprintf(fgen, append(':OUTP1:IMP ', z));
            end
            fprintf(scope, ':CHAN1:COUP DC' );
            fprintf(scope, ':CHAN2:COUP DC' );
            fprintf(scope, append(':CHAN1:PROB ', int2str(ch1Att)));
            fprintf(scope, append(':CHAN2:PROB ', int2str(ch2Att)));
            % enable/disable 20 MHz bandwidthlimit
            if bwLimit
                fprintf(scope, ':CHAN1:BWL 20M' ); 
                fprintf(scope, ':CHAN2:BWL 20M' ); 
            else
                fprintf(scope, ':CHAN1:BWL OFF' ); 
                fprintf(scope, ':CHAN2:BWL OFF' ); 
            end
            % MEASURE
            fprintf(scope, ':MEAS:CLE ALL' );
            fprintf(scope, ':MEAS:SET:PSA CHAN1' );   % Set source A of phase measurement to CH1
            fprintf(scope, ':MEAS:SET:PSB CHAN2' );   % Set source B of phase measurement to CH2
            fprintf(scope, ':CHAN1:DISP ON' );
            fprintf(scope, ':CHAN2:DISP ON' );            
        end

        function freq = makeFreq(fstart, fstop, samples, distr)
            if isequal(distr, 'log')
                freq = logspace(log10(fstart), log10(fstop), samples);
            else
                freq = linspace(fstart, fstop, samples);
            end               
        end
        % Calculates and rounds the vertical scale so that the curve
        % occupies half of the screen, used for fast auto-scaling
        function scale = calcVScale(Vpp)
            % *2 because half of the screen, /8 because the screen fits 8 divisions
            scale = Vpp*0.25;   
            if scale < 0.001
                scale = 0.001;
            elseif scale >= 0.001 || scale < 1 
                scale = round(scale, 3);
            elseif scale >= 1 || scale < 10 
                scale = round(scale, 3);
            elseif scale >= 10
                scale = 10;
            end
        end

        % Code to be executed after finishing measurements
        function cleanup(scope, fgen)
            fprintf(scope, ':OUTP1 OFF' );
            % unlock frontpanels
            fprintf(scope, ':SYST:LOCK OFF'); 
            fprintf(fgen, ':SYSTEM:KLOCK ALL OFF'); 
            fclose(fgen);
            fclose(scope);
            delete(fgen);
            delete(scope);
        end
        
        % Processing of aquired measurements
        function [mag, magdB, attdB, phase, omega] = processData(vpp1, vpp2, rawPhase, freq)
            mag = vpp2./vpp1;
            magdB = 20.*log10(mag);
            attdB = -magdB;
            omega = 2*pi.*freq;
            pha = rawPhase;
            pha(pha > 1000) = NaN;     % catch failed measurements
            phase = pha./180.*pi;
        end
    end
end