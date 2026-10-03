return {
    id = "AnimLoop", type = "toggle", name = "Loop Animations",
    section = "Анимации", tab = "Animations",
    default = true,
    tooltip = "Зацикливать анимацию",
    onChanged = function(v, S) S.AnimLoop = v end
}