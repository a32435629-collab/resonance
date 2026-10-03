-- ============================================================
-- Resonance v4.0 — ui/build.lua
-- Авто-генерация UI из Registry + Options через Obsidian
-- ============================================================

local LibraryUrl = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(LibraryUrl .. "Library.lua"))()

local Registry = _G.ResonanceRegistry
local Options  = _G.ResonanceOptions
local Settings = _G.ResonanceSettings
local Utils    = _G.ResonanceUtils
local Keybind  = _G.ResonanceKeybind
local Notify   = _G.ResonanceNotifications

-- ============================================================
-- ОКНО
-- ============================================================
local Window = Library:CreateWindow({
    Title = "Resonance",
    Icon = "rocket",
    Footer = "Resonance v4.0 | FTAP",
    NotifySide = "Right",
    ShowCustomCursor = true,
    Resizable = true,
    EnableSidebarResize = true,
    EnableCompacting = true,
    SidebarCompacted = true,
    MinSidebarWidth = 200,
    SidebarCompactWidth = 56
})

Window:SetCornerRadius(20)

-- ============================================================
-- ТАБЫ
-- ============================================================
local Tabs = {
    Home       = Window:AddTab("Home", "house", "Профиль, статистика"),
    Main       = Window:AddTab("Main", "settings", "Основные настройки"),
    Combat     = Window:AddTab("Combat", "hand", "Захват / бой"),
    Auras      = Window:AddTab("Auras", "zap", "Автоматические ауры"),
    Protection = Window:AddTab("Protection", "shield", "Защита"),
    Targeting  = Window:AddTab("Targeting", "crosshair", "Работа с целью"),
    Movement   = Window:AddTab("Movement", "footprints", "Движение"),
    Visuals    = Window:AddTab("Visuals", "eye", "Визуальные функции"),
    Server     = Window:AddTab("Server", "server", "Работа с сервером"),
    Utility    = Window:AddTab("Utility", "wrench", "Утилиты"),
    Trolling   = Window:AddTab("Trolling", "ghost", "Троллинг"),
    Animations = Window:AddTab("Animations", "person-standing", "Анимации"),
    Kick       = Window:AddTab("Kick", "user-x", "Кик функции"),
    Filters    = Window:AddTab("Filters", "filter", "Исключения"),
    Settings   = Window:AddTab("Settings", "sliders-horizontal", "Настройки GUI")
}

-- ============================================================
-- HOME
-- ============================================================
local HomeLeft = Tabs.Home:AddLeftGroupbox("Добро пожаловать", "rocket")
HomeLeft:AddLabel("Resonance v4.0")
HomeLeft:AddLabel("Создано командой Rocket Way")
HomeLeft:AddLabel("Загружено: " .. os.date("%H:%M:%S"))

local HomeRight = Tabs.Home:AddRightGroupbox("Статистика", "activity")
local totalFuncs = 0
for _, mods in pairs(Registry or {}) do
    totalFuncs = totalFuncs + #mods
end
HomeRight:AddLabel("Функций: " .. totalFuncs)
HomeRight:AddLabel("Опций: " .. (function() local c=0; for _ in pairs(Options or {}) do c=c+1 end; return c end)())
HomeRight:AddLabel("Категорий: 11")

local HomeKeys = Tabs.Home:AddLeftGroupbox("Горячие клавиши", "keyboard")
HomeKeys:AddLabel("Right Shift — открыть/закрыть меню")

-- ============================================================
-- ОПЦИИ — распределяются по табам
-- ============================================================
local OptionGroups = {}

local function getGroup(tabName, sectionName)
    local tab = Tabs[tabName] or Tabs.Main
    local key = tostring(tabName) .. "::" .. tostring(sectionName)
    if not OptionGroups[key] then
        OptionGroups[key] = tab:AddLeftGroupbox(sectionName or "Настройки", "settings-2")
    end
    return OptionGroups[key]
end

for _, opt in pairs(Options or {}) do
    local group = getGroup(opt.tab, opt.section)

    if opt.type == "slider" then
        group:AddSlider(opt.name, opt.range[1], opt.range[2], opt.default, function(v)
            opt.onChanged(v, Settings)
        end)
    elseif opt.type == "toggle" then
        group:AddToggle(opt.name, {
            Default = opt.default,
            Tooltip = opt.tooltip,
            Callback = function(v) opt.onChanged(v, Settings) end
        })
    elseif opt.type == "dropdown" then
        group:AddDropdown(opt.name, {
            Options = opt.options,
            Default = opt.default,
            Multi = opt.multiple or false,
            Tooltip = opt.tooltip,
            Callback = function(v)
                local val = type(v) == "table" and v or {v}
                opt.onChanged(val, Settings)
            end
        })
    elseif opt.type == "input" then
        group:AddInput(opt.name, {
            Default = opt.default,
            Placeholder = "Введите...",
            Tooltip = opt.tooltip,
            Callback = function(txt) opt.onChanged(txt, Settings) end
        })
    elseif opt.type == "keybind" then
        group:AddKeybind(opt.name, {
            Default = opt.default,
            Callback = function(v) opt.onChanged(v, Settings) end
        })
    end
end

-- ============================================================
-- ФУНКЦИИ — распределяются по категориям
-- ============================================================
for cat, mods in pairs(Registry or {}) do
    local tab = Tabs[cat]
    if not tab then continue end

    local toggleGroup = nil
    local buttonGroup = nil

    for _, mod in ipairs(mods) do
        if mod.type == "toggle" then
            if not toggleGroup then
                toggleGroup = tab:AddLeftGroupbox("Toggles", "settings")
            end
            toggleGroup:AddToggle(mod.name, {
                Default = mod.default or false,
                Tooltip = mod.tooltip,
                Callback = function(v)
                    Settings[mod.id] = v
                    if v and mod.onEnable then
                        local ok, err = pcall(mod.onEnable, Settings, Utils)
                        if not ok then warn("[Resonance] onEnable " .. mod.id .. ": " .. tostring(err)) end
                    end
                    if not v and mod.onDisable then
                        local ok, err = pcall(mod.onDisable, Settings, Utils)
                        if not ok then warn("[Resonance] onDisable " .. mod.id .. ": " .. tostring(err)) end
                    end
                end
            })
        elseif mod.type == "button" then
            if not buttonGroup then
                buttonGroup = tab:AddRightGroupbox("Actions", "play")
            end
            buttonGroup:AddButton({
                Text = mod.name,
                Tooltip = mod.tooltip,
                Func = function()
                    if mod.onClick then
                        local ok, err = pcall(mod.onClick, Settings, Utils)
                        if not ok then warn("[Resonance] onClick " .. mod.id .. ": " .. tostring(err)) end
                    end
                end
            })
        end
    end
end

-- ============================================================
-- SETTINGS (GUI)
-- ============================================================
local GuiConfig = Tabs.Settings:AddLeftGroupbox("Конфиг", "save")
GuiConfig:AddButton({
    Text = "Загрузить конфиг",
    Func = function()
        local Config = _G.ResonanceConfig
        if Config then
            local ok, err = Config.load(Settings)
            if not ok then
                Library:Notify({ Title = "Config", Content = tostring(err), Duration = 3 })
            end
        end
    end
})
GuiConfig:AddButton({
    Text = "Сохранить конфиг",
    Func = function()
        local Config = _G.ResonanceConfig
        if Config then
            local ok, err = Config.save(Settings)
            if not ok then
                Library:Notify({ Title = "Config", Content = tostring(err), Duration = 3 })
            end
        end
    end
})
GuiConfig:AddButton({
    Text = "Удалить конфиг",
    Func = function()
        local Config = _G.ResonanceConfig
        if Config then Config.delete() end
    end
})

local GuiInfo = Tabs.Settings:AddRightGroupbox("Информация", "info")
GuiInfo:AddLabel("Версия: 4.0")
GuiInfo:AddLabel("Загружено: " .. os.date("%d.%m.%Y %H:%M"))

local GuiDanger = Tabs.Settings:AddLeftGroupbox("Опасная зона", "alert-triangle")
GuiDanger:AddButton({
    Text = "Уничтожить UI",
    Func = function()
        Library:Unload()
    end
})

-- ============================================================
-- KEYBIND
-- ============================================================
if Keybind and Keybind.registerMenuToggle then
    Keybind.registerMenuToggle(Settings.Keybind or "RightShift", Library)
else
    local UserInputService = game:GetService("UserInputService")
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            Library:Toggle()
        end
    end)
end

-- ============================================================
-- NOTIFY
-- ============================================================
Library:Notify({
    Title = "Resonance",
    Content = "Скрипт загружен. Right Shift — открыть меню.",
    Duration = 5
})

_G.ResonanceLibrary = Library
_G.ResonanceTabs = Tabs

return Library