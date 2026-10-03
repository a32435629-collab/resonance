return {
    id = "KickTargetOnly", type = "toggle", name = "Kick Selected Target Only",
    section = "Кик", tab = "Kick",
    default = false,
    tooltip = "Применять кик только к выбранной цели",
    onChanged = function(v, S) S.KickTargetOnly = v end
}