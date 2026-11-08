-- Rankup window (bars list, history, settings) and the "ranked up" toast.
local ADDON, R = ...
local UI = {}
R.UI = UI

local GOLD = { 0.84, 0.63, 0.3 }
local BG = { 0.025, 0.024, 0.03, 0.97 }
local ROW = 30
local win, rows, tab = nil, {}, "bars"

local function Backdrop(f, edge)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(unpack(BG))
    local c = edge or GOLD
    f:SetBackdropBorderColor(c[1], c[2], c[3], 1)
end
local function Flat(parent, w, h, text, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h)
    Backdrop(b)
    b:SetBackdropColor(0.09, 0.09, 0.11, 1)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.label:SetPoint("CENTER")
    b.label:SetText(text)
    b:SetScript("OnEnter", function(self) self:SetBackdropColor(0.16, 0.14, 0.1, 1) end)
    b:SetScript("OnLeave", function(self) self:SetBackdropColor(0.09, 0.09, 0.11, 1) end)
    b:SetScript("OnClick", onClick)
    return b
end
local function Ago(t)
    local s = time() - (t or 0)
    if s < 60 then return "just now" end
    if s < 3600 then return math.floor(s / 60) .. " min ago" end
    if s < 86400 then return math.floor(s / 3600) .. " h ago" end
    return math.floor(s / 86400) .. " d ago"
end

local function GetRow(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, win.child)
    r:SetSize(380, ROW)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.03 or 0)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(24, 24)
    r.icon:SetPoint("LEFT", 4, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 5)
    r.name:SetJustifyH("LEFT")
    r.sub = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.sub:SetPoint("LEFT", r.icon, "RIGHT", 8, -7)
    r.sub:SetJustifyH("LEFT")
    r.status = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.status:SetPoint("RIGHT", -6, 0)
    r.status:SetJustifyH("RIGHT")
    r:SetScript("OnEnter", function(self)
        if not self.entry then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.entry.name, 1, 0.82, 0)
        GameTooltip:AddLine(R.SlotLabel(self.entry.slot), 0.8, 0.8, 0.8)
        if self.entry.state == "up" then
            GameTooltip:AddLine("A higher rank is known. Rankup will swap it.", 0.5, 1, 0.5, true)
            GameTooltip:AddLine("Click: keep this rank on the bar.", 1, 1, 1, true)
        elseif self.entry.state == "keep" then
            GameTooltip:AddLine("Kept at this rank on purpose.", 1, 0.8, 0.3, true)
            GameTooltip:AddLine("Click: let Rankup upgrade it again.", 1, 1, 1, true)
        else
            GameTooltip:AddLine("Already the highest rank you know.", 0.7, 0.7, 0.7, true)
            GameTooltip:AddLine("Click: keep this rank even after you learn a higher one.", 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnClick", function(self)
        local e = self.entry
        if not e then return end
        R.db.ignore[e.name] = (not R.db.ignore[e.name]) or nil
        UI.Refresh()
    end)
    rows[i] = r
    return r
end

local function Paint()
    if not win then return end
    local n = 0
    if tab == "bars" then
        local list = R.Scan()
        table.sort(list, function(a, b)
            local oa = a.state == "up" and 0 or a.state == "keep" and 1 or 2
            local ob = b.state == "up" and 0 or b.state == "keep" and 1 or 2
            if oa ~= ob then return oa < ob end
            return a.slot < b.slot
        end)
        for _, e in ipairs(list) do
            n = n + 1
            local r = GetRow(n)
            r.entry = e
            r.icon:SetTexture(e.icon or 134400)
            r.name:SetText(e.name)
            r.sub:SetText((e.rank or "") .. (e.rank and "   " or "") .. R.SlotLabel(e.slot))
            if e.state == "up" then r.status:SetText("|cff55ff55Rank up ready|r" .. (e.bestRank and ("\n" .. e.bestRank) or ""))
            elseif e.state == "keep" then r.status:SetText("|cffffaa33Kept at this rank|r")
            else r.status:SetText("|cff888888Highest rank|r") end
            r:Show()
        end
        local total, up, keep = R.Counts(list)
        win.summary:SetText(("%d spell%s on your bars   |cff55ff55%d ready to rank up|r%s"):format(total, total == 1 and "" or "s", up,
            keep > 0 and ("   |cffffaa33" .. keep .. " kept|r") or ""))
        win.empty:SetShown(total == 0)
        win.empty:SetText("No spells on your action bars yet.")
    else
        local h = R.db.history
        for _, x in ipairs(h) do
            n = n + 1
            local r = GetRow(n)
            r.entry = nil
            r.icon:SetTexture(x.icon or 134400)
            r.name:SetText(x.name)
            r.sub:SetText(((x.from and (x.from .. " -> ") or "") .. (x.to or "higher rank")))
            r.status:SetText("|cff888888" .. Ago(x.t) .. "|r")
            r:Show()
        end
        win.summary:SetText(#h .. " recent change" .. (#h == 1 and "" or "s"))
        win.empty:SetShown(#h == 0)
        win.empty:SetText("Nothing has been swapped yet.")
    end
    for i = n + 1, #rows do rows[i].entry = nil rows[i]:Hide() end
    win.child:SetHeight(math.max(1, n * ROW))
    for key, cb in pairs(win.checks) do cb:SetChecked(R.db[key] and true or false) end
    win.tabBars.label:SetTextColor(tab == "bars" and 1 or 0.55, tab == "bars" and 0.82 or 0.55, tab == "bars" and 0 or 0.55)
    win.tabHist.label:SetTextColor(tab == "hist" and 1 or 0.55, tab == "hist" and 0.82 or 0.55, tab == "hist" and 0 or 0.55)
end

local function Build()
    win = CreateFrame("Frame", "RankupWindow", UIParent, "BackdropTemplate")
    win:SetSize(430, 520)
    win:SetPoint("CENTER", 0, 40)
    win:SetFrameStrata("HIGH")
    win:SetMovable(true)
    win:EnableMouse(true)
    win:SetClampedToScreen(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    Backdrop(win)
    win:Hide()
    tinsert(UISpecialFrames, "RankupWindow")

    local icon = win:CreateTexture(nil, "ARTWORK")
    icon:SetSize(26, 26)
    icon:SetPoint("TOPLEFT", 12, -10)
    icon:SetTexture("Interface\\AddOns\\Rankup\\Media\\Icon")
    local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    title:SetText("Rankup")
    title:SetTextColor(unpack(GOLD))
    local ver = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ver:SetPoint("LEFT", title, "RIGHT", 8, -2)
    ver:SetText("v" .. R.VERSION)
    local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    win.summary = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    win.summary:SetPoint("TOPLEFT", 14, -46)

    win.tabBars = Flat(win, 70, 22, "Bars", function() tab = "bars" Paint() end)
    win.tabBars:SetPoint("TOPLEFT", 12, -66)
    win.tabHist = Flat(win, 70, 22, "History", function() tab = "hist" Paint() end)
    win.tabHist:SetPoint("LEFT", win.tabBars, "RIGHT", 6, 0)

    local holder = CreateFrame("Frame", nil, win, "BackdropTemplate")
    holder:SetPoint("TOPLEFT", 12, -94)
    holder:SetPoint("BOTTOMRIGHT", -12, 118)
    Backdrop(holder, { 0.2, 0.2, 0.24 })
    holder:SetBackdropColor(0.05, 0.05, 0.06, 1)
    local sf = CreateFrame("ScrollFrame", "RankupScroll", holder, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 4, -4)
    sf:SetPoint("BOTTOMRIGHT", -26, 4)
    win.child = CreateFrame("Frame", nil, sf)
    win.child:SetSize(380, 1)
    sf:SetScrollChild(win.child)
    win.empty = holder:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    win.empty:SetPoint("CENTER")

    win.checks = {}
    local labels = {
        { "auto", "Rank up automatically after I learn a spell" },
        { "announce", "Say what changed in chat" },
        { "toast", "Show a pop-up with the spell icons" },
        { "sound", "Play a sound" },
    }
    local prev
    for i, l in ipairs(labels) do
        local cb = CreateFrame("CheckButton", nil, win, "UICheckButtonTemplate")
        cb:SetSize(22, 22)
        cb:SetPoint("BOTTOMLEFT", 14 + ((i > 2) and 215 or 0), (i % 2 == 1) and 88 or 64)
        local fs = cb.Text or cb.text or cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        if not (cb.Text or cb.text) then fs:SetPoint("LEFT", cb, "RIGHT", 2, 0) end
        fs:SetText(l[2])
        fs:SetFontObject("GameFontHighlightSmall")
        cb:SetScript("OnClick", function(self) R.db[l[1]] = self:GetChecked() and true or false end)
        win.checks[l[1]] = cb
    end

    local run = Flat(win, 150, 26, "Rank up now", function() R.Run(true) Paint() end)
    run:SetPoint("BOTTOMLEFT", 14, 14)
    local refresh = Flat(win, 90, 26, "Refresh", Paint)
    refresh:SetPoint("LEFT", run, "RIGHT", 8, 0)
    local hint = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMRIGHT", -14, 20)
    hint:SetText("Click a spell to keep its rank")
end

function UI.Refresh() if win and win:IsShown() then Paint() end end
function UI.IsShown() return win and win:IsShown() end
function UI.Toggle()
    if not win then Build() end
    if win:IsShown() then win:Hide() else Paint() win:Show() end
end

---------------------------------------------------------------------------
-- Toast: a small banner with the spells that were just ranked up
---------------------------------------------------------------------------
local toast, hideAt
function UI.Toast(changed)
    if not toast then
        toast = CreateFrame("Frame", "RankupToast", UIParent, "BackdropTemplate")
        toast:SetSize(300, 62)
        toast:SetPoint("TOP", UIParent, "TOP", 0, -170)
        toast:SetFrameStrata("TOOLTIP")
        Backdrop(toast)
        toast:EnableMouse(false)
        toast.icon = toast:CreateTexture(nil, "ARTWORK")
        toast.icon:SetSize(40, 40)
        toast.icon:SetPoint("LEFT", 10, 0)
        toast.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        toast.head = toast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        toast.head:SetPoint("TOPLEFT", toast.icon, "TOPRIGHT", 10, -2)
        toast.head:SetTextColor(unpack(GOLD))
        toast.body = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        toast.body:SetPoint("TOPLEFT", toast.head, "BOTTOMLEFT", 0, -3)
        toast.body:SetPoint("RIGHT", -10, 0)
        toast.body:SetJustifyH("LEFT")
        toast:SetScript("OnUpdate", function(self)
            local left = (hideAt or 0) - GetTime()
            if left <= 0 then self:Hide() self:SetAlpha(1) elseif left < 1 then self:SetAlpha(left) end
        end)
    end
    local names = {}
    for i, e in ipairs(changed) do if i <= 4 then names[#names + 1] = e.name end end
    if #changed > 4 then names[#names + 1] = "+" .. (#changed - 4) .. " more" end
    toast.icon:SetTexture(changed[1].icon or 134400)
    toast.head:SetText(#changed == 1 and "Spell ranked up" or (#changed .. " spells ranked up"))
    toast.body:SetText(table.concat(names, ", "))
    hideAt = GetTime() + 6
    toast:SetAlpha(1)
    toast:Show()
end
