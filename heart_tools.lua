local ht = {}

local heartType = {
    --First two bits store type of container
    red = 0, --00 00 00
    soul = 1, --00 00 01
    bone = 2, --00 00 10
    black = 3, --00 00 11
    --Second two bits store state of heart
    empty = 0, --00 00 00
    half = 4, --00 01 00
    full = 8, --00 10 00
    rotten = 12, --00 11 00
    --Fifth bit stores eternal
    eternal = 16, --01 00 00
    --Sixth bit stores gold heart
    golden = 32, --10 00 00

    --While this isn't really necessary since broken hearts will always take priority
    --and are always at the end of the player's health, broken hearts can be enumerated as such
    broken = 13, --00 11 01 This is technically a "rotten soul heart", but since those don't exist I'm using it for broken hearts
}

--Converts players hearts into a table storing the type and state of each heart
---@param player EntityPlayer --player who's HeartString to return
---@return table playerHeartTable --table containing players heart data. Each enumeration stores the exact details of the players hearts, and its position in the table is its ID in the players health bar
function ht.GetHeartTable(player)
    local playerHeartTable = {} --Table to store the player's heart data
    local maxRedHearts = player:GetMaxHearts() --Number of red heart containers, with 2 == 1 heart container
    local soulHearts = player:GetSoulHearts() --Current number of soul hearts, with 1 == half a heart
    local effectiveMaxHearts = player:GetEffectiveMaxHearts() --Number of red + bone hearts
    local boneHearts = player:GetBoneHearts() --Current number of bone hearts, with 1 == 1 full heart (man I love consistency)
    local brokenHearts = player:GetBrokenHearts() --Current number of broken hearts, with 1 == 1 broken heart
    local currentRedHearts = player:GetHearts() --Current number of red hearts, with 1 == 1/2 a heart
    local rottenHearts = player:GetRottenHearts() --Current number of rotten hearts 1 == 1 rotten heart
    local eternalHearts = player:GetEternalHearts() --Current number of eternal hearts, with 1 == 1/2 eternal heart (Not sure it's even possible to have more than 1)
    local goldenHearts = player:GetGoldenHearts() --Current number of golden hearts, with 1 == 1 golden heart
    local heartLimit = player:GetHeartLimit() --Max amount of hearts the player can have (usually 12)
    local totalStandardizedHearts = maxRedHearts//2 + math.ceil(soulHearts/2) + boneHearts
    local redHeartCount = currentRedHearts --Counter for populating red hearts
    local soulHeartCount = soulHearts --Counter for populating soul hearts
    local rottenHeartCount = rottenHearts --Counter for populating rotten hearts
    local eternalHeartCount = eternalHearts --Counter for populating eternal hearts (kida unnecessary but whatever)
    local goldenHeartCount = goldenHearts --Counter for populating golden hearts
    local brokenHeartCount = brokenHearts --Counter for adding broken hearts
    local addHeart --Value to store in table
    local index --Position in table
    
    playerHeartTable = {} --Initializes playerHeartTable

    --I don't think the player is capable of having more than one eternal heart
    --but this check is here just in case
    if eternalHearts > 1 then
        maxRedHearts = maxRedHearts + eternalHearts//2
        eternalHearts = eternalHearts % 2
    end
    for i=1, maxRedHearts//2 do --Iterates through red heart containers, storing red hearts when possible
        addHeart = heartType.red
        if redHeartCount >= 2 then --Checks if the player still has red hearts to be stored
            addHeart = addHeart | heartType.full
            redHeartCount = redHeartCount -2
        elseif redHeartCount == 1 then
            addHeart = addHeart | heartType.half
            redHeartCount = redHeartCount - 1
        else
            addHeart = addHeart | heartType.empty
        end
        playerHeartTable[i] = addHeart --Adds determined heart to table at current index
    end
    for i = 1, totalStandardizedHearts-maxRedHearts//2 do --Starts adding non red heart containers, starting from the end of the players red heart containers
        if player:IsBoneHeart(i-1) then --Bone hearts start with index 0 at the end of the red heart containers, each heart counts as 1 in the index
            addHeart = heartType.bone
            if redHeartCount >= 2 then --Checks if bone heart can be populated with red hearts
                addHeart = addHeart | heartType.full
                redHeartCount = redHeartCount - 2
            elseif redHeartCount == 1 then --Checks if bone heart can be populated with red hearts
                addHeart = addHeart | heartType.half
                redHeartCount = redHeartCount - 1
            else
                addHeart = addHeart | heartType.empty
            end
        elseif heart & heartType.black == heartType.black then heartInfo.type = "black"
            addHeart = heartType.soul --Adds soul heart
            if soulHeartCount >= 2 then --Checks if it's a full or half soul heart
                addHeart = addHeart | heartType.full
                soulHeartCount = soulHeartCount - 2
            elseif soulHeartCount == 1 then
                addHeart = addHeart | heartType.half
                soulHeartCount = soulHeartCount - 1
            end
        end
        playerHeartTable[i+(maxRedHearts//2)] = addHeart --Adds the heart at the correct index
    end
    index = 1+maxRedHearts//2 --I dont really feel like explaining why or how I ended up with these values, it was basically just trial and error and I already forget how I did it
    for i = 1, soulHearts, 2 do --Iterates through soul hearts, swapping to black when appropriate and skipping bone hearts (why did they decide to code the indexes this way i stg)
        if playerHeartTable[index] & heartType.bone == heartType.bone then index = index + 1 end --Since bone hearts are not counted, this will resync the index with the "game index"
        if player:IsBlackHeart(i) then --Index starts at 1, bone hearts are not counted. Soul hearts count as 1 for each half, black hearts are the same but only the first half returns as a black heart
            playerHeartTable[index] = playerHeartTable[index] | heartType.black --Swaps heart enum to black
        end
        index = index + 1 --Increments index
    end
    for i = #playerHeartTable, 1, -1 do --Iterates backwards through list to apply eternal, rotten, and golden hearts
        if rottenHeartCount ~= 0 and (playerHeartTable[i] & heartType.bone == heartType.bone or playerHeartTable[i] & heartType.red == heartType.red) then
            playerHeartTable[i] = playerHeartTable[i] | heartType.rotten
            rottenHeartCount = rottenHeartCount - 1
        end
        if eternalHeartCount ~= 0 then --Checks to see if the player has eternal hearts
            if effectiveMaxHearts == 0 then --If the player has no red hearts, adds the eternal heart to the first heart in table
                playerHeartTable[1] = playerHeartTable[1] | heartType.eternal
                eternalHeartCount = eternalHeartCount - 1
            elseif playerHeartTable[i] & heartType.red == heartType.red or playerHeartTable[i] & heartType.bone == heartType.bone then --Adds the eternal heart to the last red heart
                playerHeartTable[i] = playerHeartTable[i] | heartType.eternal
                eternalHeartCount = eternalHeartCount -1
            end
        end
        if goldenHeartCount ~= 0 then --Checks if the player has golden hearts
            playerHeartTable[i] = playerHeartTable[i] | heartType.golden --Adds golden heart to last heart
            goldenHeartCount = goldenHeartCount - 1
        end
    end
    for i=heartLimit, 1, -1 do
        if brokenHeartCount == 0 then break
        else
            playerHeartTable[i] = heartType.broken
            brokenHeartCount = brokenHeartCount - 1
        end
    end
    return playerHeartTable
end


--Returns table with information about a heart based on on the provided enumerated value
---@param heartVal integer integer containing heart information
---@return table heartInfo table holding information about the heart
function ht.GetHeartInfo(heartVal)
    local heart = heartVal
    local heartInfo = {}
    
    if heart & heartType.black == heartType.black then heartInfo.type = "black"
    elseif heart & heartType.soul == heartType.soul then heartInfo.type = "soul"
    elseif heart & heartType.bone == heartType.bone then heartInfo.type = "bone"
    elseif heart & heartType.soul == heartType.soul and heart & heartType.rotten == heartType.rotten then heartInfo.type = "broken"
    else heartInfo.type = "red" end

    
    if heart & heartType.half == heartType.half then heartInfo.state = "half"
    elseif heart & heartType.full == heartType.full then heartInfo.state = "full"
    elseif heart & heartType.rotten == heartType.rotten then heartInfo.state = "rotten"
    elseif heart & heartType.soul == heartType.soul and heart & heartType.rotten == heartType.rotten then heartInfo.state = "broken"
    else heartInfo.state = "empty" end

    heartInfo.eternal = (heart & heartType.eternal == heartType.eternal)
    heartInfo.golden = (heart & heartType.golden == heartType.golden)
    return heartInfo
end


--Returns table with information about a heart based on its index
---@param player EntityPlayer player who's heart is being evaluated
---@param heartIndex? integer starting from 1, heart to be evaluated. Leave as nil to return info table for all hearts
---@return table heartInfo table holding information about the heart
function ht.GetPlayerHeartInfo(player, heartIndex)
    local heartTable = ht.GetHeartTable(player)
    local heartInfoTable = {}
    if heartIndex ~= nil then
        local heart = heartTable[tonumber(heartIndex)]
        if heart == nil then print("[ERROR] Not a valid heart") return heartInfoTable end
        heartInfoTable = ht.GetHeartInfo(heart)
    else
        for i,heart in heartTable do
            local heartInfo = ht.GetHeartInfo(heart)
            table.insert(heartInfoTable, i, heartInfo)
        end
    end
    return heartInfoTable
end


--Returns number of black hearts in a heartTable
---@param heartTable table heartTable to evaluate. Can be heartInfoTable or enumerated heartTable
---@return integer numBlackHearts number of black hearts found (1 = 1/2 black heart)
function ht.GetNumBlackHearts(heartTable)
    local numBlackHearts = 0
    for i,heart in ipairs(heartTable) do
        if type(heart) == "int" then
            if heart & heartType.black == heartType.black then
                if heart & heartType.half == heartType.half then numBlackHearts = numBlackHearts + 1
                elseif heart & heartType.full == heartType.full then numBlackHearts = numBlackHearts + 2 end
            end
        elseif type(heart) == "table" then
            if heart.type == "black" then
                if heart.state == "half" then numBlackHearts = numBlackHearts + 1
                elseif heart.state == "full" then numBlackHearts = numBlackHearts + 2 end
            end
        end
    end
    return numBlackHearts
end


--Removes all of a players hearts
---@param player EntityPlayer player whos hearts to wipe
function ht.WipeHearts(player)
    local maxRedHearts = player:GetMaxHearts() --Number of red heart containers, with 2 == 1 heart container
    local soulHearts = player:GetSoulHearts() --Current number of soul hearts, with 1 == half a heart
    local boneHearts = player:GetBoneHearts() --Current number of bone hearts, with 1 == 1 full heart (man I love consistency)
    local goldenHearts = player:GetGoldenHearts() --Current number of golden hearts
    local eternalHearts = player:GetEternalHearts() --Current number of eternal hearts, with 1 == 1/2 eternal heart (Not sure it's even possible to have more than 1)
    player:AddBlackHearts(-soulHearts) --All of these just remove all the hearts identified above
    player:AddSoulHearts(-soulHearts)
    player:AddMaxHearts(-maxRedHearts)
    player:AddBoneHearts(-boneHearts)
    player:AddGoldenHearts(-goldenHearts)
    player:AddEternalHearts(-eternalHearts)
end


--Restores player hearts from given table
---@param player EntityPlayer target player
---@param heartTable table table containing heart information
---@param additive? boolean set to false if the the players current hearts should be replaced, true if they should be added
---@param before? boolean if additive is true, set to true for previous hearts to be added before current hearts. Defaults to false
function ht.RestoreHearts(player, heartTable, additive, before)
    local tempHeartTable
    if additive == true and before == true then
        tempHeartTable = ht.GetHeartTable(player) --Stores current hearts to be added later
        ht.WipeHearts(player) --Removes all hearts
    end
    if additive == false then
        ht.WipeHearts(player) --Removes all hearts
    end
    for i,heartNum in ipairs(heartTable) do
        local heart = ht.GetHeartInfoFromInt(heartNum)
        --Checks the data about the given heart and adds it to the player
        if heart.type == "broken" then player:AddBrokenHearts(1)
        elseif heart.state == "empty" then
                if heart.type == "red" then player:AddMaxHearts(2) end
                if heart.type == "bone" then player:AddBoneHearts(1) end
        elseif heart.state == "half" then
                if heart.type == "red" then player:AddMaxHearts(2); player:AddHearts(1) end
                if heart.type == "soul" then player:AddSoulHearts(1) end
                if heart.type == "black" then player:AddBlackHearts(1) end
                if heart.type == "bone" then player:AddBoneHearts(1); player:AddHearts(1) end
        elseif heart.state == "full" then
            if heart.type == "red" then player:AddMaxHearts(2); player:AddHearts(2) end
            if heart.type == "soul" then player:AddSoulHearts(2) end
            if heart.type == "black" then player:AddBlackHearts(2) end
            if heart.type == "bone" then player:AddBoneHearts(1); player:AddHearts(2) end
        elseif heart.state == "rotten" then
            if heart.type == "red" then player:AddMaxHearts(2); player:AddRottenHearts(1) end
            if heart.type == "bone" then player:AddBoneHearts(1); player:AddRottenHearts(1) end
        end
        if heart.eternal == true then player:AddEternalHearts(1) end
        if heart.golden == true then player:AddGoldenHearts(1) end
    end
    --If additive is true and before is true, then this appends the current hearts at the end of the restored ones
    if additive == true and before == true then
        ht.RestoreHearts(player, tempHeartTable, true, false)
    end
end

return ht