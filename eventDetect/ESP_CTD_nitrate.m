%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Adaptive sampling on ESP.
%
% Yanwu Zhang
%
% February 2011
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
day2hr = 24; % 1 day = 24 hours
%
numdays_halftidalperiod = 6.0/day2hr;
numdays_fulltidalperiod = 12.0/day2hr;
numdays_shortwindow = 2.0;
%numdays_shortwindow = 5.0;
numdays_longwindow = 2.0;
%numdays_longwindow = 30.0;
numdays_lockout_full_to_full = 14.0/day2hr;
numdays_lockout_full_to_archive = 4.0/day2hr;
%factor_abovebkgnd = 1.0;
factor_abovebkgnd = 1.5;
%factor_belowbkgnd = 0.5;
factor_belowbkgnd = 1.0;
factor_abovepksbaseline = 1.0;
factor_trigger_pk = 1.0;
factor_belowctrlsbaseline = 1.0;
factor_trigger_ctrl = 1.0;
%
cd C:\work\ESP;
file_in_CTD = 'EVENTdetect2009-2010CTDOnly.txt';
filein_id_CTD = fopen(file_in_CTD, 'r');
A = fscanf(filein_id_CTD, '%f %f %f %f %f %f', [6, inf]);
Mat_CTD = A';
file_in_nitrate = 'EVENTdetect2009-2010NitrateOnly.txt';
filein_id_nitrate = fopen(file_in_nitrate, 'r');
A = fscanf(filein_id_nitrate, '%f %f', [2, inf]);
Mat_nitrate = A';
%
Time_CTD_0 = Mat_CTD(:,1);
Ind_yearend_CTD = find(diff(Time_CTD_0)<0.0);
Ind_exclusion_CTD = [];
for k = 2 : length(Ind_yearend_CTD) % From k = 2 on, some short sections of data were repeated.
    Indtmp = find(Time_CTD_0 == Time_CTD_0(Ind_yearend_CTD(k)+1));
    ind_1 = Indtmp(max(find(Indtmp < Ind_yearend_CTD(k))));
    ind_2 = Ind_yearend_CTD(k);
    Ind_exclusion_CTD = [Ind_exclusion_CTD [ind_1 : ind_2]];
end
Ind_correction_CTD = [Ind_yearend_CTD(1)+1 : length(Time_CTD_0)];
Mat_CTD(Ind_correction_CTD,1) = Mat_CTD(Ind_correction_CTD,1) + 365.0;
Ind_retained_CTD = setxor([1:length(Time_CTD_0)], Ind_exclusion_CTD);
Mat_CTD = Mat_CTD(Ind_retained_CTD, :);
Time_CTD = Mat_CTD(:,1);
Trans = Mat_CTD(:,2); % transmissometry.
Dep = Mat_CTD(:,3);
Salt = Mat_CTD(:,4);
Delta_rho = Mat_CTD(:,5);
Temp = Mat_CTD(:,6);
%
Time_nitrate_0 = Mat_nitrate(:,1);
Ind_yearend_nitrate = find(diff(Time_nitrate_0)<0.0);
Ind_exclusion_nitrate = [];
for k = 2 : length(Ind_yearend_nitrate)
    Indtmp = find(Time_nitrate_0 == Time_nitrate_0(Ind_yearend_nitrate(k)+1));
    ind_1 = Indtmp(max(find(Indtmp < Ind_yearend_nitrate(k))));
    ind_2 = Ind_yearend_nitrate(k);
    Ind_exclusion_nitrate = [Ind_exclusion_nitrate [ind_1 : ind_2]];
end
Ind_correction_nitrate = [Ind_yearend_nitrate(1)+1 : length(Time_nitrate_0)];
Mat_nitrate(Ind_correction_nitrate) = Mat_nitrate(Ind_correction_nitrate) + 365.0;
Ind_retained_nitrate = setxor([1:length(Time_nitrate_0)], Ind_exclusion_nitrate);
Mat_nitrate = Mat_nitrate(Ind_retained_nitrate, :);
Time_nitrate = Mat_nitrate(:,1);
Nitrate = Mat_nitrate(:,2);
%
figure; orient landscape; hold on;
plot(Time_CTD, Temp, '.'); 
plot(Time_CTD, Salt, 'g.');
plot(Time_CTD, Dep, 'y.');
plot(Time_CTD, Trans, 'k.');
plot(Time_nitrate, Nitrate, 'r.');
xlabel('Year day in 2009 and 2010', 'fontsize', 18);
Yrdayplot = [floor(Time_CTD(1)) : ceil(Time_CTD(length(Time_CTD)))];
Indtmp = find(Yrdayplot > 365);
Yrdayplot_2 = Yrdayplot;
Yrdayplot_2(Indtmp) = Yrdayplot(Indtmp) - 365;
set(gca, 'xlim', [min(Yrdayplot) max(Yrdayplot)], ...
    'xtick', Yrdayplot, 'xticklabel', Yrdayplot_2, 'fontsize', 12);
%
%
Ind_jump = find(diff(Time_nitrate) > 10.0); % Interval longer than 10 days.
%
Ind_2009 = [1 : Ind_jump(1)];
Time_nitrate_2009 = Time_nitrate(Ind_2009);
Nitrate_2009 = Nitrate(Ind_2009);
%
Ind_2010 = [Ind_jump(2)+1 : length(Time_nitrate)];
Time_nitrate_2010 = Time_nitrate(Ind_2010);
Time_nitrate_2010 = Time_nitrate_2010 - 365.0;
Nitrate_2010 = Nitrate(Ind_2010);
%
%
% Triggering at nitrate peaks.
%
Ind_peak_nitrate = [];
Ind_ctrl_nitrate = [];
Ind_trigger_pk_nitrate = [];
Ind_trigger_ctrl_nitrate = [];
Bkgnd_nitrate = nan(1, length(Time_nitrate_2010));
Pksbaseline_nitrate = nan(1, length(Time_nitrate_2010));
Ind_latest2highs = nan(1, 2);
Time_latest2highs = nan(1, 2);
Nitrate_latest2highs = nan(1, 2);
Ind_latest2lows = nan(1, 2);
Time_latest2lows = nan(1, 2);
Nitrate_latest2lows = nan(1, 2);
%
Bkgnd_nitrate(1) = Nitrate_2010(1);
Pksbaseline_nitrate(1) = nan;
cntr_highs = 0;
cntr_peaks = 0;
cntr_lows = 0;
cntr_ctrls = 0;
cntr_triggerings_pk = 0;
cntr_triggerings_ctrl = 0;
%
for k = 2 : length(Time_nitrate_2010)    
    time_now = Time_nitrate_2010(k);
    nitrate_now = Nitrate_2010(k);
%
    Pksbaseline_nitrate(k) = Pksbaseline_nitrate(k-1);
%
    Ind_in_longwindow = find(Time_nitrate_2010 <= time_now & ...
        (time_now-Time_nitrate_2010) <= numdays_longwindow);
    Bkgnd_nitrate(k) = mean(Nitrate_2010(Ind_in_longwindow));
%
    Ind_in_shortwindow = find(Time_nitrate_2010 <= time_now & ...
        (time_now-Time_nitrate_2010) <= numdays_halftidalperiod);
    nitrate_max_in_shortwindow = max(Nitrate_2010(Ind_in_shortwindow));
    nitrate_min_in_shortwindow = min(Nitrate_2010(Ind_in_shortwindow));    
%    
    if ((nitrate_now >= nitrate_max_in_shortwindow) && ...
            (nitrate_now >= (Bkgnd_nitrate(k) * factor_abovebkgnd)))
        cntr_highs = cntr_highs + 1;        
        if (cntr_highs == 1)
            Ind_latest2highs(1) = k;
            Time_latest2highs(1) = time_now;
            Nitrate_latest2highs(1) = nitrate_now;            
        else
            if ((time_now - Time_latest2highs(1)) < numdays_halftidalperiod)
                Ind_latest2highs(1) = k;
                Time_latest2highs(1) = time_now;
                Nitrate_latest2highs(1) = nitrate_now;
            else
                Ind_latest2highs(2) = Ind_latest2highs(1);
                Ind_latest2highs(1) = k;            
                Time_latest2highs(2) = Time_latest2highs(1);
                Time_latest2highs(1) = time_now;
                Nitrate_latest2highs(2) = Nitrate_latest2highs(1);
                Nitrate_latest2highs(1) = nitrate_now;
                Ind_peak_nitrate = [Ind_peak_nitrate Ind_latest2highs(2)];
                cntr_peaks = cntr_peaks + 1;
            end
        end
%
        if (cntr_peaks >= 1)
            Indind_peak_in_shortwindow = ...
                find((time_now-Time_nitrate_2010(Ind_peak_nitrate)) <= numdays_shortwindow);
            if (~isempty(Indind_peak_in_shortwindow))
                Pksbaseline_nitrate(k) = ...
                    mean(Nitrate_2010(Ind_peak_nitrate(Indind_peak_in_shortwindow)));
            end
        end
%
        if ((time_now - Time_latest2highs(2) >= numdays_halftidalperiod) && ...
                (time_now - Time_latest2highs(2) <= (numdays_fulltidalperiod*2)) && ...
                (nitrate_now >= (Nitrate_latest2highs(2) * factor_trigger_pk)) && ...
                (nitrate_now >= (Pksbaseline_nitrate(k) * factor_abovepksbaseline)))           
            if (cntr_triggerings_pk == 0)
                Ind_trigger_pk_nitrate = [Ind_trigger_pk_nitrate k];
                cntr_triggerings_pk = cntr_triggerings_pk + 1;
                flag_archive = 0;
            else
                indtmp = Ind_trigger_pk_nitrate(length(Ind_trigger_pk_nitrate));
                if ((time_now - Time_nitrate_2010(indtmp) >= numdays_lockout_full_to_full))
                    Ind_trigger_pk_nitrate = [Ind_trigger_pk_nitrate k];
                    cntr_triggerings_pk = cntr_triggerings_pk + 1;
                    flag_archive = 0;
                end
            end
        end
    end
%
    if ((cntr_triggerings_pk >= 1) && (flag_archive == 0) && ...
            (nitrate_now <= nitrate_min_in_shortwindow) && ...
            (nitrate_now <= (Bkgnd_nitrate(k) * factor_belowbkgnd)) && ...
            ((time_now - ...
            Time_nitrate_2010(Ind_trigger_pk_nitrate(length(Ind_trigger_pk_nitrate))) ...
            >= numdays_lockout_full_to_archive)))
         Ind_trigger_ctrl_nitrate = [Ind_trigger_ctrl_nitrate k];
         cntr_triggerings_ctrl = cntr_triggerings_ctrl + 1;
         flag_archive = 1;
    end
end
%
%
figure; orient landscape; hold on;
Hraw = plot(Time_nitrate_2010, Nitrate_2010, '.');
Hpk = plot(Time_nitrate_2010(Ind_peak_nitrate), Nitrate_2010(Ind_peak_nitrate), 'ro', ...
    'linewidth', 2.0);
Htriggerpk = plot(Time_nitrate_2010(Ind_trigger_pk_nitrate), ...
    Nitrate_2010(Ind_trigger_pk_nitrate), 'r^', 'linewidth', 2.0);
set(Htriggerpk, 'markersize', 12);
Htriggerctrl = plot(Time_nitrate_2010(Ind_trigger_ctrl_nitrate), ...
    Nitrate_2010(Ind_trigger_ctrl_nitrate), 'gv', 'linewidth', 2.0);
set(Htriggerctrl, 'markersize', 12);
Hbkgnd = plot(Time_nitrate_2010, Bkgnd_nitrate, 'c', 'linewidth', 2.0);
Hpksbaseline = plot(Time_nitrate_2010, Pksbaseline_nitrate, 'm', 'linewidth', 2.0);
Yrdayplot = [floor(Time_nitrate_2010(1)) : ceil(Time_nitrate_2010(length(Time_nitrate_2010)))];
Hlegend = legend([Hraw, Hbkgnd, Hpk, Hpksbaseline, Htriggerpk, Htriggerctrl], ...
    'Raw', ['Background level in ' num2str(numdays_longwindow) ' days'], ...
    'Peak', ['Average peak level in ' num2str(numdays_shortwindow) ' days'], ...
    ['Peak triggering (lockout time full-to-full:' num2str(numdays_lockout_full_to_full*day2hr) ' hours)'], ...    
    ['Control triggering (lockout time full-to-archive:' num2str(numdays_lockout_full_to_archive*day2hr) ' hours)']);
set(Hlegend, 'fontsize', 12);
xlabel('Year day in 2010', 'fontsize', 18);
ylabel('{NO_3}^{-} (\muM)', 'fontsize', 18);
%set(gca, 'xlim', [min(Yrdayplot) max(Yrdayplot)], 'xtick', Yrdayplot, 'fontsize', 12);
set(gca, 'xlim', [min(Yrdayplot) max(Yrdayplot)], 'ylim', [0.0 max(Nitrate_2010)], 'fontsize', 12);
%