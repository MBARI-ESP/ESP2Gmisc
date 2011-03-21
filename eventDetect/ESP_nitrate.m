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
global Time_median_filter Nitrate_median_filter ...
    Time_window Nitrate_window cntr_samples ind_end bkgnd_nitrate ...
    numpts_bkgnd numdays_window numdays_halftidalperiod;
%
day2hr = 24; % 1 day = 24 hours
hr2min = 60; % 1 hour = 60 minutes
min2sec = 60; % 1 minute = 60 seonds
%
numdays_halftidalperiod = 6.0/day2hr;
numdays_fulltidalperiod = 12.0/day2hr;
numdays_window = 1.0;
numdays_lockout_full_to_full = 14.0/day2hr;
numdays_lockout_full_to_archive = 4.0/day2hr;
%factor_abovebkgnd = 1.0;
factor_abovebkgnd = 1.2;
%factor_abovebkgnd = 1.5;
%factor_belowbkgnd = 0.5;
factor_belowbkgnd = 1.0;
factor_abovepksbaseline = 1.0;
factor_trigger_pk = 0.9;
%factor_trigger_pk = 1.0;
factor_trigger_ctrl = 1.0;
%
year_data = input('Year = ___ (2009 or 2010) ? ');
%
file_in_nitrate = 'EVENTdetect2009-2010NitrateOnly.txt';
filein_id_nitrate = fopen(file_in_nitrate, 'r');
A = fscanf(filein_id_nitrate, '%f %f', [2, inf]);
Mat_nitrate = A';
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
switch year_data
    case 2009
        Time_nitrate_year = Time_nitrate_2009;
        Nitrate_year = Nitrate_2009;
    case 2010
        Time_nitrate_year = Time_nitrate_2010;
        Nitrate_year = Nitrate_2010;
end
%
% Triggering at nitrate peaks.
%
Ind_peak_nitrate = [];
Ind_ctrl_nitrate = [];
Ind_trigger_pk_nitrate = [];
Ind_trigger_ctrl_nitrate = [];
Bkgndnitrate = nan(1, length(Time_nitrate_year));
Pksbaselinenitrate = nan(1, length(Time_nitrate_year));
Ind_latest2highs = nan(1, 2);
Time_latest2highs = nan(1, 2);
Nitrate_latest2highs = nan(1, 2);
Ind_latest2lows = nan(1, 2);
Time_latest2lows = nan(1, 2);
Nitrate_latest2lows = nan(1, 2);
%
cntr_highs = 0;
cntr_peaks = 0;
cntr_lows = 0;
cntr_ctrls = 0;
cntr_triggerings_pk = 0;
cntr_triggerings_ctrl = 0;
flag_archive = 0;
%
sampling_interval = 5.0 * min2sec; % Assuming 5-minute sampling interval.
numpts_bkgnd = (ceil((numdays_window*day2hr*hr2min*min2sec)/sampling_interval)) * 2; % "*2" to leave a margin.
Time_window = nan(1, 1000); % Assuming 5-minute sampling interval. ceil((numdays_shortindow*day2hr*hr2min*min2sec)/sampling_interval) = 288;
Nitrate_window = nan(1, 1000);
num_pks_saved_max = 200;
Time_pks_window = nan(1, num_pks_saved_max);
Nitrate_pks_window = nan(1, num_pks_saved_max);
% In each of the following filters, element [1] stores the newest sample; element [N] stores the oldest sample.
% Note that in MATLAB, array index counts from [1], not [0].
Time_latest2highs = nan(1, 2);
Nitrate_latest2highs = nan(1, 2);
Time_median_filter = nan(1, 3);
Nitrate_median_filter = nan(1, 3);
%
bkgnd_nitrate = Nitrate_year(1);
Bkgndnitrate(1) = bkgnd_nitrate;
Time_window(1) = Time_nitrate_year(1);
Nitrate_window(1) = Nitrate_year(1);
time_now = Time_nitrate_year(1);
nitrate_now = Nitrate_year(1);
Time_median_filter(1) = Time_nitrate_year(1); % Initializing the 3-element median filter.
Nitrate_median_filter(1) = Nitrate_year(1); % Initializing the 3-element median filter.
Ind_latest2highs(1) = 1;
Time_latest2highs(1) = Time_nitrate_year(1);
Nitrate_latest2highs(1) = Nitrate_year(1);
%
cntr_samples = 1;
ind_end = 1;
%
for k = 2 : length(Time_nitrate_year)
    time_last = time_now;
    nitrate_last = nitrate_now;
    time_now = Time_nitrate_year(k);
    nitrate_now = Nitrate_year(k);
%
    Pksbaselinenitrate(k) = Pksbaselinenitrate(k-1); % This array for plotting purposes only.
%
    [nitrate_median, nitrate_max_halftidalperiod, nitrate_min_halftidalperiod] = ...
        update_arrays(time_now, nitrate_now);
%
    Bkgndnitrate(k) = bkgnd_nitrate; % This array for plotting purposes only.
%
    if ((nitrate_median > nitrate_max_halftidalperiod) && ...
            (nitrate_median >= (bkgnd_nitrate * factor_abovebkgnd)))
            if ((time_now - Time_latest2highs(1)) < numdays_halftidalperiod)
                Ind_latest2highs(1) = k;
                Time_latest2highs(1) = time_now;
            Nitrate_latest2highs(1) = nitrate_median;            
            else
                Ind_latest2highs(2) = Ind_latest2highs(1);
                Time_latest2highs(2) = Time_latest2highs(1);
                Nitrate_latest2highs(2) = Nitrate_latest2highs(1);
            Ind_latest2highs(1) = k;            
            Time_latest2highs(1) = time_now;
            Nitrate_latest2highs(1) = nitrate_median;
            Ind_peak_nitrate = [Ind_peak_nitrate Ind_latest2highs(2)]; % This array for plotting purposes only.
%
            for n2 = num_pks_saved_max : -1 : 2
                Time_pks_window(n2) = Time_pks_window(n2-1);
                Nitrate_pks_window(n2) = Nitrate_pks_window(n2-1);
            end
            Time_pks_window(1) = Time_latest2highs(2);
            Nitrate_pks_window(1) = Nitrate_latest2highs(2);
            cntr_peaks = cntr_peaks + 1;
%
            if (cntr_peaks <= num_pks_saved_max)
                n_max = cntr_peaks;
            else
                n_max = num_pks_saved_max;
        end
%
            pksbaseline_nitrate = Nitrate_pks_window(1);
            if (n_max >= 2)
                for n = 2 : n_max
                    if ((time_now-Time_pks_window(n)) > numdays_window)
                        break;
                    end
                    pksbaseline_nitrate = (pksbaseline_nitrate*(n-1) + ...
                        Nitrate_pks_window(n)) / n;
            end
        end
%
            Pksbaselinenitrate(k) = pksbaseline_nitrate;
        end
%
        if ((time_now - Time_latest2highs(2) >= numdays_halftidalperiod) && ...
                (time_now - Time_latest2highs(2) <= (numdays_fulltidalperiod*2)) && ...
                ((nitrate_now >= (Nitrate_latest2highs(2) * factor_trigger_pk)) && ...
                (nitrate_now >= (pksbaseline_nitrate * factor_abovepksbaseline))) && ...
                ((nitrate_last >= (Nitrate_latest2highs(2) * factor_trigger_pk)) && ...
                (nitrate_last >= (pksbaseline_nitrate * factor_abovepksbaseline))))
            if (cntr_triggerings_pk == 0)
                Ind_trigger_pk_nitrate = [Ind_trigger_pk_nitrate k]; % This array for plotting purposes only.
                time_trigger_pk = time_now;
                cntr_triggerings_pk = cntr_triggerings_pk + 1;
                flag_archive = 0;
            else
                if ((time_now - time_trigger_pk) >= numdays_lockout_full_to_full)
                    Ind_trigger_pk_nitrate = [Ind_trigger_pk_nitrate k]; % This array for plotting purposes only.
                    time_trigger_pk = time_now;                    
                    cntr_triggerings_pk = cntr_triggerings_pk + 1;
                    flag_archive = 0;
                end
            end
        end
    end
%
    if ((cntr_triggerings_pk >= 1) && (flag_archive == 0) && ...
            (nitrate_median <= nitrate_min_halftidalperiod) && ...
            (nitrate_median <= (bkgnd_nitrate * factor_belowbkgnd)) && ...
            ((time_now - time_trigger_pk)>= numdays_lockout_full_to_archive))
         Ind_trigger_ctrl_nitrate = [Ind_trigger_ctrl_nitrate k]; % This array for plotting purposes only.
         cntr_triggerings_ctrl = cntr_triggerings_ctrl + 1;
         flag_archive = 1;
    end
end
%
%
figure; orient landscape; hold on;
Hraw = plot(Time_nitrate_year, Nitrate_year, '.');
Hpk = plot(Time_nitrate_year(Ind_peak_nitrate), Nitrate_year(Ind_peak_nitrate), 'ro', ...
    'linewidth', 2.0);
Htriggerpk = plot(Time_nitrate_year(Ind_trigger_pk_nitrate), ...
    Nitrate_year(Ind_trigger_pk_nitrate), 'r^', 'linewidth', 2.0);
set(Htriggerpk, 'markersize', 12);
Htriggerctrl = plot(Time_nitrate_year(Ind_trigger_ctrl_nitrate), ...
    Nitrate_year(Ind_trigger_ctrl_nitrate), 'gv', 'linewidth', 2.0);
set(Htriggerctrl, 'markersize', 12);
Hbkgnd = plot(Time_nitrate_year, Bkgndnitrate, 'c', 'linewidth', 2.0);
Hpksbaseline = plot(Time_nitrate_year, Pksbaselinenitrate, 'm', 'linewidth', 2.0);
Yrdayplot = [floor(Time_nitrate_year(1)) : ceil(Time_nitrate_year(length(Time_nitrate_year)))];
Hlegend = legend([Hraw, Hbkgnd, Hpk, Hpksbaseline, Htriggerpk, Htriggerctrl], ...
    'Raw', ['Background level in ' num2str(numdays_window) ' days'], ...
    'Peak', ['Average peak level in ' num2str(numdays_window) ' days'], ...
    ['Peak triggering (lockout time full-to-full:' num2str(numdays_lockout_full_to_full*day2hr) ' hours)'], ...    
    ['Control triggering (lockout time full-to-archive:' num2str(numdays_lockout_full_to_archive*day2hr) ' hours)']);
set(Hlegend, 'fontsize', 12);
switch year_data
    case 2009
        xlabel('Year day in 2009', 'fontsize', 18);
    case 2010
xlabel('Year day in 2010', 'fontsize', 18);
end
ylabel('{NO_3}^{-} (\muM)', 'fontsize', 18);
%set(gca, 'xlim', [min(Yrdayplot) max(Yrdayplot)], 'xtick', Yrdayplot, 'fontsize', 12);
set(gca, 'xlim', [min(Yrdayplot) max(Yrdayplot)], 'ylim', [0.0 max(Nitrate_year)], 'fontsize', 12);
%
