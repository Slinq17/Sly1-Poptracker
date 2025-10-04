-- logic functions for the tracker

--function to check if location cluesanity is disabled
function is_cluesanity_disabled()
    return Tracker:FindObjectForCode("opt_location_cluesanity_bundle_size").AcquiredCount < 1
end

--function to check if roll is required for hourglasses
function roll_required()
    return Tracker:FindObjectForCode("opt_require_roll").CurrentStage == 1
end
function roll_not_required()
    return Tracker:FindObjectForCode("opt_require_roll").CurrentStage == 0
end