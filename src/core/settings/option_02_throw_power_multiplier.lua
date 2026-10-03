return {
    id = "ThrowPowerMult", type = "slider", name = "Throw Power Multiplier",
    section = "Дистанции", tab = "Main",
    default = 1.0, range = {0.1, 10}, increment = 0.1, suffix = "x",
    tooltip = "Множитель силы броска",
    onChanged = function(v, S) S.ThrowPowerMult = v end
}