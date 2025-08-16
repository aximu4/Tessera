-- Tessera code :3 (i will make it shorter eventually..)

math.randomseed(os.time() + math.floor(os.clock()*1000))
term.setCursorBlink(false)

local settingsFile = "tessera_settings"
local leaderboardFile = "tessera_local_leaderboard"
local MAX_NAME_LEN = 6

local rootTerm = term.current()
local screen
local frameDepth = 0

local function createScreen()
  local rw, rh = rootTerm.getSize()
  screen = window.create(rootTerm, 1, 1, rw, rh, true)
  screen.setVisible(false)
  term.redirect(screen)
end

local function beginFrame()
  frameDepth = frameDepth + 1
  if frameDepth == 1 and screen then screen.setVisible(false) end
end

local function endFrame()
  if frameDepth > 0 then
    frameDepth = frameDepth - 1
    if frameDepth == 0 and screen then screen.setVisible(true) end
  end
end

local function handleResize(recalcLayoutFn)
  term.redirect(rootTerm)
  createScreen()
  if recalcLayoutFn then recalcLayoutFn() end
end

createScreen()

local function safeOpen(path, mode)
  local ok, h = pcall(fs.open, path, mode)
  if ok and h then return h end
  return nil
end

local function safeUnserialize(s)
  local ok, t = pcall(textutils.unserialize, s)
  if ok then return t end
  return nil
end

local function safeSerialize(t)
  return textutils.serialize(t)
end

local function migrateSettings(t)
  if t.music == nil then
    local on = (t.musicOn ~= false)
    local mode = t.musicMode or "A"
    t.music = on and mode or "Off"
    t.musicOn = nil
    t.musicMode = nil
  end
  if t.menuMusic == nil then
    t.menuMusic = "On"
  end
  return t
end

local function safeLoadSettings()
  local def = {
    musicVolume = 80,
    startLevel = 0,
    music = "A",
    menuMusic = "On",
    rebinds = {
      left = keys.left,
      right = keys.right,
      down = keys.down,
      drop = keys.space,
      rotate_cw = 88,
      rotate_ccw = 90,
      rotate_180 = 67,
      pause = 80
    },
  }
  if fs.exists(settingsFile) then
    local f = safeOpen(settingsFile, "r")
    if f then
      local data = f.readAll() or ""
      f.close()
      local t = safeUnserialize(data)
      if type(t) == "table" then
        t.rebinds = t.rebinds or {}
        for k,v in pairs(def.rebinds) do if t.rebinds[k] == nil then t.rebinds[k] = v end end
        for k,v in pairs(def) do if t[k] == nil then t[k] = v end end
        return migrateSettings(t)
      end
    end
  end
  return def
end

local function safeSaveSettings(t)
  local f = safeOpen(settingsFile, "w")
  if f then f.write(safeSerialize(t)) f.close() end
end

local settings = migrateSettings(safeLoadSettings())

local w, h = screen.getSize()
local fieldW, fieldH = 10, 20
local cellW = 2
local startX = math.floor((w - fieldW*cellW)/2)+1
local startY = math.floor((h - fieldH)/2)+1
local bgColor = colors.black
local fgColor = colors.white

local function recalcLayout()
  w, h = screen.getSize()
  startX = math.floor((w - fieldW*cellW)/2)+1
  startY = math.floor((h - fieldH)/2)+1
end

local function keyName(k)
  if type(k)~="number" then return tostring(k) end
  local ok, name = pcall(function() return keys.getName(k) end)
  if ok and name then return tostring(name) end
  return tostring(k)
end

local function nes_frames_per_cell(lvl)
  if lvl <= 0 then return 48
  elseif lvl == 1 then return 43
  elseif lvl == 2 then return 38
  elseif lvl == 3 then return 33
  elseif lvl == 4 then return 28
  elseif lvl == 5 then return 23
  elseif lvl == 6 then return 18
  elseif lvl == 7 then return 13
  elseif lvl == 8 then return 8
  elseif lvl == 9 then return 6
  elseif lvl <= 12 then return 5
  elseif lvl <= 15 then return 4
  elseif lvl <= 18 then return 3
  elseif lvl <= 28 then return 2
  else return 1
  end
end

local function nes_seconds_per_cell(lvl)
  return nes_frames_per_cell(lvl) / 60
end

local function nes_current_level(start_level, total_lines)
  local sl = math.max(0, tonumber(start_level) or 0)
  local lines = math.max(0, tonumber(total_lines) or 0)
  local first_threshold
  if sl <= 9 then
    first_threshold = sl * 10 + 10
  elseif sl <= 15 then
    first_threshold = 100
  elseif sl == 16 then
    first_threshold = 110
  elseif sl == 17 then
    first_threshold = 120
  elseif sl == 18 then
    first_threshold = 130
  else
    first_threshold = 140
  end
  if lines < first_threshold then
    return sl
  else
    return sl + 1 + math.floor((lines - first_threshold) / 10)
  end
end

local function findSpeaker()
  local ok, s = pcall(function() if peripheral then return peripheral.find("speaker") end end)
  if ok and s then return s end
  return nil
end
local speaker = findSpeaker()

local function vol01()
  return math.max(0, math.min(1, (settings.musicVolume or 80)/100))
end

local function readAll(p)
  local f = safeOpen(p, "rb") or safeOpen(p, "r")
  if not f then return nil, "cannot open" end
  local d = f.readAll(); f.close(); return d
end

local function buildSongFromBlob(blob)
  if not blob or #blob == 0 then return nil, "empty" end
  local pos = 1
  local function avail() return #blob - pos + 1 end
  local function rB() if pos>#blob then return nil end local b=string.byte(blob,pos); pos=pos+1; return b end
  local function rU16() local b1,b2=rB(),rB(); if not b1 or not b2 then return nil end return b1 + b2*256 end
  local function rI32()
    local b1,b2,b3,b4=rB(),rB(),rB(),rB(); if not b1 or not b2 or not b3 or not b4 then return nil end
    local n = b1 + b2*256 + b3*65536 + b4*16777216
    if n >= 0x80000000 then n = n - 0x100000000 end
    return n
  end
  local function rStr16()
    local len = rU16(); if not len or len<=0 then return "" end
    if avail() < len then len = avail() end
    local s = blob:sub(pos, pos+len-1); pos = pos + len; return s
  end
  local function rStr32()
    local len = rI32(); if not len or len<=0 then return "" end
    if avail() < len then len = avail() end
    local s = blob:sub(pos, pos+len-1); pos = pos + len; return s
  end

  local INSTR = {
    [0]="harp",[1]="bass",[2]="basedrum",[3]="snare",[4]="hat",[5]="guitar",
    [6]="flute",[7]="bell",[8]="chime",[9]="xylophone",[10]="iron_xylophone",
    [11]="cow_bell",[12]="didgeridoo",[13]="bit",[14]="banjo",[15]="pling",
  }
  local function keyToPitch(key)
    local p = (key or 45) - 33
    while p < 0 do p = p + 12 end
    while p > 24 do p = p - 12 end
    if p < 0 then p = 0 end; if p > 24 then p = 24 end
    return p
  end

  local song = {
    name="", author="", tempo_h=1000, lengthTicks=0, layers=0, version=0, notesByTick={}
  }

  local first = rU16()
  if not first then return nil, "invalid" end

  local newFormat = (first == 0)
  if newFormat then
    song.version      = rB() or 1
    local _vanilla    = rB() or 16
    song.lengthTicks  = rU16() or 0
    song.layers       = rU16() or 0
    song.name         = rStr32()
    song.author       = rStr32()
    song.original     = rStr32()
    song.description  = rStr32()
    song.tempo_h      = rU16() or 1000

    rB(); rB(); rB()
    rI32(); rI32(); rI32(); rI32(); rI32()
    rStr32()
    rB(); rB(); rU16()

    local tick = -1
    while true do
      local jumpTick = rU16(); if not jumpTick then break end
      if jumpTick == 0 then break end
      tick = tick + jumpTick
      local layer = -1
      while true do
        local jumpLayer = rU16(); if not jumpLayer then break end
        if jumpLayer == 0 then break end
        layer = layer + jumpLayer

        local instr = rB(); local key = rB()
        if not instr or not key then break end
        local vel = 100; local pan = 100; local fine = 0
        if song.version >= 4 then
          vel = rB() or 100
          pan = rB() or 100
          local s = rU16(); if s then if s >= 32768 then s = s - 65536 end fine = s end
        end
        song.notesByTick[tick] = song.notesByTick[tick] or {}
        table.insert(song.notesByTick[tick], {instr=INSTR[instr] or "harp", key=keyToPitch(key), vel=vel})
      end
    end
  else
    song.lengthTicks = first
    song.layers      = rU16() or 0
    song.name        = rStr16()
    song.author      = rStr16()
    song.original    = rStr16()
    song.description = rStr16()
    song.tempo_h     = rU16() or 1000
    rB(); rB(); rB()
    rI32(); rI32(); rI32(); rI32(); rI32()
    rStr16()

    local tick = -1
    while true do
      local jumpTick = rU16(); if not jumpTick then break end
      if jumpTick == 0 then break end
      tick = tick + jumpTick
      local layer = -1
      while true do
        local jumpLayer = rU16(); if not jumpLayer then break end
        if jumpLayer == 0 then break end
        layer = layer + jumpLayer
        local instr = rB(); local key = rB()
        if not instr or not key then break end
        song.notesByTick[tick] = song.notesByTick[tick] or {}
        table.insert(song.notesByTick[tick], {instr=INSTR[instr] or "harp", key=keyToPitch(key), vel=100})
      end
    end
  end

  return song
end

local Music = {}
Music.__index = Music

function Music.new()
  local self = setmetatable({}, Music)
  self.tracks = {
    A = { path = "Tessera/music-a.nbs", song = nil},
    B = { path = "Tessera/music-b.nbs", song = nil},
    C = { path = "Tessera/music-c.nbs", song = nil},
    SCORE = { path = "Tessera/score.nbs", song = nil},
  }
  self.current = "A"
  self.frameTimerId = nil
  self.framePeriod = 0.05
  self.lastTime = 0
  self.accum = 0
  self.maxTicksPerUpdate = 16
  self.playing = false
  self.tick = 1
  self.speedMul = 1.0
  self.perSongMul = { A = 1.0, B = 0.9, C = 1.0, SCORE = 1.0 }
  self._lastMode = "A"
  return self
end

function Music:setSongSpeed(tag, mul)
  if not tag then return end
  tag = tostring(tag):upper()
  if self.perSongMul[tag] ~= nil then
    local m = tonumber(mul) or 1.0
    if m <= 0 then m = 0.25 end
    if m > 8 then m = 8 end
    self.perSongMul[tag] = m
  end
end
function Music:getSongSpeed(tag)
  if not tag then return 1.0 end
  tag = tostring(tag):upper()
  return self.perSongMul[tag] or 1.0
end

function Music:setOption(opt)
  self._lastMode = self.current
  if opt == "A" or opt == "B" or opt == "C" then
    self.current = opt
  else
    self.current = "Off"
  end
end

function Music:load(tag)
  local t = self.tracks[tag]; if not t then return end
  if t.song then return end
  if not fs.exists(t.path) then return end
  local blob = readAll(t.path)
  if not blob then return end
  local song = buildSongFromBlob(blob)
  if not song then return end
  local slices = {}
  local maxTick = 0
  for tick, arr in pairs(song.notesByTick) do
    slices[tick] = arr
    if tick > maxTick then maxTick = tick end
  end
  local tempo_h = tonumber(song.tempo_h) or 1000
  local tps = tempo_h / 100.0
  if tps <= 0 then tps = 10 end
  local spt = (1.0 / tps)
  t.song = {
    tempo_h     = tempo_h,
    tps         = tps,
    spt         = spt,
    slices      = slices,
    lengthTicks = (song.lengthTicks and song.lengthTicks>0) and song.lengthTicks or maxTick
  }
end

function Music:_effectiveSPT(tag)
  local t = self.tracks[tag]
  local s = t and t.song
  local base = (s and s.spt) or (1/10)
  local globalMul  = (self.speedMul > 0 and self.speedMul or 1.0)
  local songMul    = self:getSongSpeed(tag)
  if songMul <= 0 then songMul = 0.0001 end
  return base / (globalMul * songMul)
end
function Music:_tickDuration(tag) return self:_effectiveSPT(tag) end

function Music:_scheduleFrame()
  if self.frameTimerId then return end
  self.frameTimerId = os.startTimer(self.framePeriod)
end

function Music:_playSlice(slice)
  if not speaker or not slice then return end
  local vol = math.max(0, math.min(3, vol01() * 3))
  for _,n in ipairs(slice) do
    pcall(function() speaker.playNote(n.instr or "harp", vol, n.key or 12) end)
  end
end

function Music:playGame()
  if self.current == "Off" or not speaker then return end
  local tag = self.current
  self:load(tag)
  local t = self.tracks[tag]
  if not t or not t.song then return end
  self.playing = true
  self.lastTime = os.clock()
  self.accum = 0
  self:_scheduleFrame()
end

function Music:playScore(reset)
  if not speaker then return end
  local tag = "SCORE"
  self:load(tag)
  if reset then self.tick = 0 end
  local t = self.tracks[tag]
  if not t or not t.song then return end
  self.playing = true
  self.lastTime = os.clock()
  self.accum = 0
  self:_scheduleFrame()
end

function Music:stop()
  self.playing = false
  self.frameTimerId = nil
end

function Music:resetPosition()
  self.tick = 0
  self.accum = 0
end

function Music:onTimer(id, isPaused)
  if id ~= self.frameTimerId then return end
  self.frameTimerId = nil
  if not self.playing then return end
  local tag = isPaused and "SCORE" or (self.current == "Off" and "SCORE" or self.current)
  self:load(tag)
  local t = self.tracks[tag]
  if not t or not t.song then return end
  local s = t.song
  local now = os.clock()
  local dt = now - (self.lastTime or now)
  if dt < 0 or dt > 1 then dt = self.framePeriod end
  self.lastTime = now
  self.accum = (self.accum or 0) + dt
  local spt = self:_effectiveSPT(tag)
  if spt <= 0 then spt = 0.0001 end
  local processed = 0
  while self.accum >= spt and processed < self.maxTicksPerUpdate do
    local slice = s.slices[self.tick]
    self:_playSlice(slice)
    self.tick = self.tick + 1
    if self.tick > (s.lengthTicks or 0) then
      self.tick = 0
    end
    self.accum = self.accum - spt
    processed = processed + 1
  end
  if processed >= self.maxTicksPerUpdate and self.accum > spt * 2 then
    self.accum = spt
  end
  self:_scheduleFrame()
end

function Music:setSpeedMul(mul)
  self.speedMul = math.max(0.25, math.min(3.0, mul or 1.0))
end

local music = Music.new()
music:setOption(settings.music or "A")

local palettes = {
{ I=colors.cyan, J=colors.blue, L=colors.lime, O=colors.green, S=colors.pink, T=colors.red, Z=colors.orange },
{ I=colors.lime, J=colors.green, L=colors.lightBlue, O=colors.cyan, S=colors.pink, T=colors.magenta, Z=colors.red },
{ I=colors.pink, J=colors.magenta, L=colors.lime, O=colors.green, S=colors.lightBlue,T=colors.blue, Z=colors.red },
{ I=colors.blue, J=colors.lightBlue, L=colors.lime, O=colors.green, S=colors.pink, T=colors.magenta, Z=colors.red },
{ I=colors.green, J=colors.lime, L=colors.cyan, O=colors.lightBlue,S=colors.pink, T=colors.magenta, Z=colors.red },
{ I=colors.orange, J=colors.red, L=colors.lightGray,O=colors.gray, S=colors.pink, T=colors.purple, Z=colors.magenta },
{ I=colors.magenta, J=colors.purple, L=colors.orange, O=colors.red, S=colors.lightBlue,T=colors.blue, Z=colors.cyan },
{ I=colors.blue, J=colors.cyan, L=colors.orange, O=colors.brown, S=colors.red, T=colors.orange, Z=colors.yellow },
{ I=colors.orange, J=colors.red, L=colors.magenta,O=colors.purple, S=colors.blue, T=colors.cyan, Z=colors.lime },
{ I=colors.orange, J=colors.yellow, L=colors.orange, O=colors.yellow, S=colors.orange, T=colors.yellow, Z=colors.orange }, }

local function paletteForLevel(l) return palettes[(l % #palettes) + 1] end
local function getPieceColor(id, level)
  local p = paletteForLevel(level or 0)
  return p[id] or colors.white
end

local pieces = {
  I = {
    { {0,0,0,0},{1,1,1,1},{0,0,0,0},{0,0,0,0} },
    { {0,0,1,0},{0,0,1,0},{0,0,1,0},{0,0,1,0} } 
  },
  J = {
    { {1,0,0},{1,1,1},{0,0,0} },
    { {0,1,1},{0,1,0},{0,1,0} },
    { {0,0,0},{1,1,1},{0,0,1} },
    { {0,1,0},{0,1,0},{1,1,0} }
  },
  L = {
    { {0,0,1},{1,1,1},{0,0,0} },
    { {0,1,0},{0,1,0},{0,1,1} },
    { {0,0,0},{1,1,1},{1,0,0} },
    { {1,1,0},{0,1,0},{0,1,0} }
  },
  O = {
    { {1,1},{1,1} }
  },
  S = {
    { {0,1,1},{1,1,0},{0,0,0} },
    { {0,1,0},{0,1,1},{0,0,1} }
  },
  T = {
    { {0,1,0},{1,1,1},{0,0,0} },
    { {0,1,0},{0,1,1},{0,1,0} },
    { {0,0,0},{1,1,1},{0,1,0} },
    { {0,1,0},{1,1,0},{0,1,0} }
  },
  Z = {
    { {1,1,0},{0,1,1},{0,0,0} },
    { {0,0,1},{0,1,1},{0,1,0} }
  }
}
local order = {"I","J","L","O","S","T","Z"}
local function shuffle(t) for i=#t,2,-1 do local j = math.random(1,i); t[i],t[j] = t[j],t[i] end end

local function loadLocalLeaderboard()
  if not fs.exists(leaderboardFile) then return {} end
  local f = safeOpen(leaderboardFile, "r")
  if not f then return {} end
  local data = f.readAll() or ""
  f.close()
  local t = safeUnserialize(data)
  if type(t)=="table" then return t end
  return {}
end

local function saveLocalLeaderboard(t)
  local f = safeOpen(leaderboardFile, "w")
  if f then f.write(safeSerialize(t)) f.close() end
end

local function insertLocalEntry(name, score, level)
  local nm = tostring(name or ""):sub(1,MAX_NAME_LEN)
  if nm == "" then nm = string.rep("-", MAX_NAME_LEN) end
  local t = loadLocalLeaderboard()
  table.insert(t, { name = nm, score = tonumber(score) or 0, level = tonumber(level) or 0, date = os.date("%Y-%m-%d") })
  table.sort(t, function(a,b)
    if a.score ~= b.score then return a.score > b.score end
    return a.level > b.level
  end)
  while #t > 10 do table.remove(t) end
  saveLocalLeaderboard(t)
end

local function drawNESLeaderboard()
  beginFrame()
  local entries = loadLocalLeaderboard()
  term.setBackgroundColor(bgColor); term.clear()
  term.setTextColor(colors.white)
  local title = "TOP SCORES"
  local midX = math.floor((w - #title)/2)+1
  term.setCursorPos(midX, 2); term.write(title)
  local boxW = 28
  local bx = math.floor((w - boxW)/2)+1
  local top = 4
  term.setCursorPos(bx, top); term.write("+"..string.rep("-", boxW-2).."+")
  for i=1,12 do term.setCursorPos(bx, top+i); term.write("|"..string.rep(" ", boxW-2).."|") end
  term.setCursorPos(bx, top+13); term.write("+"..string.rep("-", boxW-2).."+")
  term.setCursorPos(bx+2, top+1); term.write("RANK NAME      SCORE  LVL")
  for i=1,10 do
    local e = entries[i]
    local y = top+1+i
    term.setCursorPos(bx+2, y)
    if e then
      local rank = string.format("%2d", i)
      local name = (e.name or string.rep("-", MAX_NAME_LEN)):sub(1,MAX_NAME_LEN)
      local score = string.format("%7d", e.score or 0)
      local lv = string.format("%2d", e.level or 0)
      term.write(rank.."   "..string.format("%-"..MAX_NAME_LEN.."s", name).."  "..score.."  "..lv)
    else
      term.write(string.format("%2d   %-"..MAX_NAME_LEN.."s  %7s  %2s", i, string.rep("-", MAX_NAME_LEN), "-------", "--"))
    end
  end
  term.setTextColor(colors.lightGray)
  local hint = "Press Q to return"
  term.setCursorPos(math.floor((w-#hint)/2)+1, top+15)
  term.write(hint)
  term.setTextColor(colors.white)
  endFrame()
  while true do
    local ev,a = os.pullEvent()
    if ev=="key" then
      if a==keys.q then break end
    elseif ev=="timer" then
      music:onTimer(a, true)
    elseif ev=="term_resize" then
      handleResize(function()
        recalcLayout()
        drawNESLeaderboard()
      end)
      return
    end
  end
end

local function drawCellOnTerm(fx, fy, id, level)
  local cx = startX + (fx-1)*cellW
  local cy = startY + (fy-1)
  term.setCursorPos(cx, cy)
  local colorVal = nil
  if type(id) == "string" then colorVal = getPieceColor(id, level) elseif type(id) == "number" and id ~= 0 then colorVal = id end
  if not colorVal or colorVal == 0 then term.setBackgroundColor(bgColor); term.write(string.rep(" ", cellW))
  else term.setBackgroundColor(colorVal); term.write(string.rep(" ", cellW)) end
  term.setBackgroundColor(bgColor)
end

local function getShapeBounds(shape)
  local minR, maxR, minC, maxC = nil, nil, nil, nil
  for r=1,#shape do
    for c=1,#shape[r] do
      if shape[r][c] == 1 then
        if not minR or r < minR then minR = r end
        if not maxR or r > maxR then maxR = r end
        if not minC or c < minC then minC = c end
        if not maxC or c > maxC then maxC = c end
      end
    end
  end
  if not minR then return 1,0,1,0 end
  return minR, maxR, minC, maxC
end

local function drawField(gs)
  for y=1,fieldH do for x=1,fieldW do local cell = gs.field[y][x]; drawCellOnTerm(x,y,cell,gs.level) end end
  for y=1,fieldH do term.setBackgroundColor(bgColor); term.setTextColor(fgColor); term.setCursorPos(startX-1,startY+y-1); term.write("|"); term.setCursorPos(startX+fieldW*cellW,startY+y-1); term.write("|") end
  local topLine = string.rep("-", fieldW*cellW)
  term.setCursorPos(startX, startY-1); term.write(topLine)
  term.setCursorPos(startX, startY+fieldH); term.write(topLine)
  term.setBackgroundColor(bgColor); term.setTextColor(fgColor)
end

local function drawInfo(gs)
  beginFrame()
  term.setBackgroundColor(bgColor)
  term.setTextColor(fgColor)
  local infoX = startX + fieldW*cellW + 3
  local infoY = startY
  term.setCursorPos(infoX, infoY+1);     term.write("Lines: "..gs.linesCleared.." ")
  term.setCursorPos(infoX, infoY+2);     term.write("Score: "..gs.score.." ")
  local boxCells = 4
  local previewX = infoX
  local previewY = infoY+5
  local nextText = "NEXT"
  local textX = previewX + math.floor((boxCells*cellW - string.len(nextText)) / 2)
  term.setCursorPos(textX, previewY-2); term.write(nextText)
  term.setCursorPos(previewX-1, previewY-1); term.write("+"..string.rep("-", boxCells*cellW).."+" )
  for ry=1,boxCells do
    term.setCursorPos(previewX-1, previewY+ry-1); term.write("|")
    term.setCursorPos(previewX, previewY+ry-1); term.write(string.rep(" ", boxCells*cellW))
    term.setCursorPos(previewX+boxCells*cellW, previewY+ry-1); term.write("|")
  end
  term.setCursorPos(previewX-1, previewY+boxCells); term.write("+"..string.rep("-", boxCells*cellW).."+" )
  term.setBackgroundColor(bgColor)
  if gs.nextPiece then
    local shape = gs.nextPiece.shapeList[gs.nextPiece.rot] or gs.nextPiece.shape
    local minR,maxR,minC,maxC = getShapeBounds(shape)
    local rows = (maxR - minR + 1)
    local cols = (maxC - minC + 1)
    local offsetX = math.floor((boxCells - cols)/2)
    local offsetY = math.floor((boxCells - rows)/2)
    for r=minR,maxR do
      for c=minC,maxC do
        if shape[r][c] == 1 then
          local cellCol = previewX + (offsetX + (c - minC))*cellW
          local cellRow = previewY + offsetY + (r - minR)
          term.setCursorPos(cellCol, cellRow)
          term.setBackgroundColor(getPieceColor(gs.nextPiece.id, gs.level))
          term.write(string.rep(" ", cellW))
          term.setBackgroundColor(bgColor)
        end
      end
    end
  end
  term.setTextColor(colors.lightGray)
  term.setCursorPos(previewX, previewY + boxCells + 1); term.write("P - Pause")
  term.setTextColor(fgColor)
  term.setCursorPos(previewX, previewY + boxCells + 2); term.write("Level: "..gs.level.." ")
  endFrame()
end

local function getGhostY(gs)
  local gy = gs.current.y
  while true do
    local function collides_local(px, py, shape)
      for sy=1,#shape do
        for sx=1,#shape[sy] do
          if shape[sy][sx] == 1 then
            local fx = px + sx
            local fy = py + sy - 1
            if fx < 1 or fx > fieldW or fy > fieldH then return true end
            if fy >= 1 and gs.field[fy][fx] ~= 0 then return true end
          end
        end
      end
      return false
    end
    if collides_local(gs.current.x, gy+1, gs.current.shape) then break end
    gy = gy + 1
    if gy > fieldH then break end
  end
  return gy
end

local function drawGhost(gs)
  local gy = getGhostY(gs)
  term.setTextColor(colors.lightGray)
  term.setBackgroundColor(bgColor)
  for sy=1,#gs.current.shape do
    for sx=1,#gs.current.shape[sy] do
      if gs.current.shape[sy][sx] == 1 then
        local fx = gs.current.x + sx
        local fy = gy + sy - 1
        if fy>=1 and fy<=fieldH and fx>=1 and fx<=fieldW and gs.field[fy][fx] == 0 then
          local cx = startX + (fx-1)*cellW
          term.setCursorPos(cx, startY + (fy-1))
          term.write("[]")
        end
      end
    end
  end
  term.setTextColor(fgColor); term.setBackgroundColor(bgColor)
end

local function newGameState()
  local gs = {}
  gs.field = {}
  for y=1,fieldH do gs.field[y] = {} for x=1,fieldW do gs.field[y][x] = 0 end end
  gs.bag = {}
  for i=1,#order do gs.bag[i] = order[i] end
  shuffle(gs.bag)
  gs.score = 0
  gs.linesCleared = 0
  gs.startLevelBase = math.max(0, math.floor(settings.startLevel or 0))
  gs.level = gs.startLevelBase
  gs.gravityTimerId = nil
  gs.gravityLastClock = os.clock()
  gs.gravityAccum = 0
  gs.lockTimerId = nil
  gs.paused = false
  gs.isLocking = false
  gs.current = nil
  gs.nextPiece = nil
  return gs
end

local function refillBagFromState(gs)
  if #gs.bag == 0 then
    for i=1,#order do gs.bag[i] = order[i] end
    shuffle(gs.bag)
  end
end
local function takeFromBag(gs) refillBagFromState(gs); return table.remove(gs.bag) end
local function getShapeList(id) return pieces[id] end

local function collides(gs, px, py, shape)
  for sy=1,#shape do
    for sx=1,#shape[sy] do
      if shape[sy][sx] == 1 then
        local fx = px + sx
        local fy = py + sy - 1
        if fx < 1 or fx > fieldW or fy > fieldH then return true end
        if fy >= 1 and gs.field[fy][fx] ~= 0 then return true end
      end
    end
  end
  return false
end

local function placePiece(gs, px, py, shape, id)
  for sy=1,#shape do
    for sx=1,#shape[sy] do
      if shape[sy][sx] == 1 then
        local fx = px + sx
        local fy = py + sy - 1
        if fy >= 1 and fy <= fieldH and fx >= 1 and fx <= fieldW then
          gs.field[fy][fx] = id
        end
      end
    end
  end
end

local NES_LINE_POINTS = { [1]=40, [2]=100, [3]=300, [4]=1200 }

local function clearLines(gs)
  local newField = {}
  for y=1,fieldH do newField[y] = {} end
  local writeRow = fieldH
  local removed = 0
  for y=fieldH,1,-1 do
    local full = true
    for x=1,fieldW do if gs.field[y][x] == 0 then full = false break end end
    if full then
      removed = removed + 1
    else
      newField[writeRow] = {}
      for x=1,fieldW do newField[writeRow][x] = gs.field[y][x] end
      writeRow = writeRow - 1
    end
  end
  for y=1,writeRow do newField[y] = {} for x=1,fieldW do newField[y][x] = 0 end end
  gs.field = newField
  if removed > 0 then
    gs.linesCleared = gs.linesCleared + removed
    local base = NES_LINE_POINTS[removed] or 0
    gs.score = gs.score + base * (gs.level + 1)
    gs.level = nes_current_level(gs.startLevelBase, gs.linesCleared)
  end
end

local GRAVITY_TICK = 0.05
local function gravityReset(gs)
  gs.gravityLastClock = os.clock()
  gs.gravityAccum = 0
end
local function gravityArm(gs)
  gs.gravityTimerId = os.startTimer(GRAVITY_TICK)
end
local function gravityStart(gs)
  gravityReset(gs)
  gravityArm(gs)
end

local function spawnPiece(gs)
  gs.current = gs.nextPiece or (function()
    local id = takeFromBag(gs)
    local shapeList = getShapeList(id)
    return { id = id, shapeList = shapeList, rot = 1, shape = shapeList[1], x = math.floor(fieldW/2)-1, y = 1 }
  end)()
  gs.nextPiece = (function()
    local id = takeFromBag(gs)
    local shapeList = getShapeList(id)
    return { id = id, shapeList = shapeList, rot = 1, shape = shapeList[1] }
  end)()
  gs.current.x = math.floor(fieldW/2)-1
  gs.current.y = 1
  gs.current.shape = gs.current.shapeList[gs.current.rot]
  for sy=1,#gs.current.shape do
    for sx=1,#gs.current.shape[sy] do
      if gs.current.shape[sy][sx] == 1 then
        local fx = gs.current.x + sx
        local fy = gs.current.y + sy - 1
        if fy >=1 and fx>=1 and fx<=fieldW and gs.field[fy][fx] ~= 0 then return false end
        if fx < 1 or fx > fieldW then return false end
      end
    end
  end
  gravityReset(gs)
  return true
end

local function drawCurrent(gs)
  for sy=1,#gs.current.shape do
    for sx=1,#gs.current.shape[sy] do
      if gs.current.shape[sy][sx] == 1 then
        local fx = gs.current.x + sx; local fy = gs.current.y + sy - 1
        if fy>=1 and fy<=fieldH and fx>=1 and fx<=fieldW then drawCellOnTerm(fx, fy, gs.current.id, gs.level) end
      end
    end
  end
end

local function redrawAll(gs)
  beginFrame()
  term.setBackgroundColor(bgColor); term.clear()
  drawField(gs)
  drawGhost(gs)
  drawCurrent(gs)
  drawInfo(gs)
  endFrame()
end

local function getActionForKey(k)
  if settings and settings.rebinds then
    if k == settings.rebinds.rotate_cw then return "rotate" end
    if k == settings.rebinds.rotate_ccw then return "rotate_ccw" end
    if k == settings.rebinds.rotate_180 then return "rotate180" end
    if k == settings.rebinds.left then return "left" end
    if k == settings.rebinds.right then return "right" end
    if k == settings.rebinds.down then return "down" end
    if k == settings.rebinds.drop then return "drop" end
    if k == settings.rebinds.pause then return "pause" end
  end
  if k == keys.up then return "rotate" end
  if k == keys.enter or k == keys.space then return "drop" end
  if k == string.byte('p') or k == string.byte('P') then return "pause" end
  return nil
end

local function tryRotateNES(gs, targetRot)
  local lst = gs.current.shapeList
  local cnt = #lst
  if cnt <= 1 then return false end
  if targetRot < 1 then targetRot = cnt end
  if targetRot > cnt then targetRot = 1 end
  local targetShape = lst[targetRot]
  if not collides(gs, gs.current.x, gs.current.y, targetShape) then
    gs.current.rot = targetRot
    gs.current.shape = targetShape
    gs.isLocking = false
    gs.lockTimerId = nil
    return true
  end
  return false
end

local function settingsMenu()
  local opts = {
    {label="Music Volume: ", type="number", key="musicVolume", min=0, max=100, step=1},
    {label="Start Level: ", type="number", key="startLevel", min=0, max=9, step=1},
    {label="Music: ", type="enum", key="music", vals={"A","B","C","Off"}},
    {label="Menu Music: ", type="enum", key="menuMusic", vals={"On","Off"}},
    {label="Left Key: ", type="key", key="left"},
    {label="Right Key: ", type="key", key="right"},
    {label="Down Key: ", type="key", key="down"},
    {label="Drop Key: ", type="key", key="drop"},
    {label="Rotate CW: ", type="key", key="rotate_cw"},
    {label="Rotate CCW: ", type="key", key="rotate_ccw"},
    {label="Rotate 180: ", type="key", key="rotate_180"},
    {label="Pause Key: ", type="key", key="pause"},
    {label="", type="action", key="back"}
  }
  local sel = 1
  local function draw()
    beginFrame()
    term.setBackgroundColor(bgColor); term.clear()
    term.setTextColor(colors.white)
    local title = "SETTINGS"
    term.setCursorPos(math.floor((w - #title)/2)+1, 2); term.write(title)
    local sx = math.floor((w - 40)/2)+1
    local startLine = 4
    term.setTextColor(colors.lightGray)
    local hint = "Left - Backwards, Right - Forwards. "
    term.setCursorPos(math.floor((w - #hint)/2)+1, 3); term.write(hint)
    for i=1,#opts do
      local o = opts[i]
      local label = o.label..""
      local valueText = ""
      if o.type=="number" then valueText = tostring(settings[o.key])
      elseif o.type=="enum" then valueText = tostring(settings[o.key])
      elseif o.type=="key" then valueText = keyName(settings.rebinds[o.key])
      elseif o.type=="action" then valueText = "Back" end
      term.setCursorPos(sx, startLine + i - 1)
      if i==sel then term.setTextColor(colors.white) else term.setTextColor(colors.lightGray) end
      term.write(label..valueText)
    end
    term.setTextColor(fgColor)
    endFrame()
  end
  local function changeNumber(o, dir)
    local change = (dir==1) and o.step or -o.step
    settings[o.key] = math.max(o.min, math.min(o.max, (settings[o.key] or o.min) + change))
    safeSaveSettings(settings)
  end
  local function changeEnum(o, dir)
    local vals = o.vals
    local idx = 1
    for i,v in ipairs(vals) do if v == settings[o.key] then idx = i end end
    if dir==1 then idx = (idx) % #vals + 1 else idx = (idx-2) % #vals + 1 end
    settings[o.key] = vals[idx]
    safeSaveSettings(settings)
    if o.key=="menuMusic" then
      if settings.menuMusic == "Off" then
        music:stop()
      else
        music:stop()
        music:setSpeedMul(1.0)
        music:resetPosition()
        music:playScore(true)
      end
    end
  end
  draw()
  while true do
    local ev,a = os.pullEvent()
    if ev=="key" then
      if a==keys.up then sel = (sel-2) % #opts + 1; draw()
      elseif a==keys.down then sel = (sel) % #opts + 1; draw()
      elseif a==keys.left or a==keys.right or a==keys.enter or a==keys.leftShift or a==keys.rightShift then
        local o = opts[sel]
        local isForward = (a==keys.right or a==keys.enter)
        local isBackward = (a==keys.left or a==keys.leftShift or a==keys.rightShift)
        if o.type=="number" then
          if isForward then changeNumber(o, 1) elseif isBackward then changeNumber(o, -1) end
          draw()
        elseif o.type=="enum" then
          if isForward then changeEnum(o, 1) elseif isBackward then changeEnum(o, -1) end
          draw()
        elseif o.type=="action" and o.key=="back" and a==keys.enter then
          break
        elseif o.type=="key" and a==keys.enter then
          beginFrame()
          term.setBackgroundColor(bgColor); term.setTextColor(colors.white)
          local prompt = "Press new key for "..o.label
          term.setCursorPos(math.floor((w - string.len(prompt))/2)+1, h-2); term.write(prompt)
          endFrame()
          while true do
            local ev2,k2 = os.pullEvent()
            if ev2=="key" then
              settings.rebinds[o.key] = k2
              safeSaveSettings(settings)
              break
            elseif ev2=="mouse_click" then
              break
            elseif ev2=="timer" then
              music:onTimer(k2, true)
            elseif ev2=="term_resize" then
              handleResize(function() recalcLayout(); draw() end)
            end
          end
          draw()
        end
      elseif a==keys.backspace or a==keys.delete then
        break
      end
    elseif ev=="timer" then
      music:onTimer(a, true)
    elseif ev=="term_resize" then
      handleResize(function() recalcLayout(); draw() end)
    end
  end
end

local function pauseMenu()
  local opts = {"Continue","Top Scores","Settings","Exit"}
  local sel = 1
  local function draw()
    beginFrame()
    term.setBackgroundColor(bgColor); term.clear()
    term.setTextColor(colors.white)
    local title = "PAUSED"
    term.setCursorPos(math.floor((w - #title)/2)+1, math.floor(h/2)-3); term.write(title)
    for i=1,#opts do
      local txt = opts[i]
      local display = txt
      local color = (i==sel) and colors.white or colors.lightGray
      term.setTextColor(color)
      term.setCursorPos(math.floor((w - #display)/2)+1, math.floor(h/2)-1 + i)
      term.write(display)
    end
    term.setTextColor(fgColor)
    endFrame()
  end
  draw()
  while true do
    local ev,a = os.pullEvent()
    if ev=="key" then
      if a==keys.up then sel = (sel-2)%#opts + 1; draw()
      elseif a==keys.down then sel = (sel)%#opts + 1; draw()
      elseif a==keys.enter then return opts[sel]
      elseif a==settings.rebinds.pause or a==keys.p then return "Continue" end
    elseif ev=="timer" then
      music:onTimer(a, true)
    elseif ev=="term_resize" then
      handleResize(function() recalcLayout(); draw() end)
    end
  end
end

local function startNewGameFromState(gs)
  for y=1,fieldH do gs.field[y] = {} for x=1,fieldW do gs.field[y][x] = 0 end end
  gs.bag = {}; for i=1,#order do gs.bag[i] = order[i] end; shuffle(gs.bag)
  gs.score = 0
  gs.linesCleared = 0
  gs.startLevelBase = math.max(0, math.floor(settings.startLevel or 0))
  gs.level = gs.startLevelBase
  gs.current = nil
  gs.nextPiece = nil
  gs.gravityTimerId = nil
  gs.lockTimerId = nil
  gs.paused = false
  gs.isLocking = false
  spawnPiece(gs)
  gravityStart(gs)
  music:setOption(settings.music or "A")
  music:setSpeedMul(1.0)
  music:resetPosition()
  if (settings.music or "A") ~= "Off" then music:playGame() end
end

local function gameLoop()
  local gs = newGameState()
  startNewGameFromState(gs)
  redrawAll(gs)
  while true do
    local ev,a,b = os.pullEvent()
    if ev=="key" then
      local action = getActionForKey(a)
      if action=="left" then
        if not collides(gs, gs.current.x-1, gs.current.y, gs.current.shape) then
          gs.current.x = gs.current.x - 1; gs.isLocking = false; gs.lockTimerId = nil
        end
        redrawAll(gs)
      elseif action=="right" then
        if not collides(gs, gs.current.x+1, gs.current.y, gs.current.shape) then
          gs.current.x = gs.current.x + 1; gs.isLocking = false; gs.lockTimerId = nil
        end
        redrawAll(gs)
      elseif action=="down" then
        if not collides(gs, gs.current.x, gs.current.y+1, gs.current.shape) then
          gs.current.y = gs.current.y + 1
          gs.score = gs.score + 1
          gs.isLocking = false; gs.lockTimerId = nil
          redrawAll(gs)
          gravityReset(gs)
        else
          if not gs.isLocking then gs.lockTimerId = os.startTimer(0.5); gs.isLocking = true end
        end
      elseif action=="rotate" or action=="rotate_ccw" or action=="rotate180" then
        local cnt = #gs.current.shapeList
        if cnt > 1 then
          if action=="rotate" then
            local targetRot = gs.current.rot % cnt + 1
            tryRotateNES(gs, targetRot)
          elseif action=="rotate_ccw" then
            local targetRot = gs.current.rot - 1; if targetRot < 1 then targetRot = cnt end
            tryRotateNES(gs, targetRot)
          else
            local targetRot = ((gs.current.rot - 1 + 2) % cnt) + 1
            tryRotateNES(gs, targetRot)
          end
        end
        redrawAll(gs)
      elseif action=="drop" then
        local moved = 0
        while not collides(gs, gs.current.x, gs.current.y+1, gs.current.shape) do
          gs.current.y = gs.current.y + 1; moved = moved + 1
        end
        if moved > 0 then gs.score = gs.score + 2*moved end
        placePiece(gs, gs.current.x, gs.current.y, gs.current.shape, gs.current.id)
        clearLines(gs)
        if not spawnPiece(gs) then break end
        gs.isLocking = false; gs.lockTimerId = nil
        redrawAll(gs)
        gravityReset(gs)
      elseif action=="pause" then
        gs.paused = true
        local savedTick = music.tick
        local savedOpt = music.current
        music:stop()
        music:setSpeedMul(1.0)
        music:resetPosition()
        if settings.menuMusic ~= "Off" then music:playScore(true) end
        while true do
          local choice = pauseMenu()
          if choice == "Continue" then
            gs.paused = false
            gs.lockTimerId = nil
            gs.isLocking = false
            if collides(gs, gs.current.x, gs.current.y+1, gs.current.shape) then
              gs.lockTimerId = os.startTimer(0.5)
              gs.isLocking = true
            end
            gravityReset(gs)
            gravityArm(gs)
            music:stop()
            music.current = settings.music or savedOpt
            if (settings.music or "A") ~= "Off" then
              music.tick = savedTick or 0
              music:playGame()
            end
            redrawAll(gs)
            break
          elseif choice == "Settings" then
            settingsMenu()
            settings = safeLoadSettings()
            redrawAll(gs)
          elseif choice == "Top Scores" then
            drawNESLeaderboard()
            redrawAll(gs)
          elseif choice == "Exit" then
            music:stop()
            safeSaveSettings(settings)
            return false, gs.score, gs.linesCleared, gs.level, gs.startLevelBase
          end
        end
      end
    elseif ev=="timer" then
      if a == gs.gravityTimerId then
        gs.gravityTimerId = nil
        local now = os.clock()
        local dt = now - (gs.gravityLastClock or now)
        gs.gravityLastClock = now
        if not gs.paused then
          gs.gravityAccum = (gs.gravityAccum or 0) + dt
          local spc = nes_seconds_per_cell(gs.level)
          local steps = 0
          if spc > 0 then steps = math.floor(gs.gravityAccum / spc) end
          if steps > 0 then
            gs.gravityAccum = gs.gravityAccum - steps * spc
            if steps > 20 then steps = 20 end
            local needRedraw = false
            for i=1,steps do
              if not collides(gs, gs.current.x, gs.current.y+1, gs.current.shape) then
                gs.current.y = gs.current.y + 1
                gs.isLocking = false
                gs.lockTimerId = nil
                needRedraw = true
              else
                if not gs.isLocking then
                  gs.lockTimerId = os.startTimer(0.5)
                  gs.isLocking = true
                end
                break
              end
            end
            if needRedraw then redrawAll(gs) end
          end
        else
          gravityReset(gs)
        end
        gravityArm(gs)
      elseif a == gs.lockTimerId then
        gs.lockTimerId = nil
        if not gs.paused then
          placePiece(gs, gs.current.x, gs.current.y, gs.current.shape, gs.current.id)
          clearLines(gs)
          if not spawnPiece(gs) then break end
          gs.isLocking = false
          redrawAll(gs)
          gravityReset(gs)
        else
          gs.isLocking = false
        end
      else
        music:onTimer(a, gs.paused)
      end
      local danger = false
      do
        for y=1,5 do
          local filled = false
          for x=1,fieldW do if gs.field[y][x] ~= 0 then filled = true break end end
          if filled then danger = true break end
        end
      end
      if not gs.paused then
        if danger then music:setSpeedMul(1.5) else music:setSpeedMul(1.0) end
      end
    elseif ev=="term_resize" then
      handleResize(function()
        recalcLayout()
        redrawAll(gs)
      end)
    end
  end
  return true, gs.score, gs.linesCleared, gs.level, gs.startLevelBase
end

local function promptNameNES()
  local function drawPrompt(s)
    beginFrame()
    term.setTextColor(colors.white)
    local prompt = "Enter name (0-"..MAX_NAME_LEN.." chars), ENTER to confirm:"
    local w2,h2 = w,h
    local px = math.floor((w2 - #prompt)/2)+1
    local py = math.floor(h2/2)+1
    term.setBackgroundColor(bgColor); term.clear()
    term.setCursorPos(px, py-4); term.write(prompt)
    term.setCursorPos(px, py-2); term.write(">")
    term.setCursorPos(px+2, py-2)
    term.write(string.rep("", MAX_NAME_LEN))
    term.setCursorPos(px+2, py-2)
    term.write(s or "")
    endFrame()
    return px, py
  end
  term.setCursorBlink(true)
  local s = ""
  local px, py = drawPrompt(s)
  while true do
    local ev,a = os.pullEvent()
    if ev=="char" then
      if #s < MAX_NAME_LEN then
        local ch = string.upper(a or "")
        if ch:match("[A-Z0-9%- ]") then
          s = s .. ch
          px, py = drawPrompt(s)
          term.setCursorPos(px+2 + #s, py-2)
        end
      end
    elseif ev=="key" then
      if a == keys.enter then
        term.setCursorBlink(false)
        return s
      elseif a == keys.backspace then
        if #s > 0 then
          s = s:sub(1, -2)
          px, py = drawPrompt(s)
          term.setCursorPos(px+2 + #s, py-2)
        end
      end
    elseif ev=="timer" then
      music:onTimer(a, true)
    elseif ev=="term_resize" then
      handleResize(function()
        recalcLayout()
        px, py = drawPrompt(s)
      end)
    end
  end
end

local function gameOverScreen(score, lines, level, startLevel)
  beginFrame()
  term.setBackgroundColor(colors.black); term.clear()
  local w2,h2 = w,h
  local midY = math.floor(h2/2)
  music:stop(); music:setSpeedMul(1.0); music:resetPosition(); if settings.menuMusic ~= "Off" then music:playScore(true) end
  local function centerX(s) return math.floor((w2 - string.len(s))/2)+1 end
  term.setCursorPos(centerX("GAME OVER! Score: "..score), midY-3)
  term.setTextColor(colors.white); term.write("GAME OVER! Score: "..score)
  term.setCursorPos(centerX("Lines: "..lines.."   Level: "..level), midY-2)
  term.write("Lines: "..lines.."   Level: "..level)
  endFrame()
  local name = promptNameNES()
  insertLocalEntry(name, score, level)
  beginFrame()
  term.setCursorPos(centerX("Saved to local top scores"), midY+4)
  term.setTextColor(colors.lightGray); term.write("Saved to local top scores")
  term.setCursorPos(centerX("Press ENTER to play again, any other key to exit"), midY+6)
  term.setTextColor(colors.white); term.write("Press ENTER to play again, any other key to exit")
  endFrame()
  while true do
    local ev, a = os.pullEvent()
    if ev=="key" then
      music:stop()
      if a == keys.enter then return true else return false end
    elseif ev=="timer" then
      music:onTimer(a, true)
    elseif ev=="term_resize" then
      handleResize(function()
        recalcLayout()
        beginFrame()
        term.setBackgroundColor(colors.black); term.clear()
        w2,h2 = w,h
        midY = math.floor(h2/2)
        term.setCursorPos(centerX("Saved to local top scores"), midY+4)
        term.setTextColor(colors.lightGray); term.write("Saved to local top scores")
        term.setCursorPos(centerX("Press ENTER to play again, any other key to exit"), midY+6)
        term.setTextColor(colors.white); term.write("Press ENTER to play again, any other key to exit")
        endFrame()
      end)
    end
  end
end

while true do
  local ok, score, lines, level, startLevel = gameLoop()
  if not ok then break end
  music:stop()
  local again = gameOverScreen(score, lines or 0, level or 0, startLevel or 0)
  if not again then break end
  settings = safeLoadSettings()
end

music:stop()
beginFrame()
term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1)
endFrame()


