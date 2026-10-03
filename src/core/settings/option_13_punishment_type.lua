return {
    id = "PunishmentType", type = "dropdown", name = "Punishment Type",
    section = "Захват", tab = "Combat",
    default = "Insta-Kill",
    options = {"Insta-Kill","Void Teleport","Ragdoll","Orbit","Burn"},
    multiple = false,
    tooltip = "Наказание при захвате",
    onChanged = function(opt, S) S.PunishmentType = opt[1] end
}