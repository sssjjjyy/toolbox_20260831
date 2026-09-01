function stimulus_brain_region_label = get_label_using_stimulus(type, stimulus_type)

if(contains(type,'rat'))
    if(contains(stimulus_type,'auditory'))
        stimulus_brain_region_label = [];
    elseif(contains(stimulus_type,'forepaw electrical stimulation'))
        stimulus_brain_region_label = 14;
    end
end
end

