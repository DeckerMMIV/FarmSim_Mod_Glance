--
-- "Glance" - Similar to "Inspector" and "LoadStatus", but different.
--
-- @team    Freelance Modding Crew (FMC)
-- @author  Decker_MMIV - fs-uk.com, forum.farming-simulator.com, modhoster.com
-- @date    2013-10-xx
--
-- Modifikationen erst nach Rücksprache
-- Do not edit without my permission
--
-- @history
--  2013-October
--      v0.01       - Initial experiment
--      v0.05       - More information added
--      v0.06       - Detects VeG-S
--  2013-November
--      v0.07       - Misc. fixes regarding multiplayer
--      v0.08       - More fixes for multiplayer
--      v0.09       - If speed is higher than 1 km/h, then vehicle is considered "not blocked".
--  2013-December
--      v0.10       - Added X/Y world-coordinate. (My "cunning plan" is set on hold for now.)
--                  - Special handling of fill-types, testing/using "_windrow" or "filltype_".
--                  - DLC-Ursus BaleWrapper task added; Wrapping Bale.
--  2014-January
--      v0.11       - Begun refactoring code to allow customizable notification-levels, columns, colors, etc.
--      v0.12       - Added support for URF sowing-machine's sprayer.
--      v0.13       - Fully refactored to use GlanceConfig.XML file.
--      v0.14       - Misc. tweaks and added creation of GlanceConfig.XML.
--      v0.15       - Auto-reload GlanceConfig.XML when leaving ESC menu.
--      v0.16       - On a dedicated-server, do not create a GlanceConfig.XML.
--      v0.17       - Only create notifications when being a game client.
--                    A dedicated-server is a pure server without client.
--                    A player creating a multiplayer game-session is both client-and-server.
--      v0.20       - Mod description.
--                  - Tweaked GlanceConfig.XML and loading.
--      v0.21       - Yet another attempt at blocked/collided detection.
--                    Unfortunately this wont work with a dedicated-server as of yet!
--      v0.22       - Fixed crash with 'baleLoaderFull' notification - Reported by DrUptown.
--      v0.23       - Show warning, when can't (or wont) load GlanceConfig.XML.
--                  - Collision/blocked detection hopefully improved at bit.
--      v0.24       - Update notify-level when blocked.
--      v0.25       - Added InputBindings: GlanceMore, GlanceLess
--                    These can be used to increase/decrease the notification-level.
--      v0.26       - Check against notification levels for animal husbandry
--                  - Show notification-level when it is changed.
--  2014-February
--      v0.27       - Creation of GlanceConfig.XML now occurs in the MODS folder, to accommodate dedicated-server.
--                  - getVehicleName() function added to 'Vehicle' table.
--      v0.28       - Added notification of placeables; Greenhouse.
--                  - Tweaked getVehicleName() slighty.
--      v0.29       - Been informed following error in a multiplayer game (dedicated server):
--                      *** 30973.002423714 MoreRealistic - ERROR - RealisticVehicle.updateVehiclePosition - Service car - getLinearVelocity - impossible result returned. velx/vely/velz=-1.#IND/-1.#IND/-1.#IND
--                      *** 30973.002423714 MoreRealistic - ERROR - RealisticVehicle.updateVehiclePosition - Ifor Williams Flat Bed Trailer LM186 - getLinearVelocity - impossible result returned. velx/vely/velz=-1.#IND/-1.#IND/-1.#IND
--                      Error: LUA running function 'update'
--                      mods/zzz_Glance/Glance.lua(858) : attempt to index field '?' (a nil value)
--                      *** 30973.002423714 MoreRealistic - ERROR - RealisticVehicle.updateVehiclePosition - Service car - getLinearVelocity - impossible result returned. velx/vely/velz=-1.#IND/-1.#IND/-1.#IND
--                      [etc.]
--                  - Attempt at fixing the above in getCellData_VehicleAtWorldCorner(), getCellData_VehicleAtWorldPositionXZ() and getCellData_VehicleAtFieldNumber().
--  2014-July
--      v1.1.0      - Support for 'ForestMod'. Number of trees ready to fell.
--

--[[
spaceraver:
    http://fs-uk.com/forum/index.php?topic=154077.msg1049475#msg1049475
    "plugins" support

vionic:
    When more than one implement is activated/turned-on/lowered, the "task" only shows one of them.
    Problematic when using both cultivator _and_ sowingMachine.
--]]

Glance = {}
--
local modItem = ModsUtil.findModItemByModName(g_currentModName);
Glance.version = (modItem and modItem.version) and modItem.version or "?.?.?";
--

addModEventListener(Glance);

--
Glance.minNotifyLevel       = nil;
Glance.maxNotifyLevel       = 99;

Glance.lineColorDefault                        = "gray"
Glance.lineColorVehicleControlledByMe          = "green"
Glance.lineColorVehicleControlledByPlayer      = "white"
Glance.lineColorVehicleControlledByComputer    = "blue"

Glance.cStartLineY      = 0.98
Glance.cFontSize        = 0.016;
Glance.cFontShadowOffs  = Glance.cFontSize * 0.08;
Glance.cFontShadowColor = "black"
Glance.cLineSpacing     = Glance.cFontSize * 0.9;

Glance.cColumnDelimChar = "・"  -- Katakana Middle Dot "・" = 0x30FB or 0xE383BB
Glance.columnSpacingTxt = "I";
Glance.columnSpacing    = 0.001;

Glance.colors = {}
Glance.colors["white"]  = {0.95, 0.95, 0.95, 1.00}
Glance.colors["black"]  = {0.00, 0.00, 0.00, 1.00}
Glance.colors["red"]    = {1.00, 0.30, 0.30, 1.00}
Glance.colors["yellow"] = {1.00, 1.00, 0.30, 1.00}
Glance.colors["green"]  = {0.50, 1.00, 0.50, 1.00}
Glance.colors["blue"]   = {0.70, 0.80, 0.95, 1.00}
Glance.colors["gray"]   = {0.70, 0.70, 0.70, 1.00}

Glance.collisionDetection_belowThreshold = 1;

Glance.updateIntervalMS = 2000;
Glance.sumTime = 0;

-- For debugging
function log(txt)
    local timeMs = 0;
    if g_currentMission ~= nil then
        timeMs = g_currentMission.time;
    end;
    print(string.format("%7ums ", timeMs) .. tostring(txt));
end;

--
function Glance_Steerable_PostLoad(self, xmlFile)
  if self.name == nil or self.realVehicleName == nil then
    self.name = Utils.getXMLI18N(xmlFile, "vehicle.name", "", "(unidentified vehicle)", self.customEnvironment);
  end
end
Steerable.postLoad = Utils.appendedFunction(Steerable.postLoad, Glance_Steerable_PostLoad);

-- Add extra function to Vehicle.LUA
if Vehicle.getVehicleName == nil then
    Vehicle.getVehicleName = function(self)
        if self.realVehicleName then return self.realVehicleName; end;
        if self.name            then return self.name;            end;
        return "(vehicle with no name)";
    end
end

--
function Glance_VehicleEnterRequestEvent_run(self, connection)
  Glance.sumTime = Glance.updateIntervalMS; -- Force update, when entering vehicle
end;
VehicleEnterRequestEvent.run = Utils.appendedFunction(VehicleEnterRequestEvent.run, Glance_VehicleEnterRequestEvent_run);

--
function Glance_InGameMenu_Update(self, dt)
    -- Simple auto-reload of Glance config, when leaving the ESC menu.
    Glance.triggerReload = 5;
end

--
function Glance:loadMap(name)
    if self.initialized == nil then
        self.initialized = true
        --
        --print(string.format("** Glance - getIsServer=%s, getIsClient=%s, g_dedicated=%s, isServer=%s, isClient=%s."
        --    , tostring(g_currentMission:getIsServer())
        --    , tostring(g_currentMission:getIsClient())
        --    , tostring(g_dedicatedServerInfo~=nil)
        --    , tostring(self.isServer)
        --    , tostring(self.isClient)
        --));
        --
        if g_currentMission:getIsClient() then
            self.cWorldCorners3x3 = {
            { g_i18n:getText("northwest") ,g_i18n:getText("north")    ,g_i18n:getText("northeast") }
            ,{ g_i18n:getText("west")      ,g_i18n:getText("center")   ,g_i18n:getText("east")      }
            ,{ g_i18n:getText("southwest") ,g_i18n:getText("south")    ,g_i18n:getText("southeast") }
            };
            -- If some fruit-name could not be found, try using the map-mod's own g_i18n:getText() function
            if g_currentMission.missionInfo and g_currentMission.missionInfo.map and g_currentMission.missionInfo.map.customEnvironment then
                local env0 = getfenv(0)
                local mapMod = env0[g_currentMission.missionInfo.map.customEnvironment]
                if mapMod ~= nil and mapMod.g_i18n ~= nil then
                    self.mapGI18N = mapMod.g_i18n;
                end
            end;
            --
            g_inGameMenu.update = Utils.appendedFunction(g_inGameMenu.update, Glance_InGameMenu_Update)
        end
        --
        self:loadConfig()
    end
end;

function Glance:deleteMap()
  Glance.soilModLayers = nil;
  self.modsHusbandries = nil;
  self.mapGI18N = nil;
  self.initialized = nil;
end;

function Glance:load(xmlFile)
end;

function Glance:delete()
end;

function Glance:mouseEvent(posX, posY, isDown, isUp, button)
end;

function Glance:keyEvent(unicode, sym, modifier, isDown)
end;

function Glance:update(dt)
  if g_dedicatedServerInfo == nil then
    if Glance.triggerReload ~= nil then
      -- Simple auto-reload of Glance config, when leaving the ESC menu.
      Glance.triggerReload = Glance.triggerReload - 1
      if Glance.triggerReload <= 0 then
          Glance.triggerReload = nil
          self:loadConfig()
      end
    end
    if Glance.failedConfigLoad ~= nil and Glance.failedConfigLoad > g_currentMission.time then
        local secsRemain = math.floor((Glance.failedConfigLoad - g_currentMission.time) / 1000)
        g_currentMission:addWarning(string.format(g_i18n:getText("config_error"), secsRemain), 0.018, 0.033);
    end;
  end
  --
  Glance.sumTime = Glance.sumTime + dt;
  if Glance.sumTime >= Glance.updateIntervalMS then
    Glance.makeUpdateEventFor = {}
    --
    if g_currentMission:getIsClient() then
        if self.modsHusbandries == nil then
            Glance.discoverModsHusbandries(self);
        end;
        --
        self.drawSoilCondition = {}
        Glance.makeSoilCondition(self, Glance.sumTime, self.drawSoilCondition);
        if not next(self.drawSoilCondition) then
            self.drawSoilCondition = nil;
        end
        --
        self.drawAnimals = {}
        Glance.makeAnimalsLineV2(self, Glance.sumTime, self.drawAnimals);
        Glance.makePlaceables(self, Glance.sumTime, self.drawAnimals);
        if not next(self.drawAnimals) then
            self.drawAnimals = nil
        end
        --
        Glance.makeVehiclesLines(self, Glance.sumTime);
    else
        -- TODO - Gather notifications that are only available server-side, and when its a dedicated-server.
    end
    --
    if g_currentMission:getIsServer() and next(Glance.makeUpdateEventFor) then
        -- Only server sends to clients
        GlanceEvent.sendEvent();
    end
    --
    Glance.sumTime = 0;
  end;
  --
  if InputBinding.hasEvent(InputBinding.GlanceMore) then
    Glance.minNotifyLevel = math.max(Glance.minNotifyLevel - 1, 0)
    Glance.sumTime = Glance.updateIntervalMS; -- Force update
    Glance.textMinLevelTimeout = g_currentMission.time + 2000
  elseif InputBinding.hasEvent(InputBinding.GlanceLess) then
    Glance.minNotifyLevel = math.min(Glance.minNotifyLevel + 1, Glance.maxNotifyLevel+1)
    Glance.sumTime = Glance.updateIntervalMS; -- Force update
    Glance.textMinLevelTimeout = g_currentMission.time + 2000
  end
  --
    if g_currentMission.showHelpText then
        if self.helpButtonsTimeout ~= nil and self.helpButtonsTimeout > g_currentMission.time then
            if Glance.minNotifyLevel > 0 then
                g_currentMission:addHelpButtonText(g_i18n:getText("GlanceMore")..string.format(" (%d)",Glance.minNotifyLevel), InputBinding.GlanceMore);
            end
            if Glance.minNotifyLevel < Glance.maxNotifyLevel+1 then
                g_currentMission:addHelpButtonText(g_i18n:getText("GlanceLess")..string.format(" (%d)",Glance.minNotifyLevel), InputBinding.GlanceLess);
            end
        end
    end
end;

--
function Glance:discoverModsHusbandries()
    self.modsHusbandries = {}
    for _,obj in pairs(g_currentMission.onCreateLoadedObjectsToSave) do
        -- Pigs mod ("SchweineZucht") by Marhu, and possible mutations that would be using the same variable-names "Produktivi" & "animal".
        if obj.Produktivi ~= nil and obj.animal ~= nil then
            if self.modsHusbandries[obj.animal] == nil then
                self.modsHusbandries[obj.animal] = {
                    subObjects = { obj }
                    ,
                    getProductivity = function(slf)
                        -- Get the worst productivity, but yet non-zero if possible
                        local value = nil;
                        for _,obj in pairs(slf.subObjects) do
                            if obj.Produktivi > 0 then
                                value = math.min(value or obj.Produktivi, obj.Produktivi);
                            end;
                        end
                        return value;
                    end
                    --,
                    --getNumAnimals = function(self)
                    --    local numAnimals = 0;
                    --    for _,obj in pairs(slf.subObjects) do
                    --        numAnimals = numAnimals + obj.numPig
                    --    end
                    --    return numAnimals
                    --end
                    ,
                    getFillLevel = function(self)
                        return 0
                    end
                    ,
                    getCapacity = function(self)
                        return 0
                    end
                };
            else
                -- Found another "SchweineZucht" instance, add it to the existing modHusbandry
                table.insert(self.modsHusbandries[obj.animal].subObjects, obj);
            end;
        end;
    end;
end

Glance.cCfgVersion = 3

function Glance:getDefaultConfig()
    local rawLines = {
 '<?xml version="1.0" encoding="utf-8" standalone="no" ?>'
,'<glanceConfig version="'..tostring(Glance.cCfgVersion)..'">'
,'<!--'
,'  NOTE! If a problem occurs which you can not solve when modifying this file, or when'
,'        starting to use a different version of Glance, then please remove or delete this'
,'        GlanceConfig.XML, to allow a fresh one being created!'
,'-->'
,'    <general>'
,'        <!-- Set the minimum level a notification should have to be displayed.'
,'             Set faster or slower update interval in milliseconds, though no less than 500 (half a second) or higher than 60000 (a full minute). -->'
,'        <notification  minimumLevel="2"  updateIntervalMs="2000" />'
,''
,'        <!-- Custom color names and their color RGBA-value in percentages, where 0.00 = 0x00 (0%) and 1.00 = 0xFF (100%) -->'
,'        <colors>'
,'            <color name="white"   rgba="0.95 0.95 0.95 1.00" />'
,'            <color name="black"   rgba="0.00 0.00 0.00 1.00" />'
,'            <color name="red"     rgba="1.00 0.30 0.30 1.00" />'
,'            <color name="yellow"  rgba="1.00 1.00 0.30 1.00" />'
,'            <color name="orange"  rgba="1.00 0.70 0.30 1.00" />'
,'            <color name="green"   rgba="0.50 1.00 0.50 1.00" />'
,'            <color name="blue"    rgba="0.70 0.80 0.95 1.00" />'
,'            <color name="gray"    rgba="0.70 0.70 0.70 1.00" />'
,'        </colors>'
,'        <lineColors>'
,'            <default                      color="gray" />'
,'            <vehicleControlledByMe        color="green" />'
,'            <vehicleControlledByPlayer    color="white" />'
,'            <vehicleControlledByComputer  color="blue" />'
,'        </lineColors>'
,''
,'        <!-- Size of the font is measured in percentage of the screen-height, which goes from 0.0000 (0%) to 1.0000 (100%) -->'
,'        <font  size="0.016"  shadowOffset="0.00128"  shadowColor="black"  rowSpacing="0.0135" />'
,''
,'        <!-- Currently only Y position is supported. Bottom is at 0.0000 (0%) and top is at 1.0000 (100%) -->'
,'        <placementInDisplay  positionXY="0.000 0.983" />'
,'    </general>'
,''
,'    <notifications>'
,'        <collisionDetection whenBelowThreshold="1" /> <!-- threshold unit is "km/h" -->'
,''
,'        <!-- Set  enabled="false"   to disable a particular notification.'
,'             Set  level="<number>"  to change the level of a notification. -->'
,'        <notification  enabled="true"  type="controlledByMe"            level="3"   color="green" />'
,'        <notification  enabled="true"  type="controlledByPlayer"        level="3"   color="white" />'
,'        <notification  enabled="true"  type="controlledByHiredWorker"   level="3"   color="blue" />'
,'        <notification  enabled="true"  type="controlledByCourseplay"    level="3"   color="blue" />'
,'        <notification  enabled="true"  type="controlledByFollowMe"      level="3"   color="blue" />'
,''
,'        <notification  enabled="true"  type="hiredWorkerFinished"       level="5"   color="orange" />'
,''
,'        <notification  enabled="true"  type="vehicleBroken"             level="2"   color="red" />'
,'        <notification  enabled="true"  type="vehicleCollision"          level="6"   whenAboveThreshold="10000"  color="red"    /> <!-- threshold unit is "milliseconds" -->'
,'        <notification  enabled="true"  type="vehicleIdleMovement"       level="1"   whenBelowThreshold="0.5"                   /> <!-- threshold unit is "km/h" -->'
,'        <notification  enabled="true"  type="fuelLow"                   level="4"   whenBelowThreshold="5"      color="red"    /> <!-- threshold unit is "percentage" -->'
,''
,'        <!-- Vehicle fill-level -->'
,'        <notification  enabled="true"  type="grainTankFull"             level="5"   whenAboveThreshold="80"  color="yellow" /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="forageWagonFull"           level="3"   whenAboveThreshold="99"  color="yellow" /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="baleLoaderFull"            level="3"   whenAboveThreshold="99"  color="yellow" /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="trailerFull"               level="3"   whenAboveThreshold="99.99"              /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="sprayerLow"                level="3"   whenBelowThreshold="3"   color="red"    /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="seederLow"                 level="3"   whenBelowThreshold="3"   color="red"    /> <!-- threshold unit is "percentage" -->'
,''
,'        <!-- Animal husbandry - Productivity, Wool pallet, Eggs (pickup objects) -->'
,'        <notification  enabled="true"  type="animalProductivity"        level="4"   whenBelowThreshold="100"    color="yellow" /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="animalPallet"              level="4"   whenAboveThreshold="99.99"  color="yellow" /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="animalPickupObjects"       level="2"   whenAboveThreshold="99.99"  color="yellow" /> <!-- threshold unit is "percentage" -->'
,''
,'        <!-- Placeable - Fill-level -->'
,'        <notification  enabled="true"  type="placeableGreenhouse"       level="2"   whenBelowThreshold="5"      color="yellow" /> <!-- threshold unit is "percentage" -->'
,''
,'        <!-- Additional mods - ManualIgnition, DamageMod, ForestMod -->'
,'        <notification  enabled="true"  type="engineOnButNotControlled"  level="3"   color="yellow"/>'
,'        <notification  enabled="true"  type="damaged"                   level="4"   whenAboveThreshold="25" color="yellow"/>  <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="aForestModTrees"           level="3"   whenAboveThreshold="0"  color="yellow"/>  <!-- threshold unit is "count-of-trees-ready" -->'
,'    </notifications>'
,''
,'    <columnOrder columnSpacing="0.0020">'
,'        <!-- Set  enabled="false"  to disable a column.'
,'             It is possible to reorder columns. -->'
,'        <column  enabled="true"  contains="VehicleGroupsSwitcherNumber"  color="gray"            align="right"   minWidthText=""                  />'
,'        <column  enabled="true"  contains="VehicleController;HiredWorkerFinished;VehicleBroken"  align="right"   minWidthText=""                  />'
,'        <column  enabled="true"  contains="ColumnDelim"                  color="gray"  text="・"  align="center"  minWidthText=""                  />'
,'        <column  enabled="true"  contains="VehicleMovementSpeed;Collision"                       align="right"   minWidthText=""                  />'
,'        <column  enabled="true"  contains="ColumnDelim"                  color="gray"  text="・"  align="center"  minWidthText=""                  />'
,'        <column  enabled="false" contains="VehicleAtWorldPositionXZ"                             align="left"    minWidthText=""                  />'
,'        <column  enabled="true"  contains="VehicleAtWorldCorner"                                 align="center"  minWidthText="MN"                />'
,'        <column  enabled="true"  contains="VehicleAtFieldNumber"                                 align="left"    minWidthText=""                  />'
,'        <column  enabled="true"  contains="ColumnDelim"                  color="gray"  text="・"  align="center"  minWidthText=""                  />'
,'        <column  enabled="true"  contains="VehicleName;FuelLow"                                  align="left"    minWidthText=""  maxTextLen="20" />'
,'        <column  enabled="true"  contains="ColumnDelim"                  color="gray"  text="・"  align="center"  minWidthText=""                  />'
,'        <column  enabled="true"  contains="FillLevel"                                            align="right"   minWidthText=""                  />'
,'        <column  enabled="true"  contains="ColumnDelim"                                text=""   align="right"   minWidthText="I"                 />'
,'        <column  enabled="true"  contains="FillPercent"                                          align="center"  minWidthText=""                  />'
,'        <column  enabled="true"  contains="ColumnDelim"                                text=""   align="left"    minWidthText="I"                 />'
,'        <column  enabled="true"  contains="FillTypeName"                                         align="left"    minWidthText=""  maxTextLen="12" />'
,'        <column  enabled="true"  contains="ColumnDelim"                  color="gray"  text="・"  align="center"  minWidthText=""                  />'
,'        <column  enabled="true"  contains="ActiveTask;EngineOn;Damaged"                          align="left"    minWidthText=""                  />'
,'    </columnOrder>'
,'</glanceConfig>'
    }
    local nl = "\n";
    local xmlDoc = ""
    for _,line in pairs(rawLines) do
        xmlDoc = xmlDoc .. line .. nl
    end
    return xmlDoc
end

function Glance:createNewConfig(fileName)
    local fHndl = io.open(fileName, "w");
    if fHndl == nil then
        print("** Glance could not create a new configuration file!")
        print("** Please check that the file is not locked or read-only; " .. fileName);
    else
        fHndl:write(self:getDefaultConfig())
        fHndl:close()
        fHndl = nil
    end
end

function Glance:loadConfig()
    Glance.notifications = {}
    Glance.columnOrder = {}

    local fileName = g_modsDirectory .. "/" .. "GlanceConfig.XML";
    
    if not fileExists(fileName) then
        print("** Glance will now try to create a new default configuation file; " .. fileName);
        self:createNewConfig(fileName)
    end;
    --
    local tag = "glanceConfig"
    local xmlFile = loadXMLFile(tag, fileName)
    local version = getXMLInt(xmlFile, "glanceConfig#version")
    if xmlFile == nil or version == nil then
        print("** Looks like an error may have occurred, when Glance tried to load its configuration file.");
        print("** This could be due to a corrupted XML structure, or otherwise problematic file-handling.");
        print("!! Please stop FS13 and then fix the XML or delete the file to let Glance create a new one; " .. fileName);
        Glance.failedConfigLoad = g_currentMission.time + 10000;
        return;
    end
    if version ~= Glance.cCfgVersion then
        print("!! The existing GlanceConfig.XML file is of a not supported version '"..tostring(version).."', and will NOT be loaded.")
        Glance.failedConfigLoad = g_currentMission.time + 10000;
        return;
    end
    if Glance.failedConfigLoad ~= nil then
        Glance.failedConfigLoad = nil;
        print("** Glance could now again load its configuration file; " .. fileName);
    end

    --
    local i=0
    while true do
        local tag = string.format("glanceConfig.general.colors.color(%d)", i)
        i=i+1
        if not hasXMLProperty(xmlFile, tag.."#name") then
            break
        end
        local colorName = getXMLString(xmlFile, tag.."#name")
        Glance.colors[colorName] = {
            Utils.getVectorFromString(getXMLString(xmlFile, tag.."#rgba"))
        }
        if table.getn(Glance.colors[colorName]) ~= 4 then
            -- Error in color setting!
            Glance.colors[colorName] = nil
            print("!! GlanceConfig.XML has invalid color setting, for color name: "..tostring(colorName));
        end
    end
    --
    local function getColorName(xmlFile, tag, defaultColorName)
        local colorName = getXMLString(xmlFile, tag)
        if colorName ~= nil then
            if Glance.colors[colorName] ~= nil then
                return colorName
            end
            print("!! GlanceConfig.XML has invalid color-name '"..tostring(colorName).."', in: "..tostring(tag));
        end
        return defaultColorName
    end
    --
    local tag = "glanceConfig.general.font"
    Glance.cFontSize        = Utils.getNoNil(getXMLFloat(xmlFile, tag.."#size"), Glance.cFontSize)
    Glance.cFontShadowOffs  = Glance.cFontSize * 0.08
    Glance.cLineSpacing     = Glance.cFontSize * 0.9
    Glance.cFontShadowOffs  = Utils.getNoNil(getXMLFloat(xmlFile, tag.."#shadowOffset"), Glance.cFontShadowOffs)
    Glance.cFontShadowColor = getColorName(xmlFile, tag.."#shadowColor", Glance.cFontShadowColor)
    Glance.cLineSpacing     = Utils.getNoNil(getXMLFloat(xmlFile, tag.."#rowSpacing"), Glance.cLineSpacing)
    --
    local tag = "glanceConfig.general.placementInDisplay"
    local posX,posY = Utils.getVectorFromString(getXMLString(xmlFile, tag.."#positionXY"))
    Glance.cStartLineY      = Utils.getNoNil(tonumber(posY), Glance.cStartLineY)
    --Glance.cRowDirection    = Utils.getNoNil(Glance.cRowDirections[getXMLString(xmlFile, tag.."#rowDirection")], Glance.cRowDirection)
    --Glance.cColDirection    = Utils.getNoNil(Glance.cColDirections[getXMLString(xmlFile, tag.."#columnDirection")], Glance.cColDirection)
    --
    local tag = "glanceConfig.general.notification"
    if Glance.minNotifyLevel == nil then
        Glance.minNotifyLevel = Utils.getNoNil(getXMLInt(xmlFile, tag.."#minimumLevel"), 2)
    end
    Glance.updateIntervalMS = Utils.clamp(Utils.getNoNil(getXMLInt(xmlFile, tag.."#updateIntervalMs"), Glance.updateIntervalMS), 500, 60000)
    --
    local tag = "glanceConfig.general.lineColors"
    Glance.lineColorDefault                     = getColorName(xmlFile, tag..".default#color", Glance.lineColorDefault)
    Glance.lineColorVehicleControlledByMe       = getColorName(xmlFile, tag..".vehicleControlledByMe#color", Glance.lineColorVehicleControlledByMe)
    Glance.lineColorVehicleControlledByPlayer   = getColorName(xmlFile, tag..".vehicleControlledByPlayer#color", Glance.lineColorVehicleControlledByPlayer)
    Glance.lineColorVehicleControlledByComputer = getColorName(xmlFile, tag..".vehicleControlledByComputer#color", Glance.lineColorVehicleControlledByComputer)
    --
    Glance.maxNotifyLevel = 0;
    local i=0
    while true do
        local tag = string.format("glanceConfig.notifications.notification(%d)", i)
        i=i+1
        if not hasXMLProperty(xmlFile, tag.."#type") then
            break
        end
        local notifyType = getXMLString(xmlFile, tag.."#type")
        Glance.notifications[notifyType] = {
             enabled        = Utils.getNoNil(getXMLBool(   xmlFile, tag.."#enabled"), false)
            ,color          =                getColorName( xmlFile, tag.."#color", nil)
            ,notifyType     =                getXMLString( xmlFile, tag.."#type")
            ,level          = Utils.getNoNil(getXMLInt(    xmlFile, tag.."#level"), 0)
            ,aboveThreshold = Utils.getNoNil(getXMLFloat(  xmlFile, tag.."#whenAboveThreshold"), 100)
            ,belowThreshold = Utils.getNoNil(getXMLFloat(  xmlFile, tag.."#whenBelowThreshold"),   0)
            ,coolDownMS     =                getXMLInt(    xmlFile, tag.."#coolDownMs")
            ,text           =                getXMLString( xmlFile, tag.."#text")
        }
        --
        Glance.maxNotifyLevel = math.max(Glance.maxNotifyLevel, Glance.notifications[notifyType].level)
    end
    --
    Glance.collisionDetection_belowThreshold = Utils.getNoNil(getXMLFloat(xmlFile, "glanceConfig.notifications.collisionDetection#whenBelowThreshold"), Glance.collisionDetection_belowThreshold);
    --
    Glance.columnSpacingTxt = Utils.getNoNil(getXMLString(xmlFile, "glanceConfig.columnOrder#columnSpacing"), Glance.columnSpacingTxt);
    Glance.columnSpacing = tonumber(Glance.columnSpacingTxt)
    if Glance.columnSpacing == nil then
        Glance.columnSpacing = Utils.getNoNil(getTextWidth(Glance.cFontSize, Glance.columnSpacingTxt), 0.001)
    end

    local i=0
    while true do
        local tag = string.format("glanceConfig.columnOrder.column(%d)", i)
        i=i+1
        if not hasXMLProperty(xmlFile, tag.."#contains") then
            break
        end
        Glance.columnOrder[i] = {
             enabled      =                        Utils.getNoNil(getXMLBool(  xmlFile, tag.."#enabled"), false)
            ,color        =                                       getColorName(xmlFile, tag.."#color", nil)
            ,text         =                                       getXMLString(xmlFile, tag.."#text")
            ,align        =                        Utils.getNoNil(getXMLString(xmlFile, tag.."#align"), "left")
            ,minWidthText =             Utils.trim(Utils.getNoNil(getXMLString(xmlFile, tag.."#minWidthText"), ""))
            ,maxTextLen   =                              tonumber(getXMLString(xmlFile, tag.."#maxTextLen"))
            ,contains     = Utils.splitString(";", Utils.getNoNil(getXMLString(xmlFile, tag.."#contains"),""))
        }
    end
    --
    delete(xmlFile)
end

-----

function Glance:setProperty(obj, propKey, propValue, noEventSend)
  if obj.modGlance == nil then
    obj.modGlance = {}
  end
  if obj.modGlance[propKey] ~= propValue and noEventSend ~= true then
    --log("Glance.makeUpdateEventFor "..tostring(networkGetObjectId(obj)).." "..propKey.."="..tostring(propValue))
    self.makeUpdateEventFor[networkGetObjectId(obj)] = obj;
  end
  obj.modGlance[propKey] = propValue;
end

function Glance:getProperty(obj, propKey)
  if obj.modGlance ~= nil then
    return obj.modGlance[propKey];
  end
  return nil
end

-----

local function hasNumberValue(obj, greaterThan)
    if obj ~= nil and type(obj)==type(9) then
        if greaterThan == nil then
            return true;
        end
        if obj > greaterThan then
            return true
        end
    end
    return false
end

function Glance.testPlaceable(placeable, resultDictionary)
    -- Extension function, in case some other mod wants to supply additional notifications
--[[
    local ntfy<THING> = Glance.notifications["placeable<THING>"]
    
    if ntfy<THING> ~= nil and ntfy<THING>.enabled = true
    and placeable.<VARIABLE> ~= nil     -- To identify the placeable<THING> object.
    then
        local pct = ..some calculation against the placeable<THING> object..
        
        if pct < ntfy<THING>.belowThreshold then
        ..or..        
        if pct > ntfy<THING>.aboveThreshold then
            if resultDictionary["<THING>"] ~= nil then
                pct = math.min(pct, resultDictionary["<THING>"].pct)
                ..or..
                pct = math.max(pct, resultDictionary["<THING>"].pct)
            end
            resultDictionary["<THING>"] = { pct=pct, color=ntfy<THING>.color }
        end
    end
--]]    
end

function Glance:makePlaceables(dt, notifyList)

    if g_currentMission.placeables ~= nil then
    
        local ntfyGreenhouse = Glance.notifications["placeableGreenhouse"]
        local foundNotifications = {}

        for _,plcType in pairs(g_currentMission.placeables) do
            for _,plc in pairs(plcType) do
                --log(tostring(plc)..":"..tostring(plc.waterTankCapacity).."/"..tostring(plc.manureCapacity))
                if ntfyGreenhouse ~= nil and ntfyGreenhouse.enabled == true 
                and hasNumberValue(plc.waterTankCapacity,0) and hasNumberValue(plc.manureCapacity,0) 
                and hasNumberValue(plc.waterTankFillLevel)  and hasNumberValue(plc.manureFillLevel) then
                    -- Probably a greenhouse
                    local pct = 100 * math.min(plc.waterTankFillLevel / plc.waterTankCapacity, plc.manureFillLevel / plc.manureCapacity)
                    --log(tostring(plc)..":"..tostring(pct))
                    if pct < ntfyGreenhouse.belowThreshold then
                        if foundNotifications["Greenhouse"] ~= nil then
                            pct = math.min(pct, foundNotifications["Greenhouse"].pct)
                        end
                        foundNotifications["Greenhouse"] = { pct=pct, color=ntfyGreenhouse.color }
                    end
                end
                --
                Glance.testPlaceable(plc, foundNotifications)
            end
        end
    
        --
        for typ,elem in pairs(foundNotifications) do
            if g_i18n:hasText("TypeDesc_"..typ) then
                typ = g_i18n:getText("TypeDesc_"..typ)
            elseif g_i18n:hasText(typ) then
                typ = g_i18n:getText(typ)
            end
            local txt = string.format("%s@%.0f%%", typ, elem.pct)
            table.insert(notifyList, { Glance.colors[elem.color], txt});
        end
    end
    
    -- aForestMod
    if aForestMod ~= nil and aForestMod.TreeManager ~= nil and aForestMod.TreeManager.growingTrees ~= nil then
        local ntfyForestModTrees = Glance.notifications["aForestModTrees"]
        if ntfyForestModTrees ~= nil and ntfyForestModTrees.enabled == true then
            local countOfTreesReady = 0
            for _,tree in pairs(aForestMod.TreeManager.growingTrees) do
                if tree ~= nil and tree.growingTime ~= nil and tree.growTime ~= nil and tree.growingTime >= tree.growTime then
                    countOfTreesReady = countOfTreesReady + 1
                end
            end
            if countOfTreesReady > ntfyForestModTrees.aboveThreshold then
                local typ = "Trees to fell";
                local txt = string.format("%s:%.0f", typ, countOfTreesReady)
                table.insert(notifyList, { Glance.colors[ntfyForestModTrees.color], txt});
            end
        end
    end
end

-----

-- Support for SoilMod v1.x.x
function Glance:makeSoilCondition(dt, notifyList)
    if fmcSoilMod ~= nil then
        if Glance.soilModLayers == nil then
            -- Copied from PdaPlugin_SoilCondition.LUA and modified for Glance
            Glance.soilModLayers = {
                {
                    layerId = g_currentMission.fmcFoliageSoil_pH,
                    func = function(self, x, z, widthX, widthZ, heightX, heightZ)
                        local sumPixels1,numPixels1 = getDensityParallelogram(self.layerId, x, z, widthX, widthZ, heightX, heightZ, 0, 3)

                        local txt = nil
                        if numPixels1>0 then
                            local phValue = 0;
                            local phDenomination = ""; --g_i18n:getText("NoCalculation")
                            if (fmcSoilMod and fmcSoilMod.density_to_pH and fmcSoilMod.pH_to_Denomination) then
                                phValue         = fmcSoilMod.density_to_pH(sumPixels1, numPixels1, 3)
                                phDenomination  = fmcSoilMod.pH_to_Denomination(phValue)
                                if g_i18n:hasText(phDenomination) then
                                    phDenomination = g_i18n:getText(phDenomination)
                                end
                            end
                            txt = (g_i18n:getText("SoilpH_value_denomination")):format(phValue, phDenomination)
                        end
                        return txt
                    end,
                },
                {
                    layerId = g_currentMission.fmcFoliageFertilizerOrganic,
                    func = function(self, x, z, widthX, widthZ, heightX, heightZ)
                        local sumPixels1,numPixels1 = getDensityParallelogram(self.layerId, x, z, widthX, widthZ, heightX, heightZ, 0, 2)

                        local txt = nil
                        if sumPixels1>0 then
                            txt = (g_i18n:getText("FertilizerOrganic_Level")):format(sumPixels1/numPixels1)
                        end
                        return txt
                    end,
                },
                {
                    layerId = g_currentMission.fmcFoliageFertilizerSynthetic,
                    func = function(self, x, z, widthX, widthZ, heightX, heightZ)
                        local sumPixels1,numPixels1 = getDensityParallelogram(self.layerId, x, z, widthX, widthZ, heightX, heightZ, 0, 1)
                        local sumPixels2,numPixels2 = getDensityParallelogram(self.layerId, x, z, widthX, widthZ, heightX, heightZ, 1, 1)

                        local txt = nil
                        if sumPixels1>0 and sumPixels2>0 then
                            txt = (g_i18n:getText("FertilizerSynthetic_Type_pct")):format("C", 100 * (sumPixels1/numPixels1+sumPixels2/numPixels2)/2)
                        elseif sumPixels1>0 then
                            txt = (g_i18n:getText("FertilizerSynthetic_Type_pct")):format("A", 100 * sumPixels1/numPixels1)
                        elseif sumPixels2>0 then
                            txt = (g_i18n:getText("FertilizerSynthetic_Type_pct")):format("B", 100 * sumPixels2/numPixels2)
                        end
                        return txt
                    end,
                },
                {
                    layerId = g_currentMission.fmcFoliageHerbicide,
                    func = function(self, x, z, widthX, widthZ, heightX, heightZ)
                        local sumPixels1,numPixels1 = getDensityParallelogram(self.layerId, x, z, widthX, widthZ, heightX, heightZ, 0, 1)
                        local sumPixels2,numPixels2 = getDensityParallelogram(self.layerId, x, z, widthX, widthZ, heightX, heightZ, 1, 1)
                        
                        local txt = nil
                        if sumPixels1>0 and sumPixels2>0 then
                            txt = (g_i18n:getText("Herbicide_Type_pct")):format("C", 100 * (sumPixels1/numPixels1+sumPixels2/numPixels2)/2)
                        elseif sumPixels1>0 then
                            txt = (g_i18n:getText("Herbicide_Type_pct")):format("A", 100 * sumPixels1/numPixels1)
                        elseif sumPixels2>0 then
                            txt = (g_i18n:getText("Herbicide_Type_pct")):format("B", 100 * sumPixels2/numPixels2)
                        end
                        return txt
                    end,
                },
                {
                    layerId = g_currentMission.fmcFoliageWeed,
                    func = function(self, x, z, widthX, widthZ, heightX, heightZ)
                        local sumPixels1,numPixels1 = getDensityParallelogram(self.layerId, x, z, widthX, widthZ, heightX, heightZ, 0, 2)
                        --local sumPixels2,numPixels2 = getDensityParallelogram(self.layerId, x, z, widthX, widthZ, heightX, heightZ, 2, 1)
                        
                        local txt = nil
                        if sumPixels1>0 and numPixels1>0 --[[ and numPixels2>0 ]] then
                            local weedPct = (sumPixels1/(3*numPixels1))
                            --local alivePct = sumPixels2/numPixels2
                            if weedPct >= 1 then
                                txt = (g_i18n:getText("WeedInfestation_pct")):format(weedPct*100)
                            end
                        end
                        return txt
                    end,
                },
                --{
                --    layerId = -1,
                --    func = function(self, x, z, widthX, widthZ, heightX, heightZ)
                --        return ""; -- Blank line
                --    end,
                --},
                --{
                --    layerId = -1,
                --    func = function(self, x, z, widthX, widthZ, heightX, heightZ)
                --        -- Fruits..
                --        local foundFruits = nil
                --        for fruitIndex,fruit in pairs(g_currentMission.fruits) do
                --            if fruit.id ~= nil and fruit.id ~= 0 then
                --                setDensityCompareParams(fruit.id, "between", 1, 7)  -- growing #1-#4, harvest #5-#7
                --                local _,numPixels1 = getDensityParallelogram(fruit.id, x, z, widthX, widthZ, heightX, heightZ, 0, g_currentMission.numFruitStateChannels)
                --                setDensityCompareParams(fruit.id, "greater", 9) -- defoliaged #10-..
                --                local _,numPixels2 = getDensityParallelogram(fruit.id, x, z, widthX, widthZ, heightX, heightZ, 0, g_currentMission.numFruitStateChannels)
                --                setDensityCompareParams(fruit.id, "greater", 0)
                --                --
                --                if numPixels1 > 0 or numPixels2 > 0 then
                --                    local fillTypeIndex = FruitUtil.fruitTypeToFillType[fruitIndex]
                --                    local fillTypeName = Fillable.fillTypeIndexToDesc[fillTypeIndex].nameI18N
                --                    if fillTypeName == nil then
                --                        fillTypeName = Fillable.fillTypeIndexToDesc[fillTypeIndex].name
                --                        if g_i18n:hasText(fillTypeName) then
                --                            fillTypeName = g_i18n:getText(fillTypeName)
                --                        end
                --                    end
                --                    foundFruits = ((foundFruits == nil) and "" or foundFruits..", ") .. fillTypeName
                --                end
                --            end
                --        end
                --        return (g_i18n:getText("CropsInArea")):format(foundFruits or "-")
                --    end,
                --},
            }
        end
        
        -- Copied from PdaPlugin_SoilCondition.LUA
        local x,y,z
        if g_currentMission.controlPlayer and g_currentMission.player ~= nil then
            x,y,z = getWorldTranslation(g_currentMission.player.rootNode)
        elseif g_currentMission.controlledVehicle ~= nil then
            x,y,z = getWorldTranslation(g_currentMission.controlledVehicle.rootNode)
        end
        
        if x ~= nil and x==x and z==z then
            local color = "orange"; -- Glance.colors["orange"];
            local squareSize = 10
        
            local widthX, widthZ, heightX, heightZ = squareSize-0.5,0, 0,squareSize-0.5
            x, z = x - (squareSize/2), z - (squareSize/2)
            for _,layer in ipairs(Glance.soilModLayers) do
                if layer.layerId ~= nil and layer.layerId ~= 0 and layer.func ~= nil then
                    local txt = layer:func(x, z, widthX, widthZ, heightX, heightZ)
                    if txt ~= nil then
                        table.insert(notifyList, { Glance.colors[color], txt });
                    end
                end
            end

            --if next(notifyList) then
            --    table.insert(notifyList, 1, { Glance.colors[color], g_i18n:getText("SoilCondition") })
            --end
        end
    end
end

-----

function Glance:makeAnimalsLineV2(dt, notifyList)
    if g_currentMission.husbandries ~= nil then
        local ntfyProductivity  = Glance.notifications["animalProductivity"]
        local ntfyPallet        = Glance.notifications["animalPallet"]
        local ntfyPickupObjects = Glance.notifications["animalPickupObjects"]
        --
        for animalType,husbandry in pairs(g_currentMission.husbandries) do
            local infos = {}
            local color = Glance.lineColorDefault;
            --
            if husbandry.productivity ~= nil and ntfyProductivity ~= nil and ntfyProductivity.enabled == true then
                local pct = math.floor(husbandry.productivity * 100);

                if pct > 0 and pct < ntfyProductivity.belowThreshold and ntfyProductivity.level >= Glance.minNotifyLevel then
                    color = ntfyProductivity.color or color
                    table.insert(infos, g_i18n:getText("Productivity") .. "@" .. pct .. "%");
                end
            end;
            --
            --if husbandry.liquidManureTrigger ~= nil then
            --    local pct = math.floor((husbandry.liquidManureTrigger.fillLevel * 100) / husbandry.liquidManureTrigger.capacity);
            --    local add = false; -- or self.showAlways;
            --    if (pct >= Glance.cAnimalManureHigh) then
            --        color = Glance.colors["yellow"];
            --        add = true;
            --    end;
            --    if add then
            --        local fillName = Fillable.fillTypeIntToName[husbandry.liquidManureTrigger.fillType] or Fillable.fillTypeIntToName[FILLABLE.FILLTYPE_UNKNOWN];
            --        if g_i18n:hasText(fillName) then
            --            fillName = g_i18n:getText(fillName);
            --        end;
            --        table.insert(infos, fillName.."@"..pct.."%");
            --    end
            --end
            --
            if husbandry.currentPallet ~= nil and ntfyPallet ~= nil and ntfyPallet.enabled == true then
                local pct = math.floor((husbandry.currentPallet:getFillLevel() * 100) / husbandry.currentPallet:getCapacity());

                if pct > ntfyPallet.aboveThreshold and ntfyPallet.level >= Glance.minNotifyLevel then
                    color = ntfyPallet.color or color
                    local fillName = Fillable.fillTypeIntToName[husbandry.palletFillType] or Fillable.fillTypeIntToName[FILLABLE.FILLTYPE_UNKNOWN];
                    if g_i18n:hasText(fillName) then
                        fillName = g_i18n:getText(fillName);
                    end;
                    table.insert(infos, fillName.."@"..pct.."%");
                end
            end
            --
            if husbandry.pickupObjectsToActivate ~= nil and husbandry.numActivePickupObjects ~= nil and ntfyPickupObjects ~= nil and ntfyPickupObjects.enabled == true then
                local capacity = table.getn(husbandry.pickupObjectsToActivate) + husbandry.numActivePickupObjects;
                local pct = math.floor((husbandry.numActivePickupObjects * 100) / capacity);

                if pct > ntfyPickupObjects.aboveThreshold and ntfyPickupObjects.level >= Glance.minNotifyLevel then
                    color = ntfyPickupObjects.color or color
                    local fillName = Fillable.fillTypeIntToName[husbandry.pickupObjectsFillType] or Fillable.fillTypeIntToName[FILLABLE.FILLTYPE_UNKNOWN];
                    if g_i18n:hasText(fillName) then
                        fillName = g_i18n:getText(fillName);
                    end;
                    table.insert(infos, fillName.."@"..pct.."%");
                end;
            end;
            --
            if next(infos) then
                if g_i18n:hasText("subCategory_"..animalType) then
                    animalType = g_i18n:getText("subCategory_"..animalType);
                end;
                local txt = animalType..":";
                for _,nfo in pairs(infos) do
                    txt = txt .. " " .. nfo;
                end
                table.insert(notifyList, { Glance.colors[color], txt});
            end;
        end;
        --
        for animalType,modHusbandry in pairs(self.modsHusbandries) do
            local infos = {}
            local color = Glance.lineColorDefault;
            --
            local productivity = modHusbandry:getProductivity();
            if productivity ~= nil and ntfyProductivity ~= nil and ntfyProductivity.enabled == true then
                local pct = math.floor(productivity * 100);

                if pct > 0 and pct < ntfyProductivity.belowThreshold and ntfyProductivity.level >= Glance.minNotifyLevel then
                    color = ntfyProductivity.color or color
                    table.insert(infos, g_i18n:getText("Productivity") .. "@" .. pct .. "%");
                end;
            end;
            --
            if next(infos) then
                if g_i18n:hasText("subCategory_"..animalType) then
                    animalType = g_i18n:getText("subCategory_"..animalType);
                elseif g_i18n:hasText(animalType) then
                    animalType = g_i18n:getText(animalType);
                end;
                local txt = animalType..":";
                for _,nfo in pairs(infos) do
                    txt = txt .. " " .. nfo;
                end
                table.insert(notifyList, { Glance.colors[color], txt});
            end;
        end;
        --
    end;
end


Glance.alignTypes = {}
Glance.alignTypes["left"]   = RenderText.ALIGN_LEFT
Glance.alignTypes["right"]  = RenderText.ALIGN_RIGHT
Glance.alignTypes["center"] = RenderText.ALIGN_CENTER

function Glance:makeVehiclesLines()
  local columns = {}
  for i,col in pairs(Glance.columnOrder) do
    if col.enabled == true then
        local column = {
            sufOff      = Glance.columnSpacing --getTextWidth(Glance.cFontSize, Glance.columnSpacingTxt)
            ,delimPos   = nil
            ,pos        = 0
            ,minWidth   = getTextWidth(Glance.cFontSize, col.minWidthText)
            ,maxLetters = col.maxTextLen
            ,alignment  = Glance.alignTypes[col.align] or RenderText.ALIGN_LEFT
            ,color      = Glance.colors[col.color] or {1,1,1,1}
        };
        table.insert(columns, column)
    end
  end
  self.drawLines = { columns }
  local lines = 1
  --
  local steerables = {}
  for _,v in pairs(g_currentMission.steerables) do
    table.insert(steerables,v);
  end
  if VehicleGroupsSwitcher ~= nil then
    -- Sort steerables in same order as in VehicleGroupsSwitcher.
    table.sort(steerables, function(l,r)
        if l.modVeGS == nil or r.modVeGS == nil then
            return false
        end
        lPos = l.modVeGS.group*100 + l.modVeGS.pos;
        rPos = r.modVeGS.group*100 + r.modVeGS.pos;
        return lPos < rPos;
    end);
  end

  local maxV = table.getn(steerables);
  for v=1,maxV do
    local cells = {}
    infoLevel, lineColor = Glance.getNotificationsForSteerable(self, dt, cells, steerables[v])
    if infoLevel >= Glance.minNotifyLevel then
        -- Add line
        local columns = {}
        for i,colParms in pairs(Glance.columnOrder) do
            if colParms.enabled == true then
                local column = {}
                for _,contain in pairs(colParms.contains) do
                    if Glance["getCellData_"..contain] ~= nil then
                        local data = Glance["getCellData_"..contain](self, dt, lineColor, colParms, cells, steerables[v])
                        if data ~= nil then
                            for _,v in pairs(data) do
                                table.insert(column, v)
                            end
                        end
                    end
                end
                table.insert(columns, column)
            end
        end
        lines = lines + 1
        self.drawLines[lines] = columns
    end
  end

  -- Find max text width per column
  for i=2,table.getn(self.drawLines) do
    for c=1,table.getn(self.drawLines[1]) do
      for e=1,table.getn(self.drawLines[i][c]) do
        --
        if self.drawLines[1][c].maxLetters ~= nil and self.drawLines[i][c][e][2]:len() > self.drawLines[1][c].maxLetters then
            self.drawLines[i][c][e][2] = self.drawLines[i][c][e][2]:sub(1, self.drawLines[1][c].maxLetters) .. "…"; -- 0x2026  -- "…"
        end
        --
        local txtWidth = getTextWidth(Glance.cFontSize, self.drawLines[i][c][e][2]);
        --log("i="..i..",c="..c..",e="..e..",txt=" .. tostring(self.drawLines[i][c][e][2])..",txtWidth="..tostring(txtWidth));
        self.drawLines[1][c].minWidth = math.max(self.drawLines[1][c].minWidth, txtWidth);
      end
    end;
  end;

  -- Update column positions.
  local xPos = 0.0;
  for c=1,table.getn(self.drawLines[1]) do
    --if (self.drawLines[1][c].delimPos ~= nil) then
    --    self.drawLines[1][c].delimPos = xPos - (spaceOff / 2);
    --end;

    if (self.drawLines[1][c].alignment == RenderText.ALIGN_LEFT) then
      self.drawLines[1][c].pos = xPos;
    elseif (self.drawLines[1][c].alignment == RenderText.ALIGN_CENTER) then
      self.drawLines[1][c].pos = xPos + (self.drawLines[1][c].minWidth / 2);
    elseif (self.drawLines[1][c].alignment == RenderText.ALIGN_RIGHT) then
      self.drawLines[1][c].pos = xPos + self.drawLines[1][c].minWidth;
    end;

    xPos = xPos + self.drawLines[1][c].minWidth + self.drawLines[1][c].sufOff;
  end

end

-----
function Glance:getCellData_VehicleGroupsSwitcherNumber(dt, lineColor, colParms, cells, veh)
    if veh.modVeGS ~= nil and veh.modVeGS.group ~= 0 then
        return { { Glance.colors[colParms.color or lineColor], tostring(veh.modVeGS.group % 10) } };
    end
end
function Glance:getCellData_VehicleController(dt, lineColor, colParms, cells, veh)
    return cells["VehicleController"]
end
--function Glance:getCellData_VehicleHonk(dt, lineColor, colParms, cells, veh)
--end
function Glance:getCellData_HiredWorkerFinished(dt, lineColor, colParms, cells, veh)
    return cells["HiredFinished"]
end
function Glance:getCellData_VehicleBroken(dt, lineColor, colParms, cells, veh)
    return cells["VehicleBroken"]
end
function Glance:getCellData_VehicleMovementSpeed(dt, lineColor, colParms, cells, veh)
    return cells["MovementSpeed"]
end
function Glance:getCellData_ColumnDelim(dt, lineColor, colParms, cells, veh)
    return { { Glance.colors[colParms.color or lineColor], (colParms.text or Glance.cColumnDelimChar) } }
end
function Glance:getCellData_VehicleAtWorldPositionXZ(dt, lineColor, colParms, cells, veh)
  if veh.components and veh.components[1] and veh.components[1].node then
      local wx,_,wz = getWorldTranslation(veh.components[1].node);
      
      if wx~=wx or wz~=wz then -- v0.29
        -- Something is very wrong!
        local vehName = "(unknown vehicle name)"
        if veh.getVehicleName ~= nil then
            vehName = veh.getVehicleName()
        end
        log("ERROR - Glance:getCellData_VehicleAtWorldPositionXZ(), getWorldTranslation() returned invalid values: x/_/z="..tostring(wx).."/_/"..tostring(wz)..", for vehicle: "..vehName)
        return
      end
      
      -- World location
      wx = wx + g_currentMission.missionPDA.worldCenterOffsetX;
      wz = wz + g_currentMission.missionPDA.worldCenterOffsetZ;
      return { { Glance.colors[lineColor], string.format("%dx%d", wx,wz) } }
  end
end
function Glance:getCellData_VehicleAtWorldCorner(dt, lineColor, colParms, cells, veh)
  if veh.components and veh.components[1] and veh.components[1].node then
      local wx,_,wz = getWorldTranslation(veh.components[1].node);
      
      if wx~=wx or wz~=wz then -- v0.29
        -- Something is very wrong!
        local vehName = "(unknown vehicle name)"
        if veh.getVehicleName ~= nil then
            vehName = veh.getVehicleName()
        end
        log("ERROR - Glance:getCellData_VehicleAtWorldCorner(), getWorldTranslation() returned invalid values: x/_/z="..tostring(wx).."/_/"..tostring(wz)..", for vehicle: "..vehName)
        return
      end
      
      -- World location
      wx = wx + g_currentMission.missionPDA.worldCenterOffsetX;
      wz = wz + g_currentMission.missionPDA.worldCenterOffsetZ;
      -- Determine world corner - 3x3 grid
      wx = 1 + Utils.clamp(math.floor(wx / (g_currentMission.missionPDA.worldSizeX / 3 + 1)), 0, 2); -- We '+1' if at any point the worldSizeX would be zero.
      wz = 1 + Utils.clamp(math.floor(wz / (g_currentMission.missionPDA.worldSizeZ / 3 + 1)), 0, 2); -- We '+1' if at any point the worldSizeX would be zero.
      return { { Glance.colors[lineColor], self.cWorldCorners3x3[wz][wx] } }
  end
end
function Glance:getCellData_VehicleAtFieldNumber(dt, lineColor, colParms, cells, veh)
  if veh.components and veh.components[1] and veh.components[1].node then
      local wx,_,wz = getWorldTranslation(veh.components[1].node);

      if wx~=wx or wz~=wz then -- v0.29
        -- Something is very wrong!
        local vehName = "(unknown vehicle name)"
        if veh.getVehicleName ~= nil then
            vehName = veh.getVehicleName()
        end
        log("ERROR - Glance:getCellData_VehicleAtFieldNumber(), getWorldTranslation() returned invalid values: x/_/z="..tostring(wx).."/_/"..tostring(wz)..", for vehicle: "..vehName)
        return
      end
      
      -- Find field
      local closestField = nil;
      for _,field in pairs(g_currentMission.fieldDefinitionBase.fieldDefs) do
        if field.fieldDimensions ~= nil then
          for i = 0, getNumOfChildren(field.fieldDimensions) - 1 do
            local n1 = getChildAt(field.fieldDimensions, i)
            local n2 = getChildAt(n1, 0)
            local n3 = getChildAt(n1, 1)

            local c1 = { getWorldTranslation(n1) }
            local c2 = { getWorldTranslation(n2) }
            local c3 = { getWorldTranslation(n3) }

            local overlap = 10;
            local x1 = math.min(c1[1],c2[1],c3[1]) - overlap;
            local z1 = math.min(c1[3],c2[3],c3[3]) - overlap;
            local x2 = math.max(c1[1],c2[1],c3[1]) + overlap;
            local z2 = math.max(c1[3],c2[3],c3[3]) + overlap;

            if  x1 <= wx and wx <= x2
            and z1 <= wz and wz <= z2 then
              closestField = field.fieldNumber;
              break
            end
          end;
        end;
        if closestField ~= nil then
          return { { Glance.colors[lineColor], string.format(g_i18n:getText("closestfield"), closestField) } }
        end;
      end;
  end
end
function Glance:getCellData_VehicleName(dt, lineColor, colParms, cells, veh)
  --if veh.name ~= nil then
  --  ----local vehName = string.sub(veh.name, 0, 20);
  --  --local vehParts = Utils.splitString(" ", veh.name);
  --  --local vehName = nil;
  --  --for p=1,math.min(3,table.getn(vehParts)) do
  --  --  vehName = (vehName~=nil and (vehName.." ") or "") .. vehParts[p];
  --  --end;
  --  --return { { Glance.colors[lineColor], vehName } }
  --  return { { Glance.colors[lineColor], veh.name } }
  --end;
  
    if veh.getVehicleName ~= nil then
        return { { Glance.colors[lineColor], veh:getVehicleName() } }
    end
end
function Glance:getCellData_FuelLow(dt, lineColor, colParms, cells, veh)
    return cells["FuelLow"]
end
function Glance:getCellData_Collision(dt, lineColor, colParms, cells, veh)
    return cells["Collision"]
end
function Glance:getCellData_EngineOn(dt, lineColor, colParms, cells, veh)
    return cells["EngineOn"]
end
function Glance:getCellData_Damaged(dt, lineColor, colParms, cells, veh)
    return cells["Damaged"]
end

function Glance:getCellData_FillLevel(dt, lineColor, colParms, cells, veh)
    return cells["FillLevel"]
end
function Glance:getCellData_FillPercent(dt, lineColor, colParms, cells, veh)
    return cells["FillPct"]
end
function Glance:getCellData_FillTypeName(dt, lineColor, colParms, cells, veh)
    return cells["FillType"]
end

function Glance:getCellData_ActiveTask(dt, lineColor, colParms, cells, veh)
    return cells["ActiveTask"]
end

-----

--function Glance:notify_vehicleHornOn(dt, notifyParms, veh)
--end

function Glance:notify_vehicleBroken(dt, notifyParms, veh)
    if veh.isBroken then
        return { "VehicleBroken", g_i18n:getText("broken") }
    end
end

--function Glance:notify_vehicleCollision(dt, notifyParms, veh)
--end

function Glance:notify_fuelLow(dt, notifyParms, veh)
  if veh.fuelCapacity ~= nil and veh.fuelCapacity > 0 then
    local fuelPct = math.floor(veh.fuelFillLevel / veh.fuelCapacity * 100);
    if fuelPct < notifyParms.belowThreshold then
      return { "FuelLow", string.format(g_i18n:getText("fuellow"), tostring(fuelPct)) }
    end;
  end;
end

function Glance:notify_engineOnButNotControlled(dt, notifyParms, veh)
  if veh.isControlled
  or veh.isHired
  or veh.drive
  or (veh.modFM and veh.modFM.FollowVehicleObj)
  then
    -- do nothing
  elseif veh.isMotorStarted then
    return { "EngineOn", g_i18n:getText("engineon") }
  end;
end

function Glance:notify_damaged(dt, notifyParms, veh, implements)
  if veh.damageLevel ~= nil then -- Support for rafftnix's Damage mod.
    local dmgLvlTxt = ""
    local delim = ""
    local maxDmg = 0
    for _,vehObj in pairs(implements) do
        if vehObj.damageLevel ~= nil and vehObj.damageLevel > 0 then
            maxDmg = math.max(maxDmg, vehObj.damageLevel)
            dmgLvlTxt = dmgLvlTxt .. string.format("%s%d%%", delim, vehObj.damageLevel)
            delim = " "
        end
    end
    if maxDmg > notifyParms.aboveThreshold then
        return { "Damaged", string.format(g_i18n:getText("damageLevel"),dmgLvlTxt) }
    end
  end
end

---

function Glance:static_controllerAndMovement(dt, _, veh, implements, cells, notifyLineColor)
    local notifyLevel = 0

    cells["VehicleController"] = {}

    local vehIsControlled = false
    local vehIsControlledByComputer = false
    if veh.isControlled and veh.controllerName ~= nil then
        if g_currentMission.controlledVehicle == veh then
            -- Controlled by 'this player'
            local ntfy = Glance.notifications["controlledByMe"]
            if ntfy ~= nil and ntfy.enabled == true then
                notifyLevel = math.max(notifyLevel, ntfy.level)
                notifyLineColor = Glance.lineColorVehicleControlledByMe
                table.insert(cells["VehicleController"], { Glance.colors[Glance.lineColorVehicleControlledByMe], veh.controllerName } );
            end
            vehIsControlled = true
        else
            -- Controlled by 'other player'
            local ntfy = Glance.notifications["controlledByPlayer"]
            if ntfy ~= nil and ntfy.enabled == true then
                notifyLevel = math.max(notifyLevel, ntfy.level)
                notifyLineColor = Glance.lineColorVehicleControlledByPlayer
                table.insert(cells["VehicleController"], { Glance.colors[Glance.lineColorVehicleControlledByPlayer], veh.controllerName } );
            end
            vehIsControlled = true
        end
    end
    --
    if veh.isHired then
        self:setProperty(veh, "wasHired", true)
        --
        local ntfy = Glance.notifications["controlledByHiredWorker"]
        if ntfy ~= nil and ntfy.enabled == true then
            notifyLevel = math.max(notifyLevel, ntfy.level)
            notifyLineColor = Glance.lineColorVehicleControlledByComputer
            table.insert(cells["VehicleController"], { Glance.colors[Glance.lineColorVehicleControlledByComputer], g_i18n:getText("hired") } );
        end
        vehIsControlled = true
        vehIsControlledByComputer = true
    else
        local ntfy = Glance.notifications["hiredWorkerFinished"]
        if ntfy ~= nil and ntfy.enabled == true and self:getProperty(veh, "wasHired") then
            if veh.isControlled then
                -- Remove reminder, when a player gets into vehicle
                self:setProperty(veh, "wasHired", nil)
            else
                notifyLevel = math.max(notifyLevel, ntfy.level)
                notifyLineColor = ntfy.color or notifyLineColor;
                cells["HiredFinished"] = { { Glance.colors[notifyLineColor], g_i18n:getText("dismissed") } }
            end
        end
    end
    --
    if veh.drive then
        local ntfy = Glance.notifications["controlledByCourseplay"]
        if ntfy ~= nil and ntfy.enabled == true then
            notifyLevel = math.max(notifyLevel, ntfy.level)
            notifyLineColor = Glance.lineColorVehicleControlledByComputer
            table.insert(cells["VehicleController"], { Glance.colors[Glance.lineColorVehicleControlledByComputer], g_i18n:getText("courseplay") } );
        end
        vehIsControlled = true
        vehIsControlledByComputer = true
    end
    --
    if veh.modFM and veh.modFM.FollowVehicleObj then
        local ntfy = Glance.notifications["controlledByFollowMe"]
        if ntfy ~= nil and ntfy.enabled == true then
            notifyLevel = math.max(notifyLevel, ntfy.level)
            notifyLineColor = Glance.lineColorVehicleControlledByComputer
            table.insert(cells["VehicleController"], { Glance.colors[Glance.lineColorVehicleControlledByComputer], g_i18n:getText("followme") } );
        end
        vehIsControlled = true
        vehIsControlledByComputer = true
    end

    ---

    cells["MovementSpeed"] = {}
    cells["Collision"] = {}

  if vehIsControlled and veh.isMotorStarted then
    local speedKmh = 0
    if veh.isRealistic and veh.realDisplaySpeed ~= nil then -- Support for Dural's MoreRealistic mod.
      speedKmh = veh.realDisplaySpeed * 3.6;
    else
      speedKmh = veh.lastSpeed * 3600
    end
    --
    local waiting = nil;
    if g_currentMission:getIsServer() then
      if veh.drive and veh.wait then
        -- CoursePlay waiting?
        waiting = true
      end
      self:setProperty(veh, "cpWaiting", waiting)
    else
      waiting = self:getProperty(veh, "cpWaiting");
    end
    --
    local ntfyIdle = Glance.notifications["vehicleIdleMovement"]

    if ntfyIdle ~= nil and ntfyIdle.enabled == true and speedKmh < ntfyIdle.belowThreshold then
      -- Not moving.
      notifyLevel = math.max(notifyLevel, ntfyIdle.level)

      if waiting then
        cells["MovementSpeed"] = { { Glance.colors[Utils.getNoNil(ntfyIdle.color, notifyLineColor)], g_i18n:getText("cp_waiting") } };
      else
        cells["MovementSpeed"] = { { Glance.colors[Utils.getNoNil(ntfyIdle.color, notifyLineColor)], g_i18n:getText("speedIdle") } };
      end
    else
        cells["MovementSpeed"] = { { Glance.colors[notifyLineColor], string.format(g_i18n:getText("speed+Unit"), g_i18n:getSpeed(speedKmh), g_i18n:getText("speedometer")) } }
    end

    ---

    local ntfyCollision = Glance.notifications["vehicleCollision"]
    if ntfyCollision ~= nil then
        local hasCollision = self:getProperty(veh, "hasCollision");
        if g_currentMission:getIsServer() then
            local notifyBlockedMS = nil;
            if vehIsControlledByComputer and speedKmh < Glance.collisionDetection_belowThreshold then
                notifyBlockedMS = self:getProperty(veh, "notifyBlockedMS")
                if notifyBlockedMS ~= nil then
                    if g_currentMission.time >= notifyBlockedMS then
                        -- Not been moving during threshold time
                        hasCollision = true
                    end
                else
                    if veh.numCollidingVehicles ~= nil then
                        for _,numCollisions in pairs(veh.numCollidingVehicles) do
                            if numCollisions > 0 then
                                -- Begin timeout
                                notifyBlockedMS = g_currentMission.time + ntfyCollision.aboveThreshold
                                break;
                            end;
                        end;
                    end
                    if math.abs(veh.lastAcceleration) > 0.9 then
                        --if veh.drive and veh.wait then
                        --    -- Courseplay, and it is explicitly waiting for something... so not blocked
                        --elseif self.waitingForTrailerToUnload or self.waitingForDischarge then
                        --    -- AICombine, and it is explicitly waiting to be emptied... so not blocked
                        --else
                            -- Begin timeout
                            notifyBlockedMS = g_currentMission.time + ntfyCollision.aboveThreshold
                        --end
                    end
                end
            else
                hasCollision = nil;
            end
            self:setProperty(veh, "notifyBlockedMS", notifyBlockedMS, true) -- this is a server-side property only
            self:setProperty(veh, "hasCollision", hasCollision);
        end
        if hasCollision ~= nil and ntfyCollision.enabled == true then
            notifyLevel = math.max(notifyLevel, ntfyCollision.level)
            cells["Collision"] = { { Glance.colors[Utils.getNoNil(ntfyCollision.color, notifyLineColor)], g_i18n:getText("collision") } };
        end
    end

  end

    ---
    return notifyLevel, notifyLineColor
end

function Glance:static_activeTask(dt, staticParms, veh, implements, cells, notify_lineColor)
  -- Three state variables; nil = not-present, false = present-TurnedOFF, true = present-TurnedON
  local impStates = {}
  for _,imp in pairs(implements) do
    for _,spec in pairs(imp.specializations) do
        if      Sprayer            == spec then impStates.isSprayerOn       = imp.isTurnedOn;
        elseif  ManureSpreader     == spec then impStates.isSprayerOn       = imp.isTurnedOn;
        elseif  ManureBarrel       == spec then impStates.isSprayerOn       = imp.isTurnedOn;
        elseif  SowingMachine      == spec then impStates.isSeederOn        = (imp.movingDirection > 0 and imp.sowingMachineHasGroundContact and (not imp.needsActivation or imp.isTurnedOn));
        elseif  Cultivator         == spec then impStates.isCultivatorOn    = (imp.cultivatorHasGroundContact and (not imp.onlyActiveWhenLowered or imp:isLowered(false)) and imp.startActivationTime <= imp.time);
        elseif  Plough             == spec then impStates.isPloughOn        = imp.ploughHasGroundContact;
        elseif  Combine            == spec then impStates.isHarvesterOn     = (imp.isThreshing and imp:getIsThreshingAllowed(false));
        elseif  ForageWagon        == spec then impStates.isForageWagonOn   = imp.isTurnedOn;
        elseif  Baler              == spec then impStates.isBalerOn         = imp.isTurnedOn;
        elseif  Mower              == spec then impStates.isMowerOn         = imp.isTurnedOn;
        elseif  Tedder             == spec then impStates.isTedderOn        = imp.isTurnedOn;
        elseif  Windrower          == spec then impStates.isWindrowerOn     = imp.isTurnedOn;
        elseif  FruitPreparer      == spec then impStates.isFruitPreparerOn = imp.isTurnedOn;
        elseif  BaleLoader         == spec then impStates.isBaleLoadingOn   = imp.isInWorkPosition;
        elseif  StrawBlower        == spec then impStates.isStrawBlowerOn   = (imp.tipState == Trailer.TIPSTATE_OPENING or imp.tipState == Trailer.TIPSTATE_OPEN);
        elseif  MixerWagon         == spec then impStates.isMixerWagonOn    = imp.isTurnedOn;
        elseif  Cutter             == spec then impStates.isCutterOn        = false; -- TODO
        elseif  Trailer            == spec then impStates.isTrailerOn       = (imp.movingDirection > 0.0001) or (imp.movingDirection < -0.0001);
                                                impStates.isTrailerUnloads  = (imp.tipState == Trailer.TIPSTATE_OPENING or imp.tipState == Trailer.TIPSTATE_OPEN);
        end;
        --
        if FarmingSimulator2013ClassicsPack ~= nil then
          if FarmingSimulator2013ClassicsPack.DLCBaleloader == spec then impStates.isBaleLoadingOn   = imp.isInWorkPosition;
          end
        end
        --
        if pdlc_ursusAddon ~= nil then
          if pdlc_ursusAddon.BaleWrapper == spec then impStates.isBaleWrapperOn = (imp.baleWrapperState > 0) and (imp.baleWrapperState < 4);
          end
        end
    end
  end;

  local txt = nil; -- No task.
  if     impStates.isHarvesterOn      then txt = g_i18n:getText("task_Harvesting"   );
  elseif impStates.isFruitPreparerOn  then txt = g_i18n:getText("task_Defoliator"   );
  elseif impStates.isBaleLoadingOn    then txt = g_i18n:getText("task_Loading_bales");
  elseif impStates.isBaleWrapperOn    then txt = g_i18n:getText("task_Wrapping_bale");
  elseif impStates.isBalerOn          then txt = g_i18n:getText("task_Baling"       );
  elseif impStates.isForageWagonOn    then txt = g_i18n:getText("task_Foraging"     );
  elseif impStates.isTedderOn         then txt = g_i18n:getText("task_Tedding"      );
  elseif impStates.isWindrowerOn      then txt = g_i18n:getText("task_Swathing"     );
  elseif impStates.isMowerOn          then txt = g_i18n:getText("task_Mowing"       );
  elseif impStates.isSprayerOn        then txt = g_i18n:getText("task_Spraying"     );
  elseif impStates.isSeederOn         then txt = g_i18n:getText("task_Seeding"      );
  elseif impStates.isStrawBlowerOn    then txt = g_i18n:getText("task_Bedding"      );
  elseif impStates.isMixerWagonOn     then txt = g_i18n:getText("task_Feeding"      );
  elseif impStates.isCutterOn         then txt = g_i18n:getText("task_Cutting"      );
  elseif impStates.isCultivatorOn     then txt = g_i18n:getText("task_Cultivating"  );
  elseif impStates.isPloughOn         then txt = g_i18n:getText("task_Ploughing"    );
  elseif impStates.isTrailerUnloads   then txt = g_i18n:getText("task_Unloading"    );
  elseif impStates.isTrailerOn        then txt = g_i18n:getText("task_Transporting" );
  end

  if txt ~= nil then
    cells["ActiveTask"] = { { Glance.colors[notify_lineColor], txt } }
  end
  --
  return -1; -- notifyLevel
end

function Glance:static_fillTypeLevelPct(dt, staticParms, veh, implements, cells, notify_lineColor)
  local notifyLevel = 0

  -- Examine each implement for fillable parts.
  self.fillTypesCapacityLevelColor = {}
  local function updateFill(fillType,capacity,level,color)
    if self.fillTypesCapacityLevelColor[fillType] == nil then
        self.fillTypesCapacityLevelColor[fillType] = {capacity=capacity, level=level, color=color}
    else
        self.fillTypesCapacityLevelColor[fillType].capacity = self.fillTypesCapacityLevelColor[fillType].capacity + capacity
        self.fillTypesCapacityLevelColor[fillType].level    = self.fillTypesCapacityLevelColor[fillType].level    + level
        if self.fillTypesCapacityLevelColor[fillType].color == nil then
            self.fillTypesCapacityLevelColor[fillType].color = color
        end
    end
  end
  --
  for _,obj in pairs(implements) do
    local fillClr = notify_lineColor;
    local fillTpe = nil;
    local fillLvl = nil;
    local fillPct = nil;
    if obj.grainTankCapacity and obj.grainTankCapacity > 0 and obj.grainTankFillLevel and obj.currentGrainTankFruitType then
      if obj.grainTankFillLevel > 0 and obj.currentGrainTankFruitType ~= FruitUtil.FRUITTYPE_UNKNOWN then
        fillTpe = FruitUtil.fruitTypeToFillType[obj.currentGrainTankFruitType];
        fillLvl = obj.grainTankFillLevel;
        fillPct = math.floor(obj.grainTankFillLevel / obj.grainTankCapacity * 100);
        --
        local ntfy = Glance.notifications["grainTankFull"]
        if ntfy ~= nil and ntfy.enabled == true then
            if fillPct > ntfy.aboveThreshold then
                fillClr = ntfy.color or fillClr
                notifyLevel = math.max(notifyLevel, ntfy.level)
            end
        end
        --
        updateFill(fillTpe,obj.grainTankCapacity,obj.grainTankFillLevel,fillClr)
      end;
    elseif obj.fillLevelMax and obj.fillLevel and obj.fillLevelMax > 0 and obj.fillLevel > 0 then
        -- Most likely a baleloader
        fillTpe = g_i18n:getText("bales");
        fillPct = math.floor(obj.fillLevel / obj.fillLevelMax * 100);
        fillLvl = obj.fillLevel;
        --
        local ntfy = Glance.notifications["baleLoaderFull"]
        if ntfy ~= nil and ntfy.enabled == true then
            if fillPct > ntfy.aboveThreshold then
                fillClr = ntfy.color or fillClr
                notifyLevel = math.max(notifyLevel, ntfy.level)
            end
        end
        --
        updateFill(fillTpe,obj.fillLevelMax,obj.fillLevel,fillClr)
    elseif obj.capacity and obj.capacity > 0 and obj.fillLevel then
      if obj.fillLevel > 0 then
        fillTpe = obj.currentFillType;
        fillPct = math.floor(obj.fillLevel / obj.capacity * 100);
        fillLvl = obj.fillLevel;
        --
        if SpecializationUtil.hasSpecialization(SowingMachine, obj.specializations) then
            -- For sowingmachine, show the selected seed type.
            fillTpe = FruitUtil.fruitTypeToFillType[obj.seeds[obj.currentSeed]];
            --
            local ntfy = Glance.notifications["seederLow"]
            if ntfy ~= nil and ntfy.enabled == true then
                if fillPct < ntfy.belowThreshold then
                    fillClr = ntfy.color or fillClr
                    notifyLevel = math.max(notifyLevel, ntfy.level)
                end
            end
        elseif SpecializationUtil.hasSpecialization(Sprayer, obj.specializations) then
            local ntfy = Glance.notifications["sprayerLow"]
            if ntfy ~= nil and ntfy.enabled == true then
                if fillPct < ntfy.belowThreshold then
                    fillClr = ntfy.color or fillClr
                    notifyLevel = math.max(notifyLevel, ntfy.level)
                end
            end
        elseif SpecializationUtil.hasSpecialization(ForageWagon, obj.specializations) then
            local ntfy = Glance.notifications["forageWagonFull"]
            if ntfy ~= nil and ntfy.enabled == true then
                if fillPct > ntfy.aboveThreshold then
                    fillClr = ntfy.color or fillClr
                    notifyLevel = math.max(notifyLevel, ntfy.level)
                end
            end
        elseif SpecializationUtil.hasSpecialization(Trailer, obj.specializations) then
            local ntfy = Glance.notifications["trailerFull"]
            if ntfy ~= nil and ntfy.enabled == true then
                if fillPct > ntfy.aboveThreshold then
                    fillClr = ntfy.color or fillClr
                    notifyLevel = math.max(notifyLevel, ntfy.level)
                end
            end
        end
        --
        updateFill(fillTpe,obj.capacity,obj.fillLevel,fillClr)
      elseif SpecializationUtil.hasSpecialization(Trailer, obj.specializations) then
        updateFill("n/a",obj.capacity,0,fillClr)
      end;
    end;
    -- Support for URF sowingmachines' sprayer
    if obj.isUrfSeeder then
        if obj.sprayCapacity and obj.sprayCapacity > 0 and obj.sprayFillLevel then
          if obj.sprayFillLevel > 0 then
            fillTpe = obj.currentSprayFillType;
            fillPct = math.floor(obj.sprayFillLevel / obj.sprayCapacity * 100);
            fillLvl = obj.sprayFillLevel;
            --
            local ntfy = Glance.notifications["sprayerLow"]
            if ntfy ~= nil and ntfy.enabled == true then
                if fillPct < ntfy.belowThreshold then
                    fillClr = ntfy.color or fillClr
                    notifyLevel = math.max(notifyLevel, ntfy.level)
                end
            end
            --
            updateFill(fillTpe,obj.sprayCapacity,obj.sprayFillLevel,fillClr)
          end
        end
    end
  end;
  --
  cells["FillLevel"] = {}
  cells["FillPct"]   = {}
  cells["FillType"]  = {}
  --
  local freeCapacity = self.fillTypesCapacityLevelColor["n/a"]
  self.fillTypesCapacityLevelColor["n/a"] = nil
  for fillTpe,v in pairs(self.fillTypesCapacityLevelColor) do
    local fillClr = Glance.colors[v.color]
    local fillLvl = v.level
    local fillCap = v.capacity
    --
    if freeCapacity ~= nil then
        fillCap = fillCap + freeCapacity.capacity
        freeCapacity = nil
    end
    local fillPct = math.floor(fillLvl / fillCap * 100);
    --
    local fillNme = ""
    if type(fillTpe) == type("") then
        -- Not a "normal" Fillable type
        fillNme = fillTpe;
    else
        fillNme = Fillable.fillTypeIntToName[fillTpe];
    end
    if fillNme == nil then
        fillNme = g_i18n:getText("unknownFillType")
    end
    local fillFrmtStr = "%s";
    if Utils.endsWith(fillNme, "_windrow") then
        fillFrmtStr = string.format("%s/%%s", g_i18n:getText("straw"))
        fillNme = string.sub(fillNme,1,fillNme:len() - 8)
    end
    for _,pfx in pairs({"","filltype_"}) do
        if g_i18n:hasText(pfx..fillNme) then
          fillNme = g_i18n:getText(pfx..fillNme);
          break
        elseif self.mapGI18N ~= nil and self.mapGI18N:hasText(pfx..fillNme) then
          fillNme = self.mapGI18N:getText(pfx..fillNme);
          break
        end;
    end
    --
    table.insert(cells["FillLevel"], { fillClr, string.format("%d", fillLvl)        } );
    table.insert(cells["FillPct"],   { fillClr, string.format("(%d%%)", fillPct)    } );
    table.insert(cells["FillType"],  { fillClr, string.format(fillFrmtStr, fillNme) } );
  end
  --
  return notifyLevel
end


Glance.staticCells = {}
Glance.staticCells["activeTask"]         = { enabled=true }
Glance.staticCells["fillTypeLevelPct"]   = { enabled=true }

function Glance:getNotificationsForSteerable(dt, cells, veh)
    -- Get attached-implements, and their attached-implements etc., up to 5 max.
    local implements = {veh};
    local j = 0;
    while (j < 6 and j < table.getn(implements)) do
        j=j+1;
        for _,imp in pairs(Utils.getNoNil(implements[j].attachedImplements, {})) do
            if imp ~= nil and imp.object ~= nil then
                table.insert(implements, imp.object);
            end;
        end;
    end;
    --
    local notify_level = 0
    local notify_lineColor = Glance.lineColorDefault
    local res, lineColor
    local cellName, notifyText

    notify_level, notify_lineColor = Glance.static_controllerAndMovement(self, dt, nil, veh, implements, cells, notify_lineColor)

    for notifyType,notifyParms in pairs(Glance.notifications) do
        if notifyParms.enabled == true and Glance["notify_"..notifyType] ~= nil then
            res, lineColor = Glance["notify_"..notifyType](self, dt, notifyParms, veh, implements)
            if res ~= nil then
                if lineColor ~= nil then
                    notify_lineColor = lineColor
                end
                notify_level = math.max(notifyParms.level, notify_level)
                cellName, notifyText = unpack(res)
                if cells[cellName] ~= nil then
                    table.insert(cells[cellName], { Glance.colors[notifyParms.color], notifyText } )
                else
                    cells[cellName] = { { Glance.colors[notifyParms.color], notifyText } }
                end
            end
        end
    end

    for staticType,staticParms in pairs(Glance.staticCells) do
        if staticParms.enabled == true and Glance["static_"..staticType] ~= nil then
            local level = Glance["static_"..staticType](self, dt, staticParms, veh, implements, cells, notify_lineColor)
            notify_level = math.max(notify_level, level)
        end
    end

    return notify_level, notify_lineColor
end

------

function Glance.renderTextShaded(x,y,fontSize,txt,shadeOffset,foreColor,backColor)
    -- Back
    if backColor then
        setTextColor(unpack(backColor));
        renderText(x+shadeOffset, y-shadeOffset, fontSize, txt);
    end
    -- Fore
    if foreColor then
        setTextColor(unpack(foreColor));
    end;
    renderText(x, y, fontSize, txt);
end

function Glance:draw()
    if Glance.forceHide or Glance.hide then
        return;
    end;
    if g_currentMission.showHelpText then
        return
    end
    --
    self.helpButtonsTimeout = g_currentMission.time + 7500;
    
    --
    local xPos = 0.0;
    local yPos = Glance.cStartLineY;
    local timeSec = math.floor(g_currentMission.time / 1000);

    if Glance.textMinLevelTimeout ~= nil and Glance.textMinLevelTimeout > g_currentMission.time then
        setTextAlignment(RenderText.ALIGN_LEFT);
        setTextBold(true);
        Glance.renderTextShaded(xPos, yPos, Glance.cFontSize, string.format(g_i18n:getText("GlanceMinLevel"), Glance.minNotifyLevel), Glance.cFontShadowOffs, {1,1,1,1}, Glance.colors[Glance.cFontShadowColor]);
        yPos = yPos - Glance.cLineSpacing;
    end
    
    setTextBold(false);

    if self.drawSoilCondition then
        local delimWidth = getTextWidth(Glance.cFontSize, Glance.cColumnDelimChar) * 1.50;
        xPos = 0.0;
        for c=1,table.getn(self.drawSoilCondition) do
            if c > 1 then
                setTextAlignment(RenderText.ALIGN_CENTER);
                Glance.renderTextShaded(xPos + (delimWidth / 2),yPos,Glance.cFontSize,Glance.cColumnDelimChar,Glance.cFontShadowOffs, Glance.colors[Glance.lineColorDefault], Glance.colors[Glance.cFontShadowColor]);
                xPos = xPos + delimWidth;
            end

            local elem = self.drawSoilCondition[c];
            if elem then
                setTextAlignment(RenderText.ALIGN_LEFT);
                Glance.renderTextShaded(xPos,yPos,Glance.cFontSize,elem[2],Glance.cFontShadowOffs,elem[1], Glance.colors[Glance.cFontShadowColor]);
                xPos = xPos + getTextWidth(Glance.cFontSize, elem[2])
            end
        end;
        yPos = yPos - Glance.cLineSpacing;
    end
    
    if self.drawAnimals then
        local delimWidth = getTextWidth(Glance.cFontSize, Glance.cColumnDelimChar) * 1.50;
        xPos = 0.0;
        for c=1,table.getn(self.drawAnimals) do
            if c > 1 then
                setTextAlignment(RenderText.ALIGN_CENTER);
                Glance.renderTextShaded(xPos + (delimWidth / 2),yPos,Glance.cFontSize,Glance.cColumnDelimChar,Glance.cFontShadowOffs, Glance.colors[Glance.lineColorDefault], Glance.colors[Glance.cFontShadowColor]);
                xPos = xPos + delimWidth;
            end

            local elem = self.drawAnimals[c];
            if elem then
                setTextAlignment(RenderText.ALIGN_LEFT);
                Glance.renderTextShaded(xPos,yPos,Glance.cFontSize,elem[2],Glance.cFontShadowOffs,elem[1], Glance.colors[Glance.cFontShadowColor]);
                xPos = xPos + getTextWidth(Glance.cFontSize, elem[2])
            end
        end;
        yPos = yPos - Glance.cLineSpacing;
    end;

    if self.drawLines then
        for i=2,table.getn(self.drawLines) do -- First element of drawLines contain column-widths and other stuff.
            for c=1,table.getn(self.drawLines[1]) do
                local numSubElems = table.getn(self.drawLines[i][c]);
                if numSubElems > 0 then
                    xPos = self.drawLines[1][c].pos;
                    setTextAlignment(self.drawLines[1][c].alignment);
                    --
                    local e = 1 + (timeSec % numSubElems);
                    Glance.renderTextShaded(xPos,yPos,Glance.cFontSize,self.drawLines[i][c][e][2],Glance.cFontShadowOffs,self.drawLines[i][c][e][1], Glance.colors[Glance.cFontShadowColor]);
                end;
            end
            yPos = yPos - Glance.cLineSpacing;
        end;
    elseif nil == self.drawAnimals then
        -- Just to show that Glance is there!
        Glance.renderTextShaded(xPos, yPos, Glance.cFontSize, Glance.cColumnDelimChar, Glance.cFontShadowOffs, Glance.colors[Glance.lineColorDefault], Glance.colors[Glance.cFontShadowColor]);
    end;

    -- Some other mods can't be bothered to set-up these before they draw to screen.
    setTextAlignment(RenderText.ALIGN_LEFT);
    setTextColor(1,1,1,1);
    setTextBold(false);
end;


--
--
--

GlanceEvent = {};
GlanceEvent_mt = Class(GlanceEvent, Event);

InitEventClass(GlanceEvent, "GlanceEvent");

function GlanceEvent:emptyNew()
    local self = Event:new(GlanceEvent_mt);
    self.className="GlanceEvent";
    return self;
end;

function GlanceEvent:new()
    local self = GlanceEvent:emptyNew()
    return self;
end;

function GlanceEvent:writeStream(streamId, connection)
    --log("GlanceEvent:writeStream(streamId, connection)")
    local numElems = 0
    -- Why the h*ll won't table.getn() nor # return the correct number of elements in the table?
    -- I have to resort to this element-iteration, why why?
    for _,_ in pairs(Glance.makeUpdateEventFor) do
        numElems = numElems + 1
    end
    --log(numElems .." ".. tostring(table.getn(Glance.makeUpdateEventFor)).." "..tostring(#Glance.makeUpdateEventFor));
    --numElems = table.getn(Glance.makeUpdateEventFor);
    --log(tostring(numElems))
    streamWriteUInt8(streamId, numElems);
    --
    for _,obj in pairs(Glance.makeUpdateEventFor) do
        -- Safety for how many elements are written to the stream
        numElems = numElems - 1
        if numElems < 0 then
            break
        end
        -- Naive serialization...
        local props = ""
        for k,v in pairs(obj.modGlance) do
            props = props .. tostring(k).."="..tostring(v) ..";";
        end
        --
        --log(tostring(networkGetObjectId(obj)).." "..tostring(props))
        streamWriteInt32(streamId, networkGetObjectId(obj))
        streamWriteString(streamId, props)
    end
end;

function GlanceEvent:readStream(streamId, connection)
    --log("GlanceEvent:readStream(streamId, connection)")
    local numElems = streamReadUInt8(streamId)
    --log(tostring(numElems))
    --
    for i=1,numElems do
        local obj = networkGetObject(streamReadInt32(streamId))
        local props =                streamReadString(streamId)
        --log(tostring(obj).." "..tostring(props))
        --
        if obj ~= nil then
            obj.modGlance = {}
            local propsParts = Utils.splitString(";",props)
            -- Naive deserialization...
            for _,p in pairs(propsParts) do
                local t = Utils.splitString("=",p)
                if table.getn(t) == 2 then
                    local k,v = t[1],t[2]
                    if      v == ""      then v = nil;
                    elseif  v == "true"  then v = true;
                    elseif  v == "false" then v = false;
                    end
                    --log(tostring(k)..": "..tostring(v))
                    obj.modGlance[k] = v;
                end
            end
        end
    end
end;

--function GlanceEvent:run(connection)
--    self.vehicle:setParms(self.parm1, self.parm2, true);
--    if not connection:getIsServer() then
--        g_server:broadcastEvent(GlanceEvent:new(self.vehicle, self.parm1, self.parm2), nil, connection, self.vehicle);
--    end;
--end;

function GlanceEvent.sendEvent(noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            --log("g_server:broadcastEvent(")
            g_server:broadcastEvent(GlanceEvent:new());
        --else
        --    g_client:getServerConnection():sendEvent(GlanceEvent:new());
        end;
    end;
end;


print(string.format("Script loaded: Glance.lua (v%s)", Glance.version));
