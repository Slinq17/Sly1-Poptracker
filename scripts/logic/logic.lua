function has_pages()
    return Tracker:FindObjectForCode("opt_unlock_clockwerk_pages") and Tracker:ProviderCountForCode("thievius_raccoonus_page") >= Tracker:ProviderCountForCode("opt_required_pages")
end

function has_bosses()
    return Tracker:FindObjectForCode("opt_unlock_clockwerk_bosses") and Tracker:ProviderCountForCode("boss_beaten_count") >= Tracker:ProviderCountForCode("opt_required_bosses")
end