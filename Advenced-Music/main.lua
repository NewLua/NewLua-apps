local UI = require('opus.ui')
local Event = require('opus.event')

local colors = _G.colors

local page = UI.Page {
  terminal = UI.Window {
    x = 1, y = 1,
    ex = -1, ey = -1,
    backgroundColor = colors.black,
  }
}

-- Fonction pour lancer le programme musical
function page:shell()
  shell.run('/packages/Advenced-music/music.lua')
end

UI:setPage(page)
page:shell()
UI:start()
