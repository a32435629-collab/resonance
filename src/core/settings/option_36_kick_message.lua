return {
    id = "KickMessage", type = "input", name = "Kick Message",
    section = "Кик", tab = "Kick",
    default = "Resonance kicked you",
    tooltip = "Сообщение для жертвы",
    onChanged = function(txt, S) S.KickMessage = txt end
}