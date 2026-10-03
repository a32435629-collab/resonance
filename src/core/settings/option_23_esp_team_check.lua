return {
    id = "ESPTeamCheck", type = "toggle", name = "Team Check",
    section = "ESP", tab = "Visuals",
    default = true,
    tooltip = "Не показывать союзников",
    onChanged = function(v, S) S.ESPTeamCheck = v end
}