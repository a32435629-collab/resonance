return {
    id = "AutoLeaveStaff", type = "toggle", name = "Auto-Leave on Staff",
    section = "Исключения", tab = "Filters",
    default = false,
    tooltip = "Мгновенный выход при обнаружении модератора",
    onChanged = function(v, S) S.AutoLeaveStaff = v end
}