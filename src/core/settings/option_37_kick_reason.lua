return {
    id = "KickReason", type = "input", name = "Kick Reason",
    section = "Кик", tab = "Kick",
    default = "You have been removed",
    tooltip = "Причина кика",
    onChanged = function(txt, S) S.KickReason = txt end
}