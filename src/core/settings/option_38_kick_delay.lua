return {
    id = "KickDelay", type = "slider", name = "Kick Delay",
    section = "Кик", tab = "Kick",
    default = 0, range = {0, 5000}, increment = 100, suffix = " ms",
    tooltip = "Задержка перед киком",
    onChanged = function(v, S) S.KickDelay = v end
}