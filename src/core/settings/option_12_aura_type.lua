return {
    id = "AuraType", type = "dropdown", name = "Aura Type",
    section = "Аура", tab = "Auras",
    default = "Fling", options = {"Fling","Kill","Freeze","Fire","Void"},
    multiple = false,
    tooltip = "Режим работы ауры",
    onChanged = function(opt, S) S.AuraType = opt[1] end
}