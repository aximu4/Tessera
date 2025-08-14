local repo = "aximu4/Tessera"
local rawBase = "https://raw.githubusercontent.com/" .. repo .. "/main/"

shell.run("wget", rawBase .. "Tessera.lua", "Tessera.lua")


shell.run("mkdir", "Tessera")
local files = {"music-a.nbs", "music-b.nbs", "music-c.nbs", "score.nbs"}
for _, fname in ipairs(files) do
  local url = rawBase .. "Tessera/" .. fname
  shell.run("wget", url, "Tessera/" .. fname)
end

print("Tessera successfully installed! Run 'Tessera' to play.")
