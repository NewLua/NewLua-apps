local UI = require('opus.ui')
local Event = require('opus.event')

local colors = _G.colors

local page = UI.Page {
  terminal = UI.Window {
    x = 1, y = 1,
    ex = -1, ey = -1,
    backgroundColor = colors.black,
    UI.Terminal {
      x = 1, y = 1,
      ex = -1, ey = -1
    }
  }
}

-- Lance le shell advShell dans le terminal
function page:shell()
  self.terminal.terminal:execute('/packages/Advenced-music/music.lua')
end

UI:setPage(page)
page:shell()
UI:start()