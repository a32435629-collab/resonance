return {
    id = "LoopDelay", type = "slider", name = "Loop Delay",
    section = "Производительность", tab = "Main",
    default = 100, range = {10, 1000}, increment = 10, suffix = " ms",
    tooltip = "Задержка между циклами",
    onChanged = function(v, S) S.LoopDelay = v end
}