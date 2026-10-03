return {
    id = "AuraRadius", type = "slider", name = "Aura Radius",
    section = "Аура", tab = "Auras",
    default = 15, range = {1, 100}, increment = 1, suffix = " studs",
    tooltip = "Радиус действия ауры",
    onChanged = function(v, S) S.AuraRadius = v end
}