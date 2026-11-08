-- Rankup minimap button: click = window, right-click = rank up now, shift-click = automatic on/off,
-- ctrl-click = issue log, drag = move around the ring.
local ADDON_NAME, R = ...
local MM = {}
R.Minimap = MM
local ICON = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Icon"
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local btn

local function Place()
    if not (btn and R.db) then return end
    local w = Minimap:GetWidth()
    if type(w) ~= "number" or w <= 0 then w = 140 end
    local r = w / 2 + 12
    local a = math.rad(tonumber(R.db.minimapAngle) or 150)
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end
local function DragUpdate()
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    R.db.minimapAngle = math.deg(atan2(py / scale - my, px / scale - mx))
    Place()
end
local function Tip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Rankup", 0.88, 0.69, 0.29)
    local total, up, keep = R.Counts(R.Scan())
    GameTooltip:AddLine(("%d spells on your bars, %d ready to rank up"):format(total, up), up > 0 and 0.5 or 0.8, up > 0 and 1 or 0.8, up > 0 and 0.5 or 0.8)
    GameTooltip:AddLine("Automatic: " .. (R.db.auto and "|cff55ff55on|r" or "|cffff5555off|r"), 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click: open the window", 1, 1, 1)
    GameTooltip:AddLine("Right-click: rank up now", 1, 1, 1)
    GameTooltip:AddLine("Shift-click: automatic on / off", 1, 1, 1)
    GameTooltip:AddLine("Ctrl-click: issue log", 1, 1, 1)
    GameTooltip:AddLine("Drag: move around the minimap", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

function MM.Create()
    if btn or not Minimap then return end
    btn = CreateFrame("Button", "RankupMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    local lvl = Minimap:GetFrameLevel()
    btn:SetFrameLevel((type(lvl) == "number" and lvl or 0) + 10)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", 7, -5)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON)
    icon:SetSize(18, 18)
    icon:SetPoint("TOPLEFT", 7, -6)
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    btn:SetScript("OnClick", function(_, button)
        if IsControlKeyDown() and _G.DavidIssues and _G.DavidIssues.Toggle then _G.DavidIssues.Toggle(ADDON_NAME) return end
        if IsShiftKeyDown() then
            R.db.auto = not R.db.auto
            R.Print("automatic rank-up " .. (R.db.auto and "on" or "off"))
            if R.UI then R.UI.Refresh() end
            return
        end
        if button == "RightButton" then R.Run(true) else R.UI.Toggle() end
    end)
    btn:SetScript("OnDragStart", function(self) GameTooltip:Hide() self:SetScript("OnUpdate", DragUpdate) end)
    btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    btn:SetScript("OnEnter", Tip)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    MM.Update()
end

function MM.Update()
    if not btn then return end
    Place()
    btn:SetShown(not (R.db and R.db.minimapHide))
end
