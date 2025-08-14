local repo = "aximu4/Tessera"
local rawBase = "https://raw.githubusercontent.com/" .. repo .. "/main/"

shell.run("wget", rawBase .. "Tessera.lua", "Tessera.lua")

if not fs.exists("Tessera") then
  fs.makeDir("Tessera")
end

local files = {"music-a.nbs", "music-b.nbs", "music-c.nbs", "score.nbs"}

local baseUrl = "https://raw.githubusercontent.com/aximu4/Tessera/main/Tessera/"

for _, fname in ipairs(files) do
  local success = shell.run("wget", baseUrl .. fname, "Tessera/" .. fname)
  if not success then
    print("Couldn't install " .. fname)
  end
end


print("Tessera successfully installed! Run 'Tessera' to play.")
