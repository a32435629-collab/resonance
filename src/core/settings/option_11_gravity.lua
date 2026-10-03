return {
    id = "Gravity", type = "slider", name = "Gravity",
    section = "Физика", tab = "Movement",
    default = 196.2, range = {0, 500}, increment = 10, suffix = "",
    tooltip = "Гравитация мира",
    onChanged = function(v, S)
        S.Gravity = v
        game:GetService("Workspace").Gravity = v
    end
}