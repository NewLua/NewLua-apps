term.setBackgroundColor(colors.black)

local SHELL_NAME = "AdvShell"
local PROMPT_CHAR = ">"
local LOG_FILE = """

-- Couleurs
local colors = {
    prompt = colors.yellow,
    text = colors.white,
    error = colors.red,
    success = colors.green,
    path = colors.lightBlue
}

-- Variables globales
local currentPath = ""
local history = {}

-- Charger l'API Shell

-- Rendre handleCommand global
_G.handleCommand = handleCommand

--------------------------------------------------

-- Table des commandes avec leur chemin
local shellCommands = {
    clear = true, 
    cd = true, 
    reboot = true, 
    pkg = true, 
    mkdir = true, 
    cp = true, 
    rm = true, 
    edit = true, 
    nano = true, 
    paint = true, 
    help = true, 
    ls = true, 
    dir = true, 
    reload = true, 
    music = true, 
    pwd = true
}

-- Commandes qui acceptent des chemins comme arguments
local pathCommands = {
    cd = true,
    edit = true,
    nano = true,
    rm = true,
    cp = true,
    ls = true,
    dir = true,
    paint = true
}

-- Obtenir la liste des programmes dans le dossier actuel
local function getCurrentDirPrograms()
    local programs = {}
    local files = fs.list(currentPath)
    
    for _, item in ipairs(files) do
        if item:match("%.lua$") then
            programs[item:sub(1, -5)] = item -- Stocker le nom complet comme valeur
        end
    end
    
    return programs
end

-- Obtenir tous les fichiers/dossiers dans un chemin
local function getFilesInPath(path, includeFiles, includeDirs)
    local results = {}
    if not fs.exists(path) then return results end
    
    for _, item in ipairs(fs.list(path)) do
        local fullPath = fs.combine(path, item)
        local isDir = fs.isDir(fullPath)
        
        if (isDir and includeDirs) or (not isDir and includeFiles) then
            table.insert(results, item .. (isDir and "/" or ""))
        end
    end
    return results
end

-- Fonction principale de complétion
local function customComplete(line)
    if line == "" then
        return nil
    end

    local words = {}
    for word in string.gmatch(line, "%S+") do
        table.insert(words, word)
    end
    
    if line:match("%s$") then
        table.insert(words, "")
    end
    
    if #words == 1 then
        local partial = words[1]
        local suggestions = {}
        
        -- Vérifier les commandes internes
        for cmd in pairs(shellCommands) do
            if cmd:sub(1, #partial) == partial then
                table.insert(suggestions, cmd:sub(#partial + 1))
            end
        end
        
        -- Vérifier les programmes dans le dossier actuel
        local programs = getCurrentDirPrograms()
        for name, fullName in pairs(programs) do
            if name:sub(1, #partial) == partial then
                -- Ajouter la partie manquante avec .lua
                table.insert(suggestions, fullName:sub(#partial + 1))
            end
        end
        
        if #suggestions > 0 then
            table.sort(suggestions)
            return suggestions
        end
    end
    
    if #words > 1 then
        local cmd = words[1]
        if pathCommands[cmd] then
            local lastWord = words[#words]
            
            local path, name = "", lastWord
            local lastSlash = lastWord:match("(.*/)")
            if lastSlash then
                path = lastSlash
                name = lastWord:sub(#lastSlash + 1)
            end
            
            local fullPath = path
            if path:sub(1,1) ~= "/" then
                fullPath = fs.combine(currentPath, path)
            end
            
            local suggestions = {}
            local items = getFilesInPath(fullPath, true, true)
            
            for _, item in ipairs(items) do
                if item:sub(1, #name) == name then
                    table.insert(suggestions, item:sub(#name + 1))
                end
            end
            
            if #suggestions > 0 then
                if #suggestions == 1 and not suggestions[1]:match("/$") then
                    suggestions[1] = suggestions[1] .. " "
                end
                return suggestions
            end
        end
    end
    
    return nil
end

--------------------------------------------------

-- Fonction pour écrire dans le log
local function writeLog(message)
    local file = fs.open(LOG_FILE, "a")
    if file then
        file.write(os.date("[%Y-%m-%d %H:%M:%S] ") .. message .. "\n")
        file.close()
    end
end

-- Fonction pour résoudre le chemin complet
local function resolvePath(path)
    if path:sub(1,1) == "/" then
        return path
    else
        return fs.combine(currentPath, path)
    end
end

-- Afficher le prompt
local function displayPrompt()
    term.setTextColor(colors.prompt)
    write(SHELL_NAME .. "/" .. currentPath .. PROMPT_CHAR)
    term.setTextColor(colors.text)
end

-- Gérer les processus
local processes = {}
local processId = 0

local function startProcess(commandLine)
    processId = processId + 1
    local process = {}
    process.id = processId
    process.command = commandLine
    process.thread = coroutine.create(function() 
        shell.run(commandLine)
    end)
    table.insert(processes, process)
    return process
end


local function resumeProcess(processId)
    for i,p in ipairs(processes) do
        if p.id == tonumber(processId) then
            term.setBackgroundColor(colors.black)
            term.clear()
            term.setCursorPos(1,1)
            local result, error = coroutine.resume(p.thread)  
            if coroutine.status(p.thread) == "dead" then
                table.remove(processes, i)
            end
            return
        end
    end
    print("Processus "..processId.." introuvable")
end

local function listProcesses()
    print("ID\tCommande")
    for _,process in ipairs(processes) do
        print(process.id.."\t"..process.command)  
    end
end

local function stopProcess(id)
    for i,process in ipairs(processes) do
        if process.id == tonumber(id) then
            table.remove(processes, i)
            print("Processus "..id.." arrêté")
            return  
        end
    end
    print("Processus "..id.." introuvable")
end

-- Gérer les commandes
local function handleCommand(command)
    local words = {}
    for word in command:gmatch("%S+") do
        table.insert(words, word)
    end
    
    if #words == 0 then return end
    
    local cmd = words[1]:lower()
    
    if cmd == "clear" then
        term.clear()
        term.setCursorPos(1,1)

    elseif cmd == "cd" then
        if words[2] then
            local targetPath = resolvePath(words[2])
            if fs.exists(targetPath) and fs.isDir(targetPath) then
                currentPath = targetPath
                if currentPath:sub(1,1) == "/" then
                    currentPath = currentPath:sub(2)
                end
            else
                term.setTextColor(colors.error)
                print("Chemin invalide: " .. targetPath)
                term.setTextColor(colors.text)
            end
        end

    elseif cmd == "reboot" then
        os.reboot()

    elseif cmd == "alias" then
        if words[2] and words[3] then
            local name = words[2]  
            local command = table.concat(words, " ", 3)
            aliases[name] = command
            saveAliases()
            print("Alias créé: "..name.." -> "..command)
        else
            print("Usage: alias <name> <command>")  
        end
    
    elseif cmd == "unalias" then
        if words[2] then
            local name = words[2]
            if aliases[name] then
                aliases[name] = nil  
                saveAliases()
                print("Alias supprimé: "..name)
            else
                print("Alias inexistant: "..name)  
            end
        else
            print("Usage: unalias <name>")
        end
    
    elseif cmd == "bg" then 
        local commandLine = table.concat(words, " ", 2)
        local process = startProcess(commandLine)
        print("Processus démarré en tâche de fond [ID:"..process.id.."]")
    
    elseif cmd == "top" then
        listProcesses()
    
    elseif cmd == "stop" then  
        if words[2] then
            stopProcess(words[2])
        else
            print("Usage: stop <processId>")  
        end

    elseif cmd == "exit" then 
        shell.run("shell")

    elseif cmd == "pkg" then
        shell.run("/.AdvOS/prog/lib-pkg/pkg.lua")

    elseif cmd == "mkdir" then
        if words[2] then
            local targetDirPath = resolvePath(words[2])
            if not fs.exists(targetDirPath) then
                fs.makeDir(targetDirPath)
                print("Répertoire créé : " .. targetDirPath)
            else
                term.setTextColor(colors.error)
                print("Le répertoire existe déjà : " .. targetDirPath)
                term.setTextColor(colors.text)
            end
        end

    elseif cmd == "cp" then
        if words[2] and words[3] then
            local sourcePath = resolvePath(words[2])
            local destinationPath = resolvePath(words[3])
            if fs.exists(sourcePath) then
                fs.copy(sourcePath, destinationPath)
                print("Copié : " .. sourcePath .. " -> " .. destinationPath)
            else
                term.setTextColor(colors.error)
                print("Le fichier source n'existe pas : " .. sourcePath)
                term.setTextColor(colors.text)
            end
        end

    elseif cmd == "rm" then
        if words[2] then
            local targetPath = resolvePath(words[2])
            if fs.exists(targetPath) then
                fs.delete(targetPath)
                print("Supprimé : " .. targetPath)
            else
                term.setTextColor(colors.error)
                print("Le fichier n'existe pas : " .. targetPath)
                term.setTextColor(colors.text)
            end
        end

    elseif cmd == "edit" or cmd == "nano" then
        if words[2] then
            local targetFilePath = resolvePath(words[2])
            if fs.exists(targetFilePath) then
                shell.run("edit", targetFilePath)
            else
                local result, error = pcall(function()
                    shell.run("edit", targetFilePath)
                end)
                if not result then
                    term.setTextColor(colors.error)
                    print("Erreur: " .. error)
                    term.setTextColor(colors.text)
                end
            end
        end

    elseif cmd == "paint" then
        if words[2] then
            local targetFilePath = resolvePath(words[2])
            if fs.exists(targetFilePath) then
                shell.run("paint", targetFilePath)
            else
                local result, error = pcall(function()
                    shell.run("paint", targetFilePath)
                end)
                if not result then
                    term.setTextColor(colors.error)
                    print("Erreur: " .. error)
                    term.setTextColor(colors.text)
                end
            end
        end

    elseif cmd == "help" then
        local function displayHelp(command)
            if command then
                -- Aide spécifique pour chaque commande
                local helpTexts = {
                    clear = {
                        usage = "clear",
                        desc = "Efface l'écran et replace le curseur en haut"
                    },
                    cd = {
                        usage = "cd <répertoire>",
                        desc = "Change le répertoire courant"
                    },
                    reboot = {
                        usage = "reboot",
                        desc = "Redémarre le système"
                    },
                    pkg = {
                        usage = "pkg install <package> | pkg list",
                        desc = "Gestionnaire de paquets. 'install' installe un paquet, 'list' affiche les paquets installés"
                    },
                    mkdir = {
                        usage = "mkdir <nom_repertoire>",
                        desc = "Crée un nouveau répertoire"
                    },
                    cp = {
                        usage = "cp <source> <destination>",
                        desc = "Copie un fichier ou répertoire"
                    },
                    rm = {
                        usage = "rm <fichier/répertoire>",
                        desc = "Supprime un fichier ou répertoire"
                    },
                    edit = {
                        usage = "edit <fichier> | nano <fichier>",
                        desc = "Ouvre l'éditeur de texte pour modifier un fichier"
                    },
                    paint = {
                        usage = "paint <fichier>",
                        desc = "Ouvre l'éditeur d'images paint"
                    },
                    ls = {
                        usage = "ls [répertoire] | dir [répertoire]",
                        desc = "Liste le contenu du répertoire"
                    },
                    reload = {
                        usage = "reload",
                        desc = "Recharge le shell"
                    },
                    music = {
                        usage = "music",
                        desc = "Lance le lecteur de musique"
                    },
                    pwd = {
                        usage = "pwd",
                        desc = "Affiche le répertoire de travail actuel"
                    },
                    help = {
                        usage = "help [commande]",
                        desc = "Affiche l'aide générale ou l'aide d'une commande spécifique"
                    }
                }
    
                local help = helpTexts[command]
                if help then
                    print("\nCommande: " .. command)
                    term.setTextColor(colors.text)
                    print("Usage: " .. help.usage)
                    print("Description: " .. help.desc)
                else
                    term.setTextColor(colors.error)
                    print("Aucune aide disponible pour la commande: " .. command)
                    term.setTextColor(colors.text)
                end
            else
                -- Aide générale
                term.setTextColor(colors.success)
                print("\nCommandes disponibles dans " .. SHELL_NAME .. ":")
                term.setTextColor(colors.text)
                print("\nGestion des fichiers:")
                print("  ls, dir     - Liste les fichiers")
                print("  cd          - Change de répertoire")
                print("  pwd         - Affiche le répertoire actuel")
                print("  mkdir       - Crée un répertoire")
                print("  rm          - Supprime fichier/répertoire")
                print("  cp          - Copie fichier/répertoire")
    
                print("\nÉdition:")
                print("  edit, nano  - Éditeur de texte")
                print("  paint       - Éditeur d'images")
    
                print("\nSystème:")
                print("  clear       - Efface l'écran")
                print("  reboot      - Redémarre le système")
                print("  reload      - Recharge le shell")
    
                print("\nApplications:")
                print("  music       - Lecteur de musique")
                print("  pkg         - Gestionnaire de paquets")
    
                print("\nAide:")
                term.setTextColor(colors.path)
                print("Pour plus d'informations sur une commande: help <commande>")
                term.setTextColor(colors.text)
            end
        end
    
        -- Affiche l'aide pour une commande spécifique ou l'aide générale
        local specific_command = words[2]
        displayHelp(specific_command)

    elseif cmd == "ls" or cmd == "dir" then
        local path = words[2] and resolvePath(words[2]) or currentPath
        if fs.exists(path) then
            local list = fs.list(path)
            for _, item in ipairs(list) do
                local fullPath = fs.combine(path, item)
                if fs.isDir(fullPath) then
                    term.setTextColor(colors.path)
                    print("<DIR> " .. item)
                else
                    term.setTextColor(colors.text)
                    print("      " .. item)
                end
            end
        end

    elseif cmd == "reload" then
        shell.run("/.AdvOS/sys/shell/shell.lua")

    elseif cmd == "music" then
        shell.run("/.AdvOS/prog/music/music.lua")

    elseif cmd == "pwd" then
        print(currentPath == "" and "/" or "/" .. currentPath)

    else
        local program = resolvePath(words[1])
        if fs.exists(program) and not fs.isDir(program) then
            local success, err = pcall(function()
                shell.run(program, table.unpack(words, 2))
            end)
            if not success then
                term.setTextColor(colors.error)
                print("Erreur lors de l'exécution: " .. tostring(err))
                writeLog("Erreur d'exécution - Programme: " .. program .. " - " .. tostring(err))
                term.setTextColor(colors.text)
            end
        else
            term.setTextColor(colors.error)
            print("Commande non reconnue: " .. cmd)
            term.setTextColor(colors.text)
        end
    end
end

_G.shellAPI = {
    runShellCommand = function(command)
        handleCommand(command)
    end
}

local function mainLoop()
    while true do
        term.setTextColor(colors.text)
        displayPrompt()
        
        -- Vérifier les processus en attente ici
        local eventData = table.pack(os.pullEventRaw())
        if eventData[1] == "key" and eventData[2] == keys.tab then
            for i,process in ipairs(processes) do
                local result, error = coroutine.resume(process.thread, table.unpack(eventData,1,eventData.n))
                if coroutine.status(process.thread) == "dead" then
                    table.remove(processes, i)
                end
            end
            sleep(0)
        end
        
        local success, input = pcall(function()
            return read(nil, history, customComplete)
        end)
        
        if success and input then
            if input:len() > 0 then
                table.insert(history, input)
                local cmdSuccess, cmdErr = pcall(function()
                    handleCommand(input)
                end)
                
                if not cmdSuccess then
                    term.setTextColor(colors.error)
                    print("Erreur shell: " .. tostring(cmdErr))
                    writeLog("Erreur shell: " .. tostring(cmdErr))
                    term.setTextColor(colors.text)
                end
            end
        else
            term.setTextColor(colors.error)
            print("Erreur de lecture: " .. tostring(input))
            writeLog("Erreur de lecture: " .. tostring(input))
            term.setTextColor(colors.text)
        end
        
        os.sleep(0.05)
    end
end

-- Fonction de démarrage qui ne s'arrête jamais
while true do
    term.clear()
    term.setCursorPos(1,1)
    print("Bienvenue dans le AdvShell !")

    local success, err = pcall(mainLoop)
    
    if not success then
    end
end