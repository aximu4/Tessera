if not fs.exists("Tessera") then
    fs.makeDir("Tessera")
end

local musicFiles = {"music-a.nbs", "music-b.nbs", "music-c.nbs", "score.nbs"}

local baseUrl = "https://raw.githubusercontent.com/aximu4/Tessera/main/Tessera/"

print("Downloading Tessera.lua...")
local successMain = shell.run("wget", "https://raw.githubusercontent.com/aximu4/Tessera/main/Tessera.lua", "Tessera.lua")
if not successMain then
    print("Couldn't install Tessera.lua! Please check your internet connection.")
    return
end

for _, file in ipairs(musicFiles) do
    print("Downloading " .. file .. "...")
    local success = shell.run("wget", baseUrl .. file, "Tessera/" .. file)
    if not success then
        print("Couldn't download " .. file .. ". Please try again later.")
    end
end

print("Tessera successfully installed!")
print("Run 'Tessera' to play.")
