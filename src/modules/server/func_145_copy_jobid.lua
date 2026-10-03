-- Func #145: Copy JobID | button
return {
    id = "CopyJobId", type = "button", name = "Copy JobID",
    tooltip = "Скопировать JobID сервера", tab = "Server",
    onClick = function(Settings, Utils)
        if setclipboard then
            setclipboard(game.JobId)
            Utils.notify("Resonance", "JobID скопирован", Settings)
        end
    end
}