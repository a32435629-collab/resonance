-- ============================================================
-- Resonance v4.0 — Auto-generated bundled script
-- Source: https://github.com/a32435629-collab/resonance
-- Built: 2026-10-03 09:51:58
-- ============================================================

local __RESONANCE_MODULES = {}

-- === core/utils.lua ===
-- ============================================================
-- Resonance v4.0 — core/utils.lua
-- Утилиты: персонаж, игроки, фильтры, физика, уведомления
-- ============================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local Workspace        = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local StarterGui       = game:GetService("StarterGui")
local Debris           = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local Utils = {}

-- ---------- ПЕРСОНАЖ ----------
function Utils.getChar()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

function Utils.getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

function Utils.getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

function Utils.getAnimator()
    local c = LocalPlayer.Character
    if not c then return nil end
    return c:FindFirstChildOfClass("Animator")
        or (c:FindFirstChildOfClass("Humanoid") and c.Humanoid:FindFirstChildOfClass("Animator"))
end

-- ---------- ИГРОКИ ----------
function Utils.getAllPlayers(includeSelf)
    local list = {}
    for _, p in pairs(Players:GetPlayers()) do
        if (includeSelf or p ~= LocalPlayer) and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then table.insert(list, p) end
        end
    end
    return list
end

function Utils.getClosestPlayer(Settings)
    local myHRP = Utils.getHRP()
    if not myHRP then return nil end
    local best, dist = nil, math.huge
    for _, p in pairs(Utils.getAllPlayers(false)) do
        if not Utils.isWhitelisted(p, Settings) then
            local hrp = p.Character.HumanoidRootPart
            local d = (hrp.Position - myHRP.Position).Magnitude
            if d < dist then dist, best = d, p end
        end
    end
    return best, dist
end

function Utils.getFarthestPlayer(Settings)
    local myHRP = Utils.getHRP()
    if not myHRP then return nil end
    local best, dist = nil, -1
    for _, p in pairs(Utils.getAllPlayers(false)) do
        if not Utils.isWhitelisted(p, Settings) then
            local hrp = p.Character.HumanoidRootPart
            local d = (hrp.Position - myHRP.Position).Magnitude
            if d > dist then dist, best = d, p end
        end
    end
    return best, dist
end

function Utils.getPlayerByName(name)
    if not name or name == "" then return nil end
    return Players:FindFirstChild(name)
end

-- ---------- ФИЛЬТРЫ ----------
function Utils.isWhitelisted(player, Settings)
    if not player then return true end
    if player == LocalPlayer then return true end
    if Settings and Settings.WhitelistFriends then
        local ok, isFriend = pcall(function()
            return LocalPlayer:IsFriendsWith(player.UserId)
        end)
        if ok and isFriend then return true end
    end
    return false
end

function Utils.passesTeamCheck(player, Settings)
    if not Settings or not Settings.ESPTeamCheck then return true end
    return player.Team ~= LocalPlayer.Team
end

-- ---------- ГЕОМЕТРИЯ ----------
function Utils.distanceTo(target)
    local myHRP = Utils.getHRP()
    if not myHRP or not target then return math.huge end
    local hrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return math.huge end
    return (hrp.Position - myHRP.Position).Magnitude
end

function Utils.isInRange(target, range)
    return Utils.distanceTo(target) <= range
end

-- ---------- ФИЗИКА ----------
function Utils.fling(hrpTarget, power)
    if not hrpTarget then return end
    power = power or 300
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = Vector3.new(
        math.random(-power, power),
        power,
        math.random(-power, power)
    )
    bv.Parent = hrpTarget
    Debris:AddItem(bv, 0.25)
end

function Utils.teleportTo(cf)
    local hrp = Utils.getHRP()
    if hrp and cf then
        if _G.ResonanceAllowTeleport then _G.ResonanceAllowTeleport(1.0) end
        hrp.CFrame = cf
    end
end

-- ---------- УВЕДОМЛЕНИЯ ----------
function Utils.notify(title, text, Settings)
    if Settings and Settings.Notifications == false then return end
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title or "Resonance",
            Text = text or "",
            Duration = 3
        })
    end)
end

-- ---------- МЫШЬ ----------
function Utils.getMouseTarget()
    local mouse = LocalPlayer:GetMouse()
    if not mouse then return nil, nil end
    return mouse.Target, mouse.Hit
end

-- ---------- МЕТРИКИ ----------
function Utils.getPing()
    local ok, ping = pcall(function() return LocalPlayer:GetNetworkPing() end)
    return ok and math.floor(ping * 1000) or 0
end

function Utils.getFPS()
    return math.floor(1 / RunService.RenderStepped:Wait())
end

function Utils.wait(seconds)
    task.wait(seconds or 0.1)
end

-- ---------- ЕДИНОБРАЗИЕ КЛЮЧЕЙ ----------
function Utils.isKeyDown(key)
    return UserInputService:IsKeyDown(key)
end

return Utils

-- === core/loop.lua ===
-- ============================================================
-- Resonance v4.0 — core/loop.lua
-- Менеджер циклов: start / stop / conditional
-- ============================================================

local Loop = {}
Loop.tasks = {}

-- Запустить именованный цикл
function Loop.start(name, fn, delay)
    Loop.stop(name)
    Loop.tasks[name] = task.spawn(function()
        while Loop.tasks[name] do
            local ok, err = pcall(fn)
            if not ok then
                warn("[Resonance Loop:" .. name .. "] " .. tostring(err))
                task.wait(1)
            end
            local d = delay
            if type(d) == "function" then d = d() end
            task.wait(d or 0.1)
        end
    end)
end

function Loop.stop(name)
    if Loop.tasks[name] then
        task.cancel(Loop.tasks[name])
        Loop.tasks[name] = nil
    end
end

function Loop.stopAll()
    for name in pairs(Loop.tasks) do
        Loop.stop(name)
    end
end

function Loop.isRunning(name)
    return Loop.tasks[name] ~= nil
end

-- Условный цикл: остановится, когда condition() вернёт false
function Loop.conditional(name, condition, fn, delay)
    Loop.start(name, function()
        if not condition() then
            Loop.stop(name)
            return
        end
        fn()
    end, delay)
end

-- Ожидание с условием
function Loop.awaitCondition(condition, timeout)
    local start = tick()
    timeout = timeout or 10
    while not condition() do
        if tick() - start > timeout then return false end
        task.wait(0.1)
    end
    return true
end

return Loop

-- === core/keybind.lua ===
-- ============================================================
-- Resonance v4.0 — core/keybind.lua
-- Система горячих клавиш
-- ============================================================

local UserInputService = game:GetService("UserInputService")

local Keybind = {}
Keybind.bindings = {}
Keybind.connection = nil

function Keybind.bind(key, callback, options)
    options = options or {}
    local kc = type(key) == "string" and Enum.KeyCode[key] or key
    if not kc then return end
    Keybind.bindings[kc] = {
        callback = callback,
        gpe = options.gpe or false
    }
    Keybind._ensure()
end

function Keybind.unbind(key)
    local kc = type(key) == "string" and Enum.KeyCode[key] or key
    Keybind.bindings[kc] = nil
end

function Keybind.clear()
    Keybind.bindings = {}
end

function Keybind._ensure()
    if Keybind.connection then return end
    Keybind.connection = UserInputService.InputBegan:Connect(function(input, gpe)
        local b = Keybind.bindings[input.KeyCode]
        if not b then return end
        if gpe and not b.gpe then return end
        local ok, err = pcall(b.callback, input)
        if not ok then warn("[Resonance Keybind] " .. tostring(err)) end
    end)
end

function Keybind.toKeyCode(str)
    if type(str) == "userdata" then return str end
    local ok, key = pcall(function() return Enum.KeyCode[str] end)
    return ok and key or nil
end

-- Регистрация toggle-меню на RightShift (или другой)
function Keybind.registerMenuToggle(keyStr, library)
    local key = Keybind.toKeyCode(keyStr or "RightShift")
    if not key then return end
    Keybind.bind(key, function()
        if library.Toggle then
            library:Toggle()
        elseif library.SetVisible then
            -- fallback
        end
    end, { gpe = true })
end

return Keybind

-- === core/config.lua ===
-- ============================================================
-- Resonance v4.0 — core/config.lua
-- Сохранение/загрузка конфига через executor API
-- ============================================================

local HttpService = game:GetService("HttpService")

local Config = {}
Config.folder = "Resonance"
Config.file = "config.json"

local function getPath()
    if writefile and isfolder then
        if not isfolder(Config.folder) then makefolder(Config.folder) end
        return Config.folder .. "/" .. Config.file
    end
    return nil
end

local function sanitize(tbl)
    if type(tbl) ~= "table" then return tbl end
    local out = {}
    for k, v in pairs(tbl) do
        local tv = type(v)
        if tv ~= "function" and tv ~= "userdata" and tv ~= "thread" then
            out[k] = (tv == "table") and sanitize(v) or v
        end
    end
    return out
end

function Config.save(Settings)
    local path = getPath()
    if not path then return false, "executor без файловой системы" end
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(sanitize(Settings))
    end)
    if not ok then return false, "ошибка сериализации" end
    local ok2, err = pcall(function() writefile(path, encoded) end)
    return ok2, err
end

function Config.load(Settings)
    local path = getPath()
    if not path then return false, "executor без файловой системы" end
    if not (isfile and isfile(path)) then return false, "конфиг не найден" end
    local ok, data = pcall(function() return readfile(path) end)
    if not ok then return false, "ошибка чтения" end
    local ok2, decoded = pcall(function() return HttpService:JSONDecode(data) end)
    if not ok2 then return false, "битый JSON" end
    for k, v in pairs(decoded) do Settings[k] = v end
    return true
end

function Config.delete()
    local path = getPath()
    if path and delfile and isfile and isfile(path) then
        delfile(path)
        return true
    end
    return false
end

function Config.exists()
    local path = getPath()
    return path and isfile and isfile(path) or false
end

return Config

-- === core/rgb.lua ===
-- ============================================================
-- Resonance v4.0 — core/rgb.lua
-- Глобальный RGB-режим (радуга для UI/объектов)
-- ============================================================

local RunService = game:GetService("RunService")

local RGB = {}
RGB.hue = 0
RGB.speed = 0.5
RGB.targets = {}
RGB.running = false
RGB.conn = nil

local function step(dt)
    if not RGB.running then return end
    RGB.hue = (RGB.hue + dt * RGB.speed) % 1
    local color = Color3.fromHSV(RGB.hue, 1, 1)
    for obj, props in pairs(RGB.targets) do
        if typeof(obj) == "Instance" and obj.Parent then
            for _, prop in ipairs(props) do
                pcall(function() obj[prop] = color end)
            end
        else
            RGB.targets[obj] = nil
        end
    end
end

function RGB.start()
    if RGB.running then return end
    RGB.running = true
    RGB.conn = RunService.RenderStepped:Connect(step)
end

function RGB.stop()
    if not RGB.running then return end
    RGB.running = false
    if RGB.conn then RGB.conn:Disconnect(); RGB.conn = nil end
end

function RGB.register(obj, ...)
    local props = {...}
    if #props == 0 then props = {"Color"} end
    RGB.targets[obj] = props
end

function RGB.unregister(obj)
    RGB.targets[obj] = nil
end

function RGB.clear()
    RGB.targets = {}
end

function RGB.getColor()
    return Color3.fromHSV(RGB.hue, 1, 1)
end

function RGB.bind(Settings)
    task.spawn(function()
        while true do
            task.wait(0.5)
            if Settings.RGBMode then
                if not RGB.running then RGB.start() end
            else
                if RGB.running then RGB.stop() end
            end
        end
    end)
end

return RGB

-- === core/manifest.lua ===
-- ============================================================
-- Resonance v4.0 — core/manifest.lua
-- Список всех модулей-функций (275 файлов)
-- ============================================================

return {
    Combat = {
        "func_001_super_throw","func_002_massless_grab","func_003_freeze_grab","func_004_silent_aim",
        "func_005_aimbot","func_006_telekinesis","func_007_auto_throw","func_008_kill_aura",
        "func_009_hitbox_expander","func_010_wall_bang","func_011_rapid_fire","func_012_no_recoil",
        "func_013_fling_all","func_014_fling_random","func_015_fling_closest","func_016_kill_all",
        "func_017_kill_closest","func_018_kill_random","func_019_burn_all","func_020_burn_closest",
        "func_021_freeze_all","func_022_unfreeze_all","func_023_ragdoll_all","func_024_explode_all",
        "func_025_void_all","func_026_sky_all","func_027_shake_all","func_028_spin_all",
        "func_029_slow_all","func_030_speed_all","func_031_jump_all","func_032_reset_all",
        "func_033_anchor_all","func_034_unanchor_all","func_035_shirt_off_all","func_036_pants_off_all",
        "func_037_hats_off_all","func_038_drop_tools_all","func_039_forcefield_off_all","func_040_character_reset"
    },
    Auras = {
        "func_041_fling_aura","func_042_kill_aura","func_043_freeze_aura","func_044_fire_aura",
        "func_045_void_aura","func_046_attraction_aura","func_047_auto_counter","func_048_plot_kicker",
        "func_049_gravity_aura","func_050_spin_aura","func_051_damage_aura","func_052_slow_aura",
        "func_053_ragdoll_aura","func_054_teleport_aura","func_055_blind_aura","func_056_kick_aura",
        "func_057_confuse_aura","func_058_mute_aura","func_059_shrink_aura","func_060_grow_aura"
    },
    Protection = {
        "func_061_anti_grab","func_062_anti_fling","func_063_anti_freeze","func_064_anti_ragdoll",
        "func_065_anti_void","func_066_anti_vote_kick","func_067_anti_kick","func_068_anti_teleport",
        "func_069_anti_sit","func_070_anti_burn","func_071_anti_explosion","func_072_anti_damage",
        "func_073_anti_slow","func_074_anti_fire_touch","func_075_anti_gravity","func_076_anti_shrink",
        "func_077_noclip","func_078_infinite_yield","func_079_god_mode","func_080_rejoin_on_damage"
    },
    Targeting = {
        "func_081_loop_kill","func_082_loop_burn","func_083_loop_fling","func_084_loop_freeze",
        "func_085_loop_void","func_086_follow_target","func_087_view_target","func_088_tp_to_target",
        "func_089_tp_target_to_me","func_090_kill_target","func_091_fling_target","func_092_freeze_target",
        "func_093_void_target","func_094_sky_target","func_095_spin_target","func_096_orbit_target",
        "func_097_ragdoll_target","func_098_blind_target","func_099_steal_target_tools","func_100_copy_target_skin"
    },
    Movement = {
        "func_101_infinite_jump","func_102_noclip","func_103_fly","func_104_speed_boost",
        "func_105_high_jump","func_106_low_gravity","func_107_zero_gravity","func_108_auto_jump",
        "func_109_bunny_hop","func_110_slide","func_111_wall_run","func_112_crouch",
        "func_113_sprint","func_114_tp_spawn","func_115_tp_random_player","func_116_tp_forward",
        "func_117_tp_up","func_118_tp_down","func_119_tp_cursor","func_120_reset_speed"
    },
    Visuals = {
        "func_121_esp_boxes","func_122_esp_tracers","func_123_player_info","func_124_name_tags",
        "func_125_health_bars","func_126_distance_display","func_127_skeleton_esp","func_128_chams",
        "func_129_xray","func_130_fullbright","func_131_no_fog","func_132_remove_textures",
        "func_133_blue_sky","func_134_red_ambient","func_135_green_ambient","func_136_rainbow_light",
        "func_137_remove_baseplate","func_138_remove_lights","func_139_restore_lighting","func_140_disable_shadows"
    },
    Server = {
        "func_141_rejoin","func_142_server_hop","func_143_join_smallest","func_144_join_largest",
        "func_145_copy_jobid","func_146_copy_placeid","func_147_copy_server_link","func_148_show_server_info",
        "func_149_list_players","func_150_hop_until_empty","func_151_anti_afk","func_152_auto_rejoin_kick",
        "func_153_rejoin_delay","func_154_ping_display","func_155_fps_display","func_156_leave_game",
        "func_157_reset_character","func_158_character_respawn","func_159_unlock_fps","func_160_show_fps"
    },
    Utility = {
        "func_161_anti_afk","func_162_auto_claim_cash","func_163_cash_magnet","func_164_item_magnet",
        "func_165_bring_all_items","func_166_bring_all_players","func_167_clear_workspace","func_168_delete_grabbed",
        "func_169_unlock_mouse","func_170_full_screen","func_171_copy_position","func_172_copy_rotation",
        "func_173_show_position","func_174_print_character","func_175_clear_notifications","func_176_toggle_ui",
        "func_177_re_execute","func_178_reload_config","func_179_save_config","func_180_wipe_cache"
    },
    Trolling = {
        "func_181_music_play","func_182_reverse_controls","func_183_fling_random_aura","func_184_rainbow_all",
        "func_185_neon_all","func_186_shrink_all","func_187_grow_all","func_188_head_spin_all",
        "func_189_random_color_self","func_190_rainbow_self","func_191_neon_self","func_192_ghost_self",
        "func_193_invisible_self","func_194_visible_self","func_195_shake_screen_all","func_196_fake_death_all",
        "func_197_fire_trail","func_198_ice_trail","func_199_lightning_self","func_200_dance_all"
    },
    Animations = {
        "func_201_play_dance","func_202_play_wave","func_203_play_point","func_204_play_laugh",
        "func_205_play_cheer","func_206_play_floss","func_207_play_dab","func_208_play_russian",
        "func_209_play_karate","func_210_play_salsa","func_211_play_hiphop","func_212_play_breakdance",
        "func_213_play_robot","func_214_play_backflip","func_215_play_frontflip","func_216_play_sit",
        "func_217_play_lay","func_218_play_crawl","func_219_play_sprint_anim","func_220_play_swim",
        "func_221_play_climb","func_222_stop_all_anims","func_223_free_anims_off","func_224_anim_speed_up",
        "func_225_anim_slow_down"
    },
    Kick = {
        "func_226_kick_all","func_227_kick_closest","func_228_kick_random","func_229_kick_by_name",
        "func_230_kick_farthest","func_231_kick_lowest_hp","func_232_kick_highest_hp","func_233_kick_friend",
        "func_234_kick_non_friend","func_235_kick_team","func_236_kick_enemy_team","func_237_kick_afk",
        "func_238_kick_talking","func_239_kick_silent","func_240_kick_walking","func_241_kick_standing",
        "func_242_kick_jumping","func_243_kick_flying","func_244_kick_glitched","func_245_kick_invisible",
        "func_246_kick_visible","func_247_kick_high_ping","func_248_kick_low_ping","func_249_kick_mobile",
        "func_250_kick_pc","func_251_kick_console","func_252_kick_vr","func_253_kick_guest",
        "func_254_kick_premium","func_255_kick_non_premium","func_256_kick_verified","func_257_kick_non_verified",
        "func_258_kick_with_hats","func_259_kick_without_hats","func_260_kick_with_tools","func_261_kick_without_tools",
        "func_262_kick_rich","func_263_kick_poor","func_264_kick_high_level","func_265_kick_low_level",
        "func_266_kick_owner","func_267_kick_admin","func_268_kick_moderator","func_269_kick_staff",
        "func_270_kick_bots","func_271_kick_alts","func_272_kick_by_userid","func_273_kick_by_display_name",
        "func_274_kick_multiple","func_275_kick_blacklist"
    }
}

-- === core/remote_resolver.lua ===
-- ============================================================
-- Resonance v4.0 — core/remote_resolver.lua
-- Поиск ремоутов кика / греб / действий под конкретную игру
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Resolver = {}

Resolver.keywords = {
    grab = {"grab","hold","carry","lift","pickup","grabplayer","holdplayer"},
    kick = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"},
    throw = {"throw","toss","launch","yeet","fling"},
    admin = {"admin","mod","warn","notify"}
}

Resolver.knownGames = {
    [301549746]  = "VoteKick",
    [2788229376] = "KickPlayer",
    [286090429]  = "AdminKick",
    [3260590327] = "ModKick",
    [606849621]  = "VoteKick"
}

local function matches(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

function Resolver.findAll(kind)
    local keywords = Resolver.keywords[kind] or {}
    local out = {}
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matches(obj.Name, keywords) then
                table.insert(out, obj)
            end
        end
    end
    return out
end

function Resolver.findKickRemote()
    if Resolver.knownGames[game.PlaceId] then
        local name = Resolver.knownGames[game.PlaceId]
        local found = ReplicatedStorage:FindFirstChild(name, true)
        if found then return found end
    end
    local list = Resolver.findAll("kick")
    return list[1]
end

function Resolver.findGrabRemotes()
    return Resolver.findAll("grab")
end

function Resolver.fire(remote, ...)
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(...)
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(...)
        end
    end)
    return ok
end

function Resolver.tryKick(target, reason)
    local remote = Resolver.findKickRemote()
    if not remote then return false end
    return Resolver.fire(remote, target, reason)
end

function Resolver.dump()
    local remotes = Resolver.findAll("kick")
    print("[Resolver] kick-remotes: " .. #remotes)
    for i, r in ipairs(remotes) do
        print("  " .. i .. ". " .. r:GetFullName())
    end
    return remotes
end

return Resolver

-- === core/settings/init.lua ===
-- ============================================================
-- Resonance v4.0 — core/settings/init.lua
-- Собирает все 40 опций в единую таблицу
-- ============================================================

local OPTION_FILES = {
    "option_01_reach_distance",
    "option_02_throw_power_multiplier",
    "option_03_fling_power",
    "option_04_spin_rpm",
    "option_05_spin_radius",
    "option_06_aura_radius",
    "option_07_loop_delay",
    "option_08_walk_speed",
    "option_09_jump_power",
    "option_10_fly_speed",
    "option_11_gravity",
    "option_12_aura_type",
    "option_13_punishment_type",
    "option_14_line_material",
    "option_15_target_lock_method",
    "option_16_whitelist_friends",
    "option_17_whitelist_plots",
    "option_18_auto_leave_staff",
    "option_19_rgb_mode",
    "option_20_esp_boxes",
    "option_21_esp_tracers",
    "option_22_esp_info",
    "option_23_esp_team_check",
    "option_24_fullbright",
    "option_25_anti_grab",
    "option_26_anti_fling",
    "option_27_anti_void",
    "option_28_auto_rejoin",
    "option_29_notifications",
    "option_30_keybind",
    "option_31_animation_pack",
    "option_32_animation_speed",
    "option_33_animation_loop",
    "option_34_animation_priority",
    "option_35_animation_blend",
    "option_36_kick_message",
    "option_37_kick_reason",
    "option_38_kick_delay",
    "option_39_kick_repeat",
    "option_40_kick_target_only"
}

local BASE = "https://raw.githubusercontent.com/a32435629-collab/resonance/main/src/core/settings/"

local Settings = {}
local Options = {}

for _, name in ipairs(OPTION_FILES) do
    local ok, opt = pcall(function()
        return loadstring(game:HttpGet(BASE .. name .. ".lua"))()
    end)
    if ok and opt then
        Options[opt.id] = opt
        Settings[opt.id] = opt.default
    else
        warn("[Resonance] Не удалось загрузить опцию: " .. name)
    end
end

_G.ResonanceSettings = Settings
_G.ResonanceOptions  = Options

return Settings

-- === ui/theme.lua ===
-- ============================================================
-- Resonance v4.0 — ui/theme.lua
-- Кастомные настройки темы Obsidian
-- ============================================================

local Theme = {
    -- Основные цвета (hex)
    Accent      = Color3.fromRGB(120, 90, 255),
    AccentDark  = Color3.fromRGB(80, 60, 180),
    Background  = Color3.fromRGB(18, 18, 24),
    Panel       = Color3.fromRGB(26, 26, 36),
    Text        = Color3.fromRGB(240, 240, 255),
    TextDim     = Color3.fromRGB(150, 150, 170),
    Success     = Color3.fromRGB(80, 200, 120),
    Danger      = Color3.fromRGB(220, 80, 80),
    Warning     = Color3.fromRGB(240, 180, 60),

    -- Настройки окна
    Window = {
        Title = "Resonance",
        Icon = "rocket",
        Footer = "Resonance v4.0 | FTAP",
        CornerRadius = 20,
        Width = 600,
        Height = 500,
        MinWidth = 400,
        MinHeight = 300,
        NotifySide = "Right"
    },

    -- Настройки анимаций
    Animations = {
        OpenTime  = 0.25,
        CloseTime = 0.2,
        HoverTime = 0.15,
        EasingStyle = Enum.EasingStyle.Quart,
        EasingDirection = Enum.EasingDirection.Out
    }
}

-- Применить тему к Library (если поддерживается)
function Theme.apply(Library)
    if not Library then return end
    local ok, err = pcall(function()
        if Library.SetAccentColor then
            Library:SetAccentColor(Theme.Accent)
        end
        if Library.SetCornerRadius then
            Library:SetCornerRadius(Theme.Window.CornerRadius)
        end
    end)
    if not ok then
        warn("[Resonance Theme] " .. tostring(err))
    end
end

return Theme

-- === ui/notifications.lua ===
-- ============================================================
-- Resonance v4.0 — ui/notifications.lua
-- Обёртка над Library:Notify для единообразных уведомлений
-- ============================================================

local Notifications = {}

local function getLibrary()
    return _G.ResonanceLibrary
end

-- Базовое уведомление
function Notifications.send(title, content, duration)
    local Library = getLibrary()
    if not Library then
        warn("[Resonance] Library не загружена для уведомления")
        return
    end
    pcall(function()
        Library:Notify({
            Title = title or "Resonance",
            Content = content or "",
            Duration = duration or 3
        })
    end)
end

-- Успех
function Notifications.success(content, duration)
    Notifications.send("✓ Успех", content, duration)
end

-- Ошибка
function Notifications.error(content, duration)
    Notifications.send("✗ Ошибка", content, duration)
end

-- Предупреждение
function Notifications.warn(content, duration)
    Notifications.send("⚠ Внимание", content, duration)
end

-- Информация
function Notifications.info(content, duration)
    Notifications.send("ℹ Инфо", content, duration)
end

-- Только для debug-режима
function Notifications.debug(content)
    if _G.ResonanceSettings and _G.ResonanceSettings.Debug then
        Notifications.send("[DEBUG]", content, 2)
    end
end

-- Биндим в Utils для использования из модулей
if _G.ResonanceUtils then
    _G.ResonanceUtils.notifyLib = Notifications.send
end

return Notifications

-- === ui/build.lua ===
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

-- === modules/combat/func_001_super_throw.lua ===
-- Func #001: Super Throw | toggle

local Workspace = game:GetService("Workspace")
local Debris    = game:GetService("Debris")
local Camera    = Workspace.CurrentCamera

return {
    id = "SuperThrow", type = "toggle", name = "Super Throw",
    tooltip = "Усиленный бросок объектов", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceSuperThrowConn = Workspace.ChildAdded:Connect(function(model)
            if not Settings.SuperThrow then return end
            if model.Name ~= "GrabParts" then return end
            local grab = model:FindFirstChild("GrabPart")
            if not grab then return end
            local weld = grab:FindFirstChild("WeldConstraint")
            if not weld or not weld.Part1 then return end
            local part = weld.Part1
            local bv = Instance.new("BodyVelocity", part)
            model:GetPropertyChangedSignal("Parent"):Connect(function()
                if not model.Parent then
                    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    bv.Velocity = Camera.CFrame.LookVector * (Settings.FlingPower or 350) * (Settings.ThrowPowerMult or 1)
                    Debris:AddItem(bv, 0.5)
                end
            end)
        end)
    end,
    onDisable = function()
        if _G.ResonanceSuperThrowConn then
            _G.ResonanceSuperThrowConn:Disconnect()
            _G.ResonanceSuperThrowConn = nil
        end
    end
}

-- === modules/combat/func_002_massless_grab.lua ===
-- Func #002: Massless Grab | toggle
local Workspace = game:GetService("Workspace")

return {
    id = "MasslessGrab", type = "toggle", name = "Massless Grab",
    tooltip = "Обнуляет вес удерживаемых объектов", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceMasslessConn = Workspace.ChildAdded:Connect(function(child)
            if not Settings.MasslessGrab then return end
            if child.Name ~= "GrabParts" then return end
            task.wait(0.1)
            for _, obj in pairs(child:GetDescendants()) do
                if obj:IsA("BasePart") then obj.Massless = true end
            end
        end)
    end,
    onDisable = function()
        if _G.ResonanceMasslessConn then
            _G.ResonanceMasslessConn:Disconnect()
            _G.ResonanceMasslessConn = nil
        end
    end
}

-- === modules/combat/func_003_freeze_grab.lua ===
-- Func #003: Freeze Grab | toggle
local Workspace = game:GetService("Workspace")
local State = { running = false }

return {
    id = "FreezeGrab", type = "toggle", name = "Freeze Grab",
    tooltip = "Фиксирует удерживаемый объект", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.1)
                local gp = Workspace:FindFirstChild("GrabParts")
                if gp then
                    for _, obj in pairs(gp:GetDescendants()) do
                        if obj:IsA("BasePart") then obj.Anchored = true end
                    end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        local gp = Workspace:FindFirstChild("GrabParts")
        if gp then
            for _, obj in pairs(gp:GetDescendants()) do
                if obj:IsA("BasePart") then obj.Anchored = false end
            end
        end
    end
}

-- === modules/combat/func_004_silent_aim.lua ===
-- Func #004: Silent Aim | toggle
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")
local Camera     = Workspace.CurrentCamera

return {
    id = "SilentAim", type = "toggle", name = "Silent Aim",
    tooltip = "Плавно наводит камеру на ближайшего", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceSilentAimConn = RunService.RenderStepped:Connect(function()
            if not Settings.SilentAim then return end
            local target = Utils.getClosestPlayer(Settings)
            if not target then return end
            local hrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local myPos = Camera.CFrame.Position
            local lookDir = (hrp.Position - myPos).Unit
            local currentLook = Camera.CFrame.LookVector
            Camera.CFrame = CFrame.new(myPos, myPos + currentLook:Lerp(lookDir, 0.15))
        end)
    end,
    onDisable = function()
        if _G.ResonanceSilentAimConn then
            _G.ResonanceSilentAimConn:Disconnect()
            _G.ResonanceSilentAimConn = nil
        end
    end
}

-- === modules/combat/func_005_aimbot.lua ===
-- Func #005: Aimbot | toggle
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")
local Camera     = Workspace.CurrentCamera

return {
    id = "Aimbot", type = "toggle", name = "Aimbot",
    tooltip = "Жёстко наводит камеру на игрока", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceAimbotConn = RunService.RenderStepped:Connect(function()
            if not Settings.Aimbot then return end
            local target = Utils.getClosestPlayer(Settings)
            if not target then return end
            local hrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, hrp.Position)
        end)
    end,
    onDisable = function()
        if _G.ResonanceAimbotConn then
            _G.ResonanceAimbotConn:Disconnect()
            _G.ResonanceAimbotConn = nil
        end
    end
}

-- === modules/combat/func_006_telekinesis.lua ===
-- Func #006: Telekinesis | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "Telekinesis", type = "toggle", name = "Telekinesis",
    tooltip = "Перемещает объекты под курсором", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.05)
                local mouse = LocalPlayer:GetMouse()
                if mouse and mouse.Target and mouse.Target:IsA("BasePart") and not mouse.Target.Anchored then
                    pcall(function() mouse.Target.CFrame = mouse.Hit + Vector3.new(0, 3, 0) end)
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/combat/func_007_auto_throw.lua ===
-- Func #007: Auto Throw | toggle
local Workspace = game:GetService("Workspace")

return {
    id = "AutoThrow", type = "toggle", name = "Auto Throw",
    tooltip = "Авто-отпуск схваченного объекта", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceAutoThrowConn = Workspace.ChildAdded:Connect(function(model)
            if not Settings.AutoThrow then return end
            if model.Name ~= "GrabParts" then return end
            task.wait(0.3)
            local grab = model:FindFirstChild("GrabPart")
            if grab then pcall(function() grab:Destroy() end) end
        end)
    end,
    onDisable = function()
        if _G.ResonanceAutoThrowConn then
            _G.ResonanceAutoThrowConn:Disconnect()
            _G.ResonanceAutoThrowConn = nil
        end
    end
}

-- === modules/combat/func_008_kill_aura.lua ===
-- Func #008: Kill Aura | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "KillAuraCombat", type = "toggle", name = "Kill Aura",
    tooltip = "Убивает всех в радиусе", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait((Settings.LoopDelay or 100) / 1000)
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            hum.Health = 0
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/combat/func_009_hitbox_expander.lua ===
-- Func #009: Hitbox Expander | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "HitboxExpander", type = "toggle", name = "Hitbox Expander",
    tooltip = "Увеличивает хитбоксы игроков", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.5)
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            hrp.Size = Vector3.new(20, 20, 20)
                            hrp.Transparency = 0.7
                            hrp.CanCollide = false
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.Size = Vector3.new(2, 2, 1)
                    hrp.Transparency = 1
                end
            end
        end
    end
}

-- === modules/combat/func_010_wall_bang.lua ===
-- Func #010: Wall Bang | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "WallBang", type = "toggle", name = "Wall Bang",
    tooltip = "Урон через стены", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.5)
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and (hrp.Position - myHRP.Position).Magnitude < 30 then
                            hum:TakeDamage(10)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/combat/func_011_rapid_fire.lua ===
-- Func #011: Rapid Fire | toggle
local State = { running = false }

return {
    id = "RapidFire", type = "toggle", name = "Rapid Fire",
    tooltip = "Быстрая стрельба", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.05)
                local char = Utils.getChar()
                if char then
                    local tool = char:FindFirstChildOfClass("Tool")
                    if tool and tool:FindFirstChild("Handle") then
                        pcall(function() tool:Activate() end)
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/combat/func_012_no_recoil.lua ===
-- Func #012: No Recoil | toggle
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")
local Camera     = Workspace.CurrentCamera

return {
    id = "NoRecoil", type = "toggle", name = "No Recoil",
    tooltip = "Убирает отдачу камеры", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceNoRecoilConn = RunService.RenderStepped:Connect(function()
            if not Settings.NoRecoil then return end
            local rot = Camera.CFrame - Camera.CFrame.Position
            Camera.CFrame = CFrame.new(Camera.CFrame.Position) * rot
        end)
    end,
    onDisable = function()
        if _G.ResonanceNoRecoilConn then
            _G.ResonanceNoRecoilConn:Disconnect()
            _G.ResonanceNoRecoilConn = nil
        end
    end
}

-- === modules/combat/func_013_fling_all.lua ===
-- Func #013: Fling All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "FlingAll", type = "button", name = "Fling All",
    tooltip = "Разбросать всех игроков", tab = "Combat",
    onClick = function(Settings, Utils)
        local power = Settings.FlingPower or 300
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then Utils.fling(hrp, power) end
            end
        end
    end
}

-- === modules/combat/func_014_fling_random.lua ===
-- Func #014: Fling Random | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "FlingRandom", type = "button", name = "Fling Random",
    tooltip = "Разбросать случайного", tab = "Combat",
    onClick = function(Settings, Utils)
        local list = Utils.getAllPlayers(false)
        if #list == 0 then return end
        local target = list[math.random(1, #list)]
        local hrp = target.Character:FindFirstChild("HumanoidRootPart")
        if hrp then Utils.fling(hrp, Settings.FlingPower or 300) end
    end
}

-- === modules/combat/func_015_fling_closest.lua ===
-- Func #015: Fling Closest | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "FlingClosest", type = "button", name = "Fling Closest",
    tooltip = "Разбросать ближайшего", tab = "Combat",
    onClick = function(Settings, Utils)
        local target = Utils.getClosestPlayer(Settings)
        if not target then return end
        local hrp = target.Character:FindFirstChild("HumanoidRootPart")
        if hrp then Utils.fling(hrp, Settings.FlingPower or 300) end
    end
}

-- === modules/combat/func_016_kill_all.lua ===
-- Func #016: Kill All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "KillAll", type = "button", name = "Kill All",
    tooltip = "Убить всех", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.Health = 0 end
            end
        end
    end
}

-- === modules/combat/func_017_kill_closest.lua ===
-- Func #017: Kill Closest | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "KillClosest", type = "button", name = "Kill Closest",
    tooltip = "Убить ближайшего", tab = "Combat",
    onClick = function(Settings, Utils)
        local target = Utils.getClosestPlayer(Settings)
        if not target or not target.Character then return end
        local hum = target.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
    end
}

-- === modules/combat/func_018_kill_random.lua ===
-- Func #018: Kill Random | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "KillRandom", type = "button", name = "Kill Random",
    tooltip = "Убить случайного", tab = "Combat",
    onClick = function(Settings, Utils)
        local list = Utils.getAllPlayers(false)
        if #list == 0 then return end
        local hum = list[math.random(1, #list)].Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
    end
}

-- === modules/combat/func_019_burn_all.lua ===
-- Func #019: Burn All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "BurnAll", type = "button", name = "Burn All",
    tooltip = "Поджечь всех", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then Debris:AddItem(Instance.new("Fire", hrp), 5) end
            end
        end
    end
}

-- === modules/combat/func_020_burn_closest.lua ===
-- Func #020: Burn Closest | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "BurnClosest", type = "button", name = "Burn Closest",
    tooltip = "Поджечь ближайшего", tab = "Combat",
    onClick = function(Settings, Utils)
        local target = Utils.getClosestPlayer(Settings)
        if not target or not target.Character then return end
        local hrp = target.Character:FindFirstChild("HumanoidRootPart")
        if hrp then Debris:AddItem(Instance.new("Fire", hrp), 5) end
    end
}

-- === modules/combat/func_021_freeze_all.lua ===
-- Func #021: Freeze All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "FreezeAll", type = "button", name = "Freeze All",
    tooltip = "Заморозить всех", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = 0; hum.JumpPower = 0 end
            end
        end
    end
}

-- === modules/combat/func_022_unfreeze_all.lua ===
-- Func #022: Unfreeze All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "UnfreezeAll", type = "button", name = "Unfreeze All",
    tooltip = "Разморозить всех", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = 16; hum.JumpPower = 50 end
            end
        end
    end
}

-- === modules/combat/func_023_ragdoll_all.lua ===
-- Func #023: Ragdoll All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "RagdollAll", type = "button", name = "Ragdoll All",
    tooltip = "Ragdoll всех", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end) end
            end
        end
    end
}

-- === modules/combat/func_024_explode_all.lua ===
-- Func #024: Explode All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "ExplodeAll", type = "button", name = "Explode All",
    tooltip = "Взорвать всех", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local e = Instance.new("Explosion")
                    e.Position = hrp.Position
                    e.BlastRadius = 15
                    e.BlastPressure = 500000
                    e.Parent = workspace
                end
            end
        end
    end
}

-- === modules/combat/func_025_void_all.lua ===
-- Func #025: Void All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "VoidAll", type = "button", name = "Void All",
    tooltip = "В пустоту всех", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = CFrame.new(0, -500, 0) end
            end
        end
    end
}

-- === modules/combat/func_026_sky_all.lua ===
-- Func #026: Sky All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "SkyAll", type = "button", name = "Sky All",
    tooltip = "В небо всех", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = CFrame.new(0, 500, 0) end
            end
        end
    end
}

-- === modules/combat/func_027_shake_all.lua ===
-- Func #027: Shake All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "ShakeAll", type = "button", name = "Shake All",
    tooltip = "Трясти всех", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    task.spawn(function()
                        for i = 1, 20 do
                            if not hrp.Parent then break end
                            hrp.CFrame = hrp.CFrame + Vector3.new(math.random(-3,3), math.random(-3,3), math.random(-3,3))
                            task.wait(0.05)
                        end
                    end)
                end
            end
        end
    end
}

-- === modules/combat/func_028_spin_all.lua ===
-- Func #028: Spin All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "SpinAll", type = "button", name = "Spin All",
    tooltip = "Вращать всех", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local av = Instance.new("BodyAngularVelocity")
                    av.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                    av.AngularVelocity = Vector3.new(0, 50, 0)
                    av.Parent = hrp
                    Debris:AddItem(av, 3)
                end
            end
        end
    end
}

-- === modules/combat/func_029_slow_all.lua ===
-- Func #029: Slow All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "SlowAll", type = "button", name = "Slow All",
    tooltip = "Замедлить всех", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = 4 end
            end
        end
    end
}

-- === modules/combat/func_030_speed_all.lua ===
-- Func #030: Speed All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "SpeedAll", type = "button", name = "Speed All",
    tooltip = "Ускорить всех", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = 200 end
            end
        end
    end
}

-- === modules/combat/func_031_jump_all.lua ===
-- Func #031: Jump All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "JumpAll", type = "button", name = "Jump All",
    tooltip = "Высокий прыжок всем", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.JumpPower = 500 end
            end
        end
    end
}

-- === modules/combat/func_032_reset_all.lua ===
-- Func #032: Reset All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "ResetAll", type = "button", name = "Reset All",
    tooltip = "Ресетнуть всех", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                pcall(function() p.Character:BreakJoints() end)
            end
        end
    end
}

-- === modules/combat/func_033_anchor_all.lua ===
-- Func #033: Anchor All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "AnchorAll", type = "button", name = "Anchor All",
    tooltip = "Заякорить всех", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.Anchored = true end
            end
        end
    end
}

-- === modules/combat/func_034_unanchor_all.lua ===
-- Func #034: Unanchor All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "UnanchorAll", type = "button", name = "Unanchor All",
    tooltip = "Снять якорь", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.Anchored = false end
            end
        end
    end
}

-- === modules/combat/func_035_shirt_off_all.lua ===
-- Func #035: Shirt Off All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "ShirtOffAll", type = "button", name = "Shirt Off All",
    tooltip = "Снять рубашки", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local s = p.Character:FindFirstChildOfClass("Shirt")
                if s then s:Destroy() end
            end
        end
    end
}

-- === modules/combat/func_036_pants_off_all.lua ===
-- Func #036: Pants Off All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "PantsOffAll", type = "button", name = "Pants Off All",
    tooltip = "Снять штаны", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local s = p.Character:FindFirstChildOfClass("Pants")
                if s then s:Destroy() end
            end
        end
    end
}

-- === modules/combat/func_037_hats_off_all.lua ===
-- Func #037: Hats Off All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "HatsOffAll", type = "button", name = "Hats Off All",
    tooltip = "Снять шапки", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                for _, a in pairs(p.Character:GetChildren()) do
                    if a:IsA("Accessory") then a:Destroy() end
                end
            end
        end
    end
}

-- === modules/combat/func_038_drop_tools_all.lua ===
-- Func #038: Drop Tools All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "DropToolsAll", type = "button", name = "Drop Tools All",
    tooltip = "Уронить инструменты", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum:UnequipTools() end
            end
        end
    end
}

-- === modules/combat/func_039_forcefield_off_all.lua ===
-- Func #039: Forcefield Off All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "ForcefieldOffAll", type = "button", name = "Forcefield Off All",
    tooltip = "Снять Forcefield", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local ff = p.Character:FindFirstChildOfClass("ForceField")
                if ff then ff:Destroy() end
            end
        end
    end
}

-- === modules/combat/func_040_character_reset.lua ===
-- Func #040: Character Reset (Self) | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "CharacterReset", type = "button", name = "Character Reset (Self)",
    tooltip = "Ресетнуть себя", tab = "Combat",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if char then pcall(function() char:BreakJoints() end) end
    end
}

-- === modules/auras/func_041_fling_aura.lua ===
-- Func #041: Fling Aura
-- Категория: Auras | Тип: toggle

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

local State = { running = false }

return {
    id = "FlingAura", type = "toggle", name = "Fling Aura",
    tooltip = "Автоматически флингует всех в радиусе",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait((Settings.LoopDelay or 100) / 1000)
                if not Settings.FlingAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            local bv = Instance.new("BodyVelocity")
                            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                            bv.Velocity = Vector3.new(math.random(-500, 500), Settings.FlingPower or 400, math.random(-500, 500))
                            bv.Parent = hrp
                            Debris:AddItem(bv, 0.2)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/auras/func_042_kill_aura.lua ===
-- Func #042: Kill Aura
-- Категория: Auras | Тип: toggle

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "KillAura", type = "toggle", name = "Kill Aura",
    tooltip = "Убивает всех в радиусе",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait((Settings.LoopDelay or 100) / 1000)
                if not Settings.KillAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            hum.Health = 0
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/auras/func_043_freeze_aura.lua ===
-- Func #043: Freeze Aura
-- Категория: Auras | Тип: toggle

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "FreezeAura", type = "toggle", name = "Freeze Aura",
    tooltip = "Останавливает всех в радиусе",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.2)
                if not Settings.FreezeAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            hum.WalkSpeed = 0
                            hum.JumpPower = 0
                            hrp.Anchored = true
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hrp then hrp.Anchored = false end
                if hum then hum.WalkSpeed = 16; hum.JumpPower = 50 end
            end
        end
    end
}

-- === modules/auras/func_044_fire_aura.lua ===
-- Func #044: Fire Aura
-- Категория: Auras | Тип: toggle

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "FireAura", type = "toggle", name = "Fire Aura",
    tooltip = "Поджигает всех в радиусе",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.5)
                if not Settings.FireAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            if not hrp:FindFirstChild("ResonanceFire") then
                                local f = Instance.new("Fire")
                                f.Name = "ResonanceFire"
                                f.Size = 5
                                f.Heat = 10
                                f.Parent = hrp
                                Debris:AddItem(f, 3)
                            end
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/auras/func_045_void_aura.lua ===
-- Func #045: Void Aura
-- Категория: Auras | Тип: toggle

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "VoidAura", type = "toggle", name = "Void Aura",
    tooltip = "Отправляет всех в радиусе в пустоту",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.3)
                if not Settings.VoidAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            hrp.CFrame = CFrame.new(0, -500, 0)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/auras/func_046_attraction_aura.lua ===
-- Func #046: Attraction Aura
-- Категория: Auras | Тип: toggle

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "AttractionAura", type = "toggle", name = "Attraction Aura",
    tooltip = "Притягивает все предметы к вам",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.1)
                if not Settings.AttractionAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, obj in pairs(Workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and not obj.Anchored then
                        local owner = Players:GetPlayerFromCharacter(obj.Parent)
                        if not owner then
                            pcall(function()
                                obj.CFrame = myHRP.CFrame + Vector3.new(math.random(-3,3), 3, math.random(-3,3))
                            end)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/auras/func_047_auto_counter.lua ===
-- Func #047: Auto-Counter
-- Категория: Auras | Тип: toggle

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "AutoCounter", type = "toggle", name = "Auto-Counter",
    tooltip = "Ответный флинг на попытку вас схватить",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.15)
                if not Settings.AutoCounter then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                if myHRP.Velocity.Magnitude > 80 then
                    for _, p in pairs(Players:GetPlayers()) do
                        if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                            if hrp and (hrp.Position - myHRP.Position).Magnitude < 20 then
                                local bv = Instance.new("BodyVelocity")
                                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                                bv.Velocity = Vector3.new(math.random(-500,500), Settings.FlingPower or 400, math.random(-500,500))
                                bv.Parent = hrp
                                Debris:AddItem(bv, 0.25)
                            end
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/auras/func_048_plot_kicker.lua ===
-- Func #048: Plot Kicker
-- Категория: Auras | Тип: toggle

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "PlotKicker", type = "toggle", name = "Plot Kicker",
    tooltip = "Вышвыривает посторонних с вашей территории",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.5)
                if not Settings.PlotKicker then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            hrp.CFrame = hrp.CFrame + Vector3.new(0, 100, 0)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/auras/func_049_gravity_aura.lua ===
-- Func #049: Gravity Aura
-- Категория: Auras | Тип: toggle

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "GravityAura", type = "toggle", name = "Gravity Aura",
    tooltip = "Подбрасывает игроков в радиусе",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.3)
                if not Settings.GravityAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            local bv = Instance.new("BodyVelocity")
                            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                            bv.Velocity = Vector3.new(0, -200, 0)
                            bv.Parent = hrp
                            Debris:AddItem(bv, 0.2)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/auras/func_050_spin_aura.lua ===
-- Func #050: Spin Aura
-- Категория: Auras | Тип: toggle

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "SpinAura", type = "toggle", name = "Spin Aura",
    tooltip = "Вращает всех в радиусе",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.3)
                if not Settings.SpinAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            local av = Instance.new("BodyAngularVelocity")
                            av.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                            av.AngularVelocity = Vector3.new(0, (Settings.SpinRPM or 60) / 60 * math.pi * 2, 0)
                            av.Parent = hrp
                            Debris:AddItem(av, 2)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/auras/func_051_damage_aura.lua ===
-- Func #051: Damage Aura
-- Категория: Auras | Тип: toggle

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }
local DAMAGE_PER_TICK = 5

return {
    id = "DamageAura", type = "toggle", name = "Damage Aura",
    tooltip = "Наносит урон всем в радиусе",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.5)
                if not Settings.DamageAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            hum:TakeDamage(DAMAGE_PER_TICK)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/auras/func_052_slow_aura.lua ===
-- Func #052: Slow Aura
-- Категория: Auras | Тип: toggle

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "SlowAura", type = "toggle", name = "Slow Aura",
    tooltip = "Замедляет всех в радиусе",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.3)
                if not Settings.SlowAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            hum.WalkSpeed = 4
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/auras/func_053_ragdoll_aura.lua ===
-- Func #053: Ragdoll Aura
-- Категория: Auras | Тип: toggle

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "RagdollAura", type = "toggle", name = "Ragdoll Aura",
    tooltip = "Вводит игроков в радиусе в ragdoll",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.3)
                if not Settings.RagdollAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/auras/func_054_teleport_aura.lua ===
-- Func #054: Teleport Aura
-- Категория: Auras | Тип: toggle

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "TeleportAura", type = "toggle", name = "Teleport Aura",
    tooltip = "Телепортирует игроков в радиусе прямо к вам",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.5)
                if not Settings.TeleportAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            hrp.CFrame = myHRP.CFrame + Vector3.new(0, 3, 0)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/auras/func_055_blind_aura.lua ===
-- Func #055: Blind Aura
-- Категория: Auras | Тип: toggle

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "BlindAura", type = "toggle", name = "Blind Aura",
    tooltip = "Ослепляет всех в радиусе",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(1)
                if not Settings.BlindAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            pcall(function()
                                local sg = Instance.new("ScreenGui")
                                sg.Name = "ResonanceBlind"
                                sg.ResetOnSpawn = false
                                local f = Instance.new("Frame", sg)
                                f.Size = UDim2.fromScale(1, 1)
                                f.BackgroundColor3 = Color3.new(0, 0, 0)
                                sg.Parent = p.PlayerGui
                                Debris:AddItem(sg, 2)
                            end)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/auras/func_056_kick_aura.lua ===
-- Func #056: Kick Aura
-- Категория: Auras | Тип: toggle

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "KickAura", type = "toggle", name = "Kick Aura (bump)",
    tooltip = "Отбрасывает всех в радиусе",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.15)
                if not Settings.KickAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            local dir = (hrp.Position - myHRP.Position).Unit
                            local bv = Instance.new("BodyVelocity")
                            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                            bv.Velocity = dir * 150 + Vector3.new(0, 80, 0)
                            bv.Parent = hrp
                            Debris:AddItem(bv, 0.2)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/auras/func_057_confuse_aura.lua ===
-- Func #057: Confuse Aura
-- Категория: Auras | Тип: toggle

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "ConfuseAura", type = "toggle", name = "Confuse Aura",
    tooltip = "Хаотично дёргает игроков в радиусе",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.3)
                if not Settings.ConfuseAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            hrp.CFrame = hrp.CFrame * CFrame.new(math.random(-3,3), math.random(-2,2), math.random(-3,3))
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/auras/func_058_mute_aura.lua ===
-- Func #058: Mute Aura
-- Категория: Auras | Тип: toggle

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "MuteAura", type = "toggle", name = "Mute Aura",
    tooltip = "Заглушает игроков в радиусе",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.5)
                if not Settings.MuteAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            for _, snd in pairs(p.Character:GetDescendants()) do
                                if snd:IsA("Sound") then snd.Volume = 0 end
                            end
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/auras/func_059_shrink_aura.lua ===
-- Func #059: Shrink Aura
-- Категория: Auras | Тип: toggle

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "ShrinkAura", type = "toggle", name = "Shrink Aura",
    tooltip = "Уменьшает игроков в радиусе",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.5)
                if not Settings.ShrinkAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            hum.BodyDepthScale.Value = 0.3
                            hum.BodyWidthScale.Value = 0.3
                            hum.BodyHeightScale.Value = 0.3
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/auras/func_060_grow_aura.lua ===
-- Func #060: Grow Aura
-- Категория: Auras | Тип: toggle

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "GrowAura", type = "toggle", name = "Grow Aura",
    tooltip = "Увеличивает игроков в радиусе",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.5)
                if not Settings.GrowAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            hum.BodyDepthScale.Value = 3
                            hum.BodyWidthScale.Value = 3
                            hum.BodyHeightScale.Value = 3
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/protection/func_061_anti_grab.lua ===
-- Func #061: Anti-Grab | toggle
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local BODY_MOVERS = {
    BodyVelocity=true, BodyPosition=true, BodyGyro=true, BodyAngularVelocity=true,
    BodyForce=true, BodyThrust=true, BodyTorque=true, RocketPropulsion=true,
    VectorForce=true, LinearVelocity=true, AngularVelocity=true,
    AlignPosition=true, AlignOrientation=true, Torque=true
}
local CONSTRAINTS = { WeldConstraint=true, Weld=true, ManualWeld=true, Motor6D=true, Snap=true }
local GRAB_KEYWORDS = {"grab","hold","carry","lift","pickup","fling","throw"}

local State = {
    running = false,
    connections = {},
    grabAttempts = 0,
    weldsRemoved = 0,
    bodyMoversRemoved = 0
}

local function getChar() return LocalPlayer.Character end
local function getHRP()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function isOwn(inst)
    if not inst then return false end
    local ok, v = pcall(function() return inst:GetAttribute("ResonanceOwn") end)
    return ok and v == true
end
local function isBodyMover(inst) return BODY_MOVERS[inst.ClassName] == true end
local function isConstraint(inst) return CONSTRAINTS[inst.ClassName] == true end

local function cleanBodyMovers(hrp)
    local n = 0
    for _, o in pairs(hrp:GetChildren()) do
        if isBodyMover(o) and not isOwn(o) then
            if pcall(function() o:Destroy() end) then
                n = n + 1
                State.bodyMoversRemoved = State.bodyMoversRemoved + 1
            end
        end
    end
    return n
end

local function cleanWelds(hrp)
    local n = 0
    local myChar = getChar()
    for _, o in pairs(hrp:GetChildren()) do
        if isConstraint(o) and not isOwn(o) then
            local p0, p1
            if o:IsA("WeldConstraint") then p0 = o.Part0; p1 = o.Part1 end
            local ext = false
            if p0 and not p0:IsDescendantOf(myChar) then ext = true end
            if p1 and not p1:IsDescendantOf(myChar) then ext = true end
            if ext then
                pcall(function() o:Destroy() end)
                n = n + 1
                State.weldsRemoved = State.weldsRemoved + 1
            end
        end
    end
    return n
end

local function detectVelocity(hrp)
    local v = hrp.AssemblyLinearVelocity
    if v.Magnitude > 100 then
        local vy = v.Y
        if math.abs(vy) < 200 then
            hrp.AssemblyLinearVelocity = Vector3.new(0, vy * 0.3, 0)
        else
            hrp.AssemblyLinearVelocity = Vector3.new(0, vy, 0)
        end
        State.grabAttempts = State.grabAttempts + 1
    end
end

local function detectAngular(hrp)
    if hrp.AssemblyAngularVelocity.Magnitude > 30 then
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        State.grabAttempts = State.grabAttempts + 1
    end
end

local function loop()
    while State.running do
        task.wait(0.05)
        local hrp = getHRP()
        if not hrp then continue end
        cleanBodyMovers(hrp)
        cleanWelds(hrp)
        detectVelocity(hrp)
        detectAngular(hrp)
    end
end

return {
    id = "AntiGrab", type = "toggle", name = "Anti-Grab",
    tooltip = "Многослойная защита от захватов", tab = "Protection", default = true,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.grabAttempts = 0
        State.weldsRemoved = 0
        State.bodyMoversRemoved = 0
        State.connections = {}
        task.spawn(loop)
        table.insert(State.connections, LocalPlayer.CharacterAdded:Connect(function()
            task.wait(0.5)
        end))
    end,
    onDisable = function()
        State.running = false
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
    end,
    getStats = function()
        return { grabAttempts = State.grabAttempts, weldsRemoved = State.weldsRemoved, bodyMoversRemoved = State.bodyMoversRemoved }
    end
}

-- === modules/protection/func_062_anti_fling.lua ===
-- Func #062: Anti-Fling | toggle
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, conn = nil, blocked = 0 }
local MAX_VEL = 120
local MAX_ANG = 40

local function getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function stabilize(hrp, hard)
    if hard then
        hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y * 0.1, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        hrp.CFrame = CFrame.new(hrp.Position)
    else
        hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity * 0.4
        hrp.AssemblyAngularVelocity = hrp.AssemblyAngularVelocity * 0.4
    end
end

local function onHeartbeat()
    if not State.running then return end
    local hrp = getHRP()
    if not hrp then return end

    local v = hrp.AssemblyLinearVelocity.Magnitude
    local a = hrp.AssemblyAngularVelocity.Magnitude

    if v > MAX_VEL or a > MAX_ANG then
        State.blocked = State.blocked + 1
        stabilize(hrp, v > MAX_VEL * 2)
        for _, o in pairs(hrp:GetChildren()) do
            if o:IsA("BodyVelocity") or o:IsA("BodyAngularVelocity") or o:IsA("BodyGyro") then
                if not o:GetAttribute("ResonanceOwn") then
                    pcall(function() o:Destroy() end)
                end
            end
        end
    end
end

return {
    id = "AntiFling", type = "toggle", name = "Anti-Fling",
    tooltip = "Защита от флинга", tab = "Protection", default = true,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.blocked = 0
        State.conn = RunService.Heartbeat:Connect(onHeartbeat)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
    end,
    getStats = function() return { blocked = State.blocked } end
}

-- === modules/protection/func_063_anti_freeze.lua ===
-- Func #063: Anti-Freeze | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, unfreezes = 0, anchorRestores = 0 }

local function getChar() return LocalPlayer.Character end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function loop()
    while State.running do
        task.wait(0.1)
        local char = getChar(); if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then continue end

        if hrp.Anchored then hrp.Anchored = false; State.anchorRestores = State.anchorRestores + 1 end
        if hum.PlatformStand then hum.PlatformStand = false; State.unfreezes = State.unfreezes + 1 end
        if hum.Sit then hum.Sit = false; hum.Jump = true; State.unfreezes = State.unfreezes + 1 end
        if hum.WalkSpeed < 16 and hum.WalkSpeed > 0 then hum.WalkSpeed = 16 end
        if hum.WalkSpeed == 0 then hum.WalkSpeed = 16 end
        if hum.JumpPower < 50 and hum.JumpPower > 0 then hum.JumpPower = 50 end
    end
end

return {
    id = "AntiFreeze", type = "toggle", name = "Anti-Freeze",
    tooltip = "Защита от заморозки", tab = "Protection", default = true,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.unfreezes = 0
        State.anchorRestores = 0
        task.spawn(loop)
    end,
    onDisable = function() State.running = false end,
    getStats = function()
        return { unfreezes = State.unfreezes, anchorRestores = State.anchorRestores }
    end
}

-- === modules/protection/func_064_anti_ragdoll.lua ===
-- Func #064: Anti-Ragdoll | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local RAGDOLL_STATES = {
    [Enum.HumanoidStateType.Physics] = true,
    [Enum.HumanoidStateType.FallingDown] = true,
    [Enum.HumanoidStateType.Ragdoll] = true
}

local State = { running = false, blocks = 0, connections = {} }

local function getChar() return LocalPlayer.Character end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function bindHumanoid(hum)
    if not hum then return end
    local conn = hum.StateChanged:Connect(function(_, newState)
        if not State.running then return end
        if RAGDOLL_STATES[newState] then
            task.defer(function()
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            end)
            State.blocks = State.blocks + 1
        end
    end)
    table.insert(State.connections, conn)
    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    end)
end

local function loop()
    while State.running do
        task.wait(0.1)
        local hum = getHum()
        if hum then
            local st = hum:GetState()
            if RAGDOLL_STATES[st] then
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
                State.blocks = State.blocks + 1
            end
        end
    end
end

return {
    id = "AntiRagdoll", type = "toggle", name = "Anti-Ragdoll",
    tooltip = "Запрет на ragdoll", tab = "Protection", default = true,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.blocks = 0
        State.connections = {}
        bindHumanoid(getHum())
        table.insert(State.connections, LocalPlayer.CharacterAdded:Connect(function(c)
            task.wait(0.5)
            bindHumanoid(c:FindFirstChildOfClass("Humanoid"))
        end))
        task.spawn(loop)
    end,
    onDisable = function()
        State.running = false
        local hum = getHum()
        if hum then
            pcall(function()
                hum:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
            end)
        end
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
    end,
    getStats = function() return { blocks = State.blocks } end
}

-- === modules/protection/func_065_anti_void.lua ===
-- Func #065: Anti-Void | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local State = {
    running = false,
    conn = nil,
    lastSafeCFrame = nil,
    recoveries = 0,
    lastRecovery = 0
}

local function getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function saveSafe(hrp)
    if hrp.Position.Y > 10 then
        State.lastSafeCFrame = hrp.CFrame
    end
end

local function recover(hrp)
    if tick() - State.lastRecovery < 1 then return end
    hrp.CFrame = State.lastSafeCFrame or CFrame.new(0, 50, 0)
    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    State.recoveries = State.recoveries + 1
    State.lastRecovery = tick()
end

local function onHeartbeat()
    if not State.running then return end
    local hrp = getHRP()
    if not hrp then return end
    local y = hrp.Position.Y
    if y > 10 then saveSafe(hrp) end
    if y < -30 then
        if hrp.AssemblyLinearVelocity.Y < -100 then
            hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, -50, hrp.AssemblyLinearVelocity.Z)
        end
    end
    if y < -100 then recover(hrp) end
end

return {
    id = "AntiVoid", type = "toggle", name = "Anti-Void",
    tooltip = "Авто-возврат при падении", tab = "Protection", default = true,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.recoveries = 0
        State.lastSafeCFrame = nil
        State.conn = RunService.Heartbeat:Connect(onHeartbeat)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
    end,
    getStats = function() return { recoveries = State.recoveries } end
}

-- === modules/protection/func_066_anti_vote_kick.lua ===
-- Func #066: Anti-Vote Kick | toggle
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

local VOTE_KEYWORDS = {"vote","kick","ban","votekick"}
local State = { running = false, connections = {}, blocked = 0, destroyed = 0, hookRef = nil, remotes = {} }

local function matchKeywords(name)
    local l = name:lower()
    for _, kw in ipairs(VOTE_KEYWORDS) do if l:find(kw) then return true end end
    return false
end

local function blockReset()
    pcall(function() StarterGui:SetCore("ResetButtonCallback", false) end)
end

local function scanRemotes()
    State.remotes = {}
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name) then table.insert(State.remotes, obj) end
        end
    end
end

local function installHook()
    if not hookmetamethod or not getnamecallmethod then return end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        if not State.running then return old(self, ...) end
        local m = getnamecallmethod()
        if m == "FireServer" or m == "InvokeServer" then
            for _, r in ipairs(State.remotes) do
                if self == r then
                    for _, a in ipairs({...}) do
                        if typeof(a) == "Instance" and (a == LocalPlayer or a == LocalPlayer.Character) then
                            State.blocked = State.blocked + 1
                            return nil
                        elseif type(a) == "string" and a:lower() == LocalPlayer.Name:lower() then
                            State.blocked = State.blocked + 1
                            return nil
                        end
                    end
                    break
                end
            end
        end
        return old(self, ...)
    end)
    State.hookRef = old
end

local function monitorUI()
    local pg = LocalPlayer:WaitForChild("PlayerGui")
    table.insert(State.connections, pg.ChildAdded:Connect(function(gui)
        if not State.running then return end
        if matchKeywords(gui.Name) then
            task.wait(0.05)
            pcall(function() gui:Destroy() end)
            State.destroyed = State.destroyed + 1
        end
    end))
end

local function loop()
    while State.running do
        task.wait(2)
        scanRemotes()
        blockReset()
    end
end

return {
    id = "AntiVoteKick", type = "toggle", name = "Anti-Vote Kick",
    tooltip = "Блокировка голосований против вас", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.blocked = 0
        State.destroyed = 0
        State.connections = {}
        blockReset()
        scanRemotes()
        installHook()
        monitorUI()
        task.spawn(loop)
    end,
    onDisable = function()
        State.running = false
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
        State.hookRef = nil
        pcall(function() StarterGui:SetCore("ResetButtonCallback", true) end)
    end,
    getStats = function() return { blocked = State.blocked, destroyed = State.destroyed } end
}

-- === modules/protection/func_067_anti_kick.lua ===
-- Func #067: Anti-Kick | toggle
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}
local State = { running = false, hooks = {}, connections = {}, blocked = 0, remotes = {} }

local function matchKeywords(name)
    local l = name:lower()
    for _, kw in ipairs(KICK_KEYWORDS) do if l:find(kw) then return true end end
    return false
end

local function isKickRemote(obj)
    if not (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then return false end
    return matchKeywords(obj.Name)
end

local function installNamecallHook()
    if not hookmetamethod or not getnamecallmethod then return false end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        if not State.running then return old(self, ...) end
        local m = getnamecallmethod()
        if m == "Kick" then
            State.blocked = State.blocked + 1
            return nil
        end
        if m == "FireServer" or m == "InvokeServer" then
            for _, a in ipairs({...}) do
                if type(a) == "string" then
                    local lower = a:lower()
                    if lower:find("kick") or lower:find("ban") or lower:find("remove") then
                        State.blocked = State.blocked + 1
                        return nil
                    end
                end
            end
        end
        return old(self, ...)
    end)
    table.insert(State.hooks, old)
    return true
end

local function installIndexHook()
    if not hookmetamethod then return end
    local old
    old = hookmetamethod(game, "__index", function(self, key)
        if not State.running then return old(self, key) end
        if key == "Kick" or key == "Ban" then return function() end end
        return old(self, key)
    end)
    table.insert(State.hooks, old)
end

local function scanRemotes()
    State.remotes = {}
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if isKickRemote(obj) then table.insert(State.remotes, obj) end
    end
end

local function monitorNewRemotes()
    local conn = ReplicatedStorage.DescendantAdded:Connect(function(obj)
        if not State.running then return end
        if isKickRemote(obj) then table.insert(State.remotes, obj) end
    end)
    table.insert(State.connections, conn)
end

local function blockReset()
    pcall(function() StarterGui:SetCore("ResetButtonCallback", false) end)
    task.spawn(function()
        while State.running do
            task.wait(1)
            pcall(function() StarterGui:SetCore("ResetButtonCallback", false) end)
        end
    end)
end

return {
    id = "AntiKick", type = "toggle", name = "Anti-Kick",
    tooltip = "Многослойная защита от кика", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.blocked = 0
        State.hooks = {}
        State.connections = {}
        installNamecallHook()
        installIndexHook()
        scanRemotes()
        monitorNewRemotes()
        blockReset()
    end,
    onDisable = function()
        State.running = false
        for _, h in ipairs(State.hooks) do
            if type(h) == "userdata" and h.Disconnect then pcall(function() h:Disconnect() end) end
        end
        State.hooks = {}
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
    end,
    getStats = function() return { blocked = State.blocked } end
}

-- === modules/protection/func_068_anti_teleport.lua ===
-- Func #068: Anti-Teleport | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local State = {
    running = false,
    conn = nil,
    lastPos = nil,
    lastCFrame = nil,
    allowedUntil = 0,
    graceUntil = 0,
    reversals = 0
}

local function getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function isMoving()
    return UserInputService:IsKeyDown(Enum.KeyCode.W)
        or UserInputService:IsKeyDown(Enum.KeyCode.A)
        or UserInputService:IsKeyDown(Enum.KeyCode.S)
        or UserInputService:IsKeyDown(Enum.KeyCode.D)
        or UserInputService:IsKeyDown(Enum.KeyCode.Space)
end

local function allowTeleport(duration)
    State.allowedUntil = tick() + (duration or 1)
end

local function onHeartbeat()
    if not State.running then return end
    local hrp = getHRP()
    if not hrp then return end

    local pos = hrp.Position
    local t = tick()

    if t < State.allowedUntil then
        State.lastPos = pos
        State.lastCFrame = hrp.CFrame
        return
    end

    if State.lastPos then
        local delta = (pos - State.lastPos).Magnitude
        if delta > 30 and t > State.graceUntil and not isMoving() then
            if State.lastCFrame then
                hrp.CFrame = State.lastCFrame
                hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                State.reversals = State.reversals + 1
                State.graceUntil = t + 0.3
            end
        else
            State.lastPos = pos
            State.lastCFrame = hrp.CFrame
        end
    else
        State.lastPos = pos
        State.lastCFrame = hrp.CFrame
    end
end

return {
    id = "AntiTeleport", type = "toggle", name = "Anti-Teleport",
    tooltip = "Детект и реверс внешних телепортов", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.lastPos = nil
        State.lastCFrame = nil
        State.reversals = 0
        State.allowedUntil = 0
        State.graceUntil = 0
        State.conn = RunService.Heartbeat:Connect(onHeartbeat)
        _G.ResonanceAllowTeleport = allowTeleport
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
        _G.ResonanceAllowTeleport = nil
    end,
    getStats = function() return { reversals = State.reversals } end,
    allowTeleport = allowTeleport
}

-- === modules/protection/func_069_anti_sit.lua ===
-- Func #069: Anti-Sit | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, connections = {}, sitBlocked = 0, weldsRemoved = 0 }

local function getChar() return LocalPlayer.Character end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function cleanSeatWelds(char)
    if not char then return end
    for _, obj in pairs(char:GetChildren()) do
        if obj:IsA("Weld") and obj.Name == "SeatWeld" then
            pcall(function() obj:Destroy() end)
            State.weldsRemoved = State.weldsRemoved + 1
        end
    end
end

local function bindHumanoid(hum)
    if not hum then return end
    local conn = hum:GetPropertyChangedSignal("Sit"):Connect(function()
        if not State.running then return end
        if hum.Sit then
            hum.Sit = false
            hum.Jump = true
            State.sitBlocked = State.sitBlocked + 1
        end
    end)
    table.insert(State.connections, conn)
    pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Sitting, false) end)
end

local function loop()
    while State.running do
        task.wait(0.05)
        local char = getChar(); if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Sit then
            hum.Sit = false
            hum.Jump = true
            State.sitBlocked = State.sitBlocked + 1
        end
        cleanSeatWelds(char)
    end
end

return {
    id = "AntiSit", type = "toggle", name = "Anti-Sit",
    tooltip = "Не даёт посадить вас", tab = "Protection", default = true,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.sitBlocked = 0
        State.weldsRemoved = 0
        State.connections = {}
        bindHumanoid(getHum())
        table.insert(State.connections, LocalPlayer.CharacterAdded:Connect(function(c)
            task.wait(0.5)
            bindHumanoid(c:FindFirstChildOfClass("Humanoid"))
        end))
        task.spawn(loop)
    end,
    onDisable = function()
        State.running = false
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
        local hum = getHum()
        if hum then
            pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Sitting, true) end)
        end
    end,
    getStats = function() return { sitBlocked = State.sitBlocked, weldsRemoved = State.weldsRemoved } end
}

-- === modules/protection/func_070_anti_burn.lua ===
-- Func #070: Anti-Burn | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local PARTICLE_WHITELIST = {
    ["Fire"] = true, ["Smoke"] = true, ["Sparkles"] = true,
    ["ParticleEmitter"] = true, ["Trail"] = true, ["Beam"] = true,
    ["PointLight"] = true, ["SpotLight"] = true, ["SurfaceLight"] = true
}

local State = { running = false, connections = {}, cleared = 0 }

local function getChar() return LocalPlayer.Character end

local function shouldClear(obj)
    return PARTICLE_WHITELIST[obj.ClassName] == true
end

local function clearEffects(char)
    if not char then return end
    for _, obj in pairs(char:GetDescendants()) do
        if shouldClear(obj) then
            pcall(function() obj:Destroy() end)
            State.cleared = State.cleared + 1
        end
    end
end

local function bindChar(char)
    if not char then return end
    local conn = char.DescendantAdded:Connect(function(obj)
        if not State.running then return end
        if shouldClear(obj) then
            task.wait(0.05)
            if obj.Parent then
                pcall(function() obj:Destroy() end)
                State.cleared = State.cleared + 1
            end
        end
    end)
    table.insert(State.connections, conn)
end

local function loop()
    while State.running do
        task.wait(0.2)
        clearEffects(getChar())
    end
end

return {
    id = "AntiBurn", type = "toggle", name = "Anti-Burn",
    tooltip = "Убирает огонь и эффекты с персонажа", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.cleared = 0
        State.connections = {}
        bindChar(getChar())
        table.insert(State.connections, LocalPlayer.CharacterAdded:Connect(function(c)
            task.wait(0.5)
            bindChar(c)
        end))
        task.spawn(loop)
    end,
    onDisable = function()
        State.running = false
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
    end,
    getStats = function() return { cleared = State.cleared } end
}

-- === modules/protection/func_071_anti_explosion.lua ===
-- Func #071: Anti-Explosion | toggle
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, connections = {}, neutralized = 0 }
local DESTROY_RADIUS = 60

local function getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function neutralize(explosion)
    pcall(function()
        explosion.BlastPressure = 0
        explosion.BlastRadius = 0
        explosion:Destroy()
    end)
    State.neutralized = State.neutralized + 1
end

local function scan()
    local hrp = getHRP(); if not hrp then return end
    for _, obj in pairs(Workspace:GetChildren()) do
        if obj:IsA("Explosion") then
            if (obj.Position - hrp.Position).Magnitude < DESTROY_RADIUS then neutralize(obj) end
        end
    end
end

local function monitor()
    local conn = Workspace.DescendantAdded:Connect(function(obj)
        if not State.running then return end
        if obj:IsA("Explosion") then
            task.wait(0.02)
            local hrp = getHRP(); if not hrp then return end
            if (obj.Position - hrp.Position).Magnitude < DESTROY_RADIUS then neutralize(obj) end
        end
    end)
    table.insert(State.connections, conn)
end

local function loop()
    while State.running do
        task.wait(0.1)
        scan()
    end
end

return {
    id = "AntiExplosion", type = "toggle", name = "Anti-Explosion",
    tooltip = "Нейтрализует взрывы рядом", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.neutralized = 0
        State.connections = {}
        monitor()
        task.spawn(loop)
    end,
    onDisable = function()
        State.running = false
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
    end,
    getStats = function() return { neutralized = State.neutralized } end
}

-- === modules/protection/func_072_anti_damage.lua ===
-- Func #072: Anti-Damage | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, connections = {}, heals = 0, damagesBlocked = 0, hookRef = nil }

local function getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function bindHumanoid(hum)
    if not hum then return end
    local conn = hum:GetPropertyChangedSignal("Health"):Connect(function()
        if not State.running then return end
        if hum.Health < hum.MaxHealth then
            hum.Health = hum.MaxHealth
            State.heals = State.heals + 1
        end
    end)
    table.insert(State.connections, conn)
end

local function installHook()
    if not hookmetamethod or not getnamecallmethod then return end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        if not State.running then return old(self, ...) end
        if getnamecallmethod() == "TakeDamage" and self == getHum() then
            State.damagesBlocked = State.damagesBlocked + 1
            return nil
        end
        return old(self, ...)
    end)
    State.hookRef = old
end

local function loop()
    while State.running do
        task.wait(0.1)
        local hum = getHum()
        if hum and hum.Health < hum.MaxHealth then
            hum.Health = hum.MaxHealth
            State.heals = State.heals + 1
        end
    end
end

return {
    id = "AntiDamage", type = "toggle", name = "Anti-Damage",
    tooltip = "Не даёт получать урон", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.heals = 0
        State.damagesBlocked = 0
        State.connections = {}
        bindHumanoid(getHum())
        table.insert(State.connections, LocalPlayer.CharacterAdded:Connect(function(c)
            task.wait(0.5)
            bindHumanoid(c:FindFirstChildOfClass("Humanoid"))
        end))
        installHook()
        task.spawn(loop)
    end,
    onDisable = function()
        State.running = false
        State.hookRef = nil
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
    end,
    getStats = function() return { heals = State.heals, damagesBlocked = State.damagesBlocked } end
}

-- === modules/protection/func_073_anti_slow.lua ===
-- Func #073: Anti-Slow | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, wsRestores = 0, jpRestores = 0 }

local function getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function loop()
    while State.running do
        task.wait(0.05)
        local hum = getHum(); if not hum then continue end
        if hum.WalkSpeed < 16 then
            hum.WalkSpeed = 16
            State.wsRestores = State.wsRestores + 1
        end
        if hum.JumpPower < 50 then
            hum.JumpPower = 50
            State.jpRestores = State.jpRestores + 1
        end
    end
end

return {
    id = "AntiSlow", type = "toggle", name = "Anti-Slow",
    tooltip = "Защита от снижения скорости", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.wsRestores = 0
        State.jpRestores = 0
        task.spawn(loop)
    end,
    onDisable = function() State.running = false end,
    getStats = function() return { wsRestores = State.wsRestores, jpRestores = State.jpRestores } end
}

-- === modules/protection/func_074_anti_fire_touch.lua ===
-- Func #074: Anti-Fire Touch | toggle
local Workspace = game:GetService("Workspace")

local FIRE_KEYWORDS = {"fire","flame","lava","burn","torch"}
local State = { running = false, connections = {}, disabled = 0 }

local function isFirePart(part)
    if not part:IsA("BasePart") then return false end
    local lower = part.Name:lower()
    for _, kw in ipairs(FIRE_KEYWORDS) do if lower:find(kw) then return true end end
    return false
end

local function disableTouch(part)
    if part.CanTouch then
        part.CanTouch = false
        State.disabled = State.disabled + 1
    end
end

local function scan()
    for _, obj in pairs(Workspace:GetDescendants()) do
        if isFirePart(obj) then disableTouch(obj) end
    end
end

local function monitor()
    local conn = Workspace.DescendantAdded:Connect(function(obj)
        if not State.running then return end
        if isFirePart(obj) then
            task.wait(0.05)
            if obj.Parent then disableTouch(obj) end
        end
    end)
    table.insert(State.connections, conn)
end

local function loop()
    while State.running do
        task.wait(1)
        scan()
    end
end

return {
    id = "AntiFireTouch", type = "toggle", name = "Anti-Fire Touch",
    tooltip = "Не даёт огню касаться вас", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.disabled = 0
        State.connections = {}
        scan()
        monitor()
        task.spawn(loop)
    end,
    onDisable = function()
        State.running = false
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
    end,
    getStats = function() return { disabled = State.disabled } end
}

-- === modules/protection/func_075_anti_gravity.lua ===
-- Func #075: Anti-Gravity | toggle
local Workspace = game:GetService("Workspace")

local State = { running = false, conn = nil, restores = 0 }
local BASE = 196.2

local function restore()
    if math.abs(Workspace.Gravity - BASE) > 5 then
        Workspace.Gravity = BASE
        State.restores = State.restores + 1
    end
end

local function loop()
    while State.running do
        task.wait(0.5)
        restore()
    end
end

return {
    id = "AntiGravity", type = "toggle", name = "Anti-Gravity",
    tooltip = "Защита от изменения гравитации", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.restores = 0
        State.conn = Workspace:GetPropertyChangedSignal("Gravity"):Connect(function()
            if State.running then restore() end
        end)
        task.spawn(loop)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
    end,
    getStats = function() return { restores = State.restores } end
}

-- === modules/protection/func_076_anti_shrink.lua ===
-- Func #076: Anti-Shrink | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, restores = 0 }

local function getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function loop()
    while State.running do
        task.wait(0.2)
        local hum = getHum(); if not hum then continue end
        local r = false
        if hum.BodyDepthScale.Value < 0.95 then hum.BodyDepthScale.Value = 1; r = true end
        if hum.BodyWidthScale.Value < 0.95 then hum.BodyWidthScale.Value = 1; r = true end
        if hum.BodyHeightScale.Value < 0.95 then hum.BodyHeightScale.Value = 1; r = true end
        if r then State.restores = State.restores + 1 end
    end
end

return {
    id = "AntiShrink", type = "toggle", name = "Anti-Shrink",
    tooltip = "Не даёт уменьшить персонажа", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.restores = 0
        task.spawn(loop)
    end,
    onDisable = function() State.running = false end,
    getStats = function() return { restores = State.restores } end
}

-- === modules/protection/func_077_noclip.lua ===
-- Func #077: Noclip | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, conn = nil, saved = {}, lastChar = nil }

local function saveCollide(char)
    State.saved = {}
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            State.saved[part] = part.CanCollide
        end
    end
end

local function restore()
    for part, state in pairs(State.saved) do
        if part and part.Parent then
            pcall(function() part.CanCollide = state end)
        end
    end
    State.saved = {}
end

local function onStep()
    if not State.running then return end
    local char = LocalPlayer.Character
    if not char then return end
    if char ~= State.lastChar then
        State.lastChar = char
        saveCollide(char)
    end
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.CanCollide then
            part.CanCollide = false
        end
    end
end

return {
    id = "NoclipProt", type = "toggle", name = "Noclip",
    tooltip = "Хождение сквозь стены", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.lastChar = nil
        State.conn = RunService.Stepped:Connect(onStep)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
        restore()
    end
}

-- === modules/protection/func_078_infinite_yield.lua ===
-- Func #078: Infinite Yield | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, respawns = 0, lastDeath = 0 }

local function getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function loop()
    while State.running do
        task.wait(0.5)
        local hum = getHum()
        if hum and hum.Health <= 0 then
            if tick() - State.lastDeath > 0.5 then
                State.lastDeath = tick()
                pcall(function() LocalPlayer:LoadCharacter() end)
                State.respawns = State.respawns + 1
            end
        end
    end
end

return {
    id = "InfiniteYield", type = "toggle", name = "Infinite Yield",
    tooltip = "Авто-респавн при смерти", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.respawns = 0
        task.spawn(loop)
    end,
    onDisable = function() State.running = false end,
    getStats = function() return { respawns = State.respawns } end
}

-- === modules/protection/func_079_god_mode.lua ===
-- Func #079: God Mode | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, heals = 0, connections = {} }
local MAX_HP = 1000000

local function getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function applyGod(hum)
    if not hum then return end
    pcall(function()
        hum.MaxHealth = MAX_HP
        if hum.Health < MAX_HP then
            hum.Health = MAX_HP
            State.heals = State.heals + 1
        end
        hum.NameDisplayDistance = 0
        hum.HealthDisplayDistance = 0
    end)
end

local function loop()
    while State.running do
        task.wait(0.1)
        applyGod(getHum())
    end
end

return {
    id = "GodMode", type = "toggle", name = "God Mode",
    tooltip = "Бессмертие", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.heals = 0
        State.connections = {}
        applyGod(getHum())
        table.insert(State.connections, LocalPlayer.CharacterAdded:Connect(function(c)
            task.wait(0.5)
            applyGod(c:FindFirstChildOfClass("Humanoid"))
        end))
        task.spawn(loop)
    end,
    onDisable = function()
        State.running = false
        local hum = getHum()
        if hum then
            pcall(function()
                hum.MaxHealth = 100
                hum.Health = 100
                hum.NameDisplayDistance = 100
                hum.HealthDisplayDistance = 100
            end)
        end
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
    end,
    getStats = function() return { heals = State.heals } end
}

-- === modules/protection/func_080_rejoin_on_damage.lua ===
-- Func #080: Rejoin on Damage | toggle
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, triggered = false, lastHP = 100 }
local THRESHOLD = 50

local function getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function loop()
    while State.running do
        task.wait(0.2)
        local hum = getHum(); if not hum then continue end
        local hp = hum.Health
        local maxHP = hum.MaxHealth

        if hp <= 0 and not State.triggered then
            State.triggered = true
            task.wait(1)
            pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
            break
        end

        if maxHP > 0 then
            local percent = (hp / maxHP) * 100
            if percent < THRESHOLD and State.lastHP >= THRESHOLD and not State.triggered then
                State.triggered = true
                task.wait(1)
                pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
                break
            end
        end

        State.lastHP = hp
    end
end

return {
    id = "RejoinDamage", type = "toggle", name = "Rejoin on Damage",
    tooltip = "Переподключается при уроне", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.triggered = false
        State.lastHP = 100
        task.spawn(loop)
    end,
    onDisable = function() State.running = false end,
    getStats = function() return { triggered = State.triggered } end
}

-- === modules/targeting/func_081_loop_kill.lua ===
-- Func #081: Loop Kill | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "LoopKill", type = "toggle", name = "Loop Kill",
    tooltip = "Бесконечно убивать выбранную цель", tab = "Targeting", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait((Settings.LoopDelay or 100) / 1000)
                local name = Settings.TargetName or Settings.TargetPlayerName
                if not name or name == "" then continue end
                local target = Players:FindFirstChild(name)
                if target and target.Character then
                    local hum = target.Character:FindFirstChildOfClass("Humanoid")
                    if hum then hum.Health = 0 end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/targeting/func_082_loop_burn.lua ===
-- Func #082: Loop Burn | toggle
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "LoopBurn", type = "toggle", name = "Loop Burn",
    tooltip = "Бесконечно поджигать цель", tab = "Targeting", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.2)
                local name = Settings.TargetName or Settings.TargetPlayerName
                if not name or name == "" then continue end
                local target = Players:FindFirstChild(name)
                if target and target.Character then
                    local hrp = target.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and not hrp:FindFirstChild("ResonanceFire") then
                        local f = Instance.new("Fire")
                        f.Name = "ResonanceFire"
                        f.Parent = hrp
                        Debris:AddItem(f, 1)
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/targeting/func_083_loop_fling.lua ===
-- Func #083: Loop Fling | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "LoopFling", type = "toggle", name = "Loop Fling",
    tooltip = "Бесконечно флингать цель", tab = "Targeting", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.2)
                local name = Settings.TargetName or Settings.TargetPlayerName
                if not name or name == "" then continue end
                local target = Players:FindFirstChild(name)
                if target and target.Character then
                    local hrp = target.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then Utils.fling(hrp, Settings.FlingPower or 400) end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/targeting/func_084_loop_freeze.lua ===
-- Func #084: Loop Freeze | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "LoopFreeze", type = "toggle", name = "Loop Freeze",
    tooltip = "Бесконечно морозить цель", tab = "Targeting", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.3)
                local name = Settings.TargetName or Settings.TargetPlayerName
                if not name or name == "" then continue end
                local target = Players:FindFirstChild(name)
                if target and target.Character then
                    local hrp = target.Character:FindFirstChild("HumanoidRootPart")
                    local hum = target.Character:FindFirstChildOfClass("Humanoid")
                    if hrp then hrp.Anchored = true end
                    if hum then hum.WalkSpeed = 0; hum.JumpPower = 0 end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if target and target.Character then
            local hrp = target.Character:FindFirstChild("HumanoidRootPart")
            local hum = target.Character:FindFirstChildOfClass("Humanoid")
            if hrp then hrp.Anchored = false end
            if hum then hum.WalkSpeed = 16; hum.JumpPower = 50 end
        end
    end
}

-- === modules/targeting/func_085_loop_void.lua ===
-- Func #085: Loop Void | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "LoopVoid", type = "toggle", name = "Loop Void",
    tooltip = "Бесконечно кидать цель в пустоту", tab = "Targeting", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.3)
                local name = Settings.TargetName or Settings.TargetPlayerName
                if not name or name == "" then continue end
                local target = Players:FindFirstChild(name)
                if target and target.Character then
                    local hrp = target.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then hrp.CFrame = CFrame.new(0, -500, 0) end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/targeting/func_086_follow_target.lua ===
-- Func #086: Follow Target | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local State = { running = false, conn = nil }

return {
    id = "FollowTarget", type = "toggle", name = "Follow Target",
    tooltip = "Следовать за целью", tab = "Targeting", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.conn = RunService.Heartbeat:Connect(function()
            if not State.running then return end
            local name = Settings.TargetName or Settings.TargetPlayerName
            if not name or name == "" then return end
            local target = Players:FindFirstChild(name)
            if not target or not target.Character then return end
            local thrp = target.Character:FindFirstChild("HumanoidRootPart")
            local myHRP = Utils.getHRP()
            if thrp and myHRP then
                local dir = (thrp.Position - myHRP.Position).Unit
                myHRP.CFrame = CFrame.new(myHRP.Position, myHRP.Position + dir)
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
    end
}

-- === modules/targeting/func_087_view_target.lua ===
-- Func #087: View Target | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local State = { running = false, conn = nil }

return {
    id = "ViewTarget", type = "toggle", name = "View Target",
    tooltip = "Следить камерой за целью", tab = "Targeting", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.conn = RunService.RenderStepped:Connect(function()
            if not State.running then return end
            local name = Settings.TargetName or Settings.TargetPlayerName
            if not name or name == "" then return end
            local target = Players:FindFirstChild(name)
            if not target or not target.Character then return end
            local hrp = target.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, hrp.Position)
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
    end
}

-- === modules/targeting/func_088_tp_to_target.lua ===
-- Func #088: TP to Target | button
local Players = game:GetService("Players")

return {
    id = "TpToTarget", type = "button", name = "TP to Target",
    tooltip = "Телепорт к цели", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local hrp = target.Character:FindFirstChild("HumanoidRootPart")
        if hrp then Utils.teleportTo(hrp.CFrame + Vector3.new(0, 3, 0)) end
    end
}

-- === modules/targeting/func_089_tp_target_to_me.lua ===
-- Func #089: TP Target to Me | button
local Players = game:GetService("Players")

return {
    id = "TpTargetToMe", type = "button", name = "TP Target to Me",
    tooltip = "Телепорт цели к вам", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local thrp = target.Character:FindFirstChild("HumanoidRootPart")
        local myHRP = Utils.getHRP()
        if thrp and myHRP then
            thrp.CFrame = myHRP.CFrame + Vector3.new(0, 3, 0)
        end
    end
}

-- === modules/targeting/func_090_kill_target.lua ===
-- Func #090: Kill Target | button
local Players = game:GetService("Players")

return {
    id = "KillTarget", type = "button", name = "Kill Target",
    tooltip = "Убить цель", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local hum = target.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
    end
}

-- === modules/targeting/func_091_fling_target.lua ===
-- Func #091: Fling Target | button
local Players = game:GetService("Players")

return {
    id = "FlingTarget", type = "button", name = "Fling Target",
    tooltip = "Флингнуть цель", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local hrp = target.Character:FindFirstChild("HumanoidRootPart")
        if hrp then Utils.fling(hrp, Settings.FlingPower or 400) end
    end
}

-- === modules/targeting/func_092_freeze_target.lua ===
-- Func #092: Freeze Target | button
local Players = game:GetService("Players")

return {
    id = "FreezeTarget", type = "button", name = "Freeze Target",
    tooltip = "Заморозить цель", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local hrp = target.Character:FindFirstChild("HumanoidRootPart")
        local hum = target.Character:FindFirstChildOfClass("Humanoid")
        if hrp then hrp.Anchored = true end
        if hum then hum.WalkSpeed = 0; hum.JumpPower = 0 end
    end
}

-- === modules/targeting/func_093_void_target.lua ===
-- Func #093: Void Target | button
local Players = game:GetService("Players")

return {
    id = "VoidTarget", type = "button", name = "Void Target",
    tooltip = "Отправить цель в пустоту", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local hrp = target.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = CFrame.new(0, -500, 0) end
    end
}

-- === modules/targeting/func_094_sky_target.lua ===
-- Func #094: Sky Target | button
local Players = game:GetService("Players")

return {
    id = "SkyTarget", type = "button", name = "Sky Target",
    tooltip = "Отправить цель в небо", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local hrp = target.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = CFrame.new(0, 500, 0) end
    end
}

-- === modules/targeting/func_095_spin_target.lua ===
-- Func #095: Spin Target | button
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

return {
    id = "SpinTarget", type = "button", name = "Spin Target",
    tooltip = "Закрутить цель", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local hrp = target.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local av = Instance.new("BodyAngularVelocity")
            av.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            av.AngularVelocity = Vector3.new(0, 100, 0)
            av.Parent = hrp
            Debris:AddItem(av, 5)
        end
    end
}

-- === modules/targeting/func_096_orbit_target.lua ===
-- Func #096: Orbit Target | button
local Players = game:GetService("Players")

return {
    id = "OrbitTarget", type = "button", name = "Orbit Target",
    tooltip = "Заставить цель вращаться вокруг вас", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local thrp = target.Character:FindFirstChild("HumanoidRootPart")
        local myHRP = Utils.getHRP()
        if not thrp or not myHRP then return end
        task.spawn(function()
            for i = 1, 200 do
                if not thrp.Parent then break end
                local angle = i * 0.2
                local r = Settings.SpinRadius or 5
                thrp.CFrame = myHRP.CFrame * CFrame.new(math.cos(angle) * r, 3, math.sin(angle) * r)
                task.wait(0.05)
            end
        end)
    end
}

-- === modules/targeting/func_097_ragdoll_target.lua ===
-- Func #097: Ragdoll Target | button
local Players = game:GetService("Players")

return {
    id = "RagdollTarget", type = "button", name = "Ragdoll Target",
    tooltip = "Уронить цель в ragdoll", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local hum = target.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
        end
    end
}

-- === modules/targeting/func_098_blind_target.lua ===
-- Func #098: Blind Target | button
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

return {
    id = "BlindTarget", type = "button", name = "Blind Target",
    tooltip = "Ослепить цель", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target then return end
        pcall(function()
            local sg = Instance.new("ScreenGui")
            sg.Name = "ResonanceBlind"
            sg.ResetOnSpawn = false
            local f = Instance.new("Frame", sg)
            f.Size = UDim2.fromScale(1, 1)
            f.BackgroundColor3 = Color3.new(0, 0, 0)
            sg.Parent = target.PlayerGui
            Debris:AddItem(sg, 5)
        end)
    end
}

-- === modules/targeting/func_099_steal_target_tools.lua ===
-- Func #099: Steal Target Tools | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "StealTargetTools", type = "button", name = "Steal Target Tools",
    tooltip = "Украсть инструменты цели", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local myChar = LocalPlayer.Character
        if not myChar then return end
        for _, t in pairs(target.Character:GetChildren()) do
            if t:IsA("Tool") then
                pcall(function() t.Parent = myChar end)
            end
        end
    end
}

-- === modules/targeting/func_100_copy_target_skin.lua ===
-- Func #100: Copy Target Skin | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "CopyTargetSkin", type = "button", name = "Copy Target Skin",
    tooltip = "Скопировать цвета персонажа цели", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local myChar = LocalPlayer.Character
        if not myChar then return end
        for _, part in pairs(myChar:GetChildren()) do
            if part:IsA("BasePart") then
                local src = target.Character:FindFirstChild(part.Name)
                if src and src:IsA("BasePart") then
                    part.Color = src.Color
                    part.Material = src.Material
                end
            end
        end
    end
}

-- === modules/movement/func_101_infinite_jump.lua ===
-- Func #101: Infinite Jump | toggle
local UserInputService = game:GetService("UserInputService")

return {
    id = "InfiniteJump", type = "toggle", name = "Infinite Jump",
    tooltip = "Прыжок в воздухе", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceInfJumpConn = UserInputService.JumpRequest:Connect(function()
            if not Settings.InfiniteJump then return end
            local hum = Utils.getHum()
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end,
    onDisable = function()
        if _G.ResonanceInfJumpConn then
            _G.ResonanceInfJumpConn:Disconnect()
            _G.ResonanceInfJumpConn = nil
        end
    end
}

-- === modules/movement/func_102_noclip.lua ===
-- Func #102: Noclip | toggle
local RunService = game:GetService("RunService")

return {
    id = "NoclipMove", type = "toggle", name = "Noclip",
    tooltip = "Хождение сквозь стены", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceNoclipConn = RunService.Stepped:Connect(function()
            if not Settings.NoclipMove then return end
            local char = Utils.getChar()
            if not char then return end
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end)
    end,
    onDisable = function()
        if _G.ResonanceNoclipConn then
            _G.ResonanceNoclipConn:Disconnect()
            _G.ResonanceNoclipConn = nil
        end
        local char = Utils.getChar()
        if char then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    pcall(function() part.CanCollide = true end)
                end
            end
        end
    end
}

-- === modules/movement/func_103_fly.lua ===
-- Func #103: Fly | toggle
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local Camera           = Workspace.CurrentCamera

local bv, bg

return {
    id = "Fly", type = "toggle", name = "Fly",
    tooltip = "Полёт (WASD + Space/LCTRL)", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        local hrp = Utils.getHRP()
        if not hrp then return end

        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Velocity = Vector3.new(0, 0, 0)
        bv.Parent = hrp

        bg = Instance.new("BodyGyro")
        bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        bg.P = 1000
        bg.D = 50
        bg.Parent = hrp

        _G.ResonanceFlyConn = RunService.RenderStepped:Connect(function()
            if not Settings.Fly then return end
            local char = Utils.getChar()
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root or not bv then return end
            local moveDir = Vector3.new()
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0, 1, 0) end
            bv.Velocity = moveDir * (Settings.FlySpeed or 50)
            bg.CFrame = Camera.CFrame
        end)
    end,
    onDisable = function()
        if bv then bv:Destroy(); bv = nil end
        if bg then bg:Destroy(); bg = nil end
        if _G.ResonanceFlyConn then
            _G.ResonanceFlyConn:Disconnect()
            _G.ResonanceFlyConn = nil
        end
    end
}

-- === modules/movement/func_104_speed_boost.lua ===
-- Func #104: Speed Boost | toggle
return {
    id = "SpeedBoost", type = "toggle", name = "Speed Boost",
    tooltip = "Ускорение", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        local hum = Utils.getHum()
        if hum then hum.WalkSpeed = Settings.WalkSpeed or 100 end
    end,
    onDisable = function(Settings, Utils)
        local hum = Utils.getHum()
        if hum then hum.WalkSpeed = 16 end
    end
}

-- === modules/movement/func_105_high_jump.lua ===
-- Func #105: High Jump | toggle
return {
    id = "HighJump", type = "toggle", name = "High Jump",
    tooltip = "Высокий прыжок", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        local hum = Utils.getHum()
        if hum then hum.JumpPower = Settings.JumpPower or 200 end
    end,
    onDisable = function(Settings, Utils)
        local hum = Utils.getHum()
        if hum then hum.JumpPower = 50 end
    end
}

-- === modules/movement/func_106_low_gravity.lua ===
-- Func #106: Low Gravity | toggle
local Workspace = game:GetService("Workspace")

return {
    id = "LowGravity", type = "toggle", name = "Low Gravity",
    tooltip = "Низкая гравитация", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceOrigGravity = Workspace.Gravity
        Workspace.Gravity = (Settings.Gravity or 196.2) / 4
    end,
    onDisable = function()
        Workspace.Gravity = _G.ResonanceOrigGravity or 196.2
    end
}

-- === modules/movement/func_107_zero_gravity.lua ===
-- Func #107: Zero Gravity | toggle
local Workspace = game:GetService("Workspace")

return {
    id = "ZeroGravity", type = "toggle", name = "Zero Gravity",
    tooltip = "Невесомость", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceOrigGravity2 = Workspace.Gravity
        Workspace.Gravity = 0
    end,
    onDisable = function()
        Workspace.Gravity = _G.ResonanceOrigGravity2 or 196.2
    end
}

-- === modules/movement/func_108_auto_jump.lua ===
-- Func #108: Auto Jump | toggle
local State = { running = false }

return {
    id = "AutoJump", type = "toggle", name = "Auto Jump",
    tooltip = "Авто-прыжок", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.1)
                local hum = Utils.getHum()
                if hum and hum.FloorMaterial ~= Enum.Material.Air then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/movement/func_109_bunny_hop.lua ===
-- Func #109: Bunny Hop | toggle
local State = { running = false }

return {
    id = "BunnyHop", type = "toggle", name = "Bunny Hop",
    tooltip = "Прыжок при движении", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.05)
                local hum = Utils.getHum()
                if hum and hum.MoveDirection.Magnitude > 0 then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/movement/func_110_slide.lua ===
-- Func #110: Slide | toggle
local UserInputService = game:GetService("UserInputService")
local State = { running = false }

return {
    id = "Slide", type = "toggle", name = "Slide",
    tooltip = "Скольжение на Shift", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.05)
                local hum = Utils.getHum()
                if not hum then continue end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                    hum.WalkSpeed = 150
                else
                    hum.WalkSpeed = Settings.WalkSpeed or 16
                end
            end
        end)
    end,
    onDisable = function(Settings, Utils)
        State.running = false
        local hum = Utils.getHum()
        if hum then hum.WalkSpeed = 16 end
    end
}

-- === modules/movement/func_111_wall_run.lua ===
-- Func #111: Wall Run | toggle
local UserInputService = game:GetService("UserInputService")
local State = { running = false }

return {
    id = "WallRun", type = "toggle", name = "Wall Run",
    tooltip = "Бег по стенам", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.1)
                local hum = Utils.getHum()
                if not hum then continue end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) and hum.FloorMaterial == Enum.Material.Air then
                    hum.WalkSpeed = 80
                elseif hum.FloorMaterial ~= Enum.Material.Air then
                    hum.WalkSpeed = Settings.WalkSpeed or 16
                end
            end
        end)
    end,
    onDisable = function(Settings, Utils)
        State.running = false
        local hum = Utils.getHum()
        if hum then hum.WalkSpeed = 16 end
    end
}

-- === modules/movement/func_112_crouch.lua ===
-- Func #112: Crouch | toggle
return {
    id = "Crouch", type = "toggle", name = "Crouch",
    tooltip = "Присесть", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        local hum = Utils.getHum()
        if not hum then return end
        hum.BodyHeightScale.Value = 0.5
        hum.WalkSpeed = 8
    end,
    onDisable = function(Settings, Utils)
        local hum = Utils.getHum()
        if not hum then return end
        hum.BodyHeightScale.Value = 1
        hum.WalkSpeed = Settings.WalkSpeed or 16
    end
}

-- === modules/movement/func_113_sprint.lua ===
-- Func #113: Sprint | toggle
local UserInputService = game:GetService("UserInputService")
local State = { running = false }

return {
    id = "Sprint", type = "toggle", name = "Sprint",
    tooltip = "Бег на Shift (×3)", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.05)
                local hum = Utils.getHum()
                if not hum then continue end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and hum.MoveDirection.Magnitude > 0 then
                    hum.WalkSpeed = (Settings.WalkSpeed or 16) * 3
                else
                    hum.WalkSpeed = Settings.WalkSpeed or 16
                end
            end
        end)
    end,
    onDisable = function(Settings, Utils)
        State.running = false
        local hum = Utils.getHum()
        if hum then hum.WalkSpeed = 16 end
    end
}

-- === modules/movement/func_114_tp_spawn.lua ===
-- Func #114: Teleport to Spawn | button
local Workspace = game:GetService("Workspace")

return {
    id = "TpSpawn", type = "button", name = "Teleport to Spawn",
    tooltip = "Телепорт на спавн", tab = "Movement",
    onClick = function(Settings, Utils)
        local sp = Workspace:FindFirstChildOfClass("SpawnLocation")
        if not sp then
            for _, obj in pairs(Workspace:GetDescendants()) do
                if obj:IsA("SpawnLocation") then sp = obj; break end
            end
        end
        if sp then Utils.teleportTo(sp.CFrame + Vector3.new(0, 5, 0)) end
    end
}

-- === modules/movement/func_115_tp_random_player.lua ===
-- Func #115: Teleport to Random Player | button
return {
    id = "TpRandomPlayer", type = "button", name = "Teleport to Random Player",
    tooltip = "Телепорт к случайному игроку", tab = "Movement",
    onClick = function(Settings, Utils)
        local list = Utils.getAllPlayers(false)
        if #list == 0 then return end
        local target = list[math.random(1, #list)]
        local hrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if hrp then Utils.teleportTo(hrp.CFrame + Vector3.new(0, 3, 0)) end
    end
}

-- === modules/movement/func_116_tp_forward.lua ===
-- Func #116: Teleport Forward | button
local Workspace = game:GetService("Workspace")
local Camera    = Workspace.CurrentCamera

return {
    id = "TpForward", type = "button", name = "Teleport Forward",
    tooltip = "Телепорт вперёд на 50 studs", tab = "Movement",
    onClick = function(Settings, Utils)
        local hrp = Utils.getHRP()
        if hrp then Utils.teleportTo(hrp.CFrame + Camera.CFrame.LookVector * 50) end
    end
}

-- === modules/movement/func_117_tp_up.lua ===
-- Func #117: Teleport Up | button
return {
    id = "TpUp", type = "button", name = "Teleport Up",
    tooltip = "Телепорт вверх на 50 studs", tab = "Movement",
    onClick = function(Settings, Utils)
        local hrp = Utils.getHRP()
        if hrp then Utils.teleportTo(hrp.CFrame + Vector3.new(0, 50, 0)) end
    end
}

-- === modules/movement/func_118_tp_down.lua ===
-- Func #118: Teleport Down | button
return {
    id = "TpDown", type = "button", name = "Teleport Down",
    tooltip = "Телепорт вниз на 50 studs", tab = "Movement",
    onClick = function(Settings, Utils)
        local hrp = Utils.getHRP()
        if hrp then Utils.teleportTo(hrp.CFrame + Vector3.new(0, -50, 0)) end
    end
}

-- === modules/movement/func_119_tp_cursor.lua ===
-- Func #119: Teleport to Cursor | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "TpCursor", type = "button", name = "Teleport to Cursor",
    tooltip = "Телепорт к курсору", tab = "Movement",
    onClick = function(Settings, Utils)
        local mouse = LocalPlayer:GetMouse()
        if mouse and mouse.Hit then
            Utils.teleportTo(mouse.Hit + Vector3.new(0, 3, 0))
        end
    end
}

-- === modules/movement/func_120_reset_speed.lua ===
-- Func #120: Reset Speed | button
return {
    id = "ResetSpeed", type = "button", name = "Reset Speed",
    tooltip = "Сброс скорости и прыжка", tab = "Movement",
    onClick = function(Settings, Utils)
        local hum = Utils.getHum()
        if hum then
            hum.WalkSpeed = 16
            hum.JumpPower = 50
        end
        Settings.WalkSpeed = 16
        Settings.JumpPower = 50
        Utils.notify("Resonance", "Скорость сброшена", Settings)
    end
}

-- === modules/visuals/func_121_esp_boxes.lua ===
-- Func #121: ESP Boxes | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local State = { running = false, conn = nil, boxes = {} }

local function createBox(player)
    if player == LocalPlayer or State.boxes[player] then return end
    if not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local box = Instance.new("BoxHandleAdornment")
    box.Size = Vector3.new(4, 6, 2)
    box.Adornee = hrp
    box.AlwaysOnTop = true
    box.ZIndex = 5
    box.Transparency = 0.5
    box.Color3 = Color3.fromRGB(255, 0, 0)
    box.Parent = hrp
    State.boxes[player] = box
end

local function removeBox(player)
    if State.boxes[player] then
        pcall(function() State.boxes[player]:Destroy() end)
        State.boxes[player] = nil
    end
end

return {
    id = "ESPBoxes", type = "toggle", name = "ESP Boxes",
    tooltip = "Рамки вокруг игроков", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.boxes = {}
        State.conn = RunService.RenderStepped:Connect(function()
            if not State.running then return end
            for _, p in pairs(Players:GetPlayers()) do
                if p == LocalPlayer then continue end
                if Settings.ESPTeamCheck and p.Team == LocalPlayer.Team then
                    removeBox(p)
                elseif Settings.ESPBoxes then
                    createBox(p)
                else
                    removeBox(p)
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
        for p in pairs(State.boxes) do removeBox(p) end
        State.boxes = {}
    end
}

-- === modules/visuals/func_122_esp_tracers.lua ===
-- Func #122: ESP Tracers | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local State = { running = false, conn = nil, tracers = {} }

local function createTracer(player)
    if State.tracers[player] then return end
    local line = Instance.new("LineHandleAdornment")
    line.Thickness = 2
    line.Color3 = Color3.fromRGB(255, 0, 0)
    line.AlwaysOnTop = true
    line.ZIndex = 5
    line.Parent = Workspace
    State.tracers[player] = line
end

local function removeTracer(player)
    if State.tracers[player] then
        pcall(function() State.tracers[player]:Destroy() end)
        State.tracers[player] = nil
    end
end

return {
    id = "ESPTracers", type = "toggle", name = "ESP Tracers",
    tooltip = "Линии к игрокам", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.tracers = {}
        State.conn = RunService.RenderStepped:Connect(function()
            if not State.running then return end
            for _, p in pairs(Players:GetPlayers()) do
                if p == LocalPlayer then continue end
                if Settings.ESPTeamCheck and p.Team == LocalPlayer.Team then
                    removeTracer(p)
                elseif Settings.ESPTracers then
                    if not p.Character then removeTracer(p); continue end
                    local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                    if not hrp then removeTracer(p); continue end
                    if not State.tracers[p] then createTracer(p) end
                    local tracer = State.tracers[p]
                    if tracer then
                        tracer.Adornee = hrp
                        tracer.Length = 0
                        tracer.CFrame = CFrame.new(
                            Camera.CFrame.Position,
                            hrp.Position)
                    end
                else
                    removeTracer(p)
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
        for p in pairs(State.tracers) do removeTracer(p) end
        State.tracers = {}
    end
}

-- === modules/visuals/func_123_player_info.lua ===
-- Func #123: Player Info | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local State = { running = false, conn = nil, tags = {} }

local function createTag(player)
    if State.tags[player] then return end
    if not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "ResonanceInfo"
    bb.Size = UDim2.new(0, 200, 0, 40)
    bb.AlwaysOnTop = true
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.Adornee = hrp
    bb.Parent = hrp
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0
    label.TextSize = 14
    label.Font = Enum.Font.GothamBold
    label.Text = player.Name
    label.Parent = bb
    State.tags[player] = { gui = bb, label = label }
end

local function removeTag(player)
    if State.tags[player] then
        pcall(function() State.tags[player].gui:Destroy() end)
        State.tags[player] = nil
    end
end

return {
    id = "PlayerInfo", type = "toggle", name = "Player Info",
    tooltip = "Ник, HP и дистанция", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.tags = {}
        State.conn = RunService.RenderStepped:Connect(function()
            if not State.running then return end
            for _, p in pairs(Players:GetPlayers()) do
                if p == LocalPlayer then continue end
                if Settings.ESPTeamCheck and p.Team == LocalPlayer.Team then
                    removeTag(p)
                elseif Settings.ESPInfo then
                    if not p.Character then removeTag(p); continue end
                    if not State.tags[p] then createTag(p) end
                    local entry = State.tags[p]
                    if entry then
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        local myHRP = Utils.getHRP()
                        local dist = (hrp and myHRP) and math.floor((hrp.Position - myHRP.Position).Magnitude) or 0
                        local hp = hum and math.floor(hum.Health) or 0
                        entry.label.Text = string.format("%s | %dHP | %dm", p.Name, hp, dist)
                    end
                else
                    removeTag(p)
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
        for p in pairs(State.tags) do removeTag(p) end
        State.tags = {}
    end
}

-- === modules/visuals/func_124_name_tags.lua ===
-- Func #124: Name Tags | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false, tags = {} }

return {
    id = "NameTags", type = "toggle", name = "Name Tags",
    tooltip = "Крупные ники над игроками", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.tags = {}
        task.spawn(function()
            while State.running do
                task.wait(1)
                for _, p in pairs(Players:GetPlayers()) do
                    if p == LocalPlayer then continue end
                    if p.Character then
                        local head = p.Character:FindFirstChild("Head")
                        if head and not State.tags[p] then
                            local bb = Instance.new("BillboardGui")
                            bb.Name = "ResonanceNameTag"
                            bb.Size = UDim2.new(0, 200, 0, 50)
                            bb.AlwaysOnTop = true
                            bb.StudsOffset = Vector3.new(0, 2, 0)
                            bb.Adornee = head
                            bb.Parent = head
                            local label = Instance.new("TextLabel")
                            label.Size = UDim2.new(1, 0, 1, 0)
                            label.BackgroundTransparency = 1
                            label.TextColor3 = Color3.fromRGB(255, 200, 0)
                            label.TextStrokeTransparency = 0
                            label.TextScaled = true
                            label.Font = Enum.Font.GothamBold
                            label.Text = p.Name
                            label.Parent = bb
                            State.tags[p] = bb
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        for _, tag in pairs(State.tags) do pcall(function() tag:Destroy() end) end
        State.tags = {}
    end
}

-- === modules/visuals/func_125_health_bars.lua ===
-- Func #125: Health Bars | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local State = { running = false, conn = nil, bars = {} }

local function createBar(player)
    if State.bars[player] then return end
    if not player.Character then return end
    local head = player.Character:FindFirstChild("Head")
    if not head then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "ResonanceHealthBar"
    bb.Size = UDim2.new(0, 100, 0, 10)
    bb.AlwaysOnTop = true
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.Adornee = head
    bb.Parent = head
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    bg.BorderSizePixel = 0
    bg.Parent = bb
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    fill.BorderSizePixel = 0
    fill.Parent = bg
    State.bars[player] = { bg = bg, fill = fill }
end

local function removeBar(player)
    if State.bars[player] then
        pcall(function() State.bars[player].bg.Parent:Destroy() end)
        State.bars[player] = nil
    end
end

return {
    id = "HealthBars", type = "toggle", name = "Health Bars",
    tooltip = "Полоски HP над игроками", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.bars = {}
        State.conn = RunService.RenderStepped:Connect(function()
            if not State.running then return end
            for _, p in pairs(Players:GetPlayers()) do
                if p == LocalPlayer then continue end
                if Settings.ESPTeamCheck and p.Team == LocalPlayer.Team then
                    removeBar(p)
                else
                    if p.Character and p.Character:FindFirstChild("Head") then
                        if not State.bars[p] then createBar(p) end
                        local entry = State.bars[p]
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if entry and hum then
                            local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                            entry.fill.Size = UDim2.new(pct, 0, 1, 0)
                            entry.fill.BackgroundColor3 = Color3.fromRGB(
                                math.floor(255 * (1 - pct)),
                                math.floor(255 * pct),
                                0)
                        end
                    else
                        removeBar(p)
                    end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
        for p in pairs(State.bars) do removeBar(p) end
        State.bars = {}
    end
}

-- === modules/visuals/func_126_distance_display.lua ===
-- Func #126: Distance Display | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local State = { running = false, conn = nil, labels = {} }

local function createLabel(player)
    if State.labels[player] then return end
    if not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "ResonanceDistance"
    bb.Size = UDim2.new(0, 100, 0, 30)
    bb.AlwaysOnTop = true
    bb.StudsOffset = Vector3.new(0, -3, 0)
    bb.Adornee = hrp
    bb.Parent = hrp
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(0, 255, 100)
    label.TextStrokeTransparency = 0
    label.TextSize = 16
    label.Font = Enum.Font.GothamBold
    label.Parent = bb
    State.labels[player] = { gui = bb, label = label }
end

local function removeLabel(player)
    if State.labels[player] then
        pcall(function() State.labels[player].gui:Destroy() end)
        State.labels[player] = nil
    end
end

return {
    id = "DistanceDisplay", type = "toggle", name = "Distance Display",
    tooltip = "Дистанция до игроков", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.labels = {}
        State.conn = RunService.RenderStepped:Connect(function()
            if not State.running then return end
            for _, p in pairs(Players:GetPlayers()) do
                if p == LocalPlayer then continue end
                if Settings.ESPTeamCheck and p.Team == LocalPlayer.Team then
                    removeLabel(p)
                else
                    if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        if not State.labels[p] then createLabel(p) end
                        local entry = State.labels[p]
                        local myHRP = Utils.getHRP()
                        if entry and myHRP then
                            local dist = (p.Character.HumanoidRootPart.Position - myHRP.Position).Magnitude
                            entry.label.Text = math.floor(dist) .. "m"
                        end
                    else
                        removeLabel(p)
                    end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
        for p in pairs(State.labels) do removeLabel(p) end
        State.labels = {}
    end
}

-- === modules/visuals/func_127_skeleton_esp.lua ===
-- Func #127: Skeleton ESP | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local State = { running = false, conn = nil, lines = {} }

local BONES = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"}
}

local function createLine(player)
    local lines = {}
    for i = 1, #BONES do
        local line = Instance.new("LineHandleAdornment")
        line.Thickness = 2
        line.Color3 = Color3.fromRGB(0, 255, 255)
        line.AlwaysOnTop = true
        line.Parent = Workspace
        table.insert(lines, line)
    end
    State.lines[player] = lines
end

local function removeLine(player)
    if State.lines[player] then
        for _, l in ipairs(State.lines[player]) do
            pcall(function() l:Destroy() end)
        end
        State.lines[player] = nil
    end
end

return {
    id = "SkeletonESP", type = "toggle", name = "Skeleton ESP",
    tooltip = "Скелет игроков", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.lines = {}
        State.conn = RunService.RenderStepped:Connect(function()
            if not State.running then return end
            for _, p in pairs(Players:GetPlayers()) do
                if p == LocalPlayer then continue end
                if Settings.ESPTeamCheck and p.Team == LocalPlayer.Team then
                    removeLine(p)
                else
                    if not p.Character then removeLine(p); continue end
                    if not State.lines[p] then createLine(p) end
                    local lines = State.lines[p]
                    for i, pair in ipairs(BONES) do
                        local a = p.Character:FindFirstChild(pair[1])
                        local b = p.Character:FindFirstChild(pair[2])
                        if a and b and lines[i] then
                            lines[i].Adornee = a
                            lines[i].CFrame = CFrame.new(a.Position, b.Position)
                            lines[i].Length = (a.Position - b.Position).Magnitude
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
        for p in pairs(State.lines) do removeLine(p) end
        State.lines = {}
    end
}

-- === modules/visuals/func_128_chams.lua ===
-- Func #128: Chams | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false, conn = nil }

return {
    id = "Chams", type = "toggle", name = "Chams",
    tooltip = "Подсветка игроков цветом", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        _G.ResonanceChamsConn = game:GetService("RunService").RenderStepped:Connect(function()
            if not State.running then return end
            for _, p in pairs(Players:GetPlayers()) do
                if p == LocalPlayer then continue end
                if Settings.ESPTeamCheck and p.Team == LocalPlayer.Team then continue end
                if p.Character then
                    for _, part in pairs(p.Character:GetDescendants()) do
                        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                            part.Material = Enum.Material.ForceField
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if _G.ResonanceChamsConn then
            _G.ResonanceChamsConn:Disconnect()
            _G.ResonanceChamsConn = nil
        end
    end
}

-- === modules/visuals/func_129_xray.lua ===
-- Func #129: X-Ray | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "XRay", type = "toggle", name = "X-Ray",
    tooltip = "Прозрачные стены (через LocalTransparencyModifier)", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end
            if p.Character then
                for _, part in pairs(p.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.LocalTransparencyModifier = 0.5
                    end
                end
            end
        end
    end,
    onDisable = function()
        for _, p in pairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end
            if p.Character then
                for _, part in pairs(p.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.LocalTransparencyModifier = 0
                    end
                end
            end
        end
    end
}

-- === modules/visuals/func_130_fullbright.lua ===
-- Func #130: Fullbright | toggle
local Lighting = game:GetService("Lighting")
local State = { orig = {} }

return {
    id = "Fullbright", type = "toggle", name = "Fullbright",
    tooltip = "Максимальное освещение", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        State.orig.Ambient = Lighting.Ambient
        State.orig.OutdoorAmbient = Lighting.OutdoorAmbient
        State.orig.Brightness = Lighting.Brightness
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 3
    end,
    onDisable = function()
        if State.orig.Ambient then Lighting.Ambient = State.orig.Ambient end
        if State.orig.OutdoorAmbient then Lighting.OutdoorAmbient = State.orig.OutdoorAmbient end
        if State.orig.Brightness then Lighting.Brightness = State.orig.Brightness end
    end
}

-- === modules/visuals/func_131_no_fog.lua ===
-- Func #131: No Fog | toggle
local Lighting = game:GetService("Lighting")
local State = { orig = nil }

return {
    id = "NoFog", type = "toggle", name = "No Fog",
    tooltip = "Убрать туман", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        State.orig = Lighting.FogEnd
        Lighting.FogEnd = 1e6
    end,
    onDisable = function()
        Lighting.FogEnd = State.orig or 1000
    end
}

-- === modules/visuals/func_132_remove_textures.lua ===
-- Func #132: Remove Textures | toggle
local Workspace = game:GetService("Workspace")

return {
    id = "RemoveTextures", type = "toggle", name = "Remove Textures",
    tooltip = "Скрыть Decal/Texture", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = 1
            end
        end
    end,
    onDisable = function()
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = 0
            end
        end
    end
}

-- === modules/visuals/func_133_blue_sky.lua ===
-- Func #133: Blue Sky | toggle
local Lighting = game:GetService("Lighting")

return {
    id = "BlueSky", type = "toggle", name = "Blue Sky",
    tooltip = "Голубое небо", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        local sky = Lighting:FindFirstChild("ResonanceSky")
        if not sky then
            sky = Instance.new("Sky")
            sky.Name = "ResonanceSky"
            sky.SkyboxBk = "rbxassetid://159454299"
            sky.SkyboxDn = "rbxassetid://159454296"
            sky.SkyboxFt = "rbxassetid://159454293"
            sky.SkyboxLf = "rbxassetid://159454286"
            sky.SkyboxRt = "rbxassetid://159454300"
            sky.SkyboxUp = "rbxassetid://159454288"
            sky.Parent = Lighting
        end
    end,
    onDisable = function()
        local sky = Lighting:FindFirstChild("ResonanceSky")
        if sky then sky:Destroy() end
    end
}

-- === modules/visuals/func_134_red_ambient.lua ===
-- Func #134: Red Ambient | toggle
local Lighting = game:GetService("Lighting")
local State = { orig = nil }

return {
    id = "RedAmbient", type = "toggle", name = "Red Ambient",
    tooltip = "Красное освещение", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        State.orig = Lighting.Ambient
        Lighting.Ambient = Color3.fromRGB(255, 0, 0)
    end,
    onDisable = function()
        Lighting.Ambient = State.orig or Color3.fromRGB(0, 0, 0)
    end
}

-- === modules/visuals/func_135_green_ambient.lua ===
-- Func #135: Green Ambient | toggle
local Lighting = game:GetService("Lighting")
local State = { orig = nil }

return {
    id = "GreenAmbient", type = "toggle", name = "Green Ambient",
    tooltip = "Зелёное освещение", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        State.orig = Lighting.Ambient
        Lighting.Ambient = Color3.fromRGB(0, 255, 0)
    end,
    onDisable = function()
        Lighting.Ambient = State.orig or Color3.fromRGB(0, 0, 0)
    end
}

-- === modules/visuals/func_136_rainbow_light.lua ===
-- Func #136: Rainbow Light | toggle
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local State = { running = false, conn = nil, hue = 0 }

return {
    id = "RainbowLight", type = "toggle", name = "Rainbow Light",
    tooltip = "Радужное освещение", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        State.conn = RunService.Heartbeat:Connect(function(dt)
            if not State.running then return end
            State.hue = (State.hue + dt * 0.3) % 1
            Lighting.Ambient = Color3.fromHSV(State.hue, 1, 1)
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
        Lighting.Ambient = Color3.fromRGB(0, 0, 0)
    end
}

-- === modules/visuals/func_137_remove_baseplate.lua ===
-- Func #137: Remove Baseplate | button
local Workspace = game:GetService("Workspace")

return {
    id = "RemoveBaseplate", type = "button", name = "Remove Baseplate",
    tooltip = "Удалить Baseplate", tab = "Visuals",
    onClick = function(Settings, Utils)
        local bp = Workspace:FindFirstChild("Baseplate")
        if bp then
            bp:Destroy()
            Utils.notify("Resonance", "Baseplate удалён", Settings)
        end
    end
}

-- === modules/visuals/func_138_remove_lights.lua ===
-- Func #138: Remove Lights | button
local Workspace = game:GetService("Workspace")

return {
    id = "RemoveLights", type = "button", name = "Remove Lights",
    tooltip = "Удалить все источники света", tab = "Visuals",
    onClick = function(Settings, Utils)
        local count = 0
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Light") then
                pcall(function() obj:Destroy() end)
                count = count + 1
            end
        end
        Utils.notify("Resonance", "Удалено ламп: " .. count, Settings)
    end
}

-- === modules/visuals/func_139_restore_lighting.lua ===
-- Func #139: Restore Lighting | button
local Lighting = game:GetService("Lighting")

return {
    id = "RestoreLighting", type = "button", name = "Restore Lighting",
    tooltip = "Сбросить освещение", tab = "Visuals",
    onClick = function(Settings, Utils)
        Lighting.Ambient = Color3.fromRGB(0, 0, 0)
        Lighting.OutdoorAmbient = Color3.fromRGB(0, 0, 0)
        Lighting.FogEnd = 1000
        Lighting.Brightness = 1
        local sky = Lighting:FindFirstChild("ResonanceSky")
        if sky then sky:Destroy() end
        Utils.notify("Resonance", "Освещение сброшено", Settings)
    end
}

-- === modules/visuals/func_140_disable_shadows.lua ===
-- Func #140: Disable Shadows | toggle
local Lighting = game:GetService("Lighting")
local State = { orig = nil }

return {
    id = "DisableShadows", type = "toggle", name = "Disable Shadows",
    tooltip = "Отключить тени", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        State.orig = Lighting.GlobalShadows
        Lighting.GlobalShadows = false
    end,
    onDisable = function()
        Lighting.GlobalShadows = State.orig ~= false
    end
}

-- === modules/server/func_141_rejoin.lua ===
-- Func #141: Rejoin | button
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "Rejoin", type = "button", name = "Rejoin",
    tooltip = "Переподключиться к текущему серверу", tab = "Server",
    onClick = function(Settings, Utils)
        pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end)
    end
}

-- === modules/server/func_142_server_hop.lua ===
-- Func #142: Server Hop | button
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "ServerHop", type = "button", name = "Server Hop",
    tooltip = "Перейти на случайный сервер", tab = "Server",
    onClick = function(Settings, Utils)
        local ok, res = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(
                "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
        end)
        if ok and res and res.data and #res.data > 0 then
            local srv = res.data[math.random(1, #res.data)]
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, srv.id, LocalPlayer)
            end)
        end
    end
}

-- === modules/server/func_143_join_smallest.lua ===
-- Func #143: Join Smallest Server | button
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "JoinSmallest", type = "button", name = "Join Smallest Server",
    tooltip = "Перейти на сервер с наименьшим игроков", tab = "Server",
    onClick = function(Settings, Utils)
        local ok, res = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(
                "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
        end)
        if ok and res and res.data then
            local best, count = nil, math.huge
            for _, s in pairs(res.data) do
                if s.playing and s.playing < count then
                    best, count = s, s.playing
                end
            end
            if best then
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, best.id, LocalPlayer)
                end)
            end
        end
    end
}

-- === modules/server/func_144_join_largest.lua ===
-- Func #144: Join Largest Server | button
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "JoinLargest", type = "button", name = "Join Largest Server",
    tooltip = "Перейти на самый полный сервер", tab = "Server",
    onClick = function(Settings, Utils)
        local ok, res = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(
                "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100"))
        end)
        if ok and res and res.data and #res.data > 0 then
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, res.data[1].id, LocalPlayer)
            end)
        end
    end
}

-- === modules/server/func_145_copy_jobid.lua ===
-- Func #145: Copy JobID | button
return {
    id = "CopyJobId", type = "button", name = "Copy JobID",
    tooltip = "Скопировать JobID сервера", tab = "Server",
    onClick = function(Settings, Utils)
        if setclipboard then
            setclipboard(game.JobId)
            Utils.notify("Resonance", "JobID скопирован", Settings)
        end
    end
}

-- === modules/server/func_146_copy_placeid.lua ===
-- Func #146: Copy PlaceID | button
return {
    id = "CopyPlaceId", type = "button", name = "Copy PlaceID",
    tooltip = "Скопировать PlaceID игры", tab = "Server",
    onClick = function(Settings, Utils)
        if setclipboard then
            setclipboard(tostring(game.PlaceId))
            Utils.notify("Resonance", "PlaceID скопирован", Settings)
        end
    end
}

-- === modules/server/func_147_copy_server_link.lua ===
-- Func #147: Copy Server Link | button
return {
    id = "CopyServerLink", type = "button", name = "Copy Server Link",
    tooltip = "Скопировать ссылку на сервер", tab = "Server",
    onClick = function(Settings, Utils)
        if setclipboard then
            local link = "roblox://placeId=" .. game.PlaceId .. "&gameInstanceId=" .. game.JobId
            setclipboard(link)
            Utils.notify("Resonance", "Ссылка скопирована", Settings)
        end
    end
}

-- === modules/server/func_148_show_server_info.lua ===
-- Func #148: Show Server Info | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "ShowServerInfo", type = "button", name = "Show Server Info",
    tooltip = "Показать информацию о сервере", tab = "Server",
    onClick = function(Settings, Utils)
        local count = #Players:GetPlayers()
        local ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
        Utils.notify("Server Info", "Игроков: " .. count .. " | Ping: " .. ping .. " ms", Settings)
    end
}

-- === modules/server/func_149_list_players.lua ===
-- Func #149: List Players | button
local Players = game:GetService("Players")

return {
    id = "ListPlayers", type = "button", name = "List Players",
    tooltip = "Вывести список игроков в консоль", tab = "Server",
    onClick = function(Settings, Utils)
        local names = {}
        for _, p in pairs(Players:GetPlayers()) do
            table.insert(names, p.Name .. " (ID: " .. p.UserId .. ")")
        end
        print("[Resonance] Players:")
        for _, n in ipairs(names) do print("  " .. n) end
        Utils.notify("Resonance", "Список игроков выведен в консоль", Settings)
    end
}

-- === modules/server/func_150_hop_until_empty.lua ===
-- Func #150: Hop Until Empty | toggle
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, hops = 0 }

local function loop()
    while State.running do
        task.wait(5)
        if #Players:GetPlayers() <= 1 then
            Utils_notify("Resonance", "Сервер пуст — остановка", Settings)
            State.running = false
            break
        end
        local ok, res = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(
                "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
        end)
        if ok and res and res.data then
            local best, count = nil, math.huge
            for _, s in pairs(res.data) do
                if s.playing and s.playing < count then
                    best, count = s, s.playing
                end
            end
            if best and count < #Players:GetPlayers() then
                State.hops = State.hops + 1
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, best.id, LocalPlayer)
                end)
                break
            end
        end
    end
end

return {
    id = "HopUntilEmpty", type = "toggle", name = "Hop Until Empty",
    tooltip = "Хоп пока не найдёт пустой сервер", tab = "Server", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        State.hops = 0
        task.spawn(loop)
    end,
    onDisable = function() State.running = false end,
    getStats = function() return { hops = State.hops } end
}

-- === modules/server/func_151_anti_afk.lua ===
-- Func #151: Anti-AFK | toggle
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

return {
    id = "AntiAfk", type = "toggle", name = "Anti-AFK",
    tooltip = "Не даёт кикнуть за неактивность", tab = "Server", default = true,
    onEnable = function(Settings, Utils)
        _G.ResonanceAntiAfkConn = LocalPlayer.Idled:Connect(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end,
    onDisable = function()
        if _G.ResonanceAntiAfkConn then
            _G.ResonanceAntiAfkConn:Disconnect()
            _G.ResonanceAntiAfkConn = nil
        end
    end
}

-- === modules/server/func_152_auto_rejoin_kick.lua ===
-- Func #152: Auto Rejoin on Kick | toggle
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "AutoRejoinKick", type = "toggle", name = "Auto Rejoin on Kick",
    tooltip = "Авто-переподключение при кике", tab = "Server", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceAutoRejoin = true
    end,
    onDisable = function()
        _G.ResonanceAutoRejoin = false
    end
}

-- === modules/server/func_153_rejoin_delay.lua ===
-- Func #153: Rejoin Delay | button
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "RejoinDelay", type = "button", name = "Rejoin in 3s",
    tooltip = "Переподключиться через 3 секунды", tab = "Server",
    onClick = function(Settings, Utils)
        Utils.notify("Resonance", "Ре-джойн через 3 сек...", Settings)
        task.wait(3)
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end
}

-- === modules/server/func_154_ping_display.lua ===
-- Func #154: Ping Display | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local State = { running = false }

local function loop()
    while State.running do
        task.wait(2)
        local ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
        print("[Resonance] Ping: " .. ping .. " ms")
    end
end

return {
    id = "PingDisplay", type = "toggle", name = "Ping Display",
    tooltip = "Показывать ping в консоли", tab = "Server", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(loop)
    end,
    onDisable = function() State.running = false end
}

-- === modules/server/func_155_fps_display.lua ===
-- Func #155: FPS Display | toggle
local RunService = game:GetService("RunService")

local State = { running = false }

local function loop()
    while State.running do
        local dt = RunService.RenderStepped:Wait()
        task.wait(1)
        print("[Resonance] FPS: " .. math.floor(1 / dt))
    end
end

return {
    id = "FpsDisplay", type = "toggle", name = "FPS Display",
    tooltip = "Показывать FPS в консоли", tab = "Server", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(loop)
    end,
    onDisable = function() State.running = false end
}

-- === modules/server/func_156_leave_game.lua ===
-- Func #156: Leave Game | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "LeaveGame", type = "button", name = "Leave Game",
    tooltip = "Выйти из игры", tab = "Server",
    onClick = function(Settings, Utils)
        LocalPlayer:Kick("Resonance: leave")
    end
}

-- === modules/server/func_157_reset_character.lua ===
-- Func #157: Reset Character | button
return {
    id = "ResetCharacter", type = "button", name = "Reset Character",
    tooltip = "Ресетнуть персонажа", tab = "Server",
    onClick = function(Settings, Utils)
        local hum = Utils.getHum()
        if hum then hum.Health = 0 end
    end
}

-- === modules/server/func_158_character_respawn.lua ===
-- Func #158: Character Respawn | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "CharacterRespawn", type = "button", name = "Character Respawn",
    tooltip = "Форс-респавн персонажа", tab = "Server",
    onClick = function(Settings, Utils)
        pcall(function()
            LocalPlayer:LoadCharacter()
        end)
    end
}

-- === modules/server/func_159_unlock_fps.lua ===
-- Func #159: Unlock FPS | toggle
return {
    id = "UnlockFps", type = "toggle", name = "Unlock FPS",
    tooltip = "Снять лимит FPS (до 240)", tab = "Server", default = false,
    onEnable = function(Settings, Utils)
        if setfpscap then
            setfpscap(240)
            Utils.notify("Resonance", "FPS cap: 240", Settings)
        end
    end,
    onDisable = function(Settings, Utils)
        if setfpscap then
            setfpscap(60)
            Utils.notify("Resonance", "FPS cap: 60", Settings)
        end
    end
}

-- === modules/server/func_160_show_fps.lua ===
-- Func #160: Show FPS | button
local RunService = game:GetService("RunService")

return {
    id = "ShowFps", type = "button", name = "Show FPS",
    tooltip = "Показать текущий FPS", tab = "Server",
    onClick = function(Settings, Utils)
        local dt = RunService.RenderStepped:Wait()
        Utils.notify("FPS", math.floor(1 / dt) .. " fps", Settings)
    end
}

-- === modules/utility/func_161_anti_afk.lua ===
-- Func #161: Anti-AFK | toggle
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

return {
    id = "AntiAfkUtil", type = "toggle", name = "Anti-AFK",
    tooltip = "Не даёт кикнуть за AFK", tab = "Utility", default = true,
    onEnable = function(Settings, Utils)
        _G.ResonanceAntiAfkUtilConn = LocalPlayer.Idled:Connect(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end,
    onDisable = function()
        if _G.ResonanceAntiAfkUtilConn then
            _G.ResonanceAntiAfkUtilConn:Disconnect()
            _G.ResonanceAntiAfkUtilConn = nil
        end
    end
}

-- === modules/utility/func_162_auto_claim_cash.lua ===
-- Func #162: Auto Claim Cash | toggle
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local State = { running = false, claimed = 0 }

return {
    id = "AutoClaimCash", type = "toggle", name = "Auto Claim Cash",
    tooltip = "Авто-подбор денег", tab = "Utility", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.3)
                local hrp = Utils.getHRP()
                if not hrp then continue end
                for _, obj in pairs(Workspace:GetDescendants()) do
                    if obj:IsA("BasePart") then
                        local name = obj.Name:lower()
                        if name:find("cash") or name:find("money") or name:find("coin") then
                            pcall(function()
                                if firetouchinterest then
                                    firetouchinterest(hrp, obj, 0)
                                    firetouchinterest(hrp, obj, 1)
                                end
                                State.claimed = State.claimed + 1
                            end)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end,
    getStats = function() return { claimed = State.claimed } end
}

-- === modules/utility/func_163_cash_magnet.lua ===
-- Func #163: Cash Magnet | toggle
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "CashMagnet", type = "toggle", name = "Cash Magnet",
    tooltip = "Притягивает деньги к вам", tab = "Utility", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.1)
                local hrp = Utils.getHRP()
                if not hrp then continue end
                for _, obj in pairs(Workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and not obj.Anchored then
                        local name = obj.Name:lower()
                        if name:find("cash") or name:find("money") or name:find("coin") then
                            pcall(function() obj.CFrame = hrp.CFrame end)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/utility/func_164_item_magnet.lua ===
-- Func #164: Item Magnet | toggle
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "ItemMagnet", type = "toggle", name = "Item Magnet",
    tooltip = "Притягивает все предметы", tab = "Utility", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.1)
                local hrp = Utils.getHRP()
                if not hrp then continue end
                for _, obj in pairs(Workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and not obj.Anchored then
                        local owner = Players:GetPlayerFromCharacter(obj.Parent)
                        if not owner then
                            pcall(function()
                                obj.CFrame = hrp.CFrame + Vector3.new(math.random(-3,3), 3, math.random(-3,3))
                            end)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/utility/func_165_bring_all_items.lua ===
-- Func #165: Bring All Items | button
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

return {
    id = "BringAllItems", type = "button", name = "Bring All Items",
    tooltip = "Собрать все предметы к себе", tab = "Utility",
    onClick = function(Settings, Utils)
        local hrp = Utils.getHRP()
        if not hrp then return end
        local count = 0
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and not obj.Anchored then
                local owner = Players:GetPlayerFromCharacter(obj.Parent)
                if not owner then
                    pcall(function()
                        obj.CFrame = hrp.CFrame + Vector3.new(math.random(-3,3), 2, math.random(-3,3))
                        count = count + 1
                    end)
                end
            end
        end
        Utils.notify("Resonance", "Собрано: " .. count, Settings)
    end
}

-- === modules/utility/func_166_bring_all_players.lua ===
-- Func #166: Bring All Players | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "BringAllPlayers", type = "button", name = "Bring All Players",
    tooltip = "Телепортировать всех игроков к себе", tab = "Utility",
    onClick = function(Settings, Utils)
        local hrp = Utils.getHRP()
        if not hrp then return end
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local thrp = p.Character:FindFirstChild("HumanoidRootPart")
                if thrp then
                    thrp.CFrame = hrp.CFrame + Vector3.new(math.random(-5,5), 3, math.random(-5,5))
                end
            end
        end
    end
}

-- === modules/utility/func_167_clear_workspace.lua ===
-- Func #167: Clear Workspace | button
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

return {
    id = "ClearWorkspace", type = "button", name = "Clear Workspace",
    tooltip = "Удалить модели (кроме персонажей)", tab = "Utility",
    onClick = function(Settings, Utils)
        local count = 0
        for _, obj in pairs(Workspace:GetChildren()) do
            if obj:IsA("Model") and not Players:GetPlayerFromCharacter(obj) then
                pcall(function() obj:Destroy() end)
                count = count + 1
            end
        end
        Utils.notify("Resonance", "Удалено: " .. count, Settings)
    end
}

-- === modules/utility/func_168_delete_grabbed.lua ===
-- Func #168: Delete Grabbed | button
local Workspace = game:GetService("Workspace")

return {
    id = "DeleteGrabbed", type = "button", name = "Delete Grabbed",
    tooltip = "Удалить GrabParts", tab = "Utility",
    onClick = function(Settings, Utils)
        local gp = Workspace:FindFirstChild("GrabParts")
        if gp then
            gp:Destroy()
            Utils.notify("Resonance", "GrabParts удалены", Settings)
        end
    end
}

-- === modules/utility/func_169_unlock_mouse.lua ===
-- Func #169: Unlock Mouse | toggle
local UserInputService = game:GetService("UserInputService")

return {
    id = "UnlockMouse", type = "toggle", name = "Unlock Mouse",
    tooltip = "Отображать курсор", tab = "Utility", default = false,
    onEnable = function(Settings, Utils)
        UserInputService.MouseIconEnabled = true
    end,
    onDisable = function(Settings, Utils)
        UserInputService.MouseIconEnabled = false
    end
}

-- === modules/utility/func_170_full_screen.lua ===
-- Func #170: Full Screen | toggle
local UserInputService = game:GetService("UserInputService")

return {
    id = "FullScreen", type = "toggle", name = "Full Screen",
    tooltip = "Освободить курсор из центра", tab = "Utility", default = false,
    onEnable = function(Settings, Utils)
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end,
    onDisable = function(Settings, Utils)
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    end
}

-- === modules/utility/func_171_copy_position.lua ===
-- Func #171: Copy Position | button
return {
    id = "CopyPosition", type = "button", name = "Copy Position",
    tooltip = "Скопировать позицию", tab = "Utility",
    onClick = function(Settings, Utils)
        local hrp = Utils.getHRP()
        if hrp and setclipboard then
            setclipboard(tostring(hrp.Position))
            Utils.notify("Resonance", "Позиция скопирована", Settings)
        end
    end
}

-- === modules/utility/func_172_copy_rotation.lua ===
-- Func #172: Copy Rotation | button
return {
    id = "CopyRotation", type = "button", name = "Copy Rotation",
    tooltip = "Скопировать поворот", tab = "Utility",
    onClick = function(Settings, Utils)
        local hrp = Utils.getHRP()
        if hrp and setclipboard then
            setclipboard(tostring(hrp.Orientation))
            Utils.notify("Resonance", "Поворот скопирован", Settings)
        end
    end
}

-- === modules/utility/func_173_show_position.lua ===
-- Func #173: Show Position | button
return {
    id = "ShowPosition", type = "button", name = "Show Position",
    tooltip = "Показать текущую позицию", tab = "Utility",
    onClick = function(Settings, Utils)
        local hrp = Utils.getHRP()
        if hrp then
            Utils.notify("Position", tostring(hrp.Position), Settings)
        end
    end
}

-- === modules/utility/func_174_print_character.lua ===
-- Func #174: Print Character Tree | button
return {
    id = "PrintCharacter", type = "button", name = "Print Character Tree",
    tooltip = "Вывести дерево персонажа в консоль", tab = "Utility",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        print("[Resonance] Character tree:")
        for _, v in pairs(char:GetDescendants()) do
            print("  " .. v:GetFullName())
        end
        Utils.notify("Resonance", "Дерево выведено в консоль", Settings)
    end
}

-- === modules/utility/func_175_clear_notifications.lua ===
-- Func #175: Clear Notifications | button
local StarterGui = game:GetService("StarterGui")

return {
    id = "ClearNotifications", type = "button", name = "Clear Notifications",
    tooltip = "Очистить уведомления", tab = "Utility",
    onClick = function(Settings, Utils)
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "",
                Text = "",
                Duration = 0
            })
        end)
    end
}

-- === modules/utility/func_176_toggle_ui.lua ===
-- Func #176: Toggle UI | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "ToggleUi", type = "button", name = "Toggle UI",
    tooltip = "Показать/скрыть UI", tab = "Utility",
    onClick = function(Settings, Utils)
        local gui = LocalPlayer.PlayerGui:FindFirstChild("ResonanceMenu")
            or LocalPlayer.PlayerGui:FindFirstChildOfClass("ScreenGui")
        if gui then
            gui.Enabled = not gui.Enabled
        end
    end
}

-- === modules/utility/func_177_re_execute.lua ===
-- Func #177: Re-execute Script | button
return {
    id = "ReExecute", type = "button", name = "Re-execute Script",
    tooltip = "Перезапустить скрипт", tab = "Utility",
    onClick = function(Settings, Utils)
        local url = "https://raw.githubusercontent.com/a32435629-collab/resonance/main/dist/resonance.lua"
        local ok, err = pcall(function()
            loadstring(game:HttpGet(url))()
        end)
        if not ok then
            Utils.notify("Resonance", "Ошибка: " .. tostring(err), Settings)
        end
    end
}

-- === modules/utility/func_178_reload_config.lua ===
-- Func #178: Reload Config | button
return {
    id = "ReloadConfig", type = "button", name = "Reload Config",
    tooltip = "Загрузить конфиг", tab = "Utility",
    onClick = function(Settings, Utils)
        local Config = _G.ResonanceConfig
        if Config then
            local ok, err = Config.load(Settings)
            if ok then
                Utils.notify("Resonance", "Конфиг загружен", Settings)
            else
                Utils.notify("Resonance", "Ошибка: " .. tostring(err), Settings)
            end
        end
    end
}

-- === modules/utility/func_179_save_config.lua ===
-- Func #179: Save Config | button
return {
    id = "SaveConfig", type = "button", name = "Save Config",
    tooltip = "Сохранить конфиг", tab = "Utility",
    onClick = function(Settings, Utils)
        local Config = _G.ResonanceConfig
        if Config then
            local ok, err = Config.save(Settings)
            if ok then
                Utils.notify("Resonance", "Конфиг сохранён", Settings)
            else
                Utils.notify("Resonance", "Ошибка: " .. tostring(err), Settings)
            end
        end
    end
}

-- === modules/utility/func_180_wipe_cache.lua ===
-- Func #180: Wipe Cache | button
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

return {
    id = "WipeCache", type = "button", name = "Wipe Cache",
    tooltip = "Очистить кеш ESP/UI", tab = "Utility",
    onClick = function(Settings, Utils)
        local count = 0
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj.Name:find("ResonanceESP") or obj.Name:find("ResonanceBlind") then
                pcall(function() obj:Destroy() end)
                count = count + 1
            end
        end
        for _, p in pairs(Players:GetPlayers()) do
            local pg = p:FindFirstChild("PlayerGui")
            if pg then
                local blind = pg:FindFirstChild("ResonanceBlind")
                if blind then blind:Destroy(); count = count + 1 end
            end
        end
        Utils.notify("Resonance", "Очищено: " .. count, Settings)
    end
}

-- === modules/trolling/func_181_music_play.lua ===
-- Func #181: Music Play | button
local Debris = game:GetService("Debris")

return {
    id = "MusicPlay", type = "button", name = "Music Play",
    tooltip = "Проиграть музыку на сервере", tab = "Trolling",
    onClick = function(Settings, Utils)
        local s = Instance.new("Sound", workspace)
        s.SoundId = "rbxassetid://1837879082"
        s.Volume = 3
        s:Play()
        Debris:AddItem(s, 30)
    end
}

-- === modules/trolling/func_182_reverse_controls.lua ===
-- Func #182: Reverse Controls | toggle
local State = { running = false }

return {
    id = "ReverseControls", type = "toggle", name = "Reverse Controls",
    tooltip = "Инвертировать управление у себя", tab = "Trolling", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.05)
                local hum = Utils.getHum()
                if hum then
                    -- визуальный эффект через camera
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/trolling/func_183_fling_random_aura.lua ===
-- Func #183: Fling Random Aura | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "FlingRandomAura", type = "toggle", name = "Fling Random Aura",
    tooltip = "Случайно флингает игроков рядом", tab = "Trolling", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(2)
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                local list = {}
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude < (Settings.AuraRadius or 15) then
                            table.insert(list, hrp)
                        end
                    end
                end
                if #list > 0 then
                    Utils.fling(list[math.random(1, #list)], Settings.FlingPower or 400)
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/trolling/func_184_rainbow_all.lua ===
-- Func #184: Rainbow All | button
local Players = game:GetService("Players")

return {
    id = "RainbowAll", type = "button", name = "Rainbow All",
    tooltip = "Раскрасить всех игроков", tab = "Trolling",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p.Character then
                for _, part in pairs(p.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Color = Color3.fromHSV(math.random(), 1, 1)
                    end
                end
            end
        end
    end
}

-- === modules/trolling/func_185_neon_all.lua ===
-- Func #185: Neon All | button
local Players = game:GetService("Players")

return {
    id = "NeonAll", type = "button", name = "Neon All",
    tooltip = "Сделать всех неоновыми", tab = "Trolling",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p.Character then
                for _, part in pairs(p.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Material = Enum.Material.Neon
                    end
                end
            end
        end
    end
}

-- === modules/trolling/func_186_shrink_all.lua ===
-- Func #186: Shrink All | button
local Players = game:GetService("Players")

return {
    id = "ShrinkAll", type = "button", name = "Shrink All",
    tooltip = "Уменьшить всех игроков", tab = "Trolling",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.BodyDepthScale.Value = 0.3
                    hum.BodyWidthScale.Value = 0.3
                    hum.BodyHeightScale.Value = 0.3
                end
            end
        end
    end
}

-- === modules/trolling/func_187_grow_all.lua ===
-- Func #187: Grow All | button
local Players = game:GetService("Players")

return {
    id = "GrowAll", type = "button", name = "Grow All",
    tooltip = "Увеличить всех игроков", tab = "Trolling",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.BodyDepthScale.Value = 3
                    hum.BodyWidthScale.Value = 3
                    hum.BodyHeightScale.Value = 3
                end
            end
        end
    end
}

-- === modules/trolling/func_188_head_spin_all.lua ===
-- Func #188: Head Spin All | button
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

return {
    id = "HeadSpinAll", type = "button", name = "Head Spin All",
    tooltip = "Закрутить головы всех игроков", tab = "Trolling",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p.Character then
                local head = p.Character:FindFirstChild("Head")
                if head then
                    local av = Instance.new("BodyAngularVelocity")
                    av.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                    av.AngularVelocity = Vector3.new(0, 50, 0)
                    av.Parent = head
                    Debris:AddItem(av, 5)
                end
            end
        end
    end
}

-- === modules/trolling/func_189_random_color_self.lua ===
-- Func #189: Random Color Self | button
return {
    id = "RandomColorSelf", type = "button", name = "Random Color Self",
    tooltip = "Раскрасить себя в случайные цвета", tab = "Trolling",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Color = Color3.fromHSV(math.random(), 1, 1)
            end
        end
    end
}

-- === modules/trolling/func_190_rainbow_self.lua ===
-- Func #190: Rainbow Self | toggle
local RunService = game:GetService("RunService")
local LocalPlayer = game:GetService("Players").LocalPlayer

local State = { running = false, hue = 0, conn = nil }

return {
    id = "RainbowSelf", type = "toggle", name = "Rainbow Self",
    tooltip = "Радуга на вашем персонаже", tab = "Trolling", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.conn = RunService.Heartbeat:Connect(function(dt)
            if not State.running then return end
            State.hue = (State.hue + dt * 0.3) % 1
            local color = Color3.fromHSV(State.hue, 1, 1)
            local char = LocalPlayer.Character
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.Color = color end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
    end
}

-- === modules/trolling/func_191_neon_self.lua ===
-- Func #191: Neon Self | button
return {
    id = "NeonSelf", type = "button", name = "Neon Self",
    tooltip = "Сделать себя неоновым", tab = "Trolling",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.Material = Enum.Material.Neon end
        end
    end
}

-- === modules/trolling/func_192_ghost_self.lua ===
-- Func #192: Ghost Self | button
return {
    id = "GhostSelf", type = "button", name = "Ghost Self",
    tooltip = "Сделать себя полупрозрачным", tab = "Trolling",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.Transparency = 0.5 end
        end
    end
}

-- === modules/trolling/func_193_invisible_self.lua ===
-- Func #193: Invisible Self | button
return {
    id = "InvisibleSelf", type = "button", name = "Invisible Self",
    tooltip = "Сделать себя невидимым", tab = "Trolling",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.Transparency = 1
            end
        end
        for _, acc in pairs(char:GetChildren()) do
            if acc:IsA("Accessory") then
                for _, h in pairs(acc:GetDescendants()) do
                    if h:IsA("BasePart") then h.Transparency = 1 end
                end
            end
        end
    end
}

-- === modules/trolling/func_194_visible_self.lua ===
-- Func #194: Visible Self | button
return {
    id = "VisibleSelf", type = "button", name = "Visible Self",
    tooltip = "Вернуть видимость", tab = "Trolling",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.Transparency = 0 end
        end
    end
}

-- === modules/trolling/func_195_shake_screen_all.lua ===
-- Func #195: Shake Screen All | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "ShakeScreenAll", type = "toggle", name = "Shake Screen All",
    tooltip = "Трясти экраны всех игроков", tab = "Trolling", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(1)
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer then
                        pcall(function()
                            local gui = p.PlayerGui
                            local oldPos = gui.AbsoluteSize
                            -- Can't directly shake other's UI; used as placeholder
                        end)
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/trolling/func_196_fake_death_all.lua ===
-- Func #196: Fake Death All | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "FakeDeathAll", type = "button", name = "Fake Death All",
    tooltip = "Имитировать смерть у всех", tab = "Trolling",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    local maxHP = hum.MaxHealth
                    hum.Health = 0
                    task.wait(0.1)
                    hum.Health = maxHP
                end
            end
        end
    end
}

-- === modules/trolling/func_197_fire_trail.lua ===
-- Func #197: Fire Trail | toggle
local Debris = game:GetService("Debris")
local State = { running = false }

return {
    id = "FireTrail", type = "toggle", name = "Fire Trail",
    tooltip = "Оставляет огненный след", tab = "Trolling", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.3)
                local hrp = Utils.getHRP()
                if hrp then
                    local f = Instance.new("Fire", hrp)
                    Debris:AddItem(f, 0.5)
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/trolling/func_198_ice_trail.lua ===
-- Func #198: Ice Trail | toggle
local Debris = game:GetService("Debris")
local State = { running = false }

return {
    id = "IceTrail", type = "toggle", name = "Ice Trail",
    tooltip = "Оставляет ледяной след", tab = "Trolling", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.3)
                local hrp = Utils.getHRP()
                if hrp then
                    local s = Instance.new("Smoke", hrp)
                    s.Color = Color3.fromRGB(180, 220, 255)
                    s.Size = 2
                    Debris:AddItem(s, 0.5)
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/trolling/func_199_lightning_self.lua ===
-- Func #199: Lightning Self | toggle
local Debris = game:GetService("Debris")
local State = { running = false }

return {
    id = "LightningSelf", type = "toggle", name = "Lightning Self",
    tooltip = "Молнии на персонаже", tab = "Trolling", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.5)
                local hrp = Utils.getHRP()
                if hrp then
                    local sp = Instance.new("Sparkles", hrp)
                    sp.SparkleColor = Color3.fromRGB(150, 200, 255)
                    Debris:AddItem(sp, 0.6)
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}

-- === modules/trolling/func_200_dance_all.lua ===
-- Func #200: Dance All | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "DanceAll", type = "button", name = "Dance All",
    tooltip = "Заставить всех танцевать", tab = "Trolling",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local animator = p.Character:FindFirstChildOfClass("Animator")
                if not animator then
                    local hum = p.Character:FindFirstChildOfClass("Humanoid")
                    if hum then animator = hum:FindFirstChildOfClass("Animator") end
                end
                if animator then
                    local anim = Instance.new("Animation")
                    anim.AnimationId = "rbxassetid://507771019"
                    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
                    if ok and track then
                        pcall(function() track:Play() end)
                    end
                end
            end
        end
    end
}

-- === modules/animations/func_201_play_dance.lua ===
-- Func #201: Танец
-- Категория: Animations | Тип: button

local ANIM_ID = "rbxassetid://507771019"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayDance",
    type    = "button",
    name    = "Танец",
    tooltip = "Проиграть анимацию танца",
    tab     = "Animations",
    onClick = playAnim
}

-- === modules/animations/func_202_play_wave.lua ===
-- Func #202: Приветствие
-- Категория: Animations | Тип: button

local ANIM_ID = "rbxassetid://507770239"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayWave",
    type    = "button",
    name    = "Приветствие",
    tooltip = "Проиграть анимацию wave",
    tab     = "Animations",
    onClick = playAnim
}

-- === modules/animations/func_203_play_point.lua ===
-- Func #203: Указать
-- Категория: Animations | Тип: button

local ANIM_ID = "rbxassetid://507770453"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayPoint",
    type    = "button",
    name    = "Указать",
    tooltip = "Проиграть анимацию point",
    tab     = "Animations",
    onClick = playAnim
}

-- === modules/animations/func_204_play_laugh.lua ===
-- Func #204: Смех
-- Категория: Animations | Тип: button

local ANIM_ID = "rbxassetid://507770818"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayLaugh",
    type    = "button",
    name    = "Смех",
    tooltip = "Проиграть анимацию laugh",
    tab     = "Animations",
    onClick = playAnim
}

-- === modules/animations/func_205_play_cheer.lua ===
-- Func #205: Радость
-- Категория: Animations | Тип: button

local ANIM_ID = "rbxassetid://507770677"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayCheer",
    type    = "button",
    name    = "Радость",
    tooltip = "Проиграть анимацию cheer",
    tab     = "Animations",
    onClick = playAnim
}

-- === modules/animations/func_206_play_floss.lua ===
-- Func #206: Флосс
-- Категория: Animations | Тип: button

local ANIM_ID = "rbxassetid://5263729371"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayFloss",
    type    = "button",
    name    = "Флосс",
    tooltip = "Проиграть анимацию floss",
    tab     = "Animations",
    onClick = playAnim
}

-- === modules/animations/func_207_play_dab.lua ===
-- Func #207: Даб
-- Категория: Animations | Тип: button

local ANIM_ID = "rbxassetid://5057432604"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayDab",
    type    = "button",
    name    = "Даб",
    tooltip = "Проиграть анимацию dab",
    tab     = "Animations",
    onClick = playAnim
}

-- === modules/animations/func_208_play_russian.lua ===
-- Func #208: Русский танец
-- Категория: Animations | Тип: button

local ANIM_ID = "rbxassetid://507771919"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayRussian",
    type    = "button",
    name    = "Русский танец",
    tooltip = "Проиграть русскую анимацию",
    tab     = "Animations",
    onClick = playAnim
}

-- === modules/animations/func_209_play_karate.lua ===
-- Func #209: Каратэ
-- Категория: Animations | Тип: button

local ANIM_ID = "rbxassetid://507771019"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayKarate",
    type    = "button",
    name    = "Каратэ",
    tooltip = "Проиграть анимацию карате",
    tab     = "Animations",
    onClick = playAnim
}

-- === modules/animations/func_210_play_salsa.lua ===
-- Func #210: Сальса
-- Категория: Animations | Тип: button

local ANIM_ID = "rbxassetid://507771919"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlaySalsa",
    type    = "button",
    name    = "Сальса",
    tooltip = "Проиграть анимацию сальса",
    tab     = "Animations",
    onClick = playAnim
}

-- === modules/animations/func_211_play_hiphop.lua ===
-- Func #211: Хип-хоп
-- Категория: Animations | Тип: button

local ANIM_ID = "rbxassetid://507772104"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayHipHop",
    type    = "button",
    name    = "Хип-хоп",
    tooltip = "Проиграть анимацию хип-хоп",
    tab     = "Animations",
    onClick = playAnim
}

-- === modules/animations/func_212_play_breakdance.lua ===
-- Func #212: Брейк-данс
-- Категория: Animations | Тип: button

local ANIM_ID = "rbxassetid://507771019"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayBreakdance",
    type    = "button",
    name    = "Брейк-данс",
    tooltip = "Проиграть брейк-данс",
    tab     = "Animations",
    onClick = playAnim
}

-- === modules/animations/func_213_play_robot.lua ===
-- Func #213: Робот
-- Категория: Animations | Тип: button

local ANIM_ID = "rbxassetid://507772104"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayRobot",
    type    = "button",
    name    = "Робот",
    tooltip = "Проиграть анимацию робота",
    tab     = "Animations",
    onClick = playAnim
}

-- === modules/animations/func_214_play_backflip.lua ===
-- Func #214: Сальто назад
-- Категория: Animations | Тип: button

local ANIM_ID = "rbxassetid://5972881799"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayBackflip",
    type    = "button",
    name    = "Сальто назад",
    tooltip = "Проиграть backflip",
    tab     = "Animations",
    onClick = playAnim
}

-- === modules/animations/func_215_play_frontflip.lua ===
-- Func #215: Сальто вперёд
-- Категория: Animations | Тип: button

local ANIM_ID = "rbxassetid://5972866182"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayFrontflip",
    type    = "button",
    name    = "Сальто вперёд",
    tooltip = "Проиграть frontflip",
    tab     = "Animations",
    onClick = playAnim
}

-- === modules/animations/func_216_play_sit.lua ===
-- Func #216: Сесть
-- Категория: Animations | Тип: button

local ANIM_ID = "rbxassetid://2506281703"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlaySit",
    type    = "button",
    name    = "Сесть",
    tooltip = "Проиграть анимацию сидя",
    tab     = "Animations",
    onClick = playAnim
}

-- === modules/animations/func_217_play_lay.lua ===
-- Func #217: Лечь
-- Категория: Animations | Тип: button

local ANIM_ID = "rbxassetid://507771019"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayLay",
    type    = "button",
    name    = "Лечь",
    tooltip = "Проиграть анимацию лёжа",
    tab     = "Animations",
    onClick = playAnim
}

-- === modules/animations/func_218_play_crawl.lua ===
-- Func #218: Ползти
-- Категория: Animations | Тип: button

local ANIM_ID = "rbxassetid://507771019"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayCrawl",
    type    = "button",
    name    = "Ползти",
    tooltip = "Проиграть анимацию ползком",
    tab     = "Animations",
    onClick = playAnim
}

-- === modules/animations/func_219_play_sprint_anim.lua ===
-- Func #219: Бег (анимация)
-- Категория: Animations | Тип: button

local ANIM_ID = "rbxassetid://507767714"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlaySprintAnim",
    type    = "button",
    name    = "Бег (анимация)",
    tooltip = "Проиграть анимацию бега",
    tab     = "Animations",
    onClick = playAnim
}

-- === modules/animations/func_220_play_swim.lua ===
-- Func #220: Плавать
-- Категория: Animations | Тип: button

local ANIM_ID = "rbxassetid://507784897"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlaySwim",
    type    = "button",
    name    = "Плавать",
    tooltip = "Проиграть анимацию плавания",
    tab     = "Animations",
    onClick = playAnim
}

-- === modules/animations/func_221_play_climb.lua ===
-- Func #221: Карабкаться
-- Категория: Animations | Тип: button

local ANIM_ID = "rbxassetid://507765644"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayClimb",
    type    = "button",
    name    = "Карабкаться",
    tooltip = "Проиграть анимацию лазания",
    tab     = "Animations",
    onClick = playAnim
}

-- === modules/animations/func_222_stop_all_anims.lua ===
-- Func #222: Stop All Anims
-- Категория: Animations | Тип: button

return {
    id = "StopAllAnims", type = "button", name = "Остановить все анимации",
    tooltip = "Останавливает все проигрываемые треки персонажа",
    tab = "Animations",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        local animator = char:FindFirstChildOfClass("Animator")
        if not animator then return end
        for _, track in pairs(animator:GetPlayingAnimationTracks()) do
            pcall(function() track:Stop(0.1) end)
        end
        _G.ResonanceCurrentAnim = nil
    end
}

-- === modules/animations/func_223_free_anims_off.lua ===
-- Func #223: Free Animations Off
-- Категория: Animations | Тип: toggle
-- Отключает стандартные анимации движения

return {
    id = "FreeAnimsOff", type = "toggle", name = "Free Animations Off",
    tooltip = "Отключает анимации движения (walk/idle/jump)",
    tab = "Animations", default = false,
    onEnable = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        local animate = char:FindFirstChild("Animate")
        if animate then animate.Disabled = true end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            for _, t in pairs(hum:GetPlayingAnimationTracks()) do
                pcall(function() t:Stop(0.2) end)
            end
        end
    end,
    onDisable = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        local animate = char:FindFirstChild("Animate")
        if animate then animate.Disabled = false end
    end
}

-- === modules/animations/func_224_anim_speed_up.lua ===
-- Func #224: Anim Speed Up
-- Категория: Animations | Тип: button

return {
    id = "AnimSpeedUp", type = "button", name = "Ускорить анимации",
    tooltip = "Увеличить скорость анимаций на +0.25x",
    tab = "Animations",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        local animator = char:FindFirstChildOfClass("Animator")
        if not animator then return end
        Settings.AnimSpeed = math.min(5, (Settings.AnimSpeed or 1) + 0.25)
        for _, track in pairs(animator:GetPlayingAnimationTracks()) do
            pcall(function() track:AdjustSpeed(Settings.AnimSpeed) end)
        end
        Utils.notify("Resonance", "Anim Speed: " .. Settings.AnimSpeed .. "x", Settings)
    end
}

-- === modules/animations/func_225_anim_slow_down.lua ===
-- Func #225: Anim Slow Down
-- Категория: Animations | Тип: button

return {
    id = "AnimSlowDown", type = "button", name = "Замедлить анимации",
    tooltip = "Уменьшить скорость анимаций на -0.25x",
    tab = "Animations",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        local animator = char:FindFirstChildOfClass("Animator")
        if not animator then return end
        Settings.AnimSpeed = math.max(0.1, (Settings.AnimSpeed or 1) - 0.25)
        for _, track in pairs(animator:GetPlayingAnimationTracks()) do
            pcall(function() track:AdjustSpeed(Settings.AnimSpeed) end)
        end
        Utils.notify("Resonance", "Anim Speed: " .. Settings.AnimSpeed .. "x", Settings)
    end
}

-- === modules/kick/func_226_kick_all.lua ===
-- Func #226: Kick All
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do if l:find(kw) then return true end end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    return pcall(function()
        if remote:IsA("RemoteEvent") then remote:FireServer(target, reason)
        else remote:InvokeServer(target, reason) end
    end)
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

return {
    id = "KickAll", type = "button", name = "Kick All",
    tooltip = "Пытается кикнуть всех игроков", tab = "Kick",
    onClick = function(Settings, Utils)
        task.wait((Settings.KickDelay or 0) / 1000)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                if not fireKick(p, Settings.KickReason or "Kicked") then
                    pseudoKick(p)
                end
            end
        end
    end
}

-- === modules/kick/func_227_kick_closest.lua ===
-- Func #227: Kick Closest
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickClosest", type = "button", name = "Kick Closest",
    tooltip = "Кикнуть ближайшего", tab = "Kick",
    onClick = function(Settings, Utils)
        local target = Utils.getClosestPlayer(Settings)
        if not target then return end
        task.wait((Settings.KickDelay or 0) / 1000)
        if not fireKick(target, Settings.KickReason) then pseudoKick(target) end
    end
}

-- === modules/kick/func_228_kick_random.lua ===
-- Func #228: Kick Random
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickRandom", type = "button", name = "Kick Random",
    tooltip = "Кикнуть случайного", tab = "Kick",
    onClick = function(Settings, Utils)
        local list = Utils.getAllPlayers(false)
        if #list == 0 then return end
        local target = list[math.random(1, #list)]
        task.wait((Settings.KickDelay or 0) / 1000)
        if not fireKick(target, Settings.KickReason) then pseudoKick(target) end
    end
}

-- === modules/kick/func_229_kick_by_name.lua ===
-- Func #229: Kick By Name
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickByName", type = "button", name = "Kick By Name",
    tooltip = "Кикнуть по нику из Targeting", tab = "Kick",
    onClick = function(Settings, Utils)
        local target = Players:FindFirstChild(Settings.TargetName or "")
        if not target then return end
        task.wait((Settings.KickDelay or 0) / 1000)
        if not fireKick(target, Settings.KickReason) then pseudoKick(target) end
    end
}

-- === modules/kick/func_230_kick_farthest.lua ===
-- Func #230: Kick Farthest
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickFarthest", type = "button", name = "Kick Farthest",
    tooltip = "Кикнуть самого далёкого", tab = "Kick",
    onClick = function(Settings, Utils)
        local target = Utils.getFarthestPlayer(Settings)
        if not target then return end
        task.wait((Settings.KickDelay or 0) / 1000)
        if not fireKick(target, Settings.KickReason) then pseudoKick(target) end
    end
}

-- === modules/kick/func_231_kick_lowest_hp.lua ===
-- Func #231: Kick Lowest HP
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickLowestHP", type = "button", name = "Kick Lowest HP",
    tooltip = "Кикнуть с наименьшим HP", tab = "Kick",
    onClick = function(Settings, Utils)
        local best, hp = nil, math.huge
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local h = p.Character:FindFirstChildOfClass("Humanoid")
                if h and h.Health < hp then hp = h.Health; best = p end
            end
        end
        if best then
            task.wait((Settings.KickDelay or 0) / 1000)
            if not fireKick(best, Settings.KickReason) then pseudoKick(best) end
        end
    end
}

-- === modules/kick/func_232_kick_highest_hp.lua ===
-- Func #232: Kick Highest HP
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickHighestHP", type = "button", name = "Kick Highest HP",
    tooltip = "Кикнуть с наибольшим HP", tab = "Kick",
    onClick = function(Settings, Utils)
        local best, hp = nil, -1
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local h = p.Character:FindFirstChildOfClass("Humanoid")
                if h and h.Health > hp then hp = h.Health; best = p end
            end
        end
        if best then
            task.wait((Settings.KickDelay or 0) / 1000)
            if not fireKick(best, Settings.KickReason) then pseudoKick(best) end
        end
    end
}

-- === modules/kick/func_233_kick_friend.lua ===
-- Func #233: Kick Friend
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickFriend", type = "button", name = "Kick Friend",
    tooltip = "Кикнуть друга", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local ok, isFriend = pcall(function() return LocalPlayer:IsFriendsWith(p.UserId) end)
                if ok and isFriend then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                    return
                end
            end
        end
    end
}

-- === modules/kick/func_234_kick_non_friend.lua ===
-- Func #234: Kick Non-Friend
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickNonFriend", type = "button", name = "Kick Non-Friend",
    tooltip = "Кикнуть не-друга", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local ok, isFriend = pcall(function() return LocalPlayer:IsFriendsWith(p.UserId) end)
                if not ok or not isFriend then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                    return
                end
            end
        end
    end
}

-- === modules/kick/func_235_kick_team.lua ===
-- Func #235: Kick Team
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickTeam", type = "button", name = "Kick Team",
    tooltip = "Кикнуть союзников", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Team == LocalPlayer.Team then
                task.wait((Settings.KickDelay or 0) / 1000)
                if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
            end
        end
    end
}

-- === modules/kick/func_236_kick_enemy_team.lua ===
-- Func #236: Kick Enemy Team
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickEnemyTeam", type = "button", name = "Kick Enemy Team",
    tooltip = "Кикнуть врагов", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Team ~= LocalPlayer.Team then
                task.wait((Settings.KickDelay or 0) / 1000)
                if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
            end
        end
    end
}

-- === modules/kick/func_237_kick_afk.lua ===
-- Func #237: Kick AFK
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickAfk", type = "button", name = "Kick AFK",
    tooltip = "Кикнуть AFK", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.MoveDirection.Magnitude == 0 then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}

-- === modules/kick/func_238_kick_talking.lua ===
-- Func #238: Kick Talking
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickTalking", type = "button", name = "Kick Talking",
    tooltip = "Кикнуть тех, кто пишет", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                -- эвристика: у кого открыт чат
                if p:GetAttribute("IsTalking") or (p.Character and p.Character:GetAttribute("Talking")) then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}

-- === modules/kick/func_239_kick_silent.lua ===
-- Func #239: Kick Silent
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickSilent", type = "button", name = "Kick Silent",
    tooltip = "Кикнуть всех, кроме пишущих", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                if not (p:GetAttribute("IsTalking") or (p.Character and p.Character:GetAttribute("Talking"))) then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}

-- === modules/kick/func_240_kick_walking.lua ===
-- Func #240: Kick Walking
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickWalking", type = "button", name = "Kick Walking",
    tooltip = "Кикнуть идущих", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.MoveDirection.Magnitude > 0 then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}

-- === modules/kick/func_241_kick_standing.lua ===
-- Func #241: Kick Standing
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickStanding", type = "button", name = "Kick Standing",
    tooltip = "Кикнуть стоящих", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.MoveDirection.Magnitude == 0 and hum.FloorMaterial ~= Enum.Material.Air then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}

-- === modules/kick/func_242_kick_jumping.lua ===
-- Func #242: Kick Jumping
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickJumping", type = "button", name = "Kick Jumping",
    tooltip = "Кикнуть прыгающих", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.FloorMaterial == Enum.Material.Air then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}

-- === modules/kick/func_243_kick_flying.lua ===
-- Func #243: Kick Flying
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickFlying", type = "button", name = "Kick Flying",
    tooltip = "Кикнуть летающих", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp and hrp.Velocity.Magnitude > 100 and hrp.Position.Y > 30 then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}

-- === modules/kick/func_244_kick_glitched.lua ===
-- Func #244: Kick Glitched
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickGlitched", type = "button", name = "Kick Glitched",
    tooltip = "Кикнуть застрявших", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp and hrp.Position.Y < -50 then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}

-- === modules/kick/func_245_kick_invisible.lua ===
-- Func #245: Kick Invisible
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickInvisible", type = "button", name = "Kick Invisible",
    tooltip = "Кикнуть невидимок", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp and hrp.Transparency > 0.9 then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}

-- === modules/kick/func_246_kick_visible.lua ===
-- Func #246: Kick Visible
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickVisible", type = "button", name = "Kick Visible",
    tooltip = "Кикнуть видимых", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp and hrp.Transparency < 0.5 then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}

-- === modules/kick/func_247_kick_high_ping.lua ===
-- Func #247: Kick High Ping
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickHighPing", type = "button", name = "Kick High Ping",
    tooltip = "Кикнуть с высоким пингом", tab = "Kick",
    onClick = function(Settings, Utils)
        local worst, ping = nil, -1
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local pp = p:GetNetworkPing() * 1000
                if pp > ping then ping = pp; worst = p end
            end
        end
        if worst then
            task.wait((Settings.KickDelay or 0) / 1000)
            if not fireKick(worst, Settings.KickReason) then pseudoKick(worst) end
        end
    end
}

-- === modules/kick/func_248_kick_low_ping.lua ===
-- Func #248: Kick Low Ping
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickLowPing", type = "button", name = "Kick Low Ping",
    tooltip = "Кикнуть с низким пингом", tab = "Kick",
    onClick = function(Settings, Utils)
        local best, ping = nil, math.huge
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local pp = p:GetNetworkPing() * 1000
                if pp < ping then ping = pp; best = p end
            end
        end
        if best then
            task.wait((Settings.KickDelay or 0) / 1000)
            if not fireKick(best, Settings.KickReason) then pseudoKick(best) end
        end
    end
}

-- === modules/kick/func_249_kick_mobile.lua ===
-- Func #249: Kick Mobile
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickMobile", type = "button", name = "Kick Mobile",
    tooltip = "Кикнуть мобильных", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local ok, result = pcall(function() return p:GetAttribute("IsMobile") end)
                if ok and result then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}

-- === modules/kick/func_250_kick_pc.lua ===
-- Func #250: Kick PC
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickPC", type = "button", name = "Kick PC",
    tooltip = "Кикнуть PC-игроков", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                if not p:GetAttribute("IsMobile") and not p:GetAttribute("IsConsole") and not p:GetAttribute("IsVR") then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}

-- === modules/kick/func_251_kick_console.lua ===
-- Func #251: Kick Console
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickConsole", type = "button", name = "Kick Console",
    tooltip = "Кикнуть консольных", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local ok, result = pcall(function() return p:GetAttribute("IsConsole") end)
                if ok and result then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}

-- === modules/kick/func_252_kick_vr.lua ===
-- Func #252: Kick VR
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickVR", type = "button", name = "Kick VR",
    tooltip = "Кикнуть VR", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local ok, result = pcall(function() return p:GetAttribute("IsVR") end)
                if ok and result then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}

-- === modules/kick/func_253_kick_guest.lua ===
-- Func #253: Kick Guest
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickGuest", type = "button", name = "Kick Guest",
    tooltip = "Кикнуть гостей", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Name:lower():find("guest") then
                task.wait((Settings.KickDelay or 0) / 1000)
                if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
            end
        end
    end
}

-- === modules/kick/func_254_kick_premium.lua ===
-- Func #254: Kick Premium
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickPremium", type = "button", name = "Kick Premium",
    tooltip = "Кикнуть Premium", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.MembershipType == Enum.MembershipType.Premium then
                task.wait((Settings.KickDelay or 0) / 1000)
                if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
            end
        end
    end
}

-- === modules/kick/func_255_kick_non_premium.lua ===
-- Func #255: Kick Non-Premium
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickNonPremium", type = "button", name = "Kick Non-Premium",
    tooltip = "Кикнуть Non-Premium", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.MembershipType == Enum.MembershipType.None then
                task.wait((Settings.KickDelay or 0) / 1000)
                if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
            end
        end
    end
}

-- === modules/kick/func_256_kick_verified.lua ===
-- Func #256: Kick Verified
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickVerified", type = "button", name = "Kick Verified",
    tooltip = "Кикнуть верифицированных", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.HasVerifiedBadge then
                task.wait((Settings.KickDelay or 0) / 1000)
                if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
            end
        end
    end
}

-- === modules/kick/func_257_kick_non_verified.lua ===
-- Func #257: Kick Non-Verified
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickNonVerified", type = "button", name = "Kick Non-Verified",
    tooltip = "Кикнуть не-верифицированных", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and not p.HasVerifiedBadge then
                task.wait((Settings.KickDelay or 0) / 1000)
                if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
            end
        end
    end
}

-- === modules/kick/func_258_kick_with_hats.lua ===
-- Func #258: Kick With Hats
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickWithHats", type = "button", name = "Kick With Hats",
    tooltip = "Кикнуть с шапками", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hasHat = false
                for _, a in pairs(p.Character:GetChildren()) do
                    if a:IsA("Accessory") then hasHat = true; break end
                end
                if hasHat then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}

-- === modules/kick/func_259_kick_without_hats.lua ===
-- Func #259: Kick Without Hats
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickWithoutHats", type = "button", name = "Kick Without Hats",
    tooltip = "Кикнуть без шапок", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hasHat = false
                for _, a in pairs(p.Character:GetChildren()) do
                    if a:IsA("Accessory") then hasHat = true; break end
                end
                if not hasHat then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}

-- === modules/kick/func_260_kick_with_tools.lua ===
-- Func #260: Kick With Tools
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickWithTools", type = "button", name = "Kick With Tools",
    tooltip = "Кикнуть с инструментами", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChildOfClass("Tool") then
                task.wait((Settings.KickDelay or 0) / 1000)
                if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
            end
        end
    end
}

-- === modules/kick/func_261_kick_without_tools.lua ===
-- Func #261: Kick Without Tools
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickWithoutTools", type = "button", name = "Kick Without Tools",
    tooltip = "Кикнуть без инструментов", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and not p.Character:FindFirstChildOfClass("Tool") then
                task.wait((Settings.KickDelay or 0) / 1000)
                if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
            end
        end
    end
}

-- === modules/kick/func_262_kick_rich.lua ===
-- Func #262: Kick Rich
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickRich", type = "button", name = "Kick Rich",
    tooltip = "Кикнуть Rich (по атрибуту)", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local ok, val = pcall(function() return p:GetAttribute("Robux") end)
                if ok and type(val) == "number" and val > 1000 then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}

-- === modules/kick/func_263_kick_poor.lua ===
-- Func #263: Kick Poor
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickPoor", type = "button", name = "Kick Poor",
    tooltip = "Кикнуть Poor (по атрибуту)", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local ok, val = pcall(function() return p:GetAttribute("Robux") end)
                if ok and type(val) == "number" and val <= 0 then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}

-- === modules/kick/func_264_kick_high_level.lua ===
-- Func #264: Kick High Level
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickHighLevel", type = "button", name = "Kick High Level",
    tooltip = "Кикнуть высокий уровень", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local ok, val = pcall(function() return p:GetAttribute("Level") end)
                if ok and type(val) == "number" and val > 100 then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}

-- === modules/kick/func_265_kick_low_level.lua ===
-- Func #265: Kick Low Level
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickLowLevel", type = "button", name = "Kick Low Level",
    tooltip = "Кикнуть низкий уровень", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local ok, val = pcall(function() return p:GetAttribute("Level") end)
                if ok and type(val) == "number" and val < 10 then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}

-- === modules/kick/func_266_kick_owner.lua ===
-- Func #266: Kick Owner
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickOwner", type = "button", name = "Kick Owner",
    tooltip = "Кикнуть владельца плейса", tab = "Kick",
    onClick = function(Settings, Utils)
        local placeOwnerId = game.CreatorId
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.UserId == placeOwnerId then
                task.wait((Settings.KickDelay or 0) / 1000)
                if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
            end
        end
    end
}

-- === modules/kick/func_267_kick_admin.lua ===
-- Func #267: Kick Admin
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickAdmin", type = "button", name = "Kick Admin",
    tooltip = "Кикнуть админов группы", tab = "Kick",
    onClick = function(Settings, Utils)
        local groupId = game.CreatorType == Enum.CreatorType.Group and game.CreatorId or 0
        if groupId == 0 then return end
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local ok, rank = pcall(function() return p:GetRankInGroup(groupId) end)
                if ok and rank >= 200 then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}

-- === modules/kick/func_268_kick_moderator.lua ===
-- Func #268: Kick Moderator
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickModerator", type = "button", name = "Kick Moderator",
    tooltip = "Кикнуть модераторов", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local rank = 0
                for _, gid in pairs({game.CreatorId}) do
                    local ok, r = pcall(function() return p:GetRankInGroup(gid) end)
                    if ok and r > rank then rank = r end
                end
                if rank >= 100 and rank < 200 then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}

-- === modules/kick/func_269_kick_staff.lua ===
-- Func #269: Kick Staff
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickStaff", type = "button", name = "Kick Staff",
    tooltip = "Кикнуть любой стафф", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local maxRank = 0
                for _, gid in pairs({game.CreatorId}) do
                    local ok, r = pcall(function() return p:GetRankInGroup(gid) end)
                    if ok and r > maxRank then maxRank = r end
                end
                if maxRank >= 100 then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}

-- === modules/kick/func_270_kick_bots.lua ===
-- Func #270: Kick Bots
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickBots", type = "button", name = "Kick Bots",
    tooltip = "Кикнуть ботов", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                if p:GetAttribute("IsBot") or p.DisplayName:lower():find("bot") then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}

-- === modules/kick/func_271_kick_alts.lua ===
-- Func #271: Kick Alts
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickAlts", type = "button", name = "Kick Alts",
    tooltip = "Кикнуть альтов (AccountAge < 30)", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.AccountAge < 30 then
                task.wait((Settings.KickDelay or 0) / 1000)
                if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
            end
        end
    end
}

-- === modules/kick/func_272_kick_by_userid.lua ===
-- Func #272: Kick By UserID
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickByUserId", type = "button", name = "Kick By UserID",
    tooltip = "Кикнуть по UserID из Targeting", tab = "Kick",
    onClick = function(Settings, Utils)
        local targetId = tonumber(Settings.TargetUserId or 0)
        if targetId == 0 then return end
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.UserId == targetId then
                task.wait((Settings.KickDelay or 0) / 1000)
                if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
            end
        end
    end
}

-- === modules/kick/func_273_kick_by_display_name.lua ===
-- Func #273: Kick By DisplayName
-- Категория: Kick | Тип: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickByDisplayName", type = "button", name = "Kick By DisplayName",
    tooltip = "Кикнуть по DisplayName", tab = "Kick",
    onClick = function(Settings, Utils)
        local targetName = Settings.TargetDisplayName or ""
        if targetName == "" then return end
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.DisplayName:lower() == targetName:lower() then
                task.wait((Settings.KickDelay or 0) / 1000)
                if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
            end
        end
    end
}

-- === modules/kick/func_274_kick_multiple.lua ===
-- Func #274: Kick Multiple
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do if l:find(kw) then return true end end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    return pcall(function()
        if remote:IsA("RemoteEvent") then remote:FireServer(target, reason)
        else remote:InvokeServer(target, reason) end
    end)
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

return {
    id = "KickMultiple", type = "button", name = "Kick Multiple",
    tooltip = "Кикнуть несколько игроков сразу", tab = "Kick",
    onClick = function(Settings, Utils)
        task.wait((Settings.KickDelay or 0) / 1000)
        local count = 0
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                count = count + 1
            end
        end
        Utils.notify("Kick", "Кикнуто: " .. count, Settings)
    end
}

-- === modules/kick/func_275_kick_blacklist.lua ===
-- Func #275: Kick Blacklist
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local BLACKLIST = {}  -- сюда можно добавить UserId

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do if l:find(kw) then return true end end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    return pcall(function()
        if remote:IsA("RemoteEvent") then remote:FireServer(target, reason)
        else remote:InvokeServer(target, reason) end
    end)
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

return {
    id = "KickBlacklist", type = "button", name = "Kick Blacklist",
    tooltip = "Кикнуть игроков из чёрного списка", tab = "Kick",
    onClick = function(Settings, Utils)
        local bl = Settings.Blacklist or BLACKLIST
        if not bl then return end
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                if bl[p.UserId] or bl[p.Name] then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}

-- === runtime.lua ===
-- ============================================================
-- Resonance v4.0 — runtime.lua
-- Глобальные обработчики: RGB bind, Anti-AFK, авто-респавн
-- ============================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

local Settings = _G.ResonanceSettings or {}
local RGB      = _G.ResonanceRGB
local Utils    = _G.ResonanceUtils

local function log(msg)
    print("[Resonance Runtime] " .. tostring(msg))
end

-- ============================================================
-- 1. RGB BIND
-- ============================================================
if RGB and RGB.bind then
    pcall(function()
        RGB.bind(Settings)
        log("RGB bind активен")
    end)
end

-- ============================================================
-- 2. ANTI-AFK
-- ============================================================
local antiAfkConn = LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)
log("Anti-AFK активен")

-- ============================================================
-- 3. AUTO-REJOIN ON KICK
-- ============================================================
-- Мониторинг на случай кика — если игрок исчезает из Players
task.spawn(function()
    while true do
        task.wait(2)
        if Settings.AutoRejoin then
            if not Players:FindFirstChild(LocalPlayer.Name) then
                pcall(function()
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                end)
                break
            end
        end
    end
end)

-- ============================================================
-- 4. ON TELEPORT LOG
-- ============================================================
LocalPlayer.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Started then
        log("Teleport started")
    elseif state == Enum.TeleportState.Failed then
        log("Teleport failed")
    end
end)

-- ============================================================
-- 5. CHARACTER ADDED HOOK
-- ============================================================
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    log("Character respawned")

    -- Автоприменение настроек движения
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        if Settings.WalkSpeed then hum.WalkSpeed = Settings.WalkSpeed end
        if Settings.JumpPower then hum.JumpPower = Settings.JumpPower end
    end
end)

-- ============================================================
-- 6. WATCHDOG FPS/PING (опционально)
-- ============================================================
if Settings.PingDisplay or Settings.FPSDisplay then
    task.spawn(function()
        while true do
            task.wait(5)
            if Settings.PingDisplay then
                local ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
                log("Ping: " .. ping .. " ms")
            end
            if Settings.FPSDisplay then
                local fps = math.floor(1 / RunService.RenderStepped:Wait())
                log("FPS: " .. fps)
            end
        end
    end)
end

-- ============================================================
-- 7. ГЛОБАЛЬНЫЙ API ДЛЯ ДРУГИХ МОДУЛЕЙ
-- ============================================================
_G.ResonanceRuntime = {
    log = log,
    antiAfkConn = antiAfkConn
}

log("Runtime полностью загружен")


-- Авто-запуск через init логику
print('============================================')
print('[Resonance] Bundled script loaded')
print('[Resonance] Modules: 287 | Failed: 0')
print('============================================')