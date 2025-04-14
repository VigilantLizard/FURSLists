--[[
    Player ID Checker & Action Handler
    
    Usage:
    1. Place this script into ServerScriptService.
    2. Configure the 'Config' table with your desired settings.
    3. If necessary, modify the script to suit your specific use case.

    Description:
    This script checks joining players against external lists (Watchlist, Warning List, Blacklist)
    hosted on GitHub. If a player's UserID is found on a list, it fetches a corresponding
    reason if available and performs a configurable action.

    Features:
    - Fetches ID lists and reason lists via HttpService.
    - Parses lists separated by ',\n', handling potential leading newlines.
    - Checks players sequentially against Watchlist, Warning List, then Blacklist.
    - Executes list-specific actions defined in the configuration.
    - Includes error handling for HTTP requests and kicking.

    Customization:
    - Modify the Config table below to change URLs, default messages, and actions.
    - Edit the HandleWatchlistPlayer, HandleWarningListPlayer, and HandleBlacklistPlayer
      functions (defined early in the script) to implement custom logic.
]]

--==============================================================================
-- Services
--==============================================================================
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

--==============================================================================
-- Configuration
--==============================================================================
local Config = {
	-- URLs for the UserID lists
	LIST_URLS = {
		WATCHLIST = "https://raw.githubusercontent.com/VigilantLizard/FURSLists/refs/heads/main/lists/Watchlist.bin",
		WARNINGLIST = "https://raw.githubusercontent.com/VigilantLizard/FURSLists/refs/heads/main/lists/WarningList.bin",
		BLACKLIST = "https://raw.githubusercontent.com/VigilantLizard/FURSLists/refs/heads/main/lists/Blacklist.bin",
	},

	-- URLs for the corresponding reason lists
	REASON_URLS = {
		WATCHLIST = "https://raw.githubusercontent.com/VigilantLizard/FURSLists/refs/heads/main/reasons/WatchlistReasons.bin",
		WARNINGLIST = "https://raw.githubusercontent.com/VigilantLizard/FURSLists/refs/heads/main/reasons/WarningReasons.bin", -- This URL is correct, as WarningListReasons.bin does not exist.
		BLACKLIST = "https://raw.githubusercontent.com/VigilantLizard/FURSLists/refs/heads/main/reasons/BlacklistReasons.bin",
	},

	-- Default actions and messages for each list type and error cases
	-- 'action' can be "kick", "log", or "none" (or any custom string you handle)
	DEFAULT_ACTIONS = {
		WATCHLIST = { message = "You are on the Watchlist. Please contact an administrator.", action = "kick" },
		WARNINGLIST = { message = "You have been placed on the Warning List. Please correct your behavior.", action = "kick" },
		BLACKLIST = { message = "You are Blacklisted and banned from this game.", action = "kick" },
		GENERIC_ERROR = { message = "An error occurred while processing your request. Please try again later.", action = "kick" },
		NO_REASON = { message = "You have been kicked.", action = "kick" } -- Fallback if specific reason fetch fails
	},

	-- Delimiter used to separate items in the fetched lists
	LIST_DELIMITER = ",\n"
}

--==============================================================================
-- Action Handlers
-- Defines what happens when a player is found on a specific list.
-- Customize these functions to change behavior (e.g., logging, warnings, etc.)
--==============================================================================

-- Forward declaration for KickPlayer used in handlers below
local KickPlayer

--- Handles actions for players found on the Watchlist.
local function HandleWatchlistPlayer(player, listIndex, reasonTable)
	local listType = "WATCHLIST"
	print(string.format("%s is on the %s at index %d.", player.Name, listType, listIndex))

	local actionConfig = Config.DEFAULT_ACTIONS[listType]
	-- Start with the default message for this list type
	local actionMessage = actionConfig.message or Config.DEFAULT_ACTIONS.NO_REASON.message

	-- Try to get a specific reason from the reason table using the index
	if reasonTable and reasonTable[listIndex] then
		actionMessage = reasonTable[listIndex] -- Override with the specific reason
		print(string.format("Using specific reason for %s: %s", listType, actionMessage))
	else
		-- Log a warning if a specific reason couldn't be found at the expected index
		warn(string.format("Could not get specific reason for %s (%s) at index %d. Reason table valid: %s",
			player.Name, listType, listIndex, tostring(reasonTable ~= nil)))
	end

	-- Put your code here. This is the default code to kick the player.
	print(string.format("Kicking player %s based on %s.", player.Name, listType))
	KickPlayer(player, actionMessage)
end

--- Handles actions for players found on the Warning List.
local function HandleWarningListPlayer(player, listIndex, reasonTable)
	local listType = "WARNINGLIST"
	print(string.format("%s is on the %s at index %d.", player.Name, listType, listIndex))

	local actionConfig = Config.DEFAULT_ACTIONS[listType]
	local actionMessage = actionConfig.message or Config.DEFAULT_ACTIONS.NO_REASON.message

	if reasonTable and reasonTable[listIndex] then
		actionMessage = reasonTable[listIndex]
		print(string.format("Using specific reason for %s: %s", listType, actionMessage))
	else
		warn(string.format("Could not get specific reason for %s (%s) at index %d. Reason table valid: %s",
			player.Name, listType, listIndex, tostring(reasonTable ~= nil)))
	end

	-- Put your code here. This is the default code to kick the player.
	print(string.format("Kicking player %s based on %s.", player.Name, listType))
	KickPlayer(player, actionMessage)
end

--- Handles actions for players found on the Blacklist.
local function HandleBlacklistPlayer(player, listIndex, reasonTable)
	local listType = "BLACKLIST"
	print(string.format("%s is on the %s at index %d.", player.Name, listType, listIndex))

	local actionConfig = Config.DEFAULT_ACTIONS[listType]
	local actionMessage = actionConfig.message or Config.DEFAULT_ACTIONS.NO_REASON.message

	if reasonTable and reasonTable[listIndex] then
		actionMessage = reasonTable[listIndex]
		print(string.format("Using specific reason for %s: %s", listType, actionMessage))
	else
		warn(string.format("Could not get specific reason for %s (%s) at index %d. Reason table valid: %s",
			player.Name, listType, listIndex, tostring(reasonTable ~= nil)))
	end

	-- Put your code here. This is the default code to kick the player.
	print(string.format("Kicking player %s based on %s.", player.Name, listType))
	KickPlayer(player, actionMessage)
end

--==============================================================================
-- Helper Functions
--==============================================================================

--- Retrieves data from a URL using HttpService with error handling.
local function GetData(url)
	local response = nil
	local errorMessage = nil
	-- Use pcall for safe execution of the HTTP request
	local success, result = pcall(function()
		response = HttpService:GetAsync(url)
	end)

	if success then
		-- Request succeeded
		return response, nil
	else
		-- Request failed, log the error and return it
		errorMessage = tostring(result) -- Ensure error is a string
		warn(string.format("Error fetching data from %s: %s", url, errorMessage))
		return nil, errorMessage
	end
end

--- Parses a string separated by a specific delimiter into a table.
--- Also removes leading newline characters ('\n') from each extracted item.
local function ParseListString(data, delimiter)
	-- Return empty table if input data is nil or empty
	if not data or data == "" then return {} end

	local result = {}
	local startIndex = 1
	local delimiterLength = #delimiter

	-- Loop through the string finding delimiters
	while true do
		-- Find the next delimiter using plain text search (true flag)
		local endIndex = string.find(data, delimiter, startIndex, true)
		local item

		if endIndex then
			-- Delimiter found, extract the substring before it
			item = string.sub(data, startIndex, endIndex - 1)
			-- Set the start index for the next search after the current delimiter
			startIndex = endIndex + delimiterLength
		else
			-- No more delimiters, extract the remaining part of the string
			item = string.sub(data, startIndex)
		end

		-- Remove potential leading newline character from the extracted item
		-- '^' anchors the pattern to the start of the string
		local cleanedItem = item:gsub("^\n", "")

		-- Add the cleaned item to the results if it's not empty
		if cleanedItem ~= "" then
			table.insert(result, cleanedItem)
		end

		-- If no delimiter was found, we've processed the last item, so exit the loop
		if not endIndex then
			break
		end
	end

	return result
end

--- Kicks a player with a specific message, handling potential errors.
KickPlayer = function(player, message) -- Assign to the previously declared local variable
	-- Use pcall for safe execution, as player might disconnect before kick
	local success, kickError = pcall(function()
		player:Kick(message)
	end)
	if not success then
		warn(string.format("Failed to kick player %s (ID: %d): %s", player.Name, player.UserId, tostring(kickError)))
	end
end

--==============================================================================
-- Main Execution Logic
--==============================================================================

--- Handles player joining: fetches lists, parses them, checks player ID, and calls the appropriate handler.
local function OnPlayerAdded(player)
	local userId = player.UserId
	print(string.format("Player %s (ID: %d) joined. Checking lists...", player.Name, userId))

	-- Step 1: Fetch all required list and reason data concurrently (wrapped in pcall for safety)
	local successFetch, listsData = pcall(function()
		-- Note: These GetData calls run sequentially within the pcall.
		return {
			watchList = GetData(Config.LIST_URLS.WATCHLIST),
			warningList = GetData(Config.LIST_URLS.WARNINGLIST),
			blackList = GetData(Config.LIST_URLS.BLACKLIST),
			watchReasons = GetData(Config.REASON_URLS.WATCHLIST),
			warningReasons = GetData(Config.REASON_URLS.WARNINGLIST),
			blackReasons = GetData(Config.REASON_URLS.BLACKLIST)
		}
	end)

	-- Handle critical failure in fetching the data bundle
	if not successFetch then
		warn("Critical error during initial data fetching: " .. tostring(listsData)) -- listsData contains the error message here
		KickPlayer(player, Config.DEFAULT_ACTIONS.GENERIC_ERROR.message)
		return -- Cannot proceed without data
	end

	-- Extract individual data and potential errors from the fetched bundle
	local watchList, watchListError = listsData.watchList
	local warningList, warningListError = listsData.warningList
	local blackList, blackListError = listsData.blackList
	local watchReasons, watchReasonsError = listsData.watchReasons
	local warningReasons, warningReasonsError = listsData.warningReasons
	local blackReasons, blackReasonsError = listsData.blackReasons

	-- Step 2: Check if any of the essential ID lists failed to load
	if watchListError or warningListError or blackListError then
		warn("Error fetching one or more critical ID lists. Cannot reliably check player.")
		-- Kick player as we cannot guarantee they are allowed
		KickPlayer(player, Config.DEFAULT_ACTIONS.GENERIC_ERROR.message)
		return -- Cannot proceed without ID lists
	end

	-- Step 3: Parse the fetched list strings into Lua tables
	local listDelimiter = Config.LIST_DELIMITER
	local watchListTable = ParseListString(watchList, listDelimiter)
	local warningListTable = ParseListString(warningList, listDelimiter)
	local blackListTable = ParseListString(blackList, listDelimiter)

	-- Parse reason lists, defaulting to empty tables if fetch failed
	local watchReasonsTable = watchReasons and ParseListString(watchReasons, listDelimiter) or {}
	local warningReasonsTable = warningReasons and ParseListString(warningReasons, listDelimiter) or {}
	local blackReasonsTable = blackReasons and ParseListString(blackReasons, listDelimiter)

	-- Log warnings if reason lists failed to load (non-critical, will use default messages)
	if watchReasonsError then warn("Could not fetch Watchlist reasons: " .. watchReasonsError) end
	if warningReasonsError then warn("Could not fetch Warning List reasons: " .. warningReasonsError) end
	if blackReasonsError then warn("Could not fetch Blacklist reasons: " .. blackReasonsError) end

	-- Step 4: Check the player's ID against the lists sequentially and call the appropriate handler
	local userIdString = tostring(userId) -- Convert ID to string for comparison

	-- Check Watchlist
	for i, id in ipairs(watchListTable) do
		if id == userIdString then
			HandleWatchlistPlayer(player, i, watchReasonsTable)
			return -- Player found and handled, exit
		end
	end

	-- Check Warning List (only if not on Watchlist)
	for i, id in ipairs(warningListTable) do
		if id == userIdString then
			HandleWarningListPlayer(player, i, warningReasonsTable)
			return -- Player found and handled, exit
		end
	end

	-- Check Blacklist (only if not on Watchlist or Warning List)
	for i, id in ipairs(blackListTable) do
		if id == userIdString then
			HandleBlacklistPlayer(player, i, blackReasonsTable)
			return -- Player found and handled, exit
		end
	end

	-- Step 5: If the player was not found in any list
	print(string.format("%s (ID: %d) is not on any monitored lists.", player.Name, userId))

end

--==============================================================================
-- Event Connection
--==============================================================================

-- Connect the OnPlayerAdded function to the PlayerAdded event
Players.PlayerAdded:Connect(OnPlayerAdded)

print("Player ID Checker script loaded and connected successfully.")
