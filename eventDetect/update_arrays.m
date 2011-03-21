function [nitrate_median, nitrate_max_halftidalperiod, nitrate_min_halftidalperiod] = ...
    update_arrays(time_now, nitrate_now)
%
global Time_median_filter Nitrate_median_filter ...
    Time_window Nitrate_window cntr_samples ind_end bkgnd_nitrate ...
    numpts_bkgnd numdays_window numdays_halftidalperiod;
%
% Fill the 3-element median filter.
    if (cntr_samples == 1)
        Time_median_filter(2) = Time_median_filter(1);
        Nitrate_median_filter(2) = Nitrate_median_filter(1);
    else
        for m = 3 : -1 : 2
            Time_median_filter(m) = Time_median_filter(m-1);
            Nitrate_median_filter(m) = Nitrate_median_filter(m-1);
        end
    end
    Time_median_filter(1) = time_now;
    Nitrate_median_filter(1) = nitrate_now;
%
    if (cntr_samples == 1)
        [Vec_sorted, Ind_sorted] = bubble_sort(Nitrate_median_filter([1:2])); % Sorted to an ascending order.
        nitrate_median = Nitrate_median_filter(Ind_sorted(1));
        time_median = Time_median_filter(Ind_sorted(1));
    else
        [Vec_sorted, Ind_sorted] = bubble_sort(Nitrate_median_filter); % Sorted to an ascending order.
        nitrate_median = Nitrate_median_filter(Ind_sorted(2));
        time_median = Time_median_filter(Ind_sorted(2));
    end    
%
    if (ind_end > numpts_bkgnd)
        ind_end = numpts_bkgnd;        
    end
    time_span = time_now - Time_window(ind_end);
    if (time_span <= numdays_window)
        bkgnd_nitrate = ((bkgnd_nitrate*ind_end) + nitrate_median) / (ind_end+1);
        ind_end = ind_end + 1;
    else
        cntr_deletion = 1;
        for m2 = (ind_end-1) : -1 : 1
            time_span2 = time_now - Time_window(m2);
            if (time_span2 <= numdays_window)
                break;
            end
            cntr_deletion = cntr_deletion + 1;
        end
        sum_old = bkgnd_nitrate * ind_end;
        for m3 = 1 : cntr_deletion
            sum_old = sum_old - Nitrate_window(ind_end-m3+1);
        end
        bkgnd_nitrate = (sum_old + nitrate_median) / (ind_end-cntr_deletion+1);
        ind_end = ind_end - cntr_deletion + 1;
    end
%
    if (cntr_samples <= numpts_bkgnd)
        m_max = cntr_samples;
    else
        m_max = numpts_bkgnd;
    end
%
    nitrate_max_halftidalperiod = Nitrate_window(1);
    for m = 1 : m_max
        if ((time_now-Time_window(m)) > numdays_halftidalperiod)
            break;
        end
        if (Nitrate_window(m) > nitrate_max_halftidalperiod)
            nitrate_max_halftidalperiod = Nitrate_window(m);
        end
    end
%
    nitrate_min_halftidalperiod = Nitrate_window(1);
    for m = 1 : m_max
        if ((time_now-Time_window(m)) > numdays_halftidalperiod)
            break;
        end
        if (Nitrate_window(m) < nitrate_min_halftidalperiod)
            nitrate_min_halftidalperiod = Nitrate_window(m);
        end
    end
%
    for m = numpts_bkgnd : -1 : 2
        Time_window(m) = Time_window(m-1);
        Nitrate_window(m) = Nitrate_window(m-1);
    end
    Time_window(1) = time_now;
    Nitrate_window(1) = nitrate_median;
    cntr_samples = cntr_samples + 1;
