-- Rankup: when you learn a higher rank of a spell, it goes on your action bars where the old rank was.
local ADDON, R = ...
local VERSION = "1.1.0"
R.VERSION = VERSION

local DEFAULTS = {
    auto = true,        -- swap ranks automatically after learning a spell
    announce = true,    -- say what changed in chat
    toast = true,       -- small pop-up with the spell icons
    sound = true,       -- a short sound when ranks change
    minimapHide = false,
    minimapAngle = 150,
    ignore = {},        -- [spell name] = true: keep this one at the rank you put on the bar
    history = {},       -- recent swaps
}

local function Merge(db, def)
    for k, v in pairs(def) do
        if db[k] == nil then
            if type(v) == "table" then db[k] = {} Merge(db[k], v) else db[k] = v end
        elseif type(v) == "table" and type(db[k]) == "table" then Merge(db[k], v) end
    end
    return db
end

function R.Print(m) print("|cffe0b04aRankup:|r " .. m) end
local function Issue(kind, what, msg) if R.Issue then pcall(R.Issue, kind, what, msg) end end

---------------------------------------------------------------------------
-- Spell lookups (retail-style C_Spell where it exists, classic globals otherwise)
---------------------------------------------------------------------------
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return (GetSpellInfo(id))
end
local function SpellIcon(id)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
    return (select(3, GetSpellInfo(id)))
end
local function SpellRank(id)
    local t
    if C_Spell and C_Spell.GetSpellSubtext then t = C_Spell.GetSpellSubtext(id)
    elseif GetSpellSubtext then t = GetSpellSubtext(id) end
    if type(t) ~= "string" or t == "" then return nil end
    return t
end
local function BestId(name)
    if C_Spell and C_Spell.GetSpellInfo then
        local i = C_Spell.GetSpellInfo(name)
        return i and i.spellID
    end
    local _, _, _, _, _, _, id = GetSpellInfo(name)
    return id
end
local function Known(id)
    if IsSpellKnown and IsSpellKnown(id) then return true end
    if C_SpellBook and C_SpellBook.IsSpellKnown then return C_SpellBook.IsSpellKnown(id) end
    return false
end
local function Pickup(id)
    if C_Spell and C_Spell.PickupSpell then return C_Spell.PickupSpell(id) end
    return PickupSpell(id)
end
R.SpellName, R.SpellIcon, R.SpellRank = SpellName, SpellIcon, SpellRank

function R.SlotLabel(slot)
    return ("Bar %d, button %d"):format(math.ceil(slot / 12), (slot - 1) % 12 + 1)
end

---------------------------------------------------------------------------
-- Scan: every spell on your bars and whether a higher rank is known
---------------------------------------------------------------------------
-- state: "ok" (already the highest), "up" (a higher rank is available), "keep" (you asked to keep this rank)
function R.Scan()
    local out = {}
    if not (HasAction and GetActionInfo) then return out end
    for slot = 1, 180 do
        if HasAction(slot) then
            local kind, id = GetActionInfo(slot)
            if kind == "spell" and type(id) == "number" then
                local name = SpellName(id)
                if name then
                    local best = BestId(name)
                    local e = { slot = slot, id = id, name = name, icon = SpellIcon(id), rank = SpellRank(id), state = "ok" }
                    if best and best ~= id and Known(best) then
                        e.best, e.bestRank = best, SpellRank(best)
                        e.state = (R.db and R.db.ignore[name]) and "keep" or "up"
                    end
                    out[#out + 1] = e
                end
            end
        end
    end
    return out
end

function R.Counts(list)
    local up, keep = 0, 0
    for _, e in ipairs(list) do
        if e.state == "up" then up = up + 1 elseif e.state == "keep" then keep = keep + 1 end
    end
    return #list, up, keep
end

---------------------------------------------------------------------------
-- Swap
---------------------------------------------------------------------------
local running, again

local function Record(name, from, to, icon)
    local h = R.db.history
    table.insert(h, 1, { t = time(), name = name, from = from, to = to, icon = icon })
    while #h > 40 do h[#h] = nil end
end

function R.Run(manual)
    if not R.db then return end
    if InCombatLockdown() then
        again = true
        if manual then R.Print("in combat, it will run when combat ends.") end
        return
    end
    if running then return end
    running = true
    local changed, failed = {}, 0
    for _, e in ipairs(R.Scan()) do
        if e.state == "up" then
            ClearCursor()
            local okPick = pcall(Pickup, e.best)
            if okPick and GetCursorInfo() == "spell" then
                local okPlace = pcall(PlaceAction, e.slot)
                ClearCursor()
                local k2, id2 = GetActionInfo(e.slot)
                if okPlace and k2 == "spell" and id2 == e.best then
                    changed[#changed + 1] = e
                    Record(e.name, e.rank, e.bestRank, e.icon)
                else
                    failed = failed + 1
                end
            else
                ClearCursor()
                failed = failed + 1
            end
        end
    end
    running = false
    if #changed > 0 then
        local names = {}
        for _, e in ipairs(changed) do
            names[#names + 1] = e.name .. (e.bestRank and (" (" .. e.bestRank .. ")") or "")
        end
        if R.db.announce then R.Print("moved up to the new rank: " .. table.concat(names, ", ")) end
        if R.db.sound then pcall(PlaySound, (SOUNDKIT and SOUNDKIT.UI_LEARN_SPELL) or (SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_COMPLETE) or 888) end
        if R.db.toast and R.UI and R.UI.Toast then pcall(R.UI.Toast, changed) end
    end
    if failed > 0 then
        Issue("warn", "swap refused", failed .. " spell(s) could not be placed on the bar")
        if manual or not R.db.warned then
            R.db.warned = true
            R.Print(failed .. " spell(s) could not be swapped (the game refused). Try again out of combat.")
        end
    end
    if manual and #changed == 0 and failed == 0 then R.Print("everything on your bars is already the highest rank.") end
    if R.UI and R.UI.Refresh then pcall(R.UI.Refresh) end
    return #changed, failed
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local f = CreateFrame("Frame")
local pending
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        _G.RankupDB = Merge(_G.RankupDB or {}, DEFAULTS)
        R.db = _G.RankupDB
        for _, e in ipairs({ "LEARNED_SPELL_IN_TAB", "SPELLS_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "TRAINER_CLOSED", "ACTIONBAR_SLOT_CHANGED" }) do
            pcall(f.RegisterEvent, f, e)
        end
        if R.Minimap then R.Minimap.Create() end
        return
    end
    if not (R.db and R.db.auto) and event ~= "ACTIONBAR_SLOT_CHANGED" then return end
    if event == "PLAYER_REGEN_ENABLED" then
        if again then again = nil C_Timer.After(1, function() R.Run() end) end
        return
    end
    if event == "ACTIONBAR_SLOT_CHANGED" then
        -- keep an open window up to date when you move things around
        if R.UI and R.UI.IsShown and R.UI.IsShown() and not pending then
            pending = true
            C_Timer.After(0.5, function() pending = nil if R.UI.Refresh then R.UI.Refresh() end end)
        end
        return
    end
    if pending then return end
    pending = true
    C_Timer.After(2, function() pending = nil R.Run() end)   -- let the game finish learning the spell first
end)

SLASH_RANKUP1 = "/rankup"
SlashCmdList.RANKUP = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "show" or msg == "window" or msg == "open" then
        if R.UI then R.UI.Toggle() end
    elseif msg == "minimap" then
        R.db.minimapHide = not R.db.minimapHide
        if R.Minimap then R.Minimap.Update() end
        R.Print("minimap button " .. (R.db.minimapHide and "hidden" or "shown"))
    else
        R.Run(true)
    end
end
