-- music_player.lua
local speakerSide = "right"  -- Changez cela si votre haut-parleur est sur un autre côté.

-- Charger la configuration
local configPath = "/packages/Advenced-music/config.lua"  -- Chemin vers le fichier de configuration
local config
local success, err = pcall(function()
    config = dofile(configPath)  -- Charger la configuration
end)

if not success then
    print("Erreur lors du chargement du fichier de configuration : " .. err)
    return
end

if not peripheral.find("speaker") then
    print("Aucun périphérique 'speaker' trouvé.")
    return
end

-- Fonction pour lister les musiques disponibles sur le serveur
local function listMusic(server)
    print("Récupération des musiques depuis " .. server.name .. "...")
    local response = http.get(server.url .. "/list")
    if not response then
        print("Erreur : impossible de se connecter au serveur " .. server.name)
        return {}
    end
    local data = response.readAll()
    response.close()
    return textutils.unserializeJSON(data) or {}
end

-- Fonction pour jouer la musique
local function playMusic(server, music)
    local url = server.url .. "/music/" .. music
    print("URL de la musique : " .. url)
    local success, result = pcall(function()
        shell.run("speaker", "play", url)  -- Joue la musique via le speaker
    end)
    if not success then
        print("Erreur lors de la lecture de la musique : " .. result)
    end
end

-- Fonction pour sélectionner un serveur
local function selectServer()
    print("Choisissez un serveur :")
    for i, server in ipairs(config.servers) do
        print(i .. ". " .. server.name)
    end

    local choice = tonumber(read())
    if choice and config.servers[choice] then
        return config.servers[choice]
    else
        print("Choix invalide.")
        return nil
    end
end

-- Fonction pour sélectionner une musique parmi celles disponibles
local function selectMusic(server)
    local musics = listMusic(server)
    if #musics == 0 then
        print("Aucune musique disponible sur " .. server.name)
        return nil
    end

    print("Liste des musiques sur " .. server.name .. ":")
    for i, music in ipairs(musics) do
        print(i .. ". " .. music)
    end

    local choice = tonumber(read())
    if choice and musics[choice] then
        return musics[choice]
    else
        print("Choix invalide.")
        return nil
    end
end

-- Fonction principale du programme
local function main()
    while true do
        local server = selectServer()
        if not server then break end

        local music = selectMusic(server)
        if music then
            print("Lecture de : " .. music .. " depuis " .. server.name)
            playMusic(server, music)
        end
    end
end

-- Exécution du programme
main()