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
        else
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
        if playerHeartTable[index] & heartType.bone == heartType.bone then index = index + 1 end --Since bone hearts are not countd, this will resync the index with the "game index"
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

--Returns table with information about a heart based on its index
---@param player EntityPlayer player who's heart is being evaluated
---@param heartIndex integer starting from 1, heart to be evaluated
---@return table heartInfo table holding information about the heart
function ht.GetHeartInfo(player, heartIndex)
    local heartTable = ht.GetHeartTable(player)
    local heart = heartTable[tonumber(heartIndex)]
    --if heart == nil then error("Not a valid heart", 2) end
    local heartInfo = {}
    if heart & heartType.red == heartType.red then heartInfo.type = "red"
    elseif heart & heartType.soul == heartType.soul then heartInfo.type = "soul"
    elseif heart & heartType.bone == heartType.bone then heartInfo.type = "bone"
    else heart.type = "broken" end

    if heart & heartType.empty == heartType.empty then heartInfo.state = "empty"
    elseif heart & heartType.half == heartType.half then heartInfo.state = "half"
    elseif heart & heartType.full == heartType.full then heartInfo.state = "full"
    else heart.state = "rotten" end

    heartInfo.eternal = (heart & heartType.eternal == heartType.eternal)
    heartInfo.golden = (heart & heartType.golden == heartType.golden)
    return heartInfo
end

return ht