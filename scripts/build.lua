-- ============================================================
-- Resonance v4.0 — scripts/build.lua
-- Собирает все файлы src/** в один dist/resonance.lua
-- Запуск: lua scripts/build.lua
-- ============================================================

local ROOT      = "./"
local SRC       = ROOT .. "src/"
local DIST      = ROOT .. "dist/"
local OUTPUT    = DIST .. "resonance.lua"

-- ============================================================
-- УТИЛИТЫ
-- ============================================================
local function fileExists(path)
    local f = io.open(path, "r")
    if f then f:close() return true end
    return false
end

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local c = f:read("*a")
    f:close()
    return c
end

local function writeFile(path, content)
    local f = io.open(path, "w")
    if not f then
        error("Не могу открыть " .. path .. " для записи")
    end
    f:write(content)
    f:close()
end

local function listDir(path)
    local cmd
    local sep = package.config:sub(1,1)
    if sep == "\\" then
        cmd = 'dir /b "' .. path .. '" 2>nul'
    else
        cmd = 'ls -1 "' .. path .. '" 2>/dev/null'
    end
    local handle = io.popen(cmd)
    local result = {}
    if handle then
        for line in handle:lines() do
            table.insert(result, line)
        end
        handle:close()
    end
    return result
end

-- ============================================================
-- МАНИФЕСТ — все файлы для сборки в порядке загрузки
-- ============================================================
local MANIFEST = {
    -- CORE
    "core/utils.lua",
    "core/loop.lua",
    "core/keybind.lua",
    "core/config.lua",
    "core/rgb.lua",
    "core/manifest.lua",
    "core/remote_resolver.lua",

    -- SETTINGS
    "core/settings/init.lua",

    -- UI
    "ui/theme.lua",
    "ui/notifications.lua",
    "ui/build.lua",

    -- MODULES: Combat (40)
    "modules/combat/func_001_super_throw.lua",
    "modules/combat/func_002_massless_grab.lua",
    "modules/combat/func_003_freeze_grab.lua",
    "modules/combat/func_004_silent_aim.lua",
    "modules/combat/func_005_aimbot.lua",
    "modules/combat/func_006_telekinesis.lua",
    "modules/combat/func_007_auto_throw.lua",
    "modules/combat/func_008_kill_aura.lua",
    "modules/combat/func_009_hitbox_expander.lua",
    "modules/combat/func_010_wall_bang.lua",
    "modules/combat/func_011_rapid_fire.lua",
    "modules/combat/func_012_no_recoil.lua",
    "modules/combat/func_013_fling_all.lua",
    "modules/combat/func_014_fling_random.lua",
    "modules/combat/func_015_fling_closest.lua",
    "modules/combat/func_016_kill_all.lua",
    "modules/combat/func_017_kill_closest.lua",
    "modules/combat/func_018_kill_random.lua",
    "modules/combat/func_019_burn_all.lua",
    "modules/combat/func_020_burn_closest.lua",
    "modules/combat/func_021_freeze_all.lua",
    "modules/combat/func_022_unfreeze_all.lua",
    "modules/combat/func_023_ragdoll_all.lua",
    "modules/combat/func_024_explode_all.lua",
    "modules/combat/func_025_void_all.lua",
    "modules/combat/func_026_sky_all.lua",
    "modules/combat/func_027_shake_all.lua",
    "modules/combat/func_028_spin_all.lua",
    "modules/combat/func_029_slow_all.lua",
    "modules/combat/func_030_speed_all.lua",
    "modules/combat/func_031_jump_all.lua",
    "modules/combat/func_032_reset_all.lua",
    "modules/combat/func_033_anchor_all.lua",
    "modules/combat/func_034_unanchor_all.lua",
    "modules/combat/func_035_shirt_off_all.lua",
    "modules/combat/func_036_pants_off_all.lua",
    "modules/combat/func_037_hats_off_all.lua",
    "modules/combat/func_038_drop_tools_all.lua",
    "modules/combat/func_039_forcefield_off_all.lua",
    "modules/combat/func_040_character_reset.lua",

    -- MODULES: Auras (20)
    "modules/auras/func_041_fling_aura.lua",
    "modules/auras/func_042_kill_aura.lua",
    "modules/auras/func_043_freeze_aura.lua",
    "modules/auras/func_044_fire_aura.lua",
    "modules/auras/func_045_void_aura.lua",
    "modules/auras/func_046_attraction_aura.lua",
    "modules/auras/func_047_auto_counter.lua",
    "modules/auras/func_048_plot_kicker.lua",
    "modules/auras/func_049_gravity_aura.lua",
    "modules/auras/func_050_spin_aura.lua",
    "modules/auras/func_051_damage_aura.lua",
    "modules/auras/func_052_slow_aura.lua",
    "modules/auras/func_053_ragdoll_aura.lua",
    "modules/auras/func_054_teleport_aura.lua",
    "modules/auras/func_055_blind_aura.lua",
    "modules/auras/func_056_kick_aura.lua",
    "modules/auras/func_057_confuse_aura.lua",
    "modules/auras/func_058_mute_aura.lua",
    "modules/auras/func_059_shrink_aura.lua",
    "modules/auras/func_060_grow_aura.lua",

    -- MODULES: Protection (20)
    "modules/protection/func_061_anti_grab.lua",
    "modules/protection/func_062_anti_fling.lua",
    "modules/protection/func_063_anti_freeze.lua",
    "modules/protection/func_064_anti_ragdoll.lua",
    "modules/protection/func_065_anti_void.lua",
    "modules/protection/func_066_anti_vote_kick.lua",
    "modules/protection/func_067_anti_kick.lua",
    "modules/protection/func_068_anti_teleport.lua",
    "modules/protection/func_069_anti_sit.lua",
    "modules/protection/func_070_anti_burn.lua",
    "modules/protection/func_071_anti_explosion.lua",
    "modules/protection/func_072_anti_damage.lua",
    "modules/protection/func_073_anti_slow.lua",
    "modules/protection/func_074_anti_fire_touch.lua",
    "modules/protection/func_075_anti_gravity.lua",
    "modules/protection/func_076_anti_shrink.lua",
    "modules/protection/func_077_noclip.lua",
    "modules/protection/func_078_infinite_yield.lua",
    "modules/protection/func_079_god_mode.lua",
    "modules/protection/func_080_rejoin_on_damage.lua",

    -- MODULES: Targeting (20)
    "modules/targeting/func_081_loop_kill.lua",
    "modules/targeting/func_082_loop_burn.lua",
    "modules/targeting/func_083_loop_fling.lua",
    "modules/targeting/func_084_loop_freeze.lua",
    "modules/targeting/func_085_loop_void.lua",
    "modules/targeting/func_086_follow_target.lua",
    "modules/targeting/func_087_view_target.lua",
    "modules/targeting/func_088_tp_to_target.lua",
    "modules/targeting/func_089_tp_target_to_me.lua",
    "modules/targeting/func_090_kill_target.lua",
    "modules/targeting/func_091_fling_target.lua",
    "modules/targeting/func_092_freeze_target.lua",
    "modules/targeting/func_093_void_target.lua",
    "modules/targeting/func_094_sky_target.lua",
    "modules/targeting/func_095_spin_target.lua",
    "modules/targeting/func_096_orbit_target.lua",
    "modules/targeting/func_097_ragdoll_target.lua",
    "modules/targeting/func_098_blind_target.lua",
    "modules/targeting/func_099_steal_target_tools.lua",
    "modules/targeting/func_100_copy_target_skin.lua",

    -- MODULES: Movement (20)
    "modules/movement/func_101_infinite_jump.lua",
    "modules/movement/func_102_noclip.lua",
    "modules/movement/func_103_fly.lua",
    "modules/movement/func_104_speed_boost.lua",
    "modules/movement/func_105_high_jump.lua",
    "modules/movement/func_106_low_gravity.lua",
    "modules/movement/func_107_zero_gravity.lua",
    "modules/movement/func_108_auto_jump.lua",
    "modules/movement/func_109_bunny_hop.lua",
    "modules/movement/func_110_slide.lua",
    "modules/movement/func_111_wall_run.lua",
    "modules/movement/func_112_crouch.lua",
    "modules/movement/func_113_sprint.lua",
    "modules/movement/func_114_tp_spawn.lua",
    "modules/movement/func_115_tp_random_player.lua",
    "modules/movement/func_116_tp_forward.lua",
    "modules/movement/func_117_tp_up.lua",
    "modules/movement/func_118_tp_down.lua",
    "modules/movement/func_119_tp_cursor.lua",
    "modules/movement/func_120_reset_speed.lua",

    -- MODULES: Visuals (20)
    "modules/visuals/func_121_esp_boxes.lua",
    "modules/visuals/func_122_esp_tracers.lua",
    "modules/visuals/func_123_player_info.lua",
    "modules/visuals/func_124_name_tags.lua",
    "modules/visuals/func_125_health_bars.lua",
    "modules/visuals/func_126_distance_display.lua",
    "modules/visuals/func_127_skeleton_esp.lua",
    "modules/visuals/func_128_chams.lua",
    "modules/visuals/func_129_xray.lua",
    "modules/visuals/func_130_fullbright.lua",
    "modules/visuals/func_131_no_fog.lua",
    "modules/visuals/func_132_remove_textures.lua",
    "modules/visuals/func_133_blue_sky.lua",
    "modules/visuals/func_134_red_ambient.lua",
    "modules/visuals/func_135_green_ambient.lua",
    "modules/visuals/func_136_rainbow_light.lua",
    "modules/visuals/func_137_remove_baseplate.lua",
    "modules/visuals/func_138_remove_lights.lua",
    "modules/visuals/func_139_restore_lighting.lua",
    "modules/visuals/func_140_disable_shadows.lua",

    -- MODULES: Server (20)
    "modules/server/func_141_rejoin.lua",
    "modules/server/func_142_server_hop.lua",
    "modules/server/func_143_join_smallest.lua",
    "modules/server/func_144_join_largest.lua",
    "modules/server/func_145_copy_jobid.lua",
    "modules/server/func_146_copy_placeid.lua",
    "modules/server/func_147_copy_server_link.lua",
    "modules/server/func_148_show_server_info.lua",
    "modules/server/func_149_list_players.lua",
    "modules/server/func_150_hop_until_empty.lua",
    "modules/server/func_151_anti_afk.lua",
    "modules/server/func_152_auto_rejoin_kick.lua",
    "modules/server/func_153_rejoin_delay.lua",
    "modules/server/func_154_ping_display.lua",
    "modules/server/func_155_fps_display.lua",
    "modules/server/func_156_leave_game.lua",
    "modules/server/func_157_reset_character.lua",
    "modules/server/func_158_character_respawn.lua",
    "modules/server/func_159_unlock_fps.lua",
    "modules/server/func_160_show_fps.lua",

    -- MODULES: Utility (20)
    "modules/utility/func_161_anti_afk.lua",
    "modules/utility/func_162_auto_claim_cash.lua",
    "modules/utility/func_163_cash_magnet.lua",
    "modules/utility/func_164_item_magnet.lua",
    "modules/utility/func_165_bring_all_items.lua",
    "modules/utility/func_166_bring_all_players.lua",
    "modules/utility/func_167_clear_workspace.lua",
    "modules/utility/func_168_delete_grabbed.lua",
    "modules/utility/func_169_unlock_mouse.lua",
    "modules/utility/func_170_full_screen.lua",
    "modules/utility/func_171_copy_position.lua",
    "modules/utility/func_172_copy_rotation.lua",
    "modules/utility/func_173_show_position.lua",
    "modules/utility/func_174_print_character.lua",
    "modules/utility/func_175_clear_notifications.lua",
    "modules/utility/func_176_toggle_ui.lua",
    "modules/utility/func_177_re_execute.lua",
    "modules/utility/func_178_reload_config.lua",
    "modules/utility/func_179_save_config.lua",
    "modules/utility/func_180_wipe_cache.lua",

    -- MODULES: Trolling (20)
    "modules/trolling/func_181_music_play.lua",
    "modules/trolling/func_182_reverse_controls.lua",
    "modules/trolling/func_183_fling_random_aura.lua",
    "modules/trolling/func_184_rainbow_all.lua",
    "modules/trolling/func_185_neon_all.lua",
    "modules/trolling/func_186_shrink_all.lua",
    "modules/trolling/func_187_grow_all.lua",
    "modules/trolling/func_188_head_spin_all.lua",
    "modules/trolling/func_189_random_color_self.lua",
    "modules/trolling/func_190_rainbow_self.lua",
    "modules/trolling/func_191_neon_self.lua",
    "modules/trolling/func_192_ghost_self.lua",
    "modules/trolling/func_193_invisible_self.lua",
    "modules/trolling/func_194_visible_self.lua",
    "modules/trolling/func_195_shake_screen_all.lua",
    "modules/trolling/func_196_fake_death_all.lua",
    "modules/trolling/func_197_fire_trail.lua",
    "modules/trolling/func_198_ice_trail.lua",
    "modules/trolling/func_199_lightning_self.lua",
    "modules/trolling/func_200_dance_all.lua",

    -- MODULES: Animations (25)
    "modules/animations/func_201_play_dance.lua",
    "modules/animations/func_202_play_wave.lua",
    "modules/animations/func_203_play_point.lua",
    "modules/animations/func_204_play_laugh.lua",
    "modules/animations/func_205_play_cheer.lua",
    "modules/animations/func_206_play_floss.lua",
    "modules/animations/func_207_play_dab.lua",
    "modules/animations/func_208_play_russian.lua",
    "modules/animations/func_209_play_karate.lua",
    "modules/animations/func_210_play_salsa.lua",
    "modules/animations/func_211_play_hiphop.lua",
    "modules/animations/func_212_play_breakdance.lua",
    "modules/animations/func_213_play_robot.lua",
    "modules/animations/func_214_play_backflip.lua",
    "modules/animations/func_215_play_frontflip.lua",
    "modules/animations/func_216_play_sit.lua",
    "modules/animations/func_217_play_lay.lua",
    "modules/animations/func_218_play_crawl.lua",
    "modules/animations/func_219_play_sprint_anim.lua",
    "modules/animations/func_220_play_swim.lua",
    "modules/animations/func_221_play_climb.lua",
    "modules/animations/func_222_stop_all_anims.lua",
    "modules/animations/func_223_free_anims_off.lua",
    "modules/animations/func_224_anim_speed_up.lua",
    "modules/animations/func_225_anim_slow_down.lua",

    -- MODULES: Kick (50)
    "modules/kick/func_226_kick_all.lua",
    "modules/kick/func_227_kick_closest.lua",
    "modules/kick/func_228_kick_random.lua",
    "modules/kick/func_229_kick_by_name.lua",
    "modules/kick/func_230_kick_farthest.lua",
    "modules/kick/func_231_kick_lowest_hp.lua",
    "modules/kick/func_232_kick_highest_hp.lua",
    "modules/kick/func_233_kick_friend.lua",
    "modules/kick/func_234_kick_non_friend.lua",
    "modules/kick/func_235_kick_team.lua",
    "modules/kick/func_236_kick_enemy_team.lua",
    "modules/kick/func_237_kick_afk.lua",
    "modules/kick/func_238_kick_talking.lua",
    "modules/kick/func_239_kick_silent.lua",
    "modules/kick/func_240_kick_walking.lua",
    "modules/kick/func_241_kick_standing.lua",
    "modules/kick/func_242_kick_jumping.lua",
    "modules/kick/func_243_kick_flying.lua",
    "modules/kick/func_244_kick_glitched.lua",
    "modules/kick/func_245_kick_invisible.lua",
    "modules/kick/func_246_kick_visible.lua",
    "modules/kick/func_247_kick_high_ping.lua",
    "modules/kick/func_248_kick_low_ping.lua",
    "modules/kick/func_249_kick_mobile.lua",
    "modules/kick/func_250_kick_pc.lua",
    "modules/kick/func_251_kick_console.lua",
    "modules/kick/func_252_kick_vr.lua",
    "modules/kick/func_253_kick_guest.lua",
    "modules/kick/func_254_kick_premium.lua",
    "modules/kick/func_255_kick_non_premium.lua",
    "modules/kick/func_256_kick_verified.lua",
    "modules/kick/func_257_kick_non_verified.lua",
    "modules/kick/func_258_kick_with_hats.lua",
    "modules/kick/func_259_kick_without_hats.lua",
    "modules/kick/func_260_kick_with_tools.lua",
    "modules/kick/func_261_kick_without_tools.lua",
    "modules/kick/func_262_kick_rich.lua",
    "modules/kick/func_263_kick_poor.lua",
    "modules/kick/func_264_kick_high_level.lua",
    "modules/kick/func_265_kick_low_level.lua",
    "modules/kick/func_266_kick_owner.lua",
    "modules/kick/func_267_kick_admin.lua",
    "modules/kick/func_268_kick_moderator.lua",
    "modules/kick/func_269_kick_staff.lua",
    "modules/kick/func_270_kick_bots.lua",
    "modules/kick/func_271_kick_alts.lua",
    "modules/kick/func_272_kick_by_userid.lua",
    "modules/kick/func_273_kick_by_display_name.lua",
    "modules/kick/func_274_kick_multiple.lua",
    "modules/kick/func_275_kick_blacklist.lua",

    -- RUNTIME
    "runtime.lua"
}

-- ============================================================
-- СБОРКА
-- ============================================================
print("============================================")
print("Resonance v4.0 — Build")
print("============================================")

local out = {}
table.insert(out, "-- ============================================================")
table.insert(out, "-- Resonance v4.0 — Auto-generated bundled script")
table.insert(out, "-- Source: https://github.com/a32435629-collab/resonance")
table.insert(out, "-- Built: " .. os.date("%Y-%m-%d %H:%M:%S"))
table.insert(out, "-- ============================================================")
table.insert(out, "")
table.insert(out, "local __RESONANCE_MODULES = {}")
table.insert(out, "")

local loaded = 0
local failed = 0

for i, relPath in ipairs(MANIFEST) do
    local fullPath = SRC .. relPath
    if fileExists(fullPath) then
        local content = readFile(fullPath)
        if content then
            table.insert(out, "-- === " .. relPath .. " ===")
            table.insert(out, content)
            table.insert(out, "")
            loaded = loaded + 1
        else
            print("  [FAIL] " .. relPath .. " (не читается)")
            failed = failed + 1
        end
    else
        print("  [SKIP] " .. relPath .. " (не найден)")
        failed = failed + 1
    end
end

-- ============================================================
-- ЗАПУСК ЧЕРЕЗ INIT
-- ============================================================
table.insert(out, "")
table.insert(out, "-- Авто-запуск через init логику")
table.insert(out, "print('============================================')")
table.insert(out, "print('[Resonance] Bundled script loaded')")
table.insert(out, "print('[Resonance] Modules: " .. loaded .. " | Failed: " .. failed .. "')")
table.insert(out, "print('============================================')")

writeFile(OUTPUT, table.concat(out, "\n"))

print("")
print("============================================")
print("Готово!")
print("Output: " .. OUTPUT)
print("Модулей: " .. loaded)
print("Ошибок: " .. failed)
print("============================================")