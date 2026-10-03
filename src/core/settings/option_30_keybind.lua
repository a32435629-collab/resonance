return {
    id = "Keybind", type = "keybind", name = "Menu Keybind",
    section = "Интерфейс", tab = "Settings",
    default = "RightShift",
    tooltip = "Клавиша открытия меню",
    onChanged = function(v, S) S.Keybind = v end
}