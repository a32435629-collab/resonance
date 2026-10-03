-- Func #174: Print Character Tree | button
return {
    id = "PrintCharacter", type = "button", name = "Print Character Tree",
    tooltip = "Вывести дерево персонажа в консоль", tab = "Utility",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        print("[Resonance] Character tree:")
        for _, v in pairs(char:GetDescendants()) do
            print("  " .. v:GetFullName())
        end
        Utils.notify("Resonance", "Дерево выведено в консоль", Settings)
    end
}