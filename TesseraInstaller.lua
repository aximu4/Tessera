
local http = http
local urlBase = "https://raw.githubusercontent.com/aximu4/Tessera/main/"

local files = {
    "Tessera.lua",
    "Tessera/music-a.nbs",
    "Tessera/music-b.nbs",
    "Tessera/music-c.nbs",
    "Tessera/score.nbs",
}

if not fs.exists("Tessera") then
    fs.makeDir("Tessera")
end

local function download(file)
    local url = urlBase .. file
    print("Downloading " .. file .. "...")
    local response = http.get(url)
    if response then
        local path = file
        local dirs = {}
        
        for dir in string.gmatch(path, "([^/]+)/") do
            table.insert(dirs, dir)
        end
        local current = ""
        for _, d in ipairs(dirs) do
            current = current .. d .. "/"
            if not fs.exists(current) then
                fs.makeDir(current)
            end
        end

        local f = fs.open(path, "w")
        f.write(response.readAll())
        f.close()
        response.close()
    else
        print("Couldn't install" .. file)
    end
end

for _, file in ipairs(files) do
    download(file)
end

print("Tessera successfully installed! Run 'Tessera' to play.")
