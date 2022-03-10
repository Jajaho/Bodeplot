classdef Measurement < matlab.mixin.SetGet
    % Measurement class for frequency response measurements, Bode Plots
    %
    %   m1 = Measurement()
    %
    %   m1.makeMeasurement(scopeIp, fgenIp)
    %
    % Jakob Holz 2022

    properties 
        % Settings (except ip-adresses):
        samples         % Number of samples
        distr           % Distribution of samples over frequency range
        fstart          % Lowest measured frequency
        fstop           % Highest measured frequency
        vpp             % Peak to peak voltage
        voff            % Voltage offset
        imp             % Output impedance 
        eas             % Enhanced auto-scaling, faster, wider frequency range
        ch1Att          % Channel 1 attenuation
        ch2Att          % Channel 2 attenuation 
        bwl             % 20 MHz bandwith limit  
        lock            % Lock frontpanels
    end

    properties (SetAccess = private)
        %finished = false;
        aborted = false;
        progress = 0;       % Progress of the  measurement in percent
        time                % Date and time when the measurement was taken
        % Measured data:
        ch1Vpp              % Vpp measured at channel 1
        ch2Vpp              % Vpp measured at channel 2
        rawPhase            % unprocessed phase data in degree
        % Calculated data:  
        mag                 % Magnitude of ch2Vpp/ch1Vpp
        magdB               % Magnitude in dB
        attdB               % Attenuation in dB
        phase               % Phase
        freq                % Frequency 
        omega               % Angular frequency
    end

    methods 
        function obj = Measurement(samples, fstart, fstop, distr, ch1Att,...
                ch2Att, bwLimit, enhancedScaling, vpp, voff, imp, lockPanels)
            if nargin == 0
                return
            elseif nargin == 1
                vpp = 1;
                voff = 0;
                imp = 'HighZ';
                ch1Att = 1;
                ch2Att = 1;
                bwLimit = true;
                lockPanels = false;
                enhancedScaling = true;
                fstart = 50;
                fstop = 5000000;
                distr = 'log';
            end

            obj.fstart = fstart;
            obj.fstop = fstop;
            obj.samples = samples;
            obj.distr = distr;
            obj.vpp = vpp;
            obj.voff = voff;
            obj.imp = imp;
            obj.ch1Att = ch1Att;
            obj.ch2Att = ch2Att;
            obj.bwl = bwLimit;
            obj.lock = lockPanels;
            obj.eas = enhancedScaling;
        end

        function makeMeasurement(obj, scopeIp, fgenIp)
            obj.time = datetime;
            obj.freq = Measurement.makeFreq(obj.fstart, obj.fstop, obj.samples, obj.distr);
            scope = Measurement.visaObj(scopeIp);
            fgen = Measurement.visaObj(fgenIp);
            scope.InputBufferSize = 2048;       % useless?!?!
            fopen(scope);
            fopen(fgen);
            Measurement.setupInstr(scope, fgen, obj.lock, obj.imp, obj.ch1Att, obj.ch2Att, obj.bwl)
            [obj.ch1Vpp, obj.ch2Vpp, obj.rawPhase] = sweep(obj, scope, fgen, obj.freq, obj.samples, obj.vpp, obj.voff, obj.eas);
            [obj.mag, obj.magdB, obj.attdB, obj.phase, obj.omega] = Measurement.processData(obj.ch1Vpp, obj.ch2Vpp, obj.rawPhase, obj.freq);
        end

        function abortMeasurement(obj)
            obj.aborted = true;
        end

        %% Setter methods

        function set.samples(obj, samples)
            if isnumeric(samples) && samples > 0
                obj.samples = samples;
            else
                error('samples must a positive integer.')
            end
        end

        function set.distr(obj, distr)
            if isequal(distr, 'log') || isequal(distr, 'linear')
                obj.distr = distr;
            else
                error('distr must be of either log or linear.')
            end
        end

        function set.fstart(obj, fstart)
            if isnumeric(fstart)
                obj.fstart = fstart;
            else
                error('fstart must be of type numeric.')
            end
        end

        function set.fstop(obj, fstop)
            if isnumeric(fstop)
                obj.fstop = fstop;
            else
                error('fstop must be numeric.')
            end
        end

        function set.vpp(obj, vpp)
            if isnumeric(vpp) && vpp > 0
                obj.vpp = vpp;
            else
                error('The peak to peak voltage (vpp) must be positive numeric value.')
            end
        end

        function set.voff(obj, voff)
            if isnumeric(voff)
                obj.voff = voff;
            else
                error('The offset voltage (voff) must be numeric.')
            end
        end

        function set.imp(obj, imp)
            if isequal(imp,'HighZ') || isequal(imp,'50 Ohm') || isnumeric(imp)
                obj.imp = imp;
            else
                error('The output impedance (imp) must be numeric.')
            end
        end

        function set.ch1Att(obj, ch1Att)
            if isnumeric(ch1Att)
                obj.ch1Att = ch1Att;
            else
                error('ch1Att must be numeric.')
            end
        end

        function set.ch2Att(obj, ch2Att)
            if isnumeric(ch2Att)
                obj.ch2Att = ch2Att;
            else
                error('ch2Att must be numeric.')
            end
        end

        function set.bwl(obj, bwl)
            if islogical(bwl)
                obj.bwl = bwl;
            else
                error('Bandwidth Limit (bwl) must be logical type.')
            end
        end

        function set.lock(obj, lock)
            if islogical(lock)
                obj.lock = lock;
            else
                error('Lock frontpanels (lock) must be logical type.')
            end
        end

        function set.eas(obj, enhScaling)
            if islogical(enhScaling)
                obj.eas = enhScaling;
            else
                error('Enhanced Auto-Scaling (eas) must be logical type.')
            end
        end
    end

    methods (Access = private)
        function [ch1Vpp, ch2Vpp, phase] = sweep(obj, scope, fgen, freq, samples, vpp, voff, eas)
            ch1Vpp(1:samples) = NaN;
            ch2Vpp(1:samples) = NaN;
            phase(1:samples) = NaN;
            for k = 1:samples
                if obj.aborted
                    break
                end
                fprintf(fgen, append(':SOUR1:APPL:SIN ', num2str(freq(k)), ',', num2str(vpp), ',', num2str(voff), ',0'));
                if eas  % enhanced auto-scaling
                    if k == 1
                        fprintf(fgen, ':OUTP1 ON' );
                        pause(0.5)
                        %fprintf(scope, ':AUToscale' );
                        fprintf(scope, ':TRIG:MODE: EDGE');
                        fprintf(scope, ':TRIG:EDG:SOUR CHAN1');
                        fprintf(scope, ':TRIG:EDG:SLOP POS');
                        fprintf(scope, ':TRIG:EDG:LEV 0');
                        fprintf(scope, ':TRIG:SWE: AUTO');
                        fprintf(scope, ':TRIG:NREJ ON');
                        pause(1); % auto-scale takes about 9 sec
                        fprintf(scope, ':CHAN1:OFFS 0');
                        fprintf(scope, ':CHAN2:OFFS 0');
                        
                        fprintf(scope, append(':CHAN1:SCAL ', sprintf('%0.7e', Measurement.calcVScale(vpp, obj.ch1Att))));
%                        ch1Vpp(1) = query(scope, ':MEAS:ITEM? VPP,CHAN1');
%                        fprintf(scope, ':MEAS:ITEM? VPP,CHAN1' );
%                        ch1Vpp(1) = str2double(fscanf(scope, '%s' ));
%                        fprintf(scope, append(':CHAN1:SCAL ', sprintf('%0.7e', Measurement.calcVScale(ch1Vpp(k)))));
                    end
                    if freq(k) > 75e3
                        fprintf(scope, ':TRIG:COUP: LFR');
                    else
                        fprintf(scope, ':TRIG:COUP: HFR');
                    end
                    period = 1/freq(k);
                    nP = 2; % number of periods on the screen
                    timescale = round(period/12*nP, 9);
                    fprintf(scope, append(':TIM:MAIN:SCAL ', sprintf('%0.7e', timescale)));
                    if k == 1
                        Measurement.findVScale(scope, obj.ch2Att)
                    end
                    
                    pause(0.1)
                    fprintf(scope, ':MEAS:ITEM? VPP,CHAN1');
                    ch1Vpp(k) = str2double(fscanf(scope, '%s'));
                    fprintf(scope, ':MEAS:ITEM? VPP,CHAN2' );
                    ch2Vpp(k) = str2double(fscanf(scope, '%s'));
                    fprintf(scope, append(':CHAN1:SCAL ', sprintf('%0.7e', Measurement.calcVScale(ch1Vpp(k), obj.ch1Att))));
                    fprintf(scope, append(':CHAN2:SCAL ', sprintf('%0.7e', Measurement.calcVScale(ch2Vpp(k), obj.ch2Att))));
                    pause(1.5)
                else
                    if k == 1
                        fprintf(fgen, ':OUTP1 ON');
                        pause(0.5)
                    end
                    fprintf(scope, ':AUToscale');
                    pause(9);  % auto-scale takes about 8.6 sec
                end
                fprintf(scope, ':MEAS:ITEM? VPP,CHAN1');
                ch1Vpp(k) = str2double(fscanf(scope, '%s'));
                fprintf(scope, ':MEAS:ITEM? VPP,CHAN2' );
                ch2Vpp(k) = str2double(fscanf(scope, '%s'));
%                ch1Vpp(k) = query(scope, ':MEAS:ITEM? VPP,CHAN1', '%s', '%c');
%                ch2Vpp(k) = query(scope, ':MEAS:ITEM? VPP,CHAN2', '%s', '%c');
%                phase(k) = query(scope, ':MEAS:ITEM? RPH', '%s', '%c');
                fprintf(scope, ':MEAS:ITEM? RPH');
                phase(k) = str2double(fscanf(scope, '%s'));
                obj.progress = round(k/samples*100);
            end
            Measurement.cleanup(scope, fgen)
        end
    end

    methods (Access = private, Static)
        function setupInstr(scope, fgen, lockPanels, z, ch1Att, ch2Att, bwLimit)
            % lock frontpanels
            if(lockPanels)
                fprintf(fgen, ':SYSTEM:KLOCK ALL ON');
                fprintf(scope, ':SYST:LOCK ON');
            else
                fprintf(fgen, ':SYSTEM:KLOCK ALL OFF');
                fprintf(scope, ':SYST:LOCK OFF');
            end
            % set CH1 output impedance
            if isequal(z, 'HighZ')
                fprintf(fgen, ':OUTP1:IMP INF' );    
            else
                fprintf(fgen, append(':OUTP1:IMP ', z));
            end
            fprintf(scope, ':CHAN1:COUP DC');
            fprintf(scope, ':CHAN2:COUP DC');
            fprintf(scope, append(':CHAN1:PROB ', int2str(ch1Att)));
            fprintf(scope, append(':CHAN2:PROB ', int2str(ch2Att)));
            % enable/disable 20 MHz bandwidthlimit
            if bwLimit
                fprintf(scope, ':CHAN1:BWL 20M'); 
                fprintf(scope, ':CHAN2:BWL 20M'); 
            else
                fprintf(scope, ':CHAN1:BWL OFF'); 
                fprintf(scope, ':CHAN2:BWL OFF'); 
            end
            % MEASURE
            fprintf(scope, ':MEAS:CLE ALL');
            fprintf(scope, ':MEAS:SET:PSA CHAN1');   % Set source A of phase measurement to CH1
            fprintf(scope, ':MEAS:SET:PSB CHAN2');   % Set source B of phase measurement to CH2
            fprintf(scope, ':CHAN1:DISP ON');
            fprintf(scope, ':CHAN2:DISP ON');            
        end

        function freq = makeFreq(fstart, fstop, samples, distr)
            if isequal(distr, 'log')
                freq = logspace(log10(fstart), log10(fstop), samples);
            else
                freq = linspace(fstart, fstop, samples);
            end               
        end
        
        function findVScale(scope, att)
            vold = 0;
            for k = [10  1 0.1 0.01]    % coarse
                fprintf(scope, append(':CHAN2:SCAL ', sprintf('%0.7e', k*att)));
                pause(0.05)
                fprintf(scope, ':MEAS:ITEM? VPP,CHAN2');
                vpp = str2double(fscanf(scope, '%s'));
                if vpp < 9.9e+10
                    vold = vpp;
                    break
                end
            end
            for k = 1:5     % fine 
                fprintf(scope, append(':CHAN2:SCAL ', sprintf('%0.7e', Measurement.calcVScale(vold, att))));
                pause(0.05)
                fprintf(scope, ':MEAS:ITEM? VPP,CHAN2');
                vnew = str2double(fscanf(scope, '%s'));
                if abs(vnew-vold) <= 0.05
                    return
                end
                vold = vnew;
            end
            error('Could not display CH2 correctly, check probe attenuation!')
        end
        
        % Calculates and rounds the vertical scale so that the curve
        % occupies half of the screen, used for enhanced auto-scaling
        function scale = calcVScale(vpp, att)
            % *2 because half of the screen, /8 because the screen fits 8 divisions
            scale = vpp*0.25;   
            if scale < 0.001
                scale = 0.001;
            elseif scale >= 0.001 || scale < 1 
                scale = round(scale, 3);
            elseif scale >= 1 || scale < 10 
                scale = round(scale, 3);
            elseif scale >= 10
                scale = 10;
            end
            scale = scale*att;    % Scaling is related to probe attenuation
        end

        % Processing of aquired measurements
        function [mag, magdB, attdB, phase, omega] = processData(vpp1, vpp2, rawPhase, freq)
            mag = vpp2./vpp1;
            magdB = 20.*log10(mag);
            attdB = -magdB;
            omega = 2*pi.*freq;
            pha = rawPhase;
            pha(pha > 1000) = NaN;     % replace failed measurements
            phase = pha./180.*pi;
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
        
        % Code to be executed after finishing measurements
        function cleanup(scope, fgen)
            fprintf(fgen, ':OUTP1 OFF' );
            % unlock frontpanels
            fprintf(scope, ':SYST:LOCK OFF'); 
            fprintf(fgen, ':SYSTEM:KLOCK ALL OFF'); 
            fclose(fgen);
            fclose(scope);
            delete(fgen);
            delete(scope);
        end
    end
end