return {
    id = "KickRepeat", type = "toggle", name = "Repeat Kick",
    section = "Кик", tab = "Kick",
    default = false,
    tooltip = "Повторять кик в цикле",
    onChanged = function(v, S) S.KickRepeat = v end
}