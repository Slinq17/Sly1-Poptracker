ScriptHost:LoadScript("scripts/autotracking/item_mapping.lua")
ScriptHost:LoadScript("scripts/autotracking/location_mapping.lua")

CUR_INDEX = -1
LOCAL_ITEMS = {}
GLOBAL_ITEMS = {}
SLOT_DATA = {}

--useful for debugging slot data
function dump_table(o, depth)
    if depth == nil then
        depth = 0
    end
    if type(o) == 'table' then
        local tabs = ('\t'):rep(depth)
        local tabs2 = ('\t'):rep(depth + 1)
        local s = '{\n'
        for k, v in pairs(o) do
            local kc = k
            if type(k) ~= 'number' then
                kc = '"' .. k .. '"'
            end
            s = s .. tabs2 .. '[' .. kc .. '] = ' .. dump_table(v, depth + 1) .. ',\n'
        end
        return s .. tabs .. '}'
    else
        return tostring(o)
    end
end

function isBottle(item_code)
	local bottle = "_bottle"
	return item_code == "" or item_code:sub(-#bottle) == bottle
end

-- resets an item to its initial state
function resetItem(item_code, item_type)
	local obj = Tracker:FindObjectForCode(item_code)
	if obj then
		item_type = item_type or obj.Type
		if item_type == "toggle" then
			obj.Active = false
		elseif item_type == "progressive" then
			obj.CurrentStage = 0
			obj.Active = false
		elseif item_type == "consumable" then
			obj.AcquiredCount = 0
		elseif item_type == "static" and AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
			print(string.format("resetItem: tried to reset static item %s", item_code))
		elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
			print(string.format("resetItem: unknown item type %s for code %s", item_type, item_code))
		end
	elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
		print(string.format("resetItem: could not find item object for code %s", item_code))
	end
end

-- advances the state of an item
function incrementItem(item_code, item_type, multiplier)
	local obj = Tracker:FindObjectForCode(item_code)
	if obj then
		item_type = item_type or obj.Type
		if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
			print(string.format("incrementItem: code: %s, type %s", item_code, item_type))
		end
		if item_type == "toggle" then
			obj.Active = true
		elseif item_type == "progressive" then
			if obj.Active then
				obj.CurrentStage = obj.CurrentStage + 1
			else
				obj.Active = true
			end
		elseif item_type == "consumable" then
			if isBottle(item_code) then
				obj.AcquiredCount = obj.AcquiredCount + obj.Increment * SLOT_DATA.options.ItemCluesanityBundleSize
			else
				obj.AcquiredCount = obj.AcquiredCount + obj.Increment
			end
		elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
			print(string.format("incrementItem: unknown item type %s for code %s", item_type, item_code))
		end
	elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
		print(string.format("incrementItem: could not find object for code %s", item_code))
	end
end

-- apply everything needed from slot_data, called from onClear
function apply_slot_data(slot_data)
	if slot_data["options"]["IncludeHourglasses"] ~= nil then
		local obj = Tracker:FindObjectForCode("opt_hourglasses")
		local stage = slot_data["options"]["IncludeHourglasses"]
		if stage >= 1 then
			stage = 1
		end
		if obj then
			obj.CurrentStage = stage
		end
	end
	if slot_data["options"]["HourglassesRequireRoll"] ~= nil then
		local obj = Tracker:FindObjectForCode("opt_require_roll")
		local stage = slot_data["options"]["HourglassesRequireRoll"]
		if stage >= 1 then
			stage = 1
		end
		if obj then
			obj.CurrentStage = stage
		end
	end
	if slot_data["options"]["UnlockClockwerk"] ~= nil then
		local obj = Tracker:FindObjectForCode("opt_unlock_clockwerk")
		local stage = slot_data["options"]["UnlockClockwerk"]
		if stage >= 1 then
			stage = 1
		end
		if obj then
			obj.CurrentStage = stage
		end
	end
	if slot_data["options"]["RequiredBosses"] ~= nil then
		Tracker:FindObjectForCode('opt_required_bosses').AcquiredCount = slot_data["options"]["RequiredBosses"]
	else
		Tracker:FindObjectForCode('opt_required_bosses').AcquiredCount = 0
	end
	if slot_data["options"]["RequiredPages"] ~= nil then
		Tracker:FindObjectForCode('opt_required_pages').AcquiredCount = slot_data["options"]["RequiredPages"]
	else
		Tracker:FindObjectForCode('opt_required_pages').AcquiredCount = 0
	end
	if slot_data["options"]["LocationCluesanityBundleSize"] ~= nil then
		Tracker:FindObjectForCode('opt_location_cluesanity_bundle_size').AcquiredCount = slot_data["options"]["LocationCluesanityBundleSize"]
	else
		Tracker:FindObjectForCode('opt_location_cluesanity_bundle_size').AcquiredCount = 0
	end
end

-- called right after an AP slot is connected
function onClear(slot_data)
	-- use bulk update to pause logic updates until we are done resetting all items/locations
	Tracker.BulkUpdate = true
	if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
		print(string.format("called onClear, slot_data:\n%s", dump_table(slot_data)))
	end
	CUR_INDEX = -1
	-- reset locations
	for _, mapping_entry in pairs(LOCATION_MAPPING) do
		for _, location_table in ipairs(mapping_entry) do
			if location_table then
				local location_code = location_table[1]
				if location_code then
					-- if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
					-- 	print(string.format("onClear: clearing location %s", location_code))
					-- end
					if location_code:sub(1, 1) == "@" then
						local obj = Tracker:FindObjectForCode(location_code)
						if obj then
							obj.AvailableChestCount = obj.ChestCount
							if obj.Highlight then
								obj.Highlight = Highlight.None
							end
						elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
							print(string.format("onClear: could not find location object for code %s", location_code))
						end
					else
						-- reset hosted item
						local item_type = location_table[2]
						resetItem(location_code, item_type)
					end
				elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
					print(string.format("onClear: skipping location_table with no location_code"))
				end
			elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
				print(string.format("onClear: skipping empty location_table"))
			end
		end
	end
	-- reset items
	for _, mapping_entry in pairs(ITEM_MAPPING) do
		for _, item_table in ipairs(mapping_entry) do
			if item_table then
				local item_code = item_table[1]
				local item_type = item_table[2]
				if item_code then
					resetItem(item_code, item_type)
				elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
					print(string.format("onClear: skipping item_table with no item_code"))
				end
			elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
				print(string.format("onClear: skipping empty item_table"))
			end
		end
	end

	-- set number of bottle bundles for each level if cluesanity is enabled
	if slot_data["options"]["LocationCluesanityBundleSize"] > 0 then
		local levels = {
			"@Tide of Terror/Stealthy Approach/Bottle Bundle",
			"@Tide of Terror/Into the Machine/Bottle Bundle",
			"@Tide of Terror/High Class Heist/Bottle Bundle",
			"@Tide of Terror/Fire Down Below/Bottle Bundle",
			"@Tide of Terror/Cunning Disguise/Bottle Bundle",
			"@Tide of Terror/Gunboat Graveyard/Bottle Bundle",
			"@Sunset Snake Eyes/Rocky Start/Bottle Bundle",
			"@Sunset Snake Eyes/Boneyard Casino/Bottle Bundle",
			"@Sunset Snake Eyes/Straight to the Top/Bottle Bundle",
			"@Sunset Snake Eyes/Two to Tango/Bottle Bundle",
			"@Sunset Snake Eyes/Back Alley Heist/Bottle Bundle",
			"@Vicious Voodoo/Dread Swamp Path/Bottle Bundle",
			"@Vicious Voodoo/Lair of the Beast/Bottle Bundle",
			"@Vicious Voodoo/Grave Undertaking/Bottle Bundle",
			"@Vicious Voodoo/Descent into Danger/Bottle Bundle",
			"@Fire in the Sky/Perilous Ascent/Bottle Bundle",
			"@Fire in the Sky/Unseen Foe/Bottle Bundle",
			"@Fire in the Sky/Flaming Temple of Flame/Bottle Bundle",
			"@Fire in the Sky/Duel by the Dragon/Bottle Bundle"
		}
		for _,level in ipairs(levels) do
			local levelBundles = Tracker:FindObjectForCode(level)
			local levelBottles = levelBundles.AvailableChestCount
			levelBundles.AvailableChestCount = levelBundles.AvailableChestCount // slot_data["options"]["LocationCluesanityBundleSize"]
			if levelBottles % slot_data["options"]["LocationCluesanityBundleSize"] ~= 0 then
				levelBundles.AvailableChestCount = levelBundles.AvailableChestCount + 1
			end
		end
	end
	apply_slot_data(slot_data)
	SLOT_DATA = slot_data
	LOCAL_ITEMS = {}
	GLOBAL_ITEMS = {}
	Tracker.BulkUpdate = false
end

-- called when an item gets collected
function onItem(index, item_id, item_name, player_number)
	if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
		print(string.format("called onItem: %s, %s, %s, %s, %s", index, item_id, item_name, player_number, CUR_INDEX))
	end
	if not AUTOTRACKER_ENABLE_ITEM_TRACKING then
		return
	end
	if index <= CUR_INDEX then
		return
	end
	local is_local = player_number == Archipelago.PlayerNumber
	CUR_INDEX = index
	local mapping_entry = ITEM_MAPPING[item_id]
	if not mapping_entry then
		if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
			print(string.format("onItem: could not find item mapping for id %s", item_id))
		end
		return
	end
	for _, item_table in pairs(mapping_entry) do
		if item_table then
			local item_code = item_table[1]
			local item_type = item_table[2]
			local multiplier = item_table[3] or 1
			if item_code then
				incrementItem(item_code, item_type, multiplier)
				-- keep track which items we touch are local and which are global
				if is_local then
					if LOCAL_ITEMS[item_code] then
						LOCAL_ITEMS[item_code] = LOCAL_ITEMS[item_code] + 1
					else
						LOCAL_ITEMS[item_code] = 1
					end
				else
					if GLOBAL_ITEMS[item_code] then
						GLOBAL_ITEMS[item_code] = GLOBAL_ITEMS[item_code] + 1
					else
						GLOBAL_ITEMS[item_code] = 1
					end
				end
			elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
				print(string.format("onClear: skipping item_table with no item_code"))
			end
		elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
			print(string.format("onClear: skipping empty item_table"))
		end
	end
	if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
		print(string.format("local items: %s", dump_table(LOCAL_ITEMS)))
		print(string.format("global items: %s", dump_table(GLOBAL_ITEMS)))
	end
end

-- called when a location gets cleared
function onLocation(location_id, location_name)
	if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
		print(string.format("called onLocation: %s, %s", location_id, location_name))
	end
	if not AUTOTRACKER_ENABLE_LOCATION_TRACKING then
		return
	end
	local mapping_entry = LOCATION_MAPPING[location_id]
	if not mapping_entry then
		if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
			print(string.format("onLocation: could not find location mapping for id %s", location_id))
		end
		return
	end
	for _, location_table in pairs(mapping_entry) do
		if location_table then
			local location_code = location_table[1]
			if location_code then
				local obj = Tracker:FindObjectForCode(location_code)
				if obj then
					if location_code:sub(1, 1) == "@" then
						if location_code:sub(-7) == "Bottles" then
							if obj.AvailableChestCount <= SLOT_DATA.options.LocationCluesanityBundleSize then
								obj.AvailableChestCount = 0
							else
								obj.AvailableChestCount = obj.AvailableChestCount - SLOT_DATA.options.LocationCluesanityBundleSize
							end
						else 
							obj.AvailableChestCount = obj.AvailableChestCount - 1
						end
					else
						-- increment hosted item
						local item_type = location_table[2]
						incrementItem(location_code, item_type)
					end
				elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
					print(string.format("onLocation: could not find object for code %s", location_code))
				end
			elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
				print(string.format("onLocation: skipping location_table with no location_code"))
			end
		elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
			print(string.format("onLocation: skipping empty location_table"))
		end
	end
end

-- add AP callbacks
-- un-/comment as needed
Archipelago:AddClearHandler("clear handler", onClear)
if AUTOTRACKER_ENABLE_ITEM_TRACKING then
	Archipelago:AddItemHandler("item handler", onItem)
end
if AUTOTRACKER_ENABLE_LOCATION_TRACKING then
	Archipelago:AddLocationHandler("location handler", onLocation)
end
