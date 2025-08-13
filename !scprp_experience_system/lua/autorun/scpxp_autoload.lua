local mainfolder = "!scpxp_experience_system/"

if SERVER then
    for k,v in pairs(file.Find(mainfolder .. "sv_*", "LUA")) do
        include(mainfolder .. tostring(v))
    end
end

for k,v in pairs(file.Find(mainfolder .. "sh_*", "LUA")) do
    include(mainfolder .. tostring(v))
    if SERVER then AddCSLuaFile(mainfolder .. tostring(v)) end
end

for k,v in pairs(file.Find(mainfolder .. "cl_*", "LUA")) do
    if SERVER then AddCSLuaFile(mainfolder ..  tostring(v))
    else include(mainfolder .. tostring(v))
    end