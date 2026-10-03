return {
    id = "WhitelistFriends", type = "toggle", name = "Whitelist Friends",
    section = "Исключения", tab = "Filters",
    default = true,
    tooltip = "Игнорировать ваших друзей",
    onChanged = function(v, S) S.WhitelistFriends = v end
}