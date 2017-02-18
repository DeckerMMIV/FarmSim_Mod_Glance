--
-- Glance
--
-- @author  Decker_MMIV
-- @contact fs-uk.com, modcentral.co.uk, forum.farming-simulator.com
-- @date    2016-12-xx
--
-- Modifikationen erst nach Rücksprache
-- Do not edit without my permission
--

--[[
spaceraver:
    http://fs-uk.com/forum/index.php?topic=154077.msg1049475#msg1049475
    "plugins" support
    
Dzi4d3k:
    http://fs-uk.com/forum/index.php?topic=171211.msg1154025#msg1154025
    Player stats
--]]

Glance = {}
--
local modItem = ModsUtil.findModItemByModName(g_currentModName);
Glance.version = (modItem and modItem.version) and modItem.version or "?.?.?";
--

addModEventListener(Glance);

--
Glance.initialized      = -1
Glance.minNotifyLevel   = 4;
Glance.maxNotifyLevel   = 99;
Glance.ignoreHelpboxVisibility = false;

Glance.lineColorDefault                        = "gray"
Glance.lineColorVehicleControlledByMe          = "green"
Glance.lineColorVehicleControlledByPlayer      = "white"
Glance.lineColorVehicleControlledByComputer    = "blue"

Glance.cStartLineX      = 0.0
Glance.cStartLineY      = 0.999
Glance.cFontSize        = 0.011;
Glance.cFontShadowOffs  = Glance.cFontSize * 0.08;
Glance.cFontShadowColor = "black"
Glance.cLineSpacing     = Glance.cFontSize * 0.9;

--
Glance.nonVehiclesSeparator         = "  //  ";
Glance.nonVehiclesFillLevelFormat   = "%s %s %s";

Glance.allFillLvlsSeparator = ","
Glance.allFillLvlsFormat    = "%s%s(%s)"
Glance.allFillPctsSeparator = ","
Glance.allFillPctsFormat    = "%s%s@%s"

Glance.cColumnDelimChar = " "
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
local function log(...)
    if true then
        local txt = ""
        for idx = 1,select("#", ...) do
            txt = txt .. tostring(select(idx, ...))
        end
        print(string.format("%7ums [Glance] ", (g_currentMission ~= nil and g_currentMission.time or 0)) .. txt);
    end
end;

--

-- Reuse from VehicleGroupsSwitcher
function Glance_Steerable_PostLoad(self, savegame)
    if self.motorType == "locomotive" then
        return
    end
  
    local storeItem = StoreItemsUtil.storeItemsByXMLFilename[self.configFileName:lower()];
    if storeItem ~= nil and storeItem.name ~= nil then
        local brand = ""
        if storeItem.brand ~= nil and storeItem.brand ~= "" then
            brand = tostring(storeItem.brand) .. " " 
        end
        self.modVeGS = Utils.getNoNil(self.modVeGS, {group=0,pos=0})
        self.modVeGS.vehicleName = brand .. tostring(storeItem.name);
    end
end

Steerable.postLoad = Utils.appendedFunction(Steerable.postLoad, Glance_Steerable_PostLoad);

-- Add extra function to Vehicle.LUA
if Vehicle.getVehicleName == nil then
    Vehicle.getVehicleName = function(self)
        if self.modVeGS and self.modVeGS.vehicleName then
            return self.modVeGS.vehicleName
        end;
        return "(vehicle with no name)";
    end
end

-- Add extra function to RailroadVehicle.LUA
if RailroadVehicle.getVehicleName == nil then
    RailroadVehicle.getVehicleName = function(self)
        if self.modVeGS and self.modVeGS.vehicleName then
            return self.modVeGS.vehicleName
        end;
        --return "Locomotive"
        if g_i18n:hasText("locomotive") then
            return g_i18n:getText("locomotive")
        end
        return g_i18n:getText("helpTitle_59") -- contains 'Train'
    end
end


--
function Glance_VehicleEnterRequestEvent_run(self, connection)
    Glance.sumTime = Glance.updateIntervalMS; -- Force update, when entering vehicle
end;
VehicleEnterRequestEvent.run = Utils.appendedFunction(VehicleEnterRequestEvent.run, Glance_VehicleEnterRequestEvent_run);

--
function Glance:loadMap(name)
    if Glance.initialized > 0 then
        return
    end
    Glance.initialized = 1
    
    Glance.fieldsRects = nil
    --
    if g_currentMission:getIsServer() then
        -- Force husbandries to update NOW!
        if g_currentMission.husbandries ~= nil then
            for animalType,husbandry in pairs(g_currentMission.husbandries) do
                if husbandry.updateMinutesInterval ~= nil then
                    husbandry.updateMinutes = husbandry.updateMinutesInterval + 1
                end
            end
        end
    end
    --
    if g_currentMission:getIsClient() then
        self.cWorldCorners3x3 = {
            { g_i18n:getText("northwest") ,g_i18n:getText("north")    ,g_i18n:getText("northeast") },
            { g_i18n:getText("west")      ,g_i18n:getText("center")   ,g_i18n:getText("east")      },
            { g_i18n:getText("southwest") ,g_i18n:getText("south")    ,g_i18n:getText("southeast") },
        };
        -- If some fruit-name could not be found, try using the map-mod's own g_i18n:getText() function
        self.i18n = (g_currentMission.missionInfo.customEnvironment ~= nil) and _G[g_currentMission.missionInfo.customEnvironment].g_i18n or g_i18n;
    end
    --
    Glance.c_KeysMoreLess = ("%s / %s"):format(
        table.concat(InputBinding.getRawKeyNamesOfDigitalAction(InputBinding.GLANCE_MORE), ' '),
        table.concat(InputBinding.getRawKeyNamesOfDigitalAction(InputBinding.GLANCE_LESS), ' ')
    )
    --
    self:loadConfig()
end;

function Glance:deleteMap()
    self.i18n = nil;
    Glance.initialized = 0;
end;

function Glance:load(xmlFile)
end;

function Glance:delete()
end;

function Glance:mouseEvent(posX, posY, isDown, isUp, button)
end;

function Glance:keyEvent(unicode, sym, modifier, isDown)
end;

local logError = true
local function safeGetValue(...)
    local obj = _G
    for idx = 1,select("#", ...) do
        local elem = select(idx, ...)
        obj = obj[elem]
        if obj == nil and logError then
            log("Failed at: ",elem)
            logError = false
            return nil
        end
    end
    return obj
end


function Glance:update(dt)
    Glance.sumTime = Glance.sumTime + dt;
    if Glance.sumTime >= Glance.updateIntervalMS then
        -- Work-around for reloading Glance config while in-game.
        if g_dedicatedServerInfo == nil then
            local state = safeGetValue('g_inGameMenu','helpLineCategorySelectorElement','state')
            if Glance.prevHelpLineState ~= state then
                if Glance.prevHelpLineState ~= nil then
                    self:loadConfig()
                    --
                    if Glance.failedConfigLoad ~= nil then
                        if g_currentMission.inGameMessage ~= nil then
                            g_currentMission.inGameMessage:showMessage("Glance", g_i18n:getText("config_error"), 5000);
                            Glance.failedConfigLoad = nil;
                        end
                    end
                end
                Glance.prevHelpLineState = state
            end
        end
    
        --
        Glance.sumTime = 0;
        Glance.makeUpdateEventFor = {}
        --
        if Glance.fieldsRects == nil then
            Glance.fieldsRects = {}
            Glance.buildFieldsRects()
        end
        --
        if g_currentMission:getIsClient() then
            self.linesNonVehicles = {};
            
            local lineNonVehicles = {}
            Glance.makeHusbandriesLine(self, Glance.sumTime, lineNonVehicles);
            Glance.makePlaceablesLine(self, Glance.sumTime, lineNonVehicles);
            if next(lineNonVehicles) then
                table.insert(self.linesNonVehicles, lineNonVehicles)
            end
        
            lineNonVehicles = {}
            Glance.makeFieldsLine(self, Glance.sumTime, lineNonVehicles);
            if next(lineNonVehicles) then
                table.insert(self.linesNonVehicles, lineNonVehicles)
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
    end;
    --
    if g_currentMission:getIsClient() then
        if InputBinding.hasEvent(InputBinding.GLANCE_MORE) then
            Glance.minNotifyLevel = math.max(Glance.minNotifyLevel - 1, 0)
            Glance.sumTime = Glance.updateIntervalMS; -- Force update
            Glance.textMinLevelTimeout = g_currentMission.time + 2000
        elseif InputBinding.hasEvent(InputBinding.GLANCE_LESS) then
            Glance.minNotifyLevel = math.min(Glance.minNotifyLevel + 1, Glance.maxNotifyLevel+1)
            Glance.sumTime = Glance.updateIntervalMS; -- Force update
            Glance.textMinLevelTimeout = g_currentMission.time + 2000
        end
        --
        if self.helpButtonsTimeout ~= nil and self.helpButtonsTimeout > g_currentMission.time then
            local txt = ("%s - %s"):format(
                Glance.c_KeysMoreLess,
                (g_i18n:getText("GlanceLevel")):format(Glance.minNotifyLevel)
            )
            g_currentMission:addExtraPrintText(txt, nil, GS_PRIO_NORMAL);
        end
    end
end;

Glance.cCfgVersion = 11
Glance.cCfgVersionsSupported = {[10]=true,[11]=true}

function Glance:getDefaultConfig()
    local function dnl(offset) -- default notification level
        return Utils.clamp(4 + Utils.getNoNil(offset, 0), 0, 99)
    end
    
    local rawLines = {
 '<?xml version="1.0" encoding="utf-8" standalone="no" ?>'
,'<glanceConfig version="'..tostring(Glance.cCfgVersion)..'">'
,'<!--'
,'  NOTE! If a problem occurs which you can not solve when modifying this file, or when'
,'        starting to use a different version of Glance, then please remove or delete this'
,'        Glance_Config.XML, to allow a fresh one being created!'
,'-->'
,'    <general>'
,'        <!-- Set the minimum level a notification should have to be displayed.'
,'             Set faster or slower update interval in milliseconds, though no less than 500 (half a second) or higher than 60000 (a full minute). -->'
,'        <notification  minimumLevel="'..dnl()..'"  updateIntervalMs="2000"  ignoreHelpboxVisibility="false" />'
,''
,'        <!-- Size of the font is measured in percentage of the screen-height, which goes from 0.0000 (0%) to 1.0000 (100%)'
,'             Next row position is calculated from \'size + rowSpacing\', which then gives the rowHeight. -->'
,'        <font  size="0.011"  rowSpacing="-0.001"  shadowOffset="0.00128"  shadowColor="black" />'
,''
,'        <!-- Left/Bottom is at 0.0000 (0%) and right/top is at 1.0000 (100%) -->'
,'        <placementInDisplay  positionXY="0.000 0.999" />'
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
,'    </general>'
,''
,'    <notifications>'
,'        <collisionDetection whenBelowThreshold="1" /> <!-- threshold unit is "km/h" -->'
,''
,'        <!-- Set  enabled="false"   to disable a particular notification.'
,'             Set  level="<number>"  to change the level of a notification. -->'
,''
,'        <!-- Controller notifications/colors -->'
,'        <notification  enabled="true"  type="controlledByMe"            level="'..dnl( 1)..'"   color="green" />'
,'        <notification  enabled="true"  type="controlledByPlayer"        level="'..dnl( 1)..'"   color="white" />'
,'        <notification  enabled="true"  type="controlledByHiredWorker"   level="'..dnl( 1)..'"   color="blue" />'
,'        <notification  enabled="true"  type="controlledByCourseplay"    level="'..dnl( 1)..'"   color="blue" />'
,'        <notification  enabled="true"  type="controlledByFollowMe"      level="'..dnl( 1)..'"   color="blue" />'
,'        <notification  enabled="true"  type="controlledByAutoDrive"     level="'..dnl( 1)..'"   color="blue" />'
,''
,'        <notification  enabled="true"  type="hiredWorkerFinished"       level="'..dnl( 3)..'"   color="orange" />'
,'        <notification  enabled="true"  type="engineOnButNotControlled"  level="'..dnl( 0)..'"   color="yellow"/>'
,'        <notification  enabled="true"  type="vehicleBroken"             level="'..dnl( 0)..'"   color="red" />'
,''
,'        <notification  enabled="true"  type="vehicleCollision"          level="'..dnl( 3)..'"   whenBelow=""      whenAbove="10000"  color="red"    /> <!-- threshold unit is "milliseconds" -->'
,'        <notification  enabled="true"  type="vehicleIdleMovement"       level="'..dnl(-2)..'"   whenBelow="0.5"   whenAbove=""                      /> <!-- threshold unit is "km/h" -->'
,'        <notification  enabled="true"  type="vehicleFuelLow"            level="'..dnl( 0)..'"   whenBelow="5"     whenAbove=""       color="red"    /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="vehicleDirtAmount"         level="'..dnl(-2)..'"   whenBelow=""      whenAbove="90"     color="yellow" /> <!-- threshold unit is "percentage" -->'
,''
,'        <!-- Vehicles/trailers fill-level -->'
,'        <notification  enabled="true"  type="grainTankFull"  > <!-- threshold unit is "percentage" -->'
,'            <threshold  level="'..dnl( 2)..'"  whenBelow=""  whenAbove="99"  color="red"     blinkIcon="true" />'
,'            <threshold  level="'..dnl( 0)..'"  whenBelow=""  whenAbove="80"  color="yellow"  blinkIcon="true" />'
,'        </notification>'
,'        <notification  enabled="true"  type="forageWagonFull"  > <!-- threshold unit is "percentage" -->'
,'            <threshold  level="'..dnl( 0)..'"  whenBelow=""  whenAbove="99"  color="yellow" />'
,'        </notification>'
,'        <notification  enabled="true"  type="baleLoaderFull"  > <!-- threshold unit is "percentage" -->'
,'            <threshold  level="'..dnl( 1)..'"  whenBelow=""  whenAbove="99"  color="yellow" />'
,'        </notification>'
,'        <notification  enabled="true"  type="trailerFull"  > <!-- threshold unit is "percentage" -->'
,'            <threshold  level="'..dnl( 0)..'"  whenBelow=""  whenAbove="99.99"  color="orange" />'
,'            <threshold  level="'..dnl(-1)..'"  whenBelow=""  whenAbove="80"     color="yellow" />'
,'        </notification>'
,'        <notification  enabled="true"  type="liquidsLow"  > <!-- threshold unit is "percentage" -->'
,'            <threshold  level="'..dnl( 0)..'"  whenBelow="5"  whenAbove="0"  color="red" />'
,'        </notification>'
,'        <notification  enabled="true"  type="sprayerLow"  > <!-- threshold unit is "percentage" -->'
,'            <threshold  level="'..dnl( 0)..'"  whenBelow="2"  whenAbove="-1"  color="red" />'
,'        </notification>'
,'        <notification  enabled="true"  type="seederLow" > <!-- threshold unit is "percentage" -->'
,'            <threshold  level="'..dnl( 0)..'"  whenBelow="2"  whenAbove="-1"  color="red" />'
,'        </notification>'
,''
--[[
,'        <!-- Fields specific -->'           
,'        <notification  enabled="true"  type="balesWithinFields"             level="'..dnl(-1)..'"   whenBelow=""  whenAbove="0"  color="yellow" /> <!-- threshold unit is "units" -->'
,'        <notification  enabled="false" type="balesOutsideFields"            level="'..dnl(-2)..'"   whenBelow=""  whenAbove="0"  color="yellow" /> <!-- threshold unit is "units" -->'
,''
--]]
,'        <!-- Show bunker silo fill-level, but only when being inside the silo area -->'
,'        <notification  enabled="true"  type="proximity:bunkerSilo"                level="'..dnl(0)..'"  />'
,''
,'        <!-- Show greenhouse fill-level, but only when being near the greenhouse -->'
,'        <notification  enabled="true"  type="proximity:greenhouse"                level="'..dnl(0)..'"  />'
,''
,'        <!-- Show slurry fill-level, but only when being near the fill-trigger -->'
,'        <notification  enabled="true"  type="proximity:liquidManureFillTrigger"   level="'..dnl(0)..'"  />'
,''
,'        <!-- Animal husbandry - Animals (amount), Productivity, Wool pallet, Eggs (pickup objects), Cleanliness -->'
,'        <notification  enabled="true"  type="husbandry:chicken:PickupObjects" > <!-- threshold unit is "percentage" -->'
,'              <threshold  level="'..dnl(-2)..'"  whenBelow=""  whenAbove="99.99"  color="yellow" />'
,'        </notification>'
,''
,'        <notification  enabled="true"  type="husbandry:sheep:Pallet"  > <!-- threshold unit is "percentage" -->'
,'              <threshold  level="'..dnl( 1)..'"  whenBelow=""  whenAbove="99.99"  color="red"    />'
,'              <threshold  level="'..dnl( 0)..'"  whenBelow=""  whenAbove="95"     color="yellow" />'
,'        </notification>'
,''
,'        <notification  enabled="true"  type="husbandry:Productivity" > <!-- threshold unit is "percentage" -->'
,'              <threshold  level="'..dnl( 2)..'"  whenBelow="75"  whenAbove=""  color="red"     />'
,'              <threshold  level="'..dnl( 1)..'"  whenBelow="85"  whenAbove=""  color="orange"  />'
,'              <threshold  level="'..dnl( 0)..'"  whenBelow="95"  whenAbove=""  color="yellow"  />'
,'        </notification>'
,'        <notification  enabled="true"  type="husbandry:sheep:Productivity" > <!-- threshold unit is "percentage" -->'
,'              <threshold  level="'..dnl( 0)..'"  whenBelow="90"  whenAbove=""  color="yellow" />'
,'        </notification>'
,''
,'        <notification  enabled="true"  type="husbandry:Cleanliness"  > <!-- threshold unit is "percentage" -->'
,'              <threshold  level="'..dnl( 1)..'"  whenBelow="5"   whenAbove="-1"   color="red"     />'
,'              <threshold  level="'..dnl( 0)..'"  whenBelow="10"  whenAbove="-1"   color="yellow"  />'
,'        </notification>'
,''
,'        <notification  enabled="true"  type="husbandry:sheep:Animals" > <!-- threshold unit is "units" -->'
,'              <threshold  level="'..dnl( 1)..'"  whenBelow=""  whenAbove="299"  color="red" />'
,'              <threshold  level="'..dnl( 0)..'"  whenBelow=""  whenAbove="99"   color="yellow" />'
,'        </notification>'
,'        <notification  enabled="true"  type="husbandry:pig:Animals" > <!-- threshold unit is "units" -->'
,'              <threshold  level="'..dnl( 1)..'"  whenBelow=""  whenAbove="299"  color="red" />'
,'              <threshold  level="'..dnl( 0)..'"  whenBelow=""  whenAbove="99"   color="yellow" />'
,'        </notification>'
,'        <notification  enabled="true"  type="husbandry:cow:Animals" > <!-- threshold unit is "units" -->'
,'              <threshold  level="'..dnl( 1)..'"  whenBelow=""  whenAbove="299"  color="red" />'
,'              <threshold  level="'..dnl( 0)..'"  whenBelow=""  whenAbove="99"   color="yellow" />'
,'        </notification>'
,''
,'        <!-- Animal husbandry - Fill-level -->'
,'        <!--                                "husbandry[:<animalTypeName>]:<fillTypeName>"  -->'
,'        <notification  enabled="true"  type="husbandry:cow:manure"     level="'..dnl( 0)..'"   whenBelow=""     whenAbove="70000"  color="yellow" /> <!-- threshold unit is "units" -->'
,'        <notification  enabled="true"  type="husbandry:pig:manure"     level="'..dnl( 0)..'"   whenBelow=""     whenAbove="70000"  color="yellow" /> <!-- threshold unit is "units" -->'
,'        <notification  enabled="true"  type="husbandry:milk"           level="'..dnl(-1)..'"   whenBelow=""     whenAbove="10000"  color="yellow" /> <!-- threshold unit is "units" -->'
,'        <notification  enabled="true"  type="husbandry:liquidManure"   level="'..dnl( 0)..'"   whenBelow=""     whenAbove="90"     color="yellow" /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="husbandry:water"          level="'..dnl( 1)..'"   whenBelow="25"   whenAbove=""       color="yellow" /> <!-- threshold unit is "percentage" -->'
,''
,'        <!-- Animal husbandry - Food group fill-level -->'
,'        <!--                                "husbandry[:<animalTypeName>]:foodGroup[:<foodGroupName>]"  -->'
,'        <notification  enabled="true"  type="husbandry:sheep:foodGroup:grass"   level="'..dnl( 1)..'"   whenBelow="25"  whenAbove=""  color="yellow" /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="husbandry:cow:foodGroup:grass"     level="'..dnl( 1)..'"   whenBelow="25"  whenAbove=""  color="yellow" /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="husbandry:cow:foodGroup:bulk"      level="'..dnl( 1)..'"   whenBelow="25"  whenAbove=""  color="yellow" /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="husbandry:cow:foodGroup:power"     level="'..dnl( 1)..'"   whenBelow="25"  whenAbove=""  color="yellow" /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="husbandry:pig:foodGroup:base"      level="'..dnl( 1)..'"   whenBelow="25"  whenAbove=""  color="yellow" /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="husbandry:pig:foodGroup:grain"     level="'..dnl( 1)..'"   whenBelow="25"  whenAbove=""  color="yellow" /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="husbandry:pig:foodGroup:protein"   level="'..dnl( 1)..'"   whenBelow="25"  whenAbove=""  color="yellow" /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="husbandry:pig:foodGroup:earth"     level="'..dnl( 1)..'"   whenBelow="25"  whenAbove=""  color="yellow" /> <!-- threshold unit is "percentage" -->'
,''
,'        <!-- Placeable - Fill-level -->'
,'        <!--                                "placeable:Greenhouse[:<fillTypeName>]"  -->'
,'        <notification  enabled="true"  type="placeable:Greenhouse:water"    level="'..dnl(0)..'"   whenBelow="5"  whenAbove="-1"  color="yellow" /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="placeable:Greenhouse:manure"   level="'..dnl(0)..'"   whenBelow="5"  whenAbove="-1"  color="yellow" /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="false" type="placeable:Greenhouse"          level="'..dnl(0)..'"   whenBelow="5"  whenAbove="-1"  color="yellow" /> <!-- threshold unit is "percentage" -->'
--[[
,'        <!-- mod support -->'
,'        <notification  enabled="false" type="placeable:MischStation:wheat_windrow"    level="'..dnl(-1)..'"   whenBelow="1"   whenAbove=""  color="yellow"  text="Straw"  /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="false" type="placeable:MischStation:barley_windrow"   level="'..dnl(-1)..'"   whenBelow="1"   whenAbove=""  color="yellow"  text="Straw"  /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="false" type="placeable:MischStation:grass_windrow"    level="'..dnl(-1)..'"   whenBelow="1"   whenAbove=""  color="yellow"  text="Grass"  /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="false" type="placeable:MischStation:dryGrass_windrow" level="'..dnl(-1)..'"   whenBelow="1"   whenAbove=""  color="yellow"  text="Grass"  /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="false" type="placeable:MischStation:silage"           level="'..dnl(-1)..'"   whenBelow="1"   whenAbove=""  color="yellow"  text="Silage" /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="placeable:MischStation:forage"           level="'..dnl( 0)..'"   whenBelow="10"  whenAbove=""  color="yellow"  text="TMR"    /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="false" type="placeable:MischStation"                  level="'..dnl(-1)..'"   whenBelow="10"  whenAbove=""  color="yellow"                /> <!-- threshold unit is "percentage" -->'

,'        <notification  enabled="true" type="placeable:Saegewerk:woodChips"   level="'..dnl(-1)..'" > <!-- threshold unit is "percentage" -->'
,'              <threshold  level="'..dnl( 1)..'"  whenAbove="99.99" color="red"       />'
,'              <threshold  level="'..dnl( 0)..'"  whenAbove="95"    color="yellow"    />'
,'        </notification>'
,'        <notification  enabled="true" type="placeable:Saegewerk:boardWood"   level="'..dnl(-1)..'" > <!-- threshold unit is "percentage" -->'
,'              <threshold  level="'..dnl( 1)..'"  whenAbove="99.99" color="red"       />'
,'              <threshold  level="'..dnl( 0)..'"  whenAbove="95"    color="yellow"    />'
,'        </notification>'
,'        <notification  enabled="false" type="placeable:Saegewerk:fuel"        level="'..dnl(-1)..'" > <!-- threshold unit is "percentage" -->'
,'              <threshold  level="'..dnl( 1)..'"  whenBelow="1"     color="red"       />'
,'              <threshold  level="'..dnl( 0)..'"  whenBelow="3"     color="yellow"    />'
,'        </notification>'
,'        <notification  enabled="false" type="placeable:Saegewerk:logs"        level="'..dnl(-1)..'" > <!-- threshold unit is "percentage" -->'
,'              <threshold  level="'..dnl( 1)..'"  whenBelow="1"     color="red"       />'
,'              <threshold  level="'..dnl( 0)..'"  whenBelow="5"     color="yellow"    />'
,'        </notification>'

,'        <notification  enabled="true" type="placeable:LettuceGreenhouse:lettuce"     level="'..dnl(-1)..'" > <!-- threshold unit is "percentage" -->'
,'              <threshold  level="'..dnl( 1)..'"  whenAbove="99.99" color="red"    />'
,'              <threshold  level="'..dnl( 0)..'"  whenAbove="95"    color="yellow" />'
,'        </notification>'
,'        <notification  enabled="true" type="placeable:LettuceGreenhouse:chaff"       level="'..dnl(-1)..'" > <!-- threshold unit is "percentage" -->'
,'              <threshold  level="'..dnl( 1)..'"  whenAbove="99.99" color="red"    />'
,'              <threshold  level="'..dnl( 0)..'"  whenAbove="95"    color="yellow" />'
,'        </notification>'
,'        <notification  enabled="false" type="placeable:LettuceGreenhouse:fuel"        level="'..dnl(-1)..'" > <!-- threshold unit is "percentage" -->'
,'              <threshold  level="'..dnl( 1)..'"  whenBelow="1"     color="red"       />'
,'              <threshold  level="'..dnl( 0)..'"  whenBelow="3"     color="yellow"    />'
,'        </notification>'
,'        <notification  enabled="false" type="placeable:LettuceGreenhouse:water"       level="'..dnl(-1)..'" > <!-- threshold unit is "percentage" -->'
,'              <threshold  level="'..dnl( 1)..'"  whenBelow="1"     color="red"       />'
,'              <threshold  level="'..dnl( 0)..'"  whenBelow="3"     color="yellow"    />'
,'        </notification>'
,'        <notification  enabled="false" type="placeable:LettuceGreenhouse:seeds"       level="'..dnl(-1)..'" > <!-- threshold unit is "percentage" -->'
,'              <threshold  level="'..dnl( 1)..'"  whenBelow="1"     color="red"       />'
,'              <threshold  level="'..dnl( 0)..'"  whenBelow="3"     color="yellow"    />'
,'        </notification>'
,'        <notification  enabled="false" type="placeable:LettuceGreenhouse:fertilizer"  level="'..dnl(-1)..'" > <!-- threshold unit is "percentage" -->'
,'              <threshold  level="'..dnl( 1)..'"  whenBelow="1"     color="red"       />'
,'              <threshold  level="'..dnl( 0)..'"  whenBelow="3"     color="yellow"    />'
,'        </notification>'
,''
--]]
,'    </notifications>'
,''
,'    <!-- The following line, controls how the formatting of animals/placeables should be.'
,'         The `separator` specifies what string should be printed between the types of animals/placeables notifications.'
,'         The `fillLevelFormat` MUST contain three `%s` format-specifiers; first will be the delimiter, second is the fillType-name and third is the fill-level/percentage.'
,'         Example: if using `separator=" * " fillLevelFormat="%s%s@%s"` then the rendered output on screen would look something like:'
,'                  "Sheep:Grass@230 * Cows:TMR@998,Manure@100% * Greenhouse(x4):Water@9%"             -->'
,'    <nonVehicles  separator="  //  "  fillLevelFormat="%s %s %s" />'
,''
,'    <!-- -->'
,'    <allFillLvls  separator=","  fillLevelFormat="%s%s(%s)" />'
,'    <allFillPcts  separator=","  fillLevelFormat="%s%s@%s" />'
,''
,'    <vehiclesColumnOrder columnSpacing="0.0020">'
,'        <!-- Set  enabled="false"  to disable a column.'
,'             It is possible to reorder columns. -->'
,'        <column  enabled="true"  contains="VehicleGroupsSwitcherNumber"  color="gray"            align="right"   minWidthText=""                  />'
,'        <column  enabled="true"  contains="VehicleController;HiredWorkerFinished;VehicleBroken"  align="right"   minWidthText=""                  />'
,'        <column  enabled="true"  contains="ColumnDelim"                  color="gray"            align="center"  minWidthText=""                  text="'..Glance.cColumnDelimChar..'" />'
,'        <column  enabled="true"  contains="VehicleMovementSpeed;Collision"                       align="right"   minWidthText=""                  />'
,'        <column  enabled="true"  contains="ColumnDelim"                  color="gray"            align="center"  minWidthText=""                  text="'..Glance.cColumnDelimChar..'" />'
,'        <column  enabled="false" contains="VehicleAtWorldPositionXZ"                             align="left"    minWidthText=""                  />'
,'        <column  enabled="true"  contains="VehicleAtWorldCorner"                                 align="center"  minWidthText="MN"                />'
,'        <column  enabled="true"  contains="VehicleAtFieldNumber"                                 align="left"    minWidthText=""                  />'
,'        <column  enabled="true"  contains="ColumnDelim"                  color="gray"            align="center"  minWidthText=""                  text="'..Glance.cColumnDelimChar..'" />'
,'        <column  enabled="true"  contains="VehicleName;FuelLow"                                  align="left"    minWidthText=""  maxTextLen="20" />'
,'        <column  enabled="false" contains="FuelLevel;FuelLevelPct"                               align="left"    minWidthText=""                  />'
,'        <column  enabled="true"  contains="ColumnDelim"                  color="gray"            align="center"  minWidthText=""                  text="'..Glance.cColumnDelimChar..'" />'
,'        <column  enabled="true"  contains="FillLevel"                                            align="right"   minWidthText=""                  />'
,'        <column  enabled="true"  contains="ColumnDelim"                                          align="right"   minWidthText="I"                 text="" />'
,'        <column  enabled="true"  contains="FillPercent"                                          align="center"  minWidthText=""                  />'
,'        <column  enabled="true"  contains="ColumnDelim"                                          align="left"    minWidthText="I"                 text="" />'
,'        <column  enabled="true"  contains="FillTypeName"                                         align="left"    minWidthText=""  maxTextLen="12" />'
,'        <column  enabled="true"  contains="ColumnDelim"                  color="gray"            align="center"  minWidthText=""                  text="'..Glance.cColumnDelimChar..'" />'
,'        <column  enabled="true"  contains="ActiveTask;EngineOn;DirtAmount"                       align="left"    minWidthText=""                  />'
,'        <column  enabled="false" contains="ColumnDelim"                  color="gray"            align="center"  minWidthText=""                  text="'..Glance.cColumnDelimChar..'" />'
,'        <column  enabled="false" contains="AllFillLvls;AllFillPcts"                              align="left"    minWidthText=""                  />'
,'    </vehiclesColumnOrder>'
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
        print("## Glance: Could not create a new configuration file!")
        print("## Glance: Please check that the file is not locked or read-only; " .. fileName);
    else
        fHndl:write(self:getDefaultConfig())
        fHndl:close()
        fHndl = nil
    end
end

function Glance:loadConfig()
    Glance.notifications = {}
    Glance.columnOrder = {}

    -- Attempt (possibly futile) at somehow making a 'standard folder' for setting-/config-files for mods.
    local folder = getUserProfileAppPath() .. "modsSettings";
    
    --
    local fileName = folder .. "/" .. "Glance_Config.XML";
    local tag = "glanceConfig"

    local xmlFile = nil
    if g_dedicatedServerInfo ~= nil then
        print("## Glance: Seems to be running on a dedicated-server. So default built-in configuration values will be used.");
        xmlFile = loadXMLFileFromMemory(tag, self:getDefaultConfig(), true)
    elseif fileExists(fileName) then
        xmlFile = loadXMLFile(tag, fileName)
    else
        print("## Glance: Trying to create a new default configuration file; " .. fileName);
        createFolder(folder)
        self:createNewConfig(fileName)
        xmlFile = loadXMLFile(tag, fileName)
    end;

    --
    local version = getXMLInt(xmlFile, "glanceConfig#version")
    if xmlFile == nil or version == nil then
        print("## Glance: Looks like an error may have occurred, when Glance tried to load its configuration file.");
        print("## Glance: This could be due to a corrupted XML structure, or otherwise problematic file-handling.");
        print("!! Glance: Please quit the game and fix the XML or delete the file to let Glance create a new one; " .. fileName);
        Glance.failedConfigLoad = g_currentMission.time + 10000;
        return;
    end
    if Glance.cCfgVersionsSupported[version] ~= true then
        print("!! Glance: The existing Glance_Config.XML file is of a not supported version '"..tostring(version).."', and will NOT be loaded.")
        print("!! Glance: Please quit the game and fix the XML or delete the file to let Glance create a new one; " .. fileName);
        Glance.failedConfigLoad = g_currentMission.time + 10000;
        return;
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
            print("!! Glance: Glance_Config.XML has invalid color setting, for color name: "..tostring(colorName));
        end
    end
    --
    local function getColorName(xmlFile, tag, defaultColorName)
        local colorName = getXMLString(xmlFile, tag)
        if colorName ~= nil then
            if Glance.colors[colorName] ~= nil then
                return colorName
            end
            print("!! Glance: Glance_Config.XML has invalid color-name '"..tostring(colorName).."', in: "..tostring(tag));
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
    Glance.cLineSpacing     = Glance.cFontSize + Utils.getNoNil(getXMLFloat(xmlFile, tag.."#rowSpacing"), Glance.cLineSpacing - Glance.cFontSize)
    --
    local tag = "glanceConfig.general.placementInDisplay"
    local posX,posY = Utils.getVectorFromString(getXMLString(xmlFile, tag.."#positionXY"))
    Glance.cStartLineX      = Utils.getNoNil(tonumber(posX), Glance.cStartLineX)
    Glance.cStartLineY      = Utils.getNoNil(tonumber(posY), Glance.cStartLineY)
    --
    local tag = "glanceConfig.general.notification"
    
    Glance.minNotifyLevel = Utils.getNoNil(getXMLInt(xmlFile, tag.."#minimumLevel"), 4)
    Glance.textMinLevelTimeout = g_currentMission.time + 2000
    
    Glance.updateIntervalMS = Utils.clamp(Utils.getNoNil(getXMLInt(xmlFile, tag.."#updateIntervalMs"), Glance.updateIntervalMS), 500, 60000)
    Glance.ignoreHelpboxVisibility = Utils.getNoNil(getXMLBool(xmlFile, tag.."#ignoreHelpboxVisibility"), Glance.ignoreHelpboxVisibility)
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
            ,notifyType     =                getXMLString( xmlFile, tag.."#type")
            ,level          = Utils.getNoNil(getXMLInt(    xmlFile, tag.."#level"), 0)
            ,aboveThreshold = Utils.getNoNil(getXMLFloat(  xmlFile, tag.."#whenAbove"), getXMLFloat(xmlFile, tag.."#whenAboveThreshold")) -- Still support old-config attributes.
            ,belowThreshold = Utils.getNoNil(getXMLFloat(  xmlFile, tag.."#whenBelow"), getXMLFloat(xmlFile, tag.."#whenBelowThreshold")) -- Still support old-config attributes.
            ,text           =                getXMLString( xmlFile, tag.."#text")
            ,color          =                getColorName( xmlFile, tag.."#color", nil)
        }
        --
        Glance.notifications[notifyType].thresholds = {}
        local j=0
        while true do
            local subTag = ("%s.threshold(%d)"):format(tag, j)
            j=j+1
            if not hasXMLProperty(xmlFile, subTag.."#level") then
                break
            end
            Glance.notifications[notifyType].thresholds[j] = {
                 level          = Utils.getNoNil(getXMLInt(    xmlFile, subTag.."#level"), 0)
                ,aboveThreshold =                getXMLFloat(  xmlFile, subTag.."#whenAbove")
                ,belowThreshold =                getXMLFloat(  xmlFile, subTag.."#whenBelow")
                ,text           =                getXMLString( xmlFile, subTag.."#text")
                ,color          =                getColorName( xmlFile, subTag.."#color", nil)
                ,blinkIcon      =                getXMLBool(   xmlFile, subTag.."#blinkIcon")
            }
            --
            Glance.notifications[notifyType].level = math.max(Glance.notifications[notifyType].level, Glance.notifications[notifyType].thresholds[j].level)
        end
        --
        Glance.maxNotifyLevel = math.max(Glance.maxNotifyLevel, Glance.notifications[notifyType].level)
    end
    --
    Glance.collisionDetection_belowThreshold = Utils.getNoNil(getXMLFloat(xmlFile, "glanceConfig.notifications.collisionDetection#whenBelowThreshold"), Glance.collisionDetection_belowThreshold);

    Glance.nonVehiclesSeparator = Utils.getNoNil(getXMLString(xmlFile, "glanceConfig.nonVehicles#separator"), Glance.nonVehiclesSeparator);
    Glance.nonVehiclesFillLevelFormat = Utils.getNoNil(getXMLString(xmlFile, "glanceConfig.nonVehicles#fillLevelFormat"), Glance.nonVehiclesFillLevelFormat);

    Glance.allFillLvlsSeparator = Utils.getNoNil(getXMLString(xmlFile, "glanceConfig.allFillLvls#separator"), Glance.allFillLvlsSeparator);
    Glance.allFillLvlsFormat    = Utils.getNoNil(getXMLString(xmlFile, "glanceConfig.allFillLvls#fillLevelFormat"), Glance.allFillLvlsFormat);
    Glance.allFillPctsSeparator = Utils.getNoNil(getXMLString(xmlFile, "glanceConfig.allFillPcts#separator"), Glance.allFillPctsSeparator);
    Glance.allFillPctsFormat    = Utils.getNoNil(getXMLString(xmlFile, "glanceConfig.allFillPcts#fillLevelFormat"), Glance.allFillPctsFormat);
    
    --
    Glance.columnSpacingTxt = Utils.getNoNil(getXMLString(xmlFile, "glanceConfig.vehiclesColumnOrder#columnSpacing"), Glance.columnSpacingTxt);
    Glance.columnSpacing = tonumber(Glance.columnSpacingTxt)
    if Glance.columnSpacing == nil then
        Glance.columnSpacing = Utils.getNoNil(getTextWidth(Glance.cFontSize, Glance.columnSpacingTxt), 0.001)
    end

    local i=0
    while true do
        local tag = string.format("glanceConfig.vehiclesColumnOrder.column(%d)", i)
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

    Glance.failedConfigLoad = nil;
    if g_dedicatedServerInfo == nil then
        print("## Glance: (Re)Loaded settings from: "..fileName)
    end
end

-----

function Glance:setProperty(obj, propKey, propValue, noEventSend)
    if obj == nil or obj == Glance then
        obj = Glance;
        netId = 0;
    else
        netId = networkGetObjectId(obj);
    end
    
    if obj.modGlance == nil then
        obj.modGlance = {}
    end
    if obj.modGlance[propKey] ~= propValue and noEventSend ~= true then
        self.makeUpdateEventFor[netId] = obj;
    end
    obj.modGlance[propKey] = propValue;
end

function Glance:getProperty(obj, propKey)
    if obj == nil then
        obj = Glance
    end
    if obj.modGlance ~= nil then
        return obj.modGlance[propKey];
    end
    return nil
end

-----

local function getNotificationColor(colorName, alternativeColorName)
    if colorName ~= nil and Glance.colors[colorName] ~= nil then
        return Glance.colors[colorName]
    end
    if alternativeColorName ~= nil and Glance.colors[alternativeColorName] ~= nil then
        return Glance.colors[alternativeColorName]
    end
    return Glance.colors[Glance.lineColorDefault]
end

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

local function isNotifyEnabled(ntfy)
    return (ntfy ~= nil and ntfy.enabled == true)
end

local function isNotifyLevel(ntfy)
    return (ntfy ~= nil and ntfy.enabled == true and ntfy.level >= Glance.minNotifyLevel)
end    

local function isBreakingThresholds(ntfy, value, oldValue)
    if (ntfy ~= nil and ntfy.enabled == true and ntfy.level >= Glance.minNotifyLevel and value ~= nil) then
        local thlds = ntfy.thresholds
        if ntfy.belowThreshold ~= nil or ntfy.aboveThreshold ~= nil then
            thlds = { ntfy, unpack(ntfy.thresholds) }
        end
        for _,thld in ipairs( thlds ) do
            if (thld.level >= Glance.minNotifyLevel) then
                if (thld.belowThreshold == nil and thld.aboveThreshold ~= nil) then
                    -- Only test above
                    if (value > thld.aboveThreshold) then
                        newValue = math.max(value, Utils.getNoNil(oldValue, value))
                        return { value=newValue, threshold=thld }
                    end
                elseif (thld.belowThreshold ~= nil and thld.aboveThreshold == nil) then
                    -- Only test below
                    if (value < thld.belowThreshold) then
                        newValue = math.min(value, Utils.getNoNil(oldValue, value))
                        return { value=newValue, threshold=thld }
                    end
                elseif (thld.belowThreshold ~= nil and thld.aboveThreshold ~= nil) then
                    -- Either test outside or inside
                    if (thld.belowThreshold < thld.aboveThreshold) then
                        -- Only test outside
                        if (value < thld.belowThreshold) then
                            newValue = math.min(value, Utils.getNoNil(oldValue, value))
                            return { value=newValue, threshold=thld }
                        elseif (thld.aboveThreshold < value) then
                            newValue = math.max(value, Utils.getNoNil(oldValue, value))
                            return { value=newValue, threshold=thld }
                        end
                    elseif (thld.belowThreshold > thld.aboveThreshold) then
                        -- Only test inside
                        if (thld.aboveThreshold < value and value < thld.belowThreshold) then
                            newValue = math.max(value, Utils.getNoNil(oldValue, value)) -- TODO. Calculate closest distance to either above or below, and use that as new value.
                            return { value=newValue, threshold=thld }
                        end
                    end
                end
            end
        end
    end
    return nil
end

-----

function Glance.buildFieldsRects()

    local function getFieldRects(field)
        local rects = {}
        if field ~= nil and field.fieldDimensions ~= nil then
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
            
                table.insert(rects, {x1=x1,z1=z1,x2=x2,z2=z2})
            end;
        end;
        return rects;
    end

    if  g_currentMission.fieldDefinitionBase ~= nil 
    and g_currentMission.fieldDefinitionBase.fieldDefs ~= nil 
    then
        for fieldNum,fieldDef in ipairs(g_currentMission.fieldDefinitionBase.fieldDefs) do
            Glance.fieldsRects[fieldNum] = getFieldRects(fieldDef)
        end
    end
end

-----

function Glance:makeFieldsLine(dt, notifyList)
--[[
    local balesWithinFields  = Glance.notifications["balesWithinFields"]
    local balesOutsideFields = Glance.notifications["balesOutsideFields"]

    if g_currentMission.itemsToSave ~= nil 
    and (isNotifyLevel(balesWithinFields) or isNotifyLevel(balesOutsideFields))
    then
        local constNumFields = table.getn(g_currentMission.fieldDefinitionBase.fieldDefs)
        local fieldsBales = {}
        local lastFieldDefIdx = 1; -- Its likely that "the next bale" is within "the same field" that was just found previously.

        -- Find all bales...
        for _,item in pairs(g_currentMission.itemsToSave) do
            if item.className == "Bale" then -- TO DO - there must be a faster way than string-compare.
                local maxIter = constNumFields
                -- Get position of bale in the world
                local wx,_,wz = getWorldTranslation(item.item.nodeId);
                if wx~=wx or wz~=wz then
                    -- Something is very wrong with the coordinates
                else
                    -- Find field the bale is within    -- TODO - maybe change this to a binary-space-partitioned search somehow?
                    lastFieldDefIdx = lastFieldDefIdx - 1
                    while (maxIter > 0) do
                        lastFieldDefIdx = (lastFieldDefIdx % constNumFields) + 1
                        maxIter = maxIter - 1
                        for _,rect in pairs(Glance.fieldsRects[lastFieldDefIdx]) do
                            if  rect.x1 <= wx and wx <= rect.x2
                            and rect.z1 <= wz and wz <= rect.z2 then
                                -- Found field, increase its number of bales
                                fieldsBales[lastFieldDefIdx] = 1 + Utils.getNoNil(fieldsBales[lastFieldDefIdx],0)
                                maxIter = -1 -- Magic number!
                                break
                            end
                        end
                    end
                end
                -- If not the magic number
                if maxIter ~= -1 then
                    -- Bale not within a known field
                    fieldsBales["0"] = 1 + Utils.getNoNil(fieldsBales["0"],0)
                end
            end
        end
        
        --
        if isNotifyLevel(balesWithinFields) then
            local txt = nil
            for fieldNum=1,constNumFields do
                if isBreakingThresholds(balesWithinFields, fieldsBales[fieldNum]) then
                    txt = Utils.getNoNil(txt,"") .. (g_i18n:getText("fieldNumAndBales")):format(fieldNum,fieldsBales[fieldNum]);
                end
            end
            if txt ~= nil then
                table.insert(notifyList, { getNotificationColor(balesWithinFields.color), g_i18n:getText("fieldsWithBales") .. txt });
            end
        end
        --
        if isBreakingThresholds(balesOutsideFields, fieldsBales["0"]) then
            table.insert(notifyList, { getNotificationColor(balesOutsideFields.color), (g_i18n:getText("balesElsewhere")):format(fieldsBales["0"]) });
        end
    end
--]]
end

-----

function Glance:makePlaceablesLine(dt, notifyList)

--[[
    g_currentMission.storages[].capacity
                               .fillLevels[<idx>]
                               .fillTypes[<idx>]    (fill-type-index)
                               .storageName         (string)

                               
    g_currentMission.ownedItems[].storeItem.category    'placeables'
                                           .species     'placeables'
                                           .xmlFilename
                                           .xmlFilenameLower
                                           
                                 .items[].
                               
--]]

    local function getNotification(placeableType,subElement)
        local keyArray = {}
        if subElement ~= nil then
            table.insert(keyArray, "placeable:"..placeableType..":"..subElement)
        else
            table.insert(keyArray, "placeable:"..placeableType)
        end
        for _,key in pairs(keyArray) do
            if Glance.notifications[key] ~= nil then
                return Glance.notifications[key]
            end
        end
        return nil
    end
    --
    local foundNotifications = {}
    local function updateNotification(placeableType, addItemCount, fillType, newLow, newHigh, newColorName)
        if foundNotifications[placeableType] == nil then
            foundNotifications[placeableType] = {}
            foundNotifications[placeableType].fillLevels = {}
            foundNotifications[placeableType].itemCount = 0
        end
        if addItemCount ~= nil then
            foundNotifications[placeableType].itemCount = foundNotifications[placeableType].itemCount + addItemCount
        end
        if fillType ~= nil then
            local pct = foundNotifications[placeableType].fillLevels[fillType]
            if newLow ~= nil and (pct == nil or pct > newLow) then
                foundNotifications[placeableType].fillLevels[fillType] = newLow
                if newColorName ~= nil then
                    foundNotifications[placeableType].color = newColorName
                end
            end
            if newHigh ~= nil and (pct == nil or pct < newHigh) then
                foundNotifications[placeableType].fillLevels[fillType] = newHigh
                if newColorName ~= nil then
                    foundNotifications[placeableType].color = newColorName
                end
            end
        end
    end

    --
    for _,oi in pairs(g_currentMission.ownedItems) do
      if  nil ~= oi.storeItem
      and "placeables" == oi.storeItem.category
      and nil ~= oi.storeItem.xmlFilenameLower
      then
        local funcTestPlaceable = nil
        local plcTable = oi.items
        local plcXmlFilename = oi.storeItem.xmlFilenameLower

        --
        if string.find(plcXmlFilename, "greenhouse") ~= nil then
            local placeableType = "Greenhouse"
            local ntfyGreenhouse = {}
            ntfyGreenhouse[FillUtil.FILLTYPE_WATER]   = getNotification(placeableType, "water")
            ntfyGreenhouse[FillUtil.FILLTYPE_MANURE]  = getNotification(placeableType, "manure")
            ntfyGreenhouse[FillUtil.FILLTYPE_UNKNOWN] = getNotification(placeableType)
            --
            funcTestPlaceable = function(plc)
                -- Make sure the variables we expect, are actually there.
                if not (    hasNumberValue(plc.waterTankFillLevel) and hasNumberValue(plc.waterTankCapacity,0)
                        and hasNumberValue(plc.manureFillLevel)    and hasNumberValue(plc.manureCapacity   ,0) )
                then
                    return
                end
                --
                local fillLevels = {}
                fillLevels[FillUtil.FILLTYPE_WATER]  = 100 * plc.waterTankFillLevel / plc.waterTankCapacity;
                fillLevels[FillUtil.FILLTYPE_MANURE] = 100 * plc.manureFillLevel    / plc.manureCapacity;
                
                if isNotifyEnabled(ntfyGreenhouse[FillUtil.FILLTYPE_UNKNOWN]) then
                    local minPct = math.min(fillLevels[FillUtil.FILLTYPE_WATER], fillLevels[FillUtil.FILLTYPE_MANURE])
                    local res = isBreakingThresholds(ntfyGreenhouse[FillUtil.FILLTYPE_UNKNOWN], minPct)
                    if res then
                        updateNotification(placeableType, 1, FillUtil.FILLTYPE_UNKNOWN, res.value, nil, res.threshold.color)
                    end
                else
                    local itemCount = nil
                    for fillType,ntfy in pairs(ntfyGreenhouse) do
                        if fillType ~= FillUtil.FILLTYPE_UNKNOWN then
                            local res = isBreakingThresholds(ntfy, fillLevels[fillType])
                            if res then
                                updateNotification(placeableType, nil, fillType, res.value, nil, res.threshold.color)
                                itemCount = 1
                            end
                        end
                    end
                    if itemCount ~= nil then
                        updateNotification(placeableType, itemCount)
                    end
                end
            end
        --elseif string.find(plcXmlFilename, "lettuce_greenhouse") ~= nil then
        --    local placeableType = "LettuceGreenhouse"
        --    local ntfyLettuceGreenhouse = {}
        --    for fillType,fillDesc in pairs(Fillable.fillTypeIndexToDesc) do
        --        local fillName = (fillType ~= Fillable.FILLTYPE_UNKNOWN and fillDesc.name or nil)
        --        local ntfy = getNotification(placeableType, fillName)
        --        if ntfy ~= nil then
        --            ntfyLettuceGreenhouse[fillType] = ntfy
        --        end
        --    end
        --    --
        --    local lettuceGreenhouseSpecialFillTypes = {
        --        [Glance.FILLTYPE_LETTUCE]="lettuce",
        --    }
        --    for fillType,fillName in pairs(lettuceGreenhouseSpecialFillTypes) do
        --        local ntfy = getNotification(placeableType, fillName)
        --        if ntfy ~= nil then
        --            ntfyLettuceGreenhouse[fillType] = ntfy
        --        end
        --    end
        --    --
        --    funcTestPlaceable = function(plc)
        --        -- Make sure the variables we expect, are actually there.
        --        if not ( plc.FabrikScriptDirtyFlag ~= nil and plc.Produkte ~= nil )
        --        then
        --            return
        --        end
        --        --
        --        local fillLevels = {}
        --        
        --        if plc.Produkte ~= nil then
        --            if plc.Produkte.lettuceboxes ~= nil then
        --                fillLevels[Glance.FILLTYPE_LETTUCE] = 100 * plc.Produkte.lettuceboxes.fillLevel / plc.Produkte.lettuceboxes.capacity
        --            end
        --            if plc.Produkte.lettuce_waste ~= nil then
        --                fillLevels[Fillable.FILLTYPE_CHAFF] = 100 * plc.Produkte.lettuce_waste.fillLevel / plc.Produkte.lettuce_waste.capacity
        --            end
        --        end
        --        if plc.Rohstoffe ~= nil then
        --            if plc.Rohstoffe.Dungemittel ~= nil then
        --                fillLevels[Fillable.FILLTYPE_FERTILIZER] = 100 * plc.Rohstoffe.Dungemittel.fillLevel / plc.Rohstoffe.Dungemittel.capacity
        --            end
        --            if plc.Rohstoffe.Diesel ~= nil then
        --                fillLevels[Fillable.FILLTYPE_FUEL] = 100 * plc.Rohstoffe.Diesel.fillLevel / plc.Rohstoffe.Diesel.capacity
        --            end
        --            if plc.Rohstoffe.Saatgut ~= nil then
        --                fillLevels[Fillable.FILLTYPE_SEEDS] = 100 * plc.Rohstoffe.Saatgut.fillLevel / plc.Rohstoffe.Saatgut.capacity
        --            end
        --            if plc.Rohstoffe.Wasser ~= nil then
        --                fillLevels[Fillable.FILLTYPE_WATER] = 100 * plc.Rohstoffe.Wasser.fillLevel / plc.Rohstoffe.Wasser.capacity
        --            end
        --        end
        --        
        --        local itemCount = nil
        --        for fillType,ntfy in pairs(ntfyLettuceGreenhouse) do
        --            if fillType ~= Fillable.FILLTYPE_UNKNOWN then
        --                local res = isBreakingThresholds(ntfy, fillLevels[fillType])
        --                if res then
        --                    updateNotification(placeableType, nil, fillType, res.value, nil, res.threshold.color)
        --                    itemCount = 1
        --                end
        --            end
        --        end
        --        if itemCount ~= nil then
        --            updateNotification(placeableType, itemCount)
        --        end
        --    end
        --elseif string.find(plcXmlFilename, "mischstation") ~= nil then
        --    local placeableType = "MischStation"
        --    local ntfyMischStation = {}
        --    for fillType,fillDesc in pairs(Fillable.fillTypeIndexToDesc) do
        --        local fillName = (fillType ~= Fillable.FILLTYPE_UNKNOWN and fillDesc.name or nil)
        --        local ntfy = getNotification(placeableType, fillName)
        --        if ntfy ~= nil then
        --            ntfyMischStation[fillType] = ntfy
        --        end
        --    end
        --    --
        --    funcTestPlaceable = function(plc)
        --        -- Make sure the variables we expect, are actually there.
        --        if not (    plc.SetLamp ~= nil and plc.MixLvl ~= nil and plc.LvLIndicator ~= nil and hasNumberValue(plc.LvLIndicator.capacity,0) 
        --                and plc.MixTypLvl ~= nil and plc.MixTypName ~= nil and plc.TipTriggers ~= nil )
        --        then
        --            return
        --        end
        --        --
        --        local fillLevels = {}
        --        fillLevels[Fillable.FILLTYPE_FORAGE] = 100 * plc.MixLvl / plc.LvLIndicator.capacity;
        --        local minPct = fillLevels[Fillable.FILLTYPE_FORAGE];
        --        for i=1,table.getn(plc.MixTypName) do
        --            if plc.MixTypName[i] ~= nil and plc.MixTypName[i].index ~= nil and plc.TipTriggers[i] ~= nil and hasNumberValue(plc.TipTriggers[i].capacity,0) then
        --                local fillType = plc.MixTypName[i].index
        --                local pct = 100 * plc.MixTypLvl[i] / plc.TipTriggers[i].capacity;
        --                fillLevels[fillType] = pct
        --                minPct = math.min(minPct,pct)
        --            end
        --        end
        --        
        --        if isNotifyEnabled(ntfyMischStation[Fillable.FILLTYPE_UNKNOWN]) then
        --            local res = isBreakingThresholds(ntfyMischStation[Fillable.FILLTYPE_UNKNOWN], minPct)
        --            if res then
        --                updateNotification(placeableType, 1, Fillable.FILLTYPE_UNKNOWN, res.value, nil, res.threshold.color)
        --            end
        --        else
        --            local itemCount = nil
        --            for fillType,ntfy in pairs(ntfyMischStation) do
        --                if fillType ~= Fillable.FILLTYPE_UNKNOWN then
        --                    local res = isBreakingThresholds(ntfy, fillLevels[fillType])
        --                    if res then
        --                        updateNotification(placeableType, nil, fillType, res.value, nil, res.threshold.color)
        --                        itemCount = 1
        --                    end
        --                end
        --            end
        --            if itemCount ~= nil then
        --                updateNotification(placeableType, itemCount)
        --            end
        --        end
        --    end
        --elseif string.find(plcXmlFilename, "saegewerk") ~= nil then
        --    local placeableType = "Saegewerk"
        --    local ntfySaegewerk = {}
        --    for fillType,fillDesc in pairs(Fillable.fillTypeIndexToDesc) do
        --        local fillName = (fillType ~= Fillable.FILLTYPE_UNKNOWN and fillDesc.name or nil)
        --        local ntfy = getNotification(placeableType, fillName)
        --        if ntfy ~= nil then
        --            ntfySaegewerk[fillType] = ntfy
        --        end
        --    end
        --    --
        --    local saegewerkSpecialFillTypes = {
        --        [Glance.FILLTYPE_BOARDWOOD]="boardWood",
        --        [Glance.FILLTYPE_LOGS]="logs",
        --    }
        --    for fillType,fillName in pairs(saegewerkSpecialFillTypes) do
        --        local ntfy = getNotification(placeableType, fillName)
        --        if ntfy ~= nil then
        --            ntfySaegewerk[fillType] = ntfy
        --        end
        --    end
        --    --
        --    funcTestPlaceable = function(plc)
        --        -- Make sure the variables we expect, are actually there.
        --        if not ( plc.FabrikScriptDirtyFlag ~= nil and plc.Produkte ~= nil )
        --        then
        --            return
        --        end
        --        --
        --        local fillLevels = {}
        --        
        --        if plc.Produkte ~= nil then
        --            if plc.Produkte.boardwood ~= nil then
        --                fillLevels[Glance.FILLTYPE_BOARDWOOD] = 100 * plc.Produkte.boardwood.fillLevel / plc.Produkte.boardwood.capacity
        --            end
        --            if plc.Produkte.woodChips ~= nil then
        --                fillLevels[Fillable.FILLTYPE_WOODCHIPS] = 100 * plc.Produkte.woodChips.fillLevel / plc.Produkte.woodChips.capacity
        --            end
        --        end
        --        if plc.Rohstoffe ~= nil then
        --            if plc.Rohstoffe.Brennstoffe ~= nil then
        --                fillLevels[Fillable.FILLTYPE_FUEL] = 100 * plc.Rohstoffe.Brennstoffe.fillLevel / plc.Rohstoffe.Brennstoffe.capacity
        --            end
        --            if plc.Rohstoffe.Holz ~= nil then
        --                fillLevels[Glance.FILLTYPE_LOGS] = 100 * plc.Rohstoffe.Holz.fillLevel / plc.Rohstoffe.Holz.capacity
        --            end
        --        end
        --        
        --        local itemCount = nil
        --        for fillType,ntfy in pairs(ntfySaegewerk) do
        --            if fillType ~= Fillable.FILLTYPE_UNKNOWN then
        --                local res = isBreakingThresholds(ntfy, fillLevels[fillType])
        --                if res then
        --                    updateNotification(placeableType, nil, fillType, res.value, nil, res.threshold.color)
        --                    itemCount = 1
        --                end
        --            end
        --        end
        --        if itemCount ~= nil then
        --            updateNotification(placeableType, itemCount)
        --        end
        --    end
        else
            -- TODO - Add other useful placeables???
        end

        --
        if funcTestPlaceable ~= nil and plcTable ~= nil then
            for _,plc in pairs(plcTable) do
                funcTestPlaceable(plc)
            end
        end
      end
    end
   
    --
    local function getFillType_NameI18N(fillType)
        local fillDesc = FillUtil.fillTypeIndexToDesc[fillType]
        if nil ~= fillDesc and nil ~= fillDesc.nameI18N then
            return fillDesc.nameI18N
        end
        return ("(unknown:%s)"):format(tostring(fillType))
    end
    
    for typ,elem in pairs(foundNotifications) do
        if g_i18n:hasText("TypeDesc_"..typ) then
            typ = g_i18n:getText("TypeDesc_"..typ)
        elseif g_i18n:hasText(typ) then
            typ = g_i18n:getText(typ)
        end
        local txt = string.upper(string.sub(typ,1,1))..string.sub(typ,2)
        if elem.itemCount ~= nil and elem.itemCount > 1 then
            txt = txt .. ("(x%d)"):format(elem.itemCount)
        end
        if elem.fillLevels[FillUtil.FILLTYPE_UNKNOWN] ~= nil then
            txt = txt .. (Glance.nonVehiclesFillLevelFormat):format("", "", ("%.0f%%"):format(elem.fillLevels[FillUtil.FILLTYPE_UNKNOWN]))
        else
            local prefix=":"
            for fillType,fillPct in pairs(elem.fillLevels) do
                if fillType ~= FillUtil.FILLTYPE_UNKNOWN then
                    txt = txt .. (Glance.nonVehiclesFillLevelFormat):format(prefix, getFillType_NameI18N(fillType), ("%.0f%%"):format(fillPct))
                    prefix=","
                end
            end
        end
        table.insert(notifyList, { getNotificationColor(elem.color), txt });
    end

    --
    if Glance.proximityObj ~= nil and Glance.proximityObj.type ~= nil then
        local ntfyProximity = Glance.notifications["proximity:" .. Glance.proximityObj.type]
        local func,obj = Glance.proximityObj.func, Glance.proximityObj.obj
        Glance.proximityObj = nil
        if isNotifyEnabled(ntfyProximity) and func ~= nil and obj ~= nil then
            local txt = func(obj)
            if txt ~= nil then
                table.insert(notifyList, { getNotificationColor(nil), txt });
            end
        end
    end
end

-----

GreenhousePlaceable.getShowInfo = Utils.overwrittenFunction(
    GreenhousePlaceable.getShowInfo,
    function(self, superFunc)
        local res = superFunc(self)
        
        if true == res and g_client ~= nil then
            Glance.proximityObj = {obj=self, type="greenhouse", func=Glance.getGreenhouseInfo}
        end
        
        return res
    end
)

function Glance.getGreenhouseInfo(greenhouseObj)
    local txt =    g_i18n:getText("info_waterFillLevel").." "..math.floor(greenhouseObj.waterTankFillLevel).." ("..math.floor(100*greenhouseObj.waterTankFillLevel/greenhouseObj.waterTankCapacity).."%)"
        .. ", " .. g_i18n:getText("info_manureFillLevel").." "..math.floor(greenhouseObj.manureFillLevel).." ("..math.floor(100*greenhouseObj.manureFillLevel/greenhouseObj.manureCapacity).."%)"
    return txt
end

---

LiquidManureFillTrigger.getShowInfo = Utils.overwrittenFunction(
    LiquidManureFillTrigger.getShowInfo,
    function(self, superFunc)
        local res = superFunc(self)
        
        if true == res and g_client ~= nil then
            Glance.proximityObj = {obj=self, type="liquidManureFillTrigger", func=Glance.getLiquidManureFillTriggerInfo}
        end
        
        return res
    end
)
    
function Glance.getLiquidManureFillTriggerInfo(fillTrigger)
    local txt = FillUtil.fillTypeIndexToDesc[fillTrigger.fillType].nameI18N .. " " ..g_i18n:getText("info_fillLevel").." "..math.floor(fillTrigger.fillLevel).." ("..math.floor(100*fillTrigger.fillLevel/fillTrigger.capacity).."%)"
    return txt
end

---

BunkerSilo.getCanInteract = Utils.overwrittenFunction(
    BunkerSilo.getCanInteract,
    function(self, superFunc, showInformationOnly)
        local res = superFunc(self, showInformationOnly)

        if showInformationOnly and true == res and g_client ~= nil then
            Glance.proximityObj = {obj=self, type="bunkerSilo", func=Glance.getBunkerSiloInfo}
        end

        return res
    end
)

function getBunkerSiloFillTypeName(siloObj,useOutput)
    local fillType = siloObj.inputFillType;
    if useOutput then
        fillType = siloObj.outputFillType;
    end
    local fillTypeName = "";
    if FillUtil.fillTypeIndexToDesc[fillType] ~= nil then
        fillTypeName = FillUtil.fillTypeIndexToDesc[fillType].nameI18N;
    end
    return fillTypeName
end

function Glance.getBunkerSiloInfo(siloObj)
    local txt = nil
    if siloObj.state == BunkerSilo.STATE_FILL then
        txt = g_i18n:getText("info_fillLevel")..string.format(" %s: %d", getBunkerSiloFillTypeName(siloObj), siloObj.fillLevel)
        txt = txt .. ", " .. g_i18n:getText("info_compacting")..string.format(" %d%%", siloObj.compactedPercent)
    elseif siloObj.state == BunkerSilo.STATE_CLOSED or siloObj.state == BunkerSilo.STATE_FERMENTED then
        txt = g_i18n:getText("info_fermenting")..string.format(" %s: %d%%", getBunkerSiloFillTypeName(siloObj,true), siloObj.fermentingPercent)
    elseif siloObj.state == BunkerSilo.STATE_DRAIN then
        txt = g_i18n:getText("info_fillLevel")..string.format(" %s: %d", getBunkerSiloFillTypeName(siloObj,true), siloObj.fillLevel)
    end;
    return txt
end

-----

function Glance:makeComplexBga(dt, notifyList)
--[[
    // complexBGA
    Bga.complexBGA_data ~= nil
    Bga.complexBgaDebug ~= nil
    
    g_currentMission.onCreateLoadedObjectsToSave[<int>]
      // default BGA
        .silageCatcherId ~= nil
      // complexBGA
        .bunkerFillLevel <float>    (do /1000 to get m2)
        .printPower      <float>    (power production)
    
--]]
end

-----

function Glance:makeHusbandriesLine(dt, notifyList)
    if g_currentMission.husbandries ~= nil then
        --
        local function getNotification(animalType,subElement)
            for _,key in pairs({"husbandry:"..animalType..":"..subElement, "husbandry:"..subElement}) do
                if Glance.notifications[key] ~= nil then
                    return Glance.notifications[key]
                end
            end
            return nil
        end
        
        --
        local function getFillName(ntfy, i18nName, fillTypeIndex)
            if ntfy.text ~= nil then
                return tostring(ntfy.text)
            end
            if fillTypeIndex ~= nil then
                if FillUtil.fillTypeIndexToDesc[fillTypeIndex] ~= nil then
                    if FillUtil.fillTypeIndexToDesc[fillTypeIndex].nameI18N ~= nil then
                        return FillUtil.fillTypeIndexToDesc[fillTypeIndex].nameI18N
                    else
                        return FillUtil.fillTypeIndexToDesc[fillTypeIndex].name
                    end
                end
            end
            if i18nName ~= nil then
                if g_i18n:hasText(i18nName) then
                    return g_i18n:getText(i18nName)
                else
                    return tostring(i18nName)
                end
            end
            return ("(unknown:%s)"):format(tostring(fillTypeIndex))
        end

        --
        local infos = {}
        local function updateInfoValue(propertyName, addItemCount, newValue, valueSuffix)
            if infos[propertyName] == nil then
                infos[propertyName] = {}
                infos[propertyName].itemCount = 0
                infos[propertyName].value = newValue
                infos[propertyName].valueSuffix = valueSuffix
            end
            if addItemCount ~= nil then
                infos[propertyName].itemCount = infos[propertyName].itemCount + addItemCount
            end
            if newValue ~= nil then
                infos[propertyName].value = newValue
            end
        end
        
        local function getInfoValue(propertyName)
            if infos[propertyName] == nil then
                return nil
            end
            return infos[propertyName].value
        end
        
        local colorAndLevel = nil
        local function updateColor(threshold)
            if threshold ~= nil then
                if colorAndLevel == nil then
                    colorAndLevel = {}
                    colorAndLevel.level = Utils.getNoNil(threshold.level, 0)
                    colorAndLevel.color = Utils.getNoNil(threshold.color, Glance.lineColorDefault)
                elseif threshold.level ~= nil and threshold.level > colorAndLevel.level then
                    colorAndLevel.level = threshold.level
                    colorAndLevel.color = Utils.getNoNil(threshold.color, colorAndLevel.color)
                end
            end
        end
        
        --
        for animalType,mainHusbandry in pairs(g_currentMission.husbandries) do
            local husbandries = { mainHusbandry } -- Due to support for possible multiple husbandries of same animalType
            infos = {}
            colorAndLevel = nil
            updateColor( { level=0, color=Glance.lineColorDefault } )
            --
            local ntfyLivestock     = getNotification(animalType, "Animals")
            local ntfyProductivity  = getNotification(animalType, "Productivity")
            local ntfyPallet        = getNotification(animalType, "Pallet")
            local ntfyPickupObjects = getNotification(animalType, "PickupObjects")
            local ntfyCleanliness   = getNotification(animalType, "Cleanliness")

            -- Fill-levels
            local ntfyStorage = {}
            for fillType,fillDesc in pairs(FillUtil.fillTypeIndexToDesc) do
                if fillType ~= FillUtil.FILLTYPE_UNKNOWN then
                    local ntfy = getNotification(animalType, fillDesc.name)
                    if ntfy ~= nil then
                        ntfyStorage[fillType] = ntfy
                    end
                end
            end

            -- Fill-levels for food groups
            local ntfyFoodGroups = {}
            if  mainHusbandry.animalDesc ~= nil
            and mainHusbandry.animalDesc.index ~= nil
            and FillUtil.foodGroups[mainHusbandry.animalDesc.index] ~= nil
            then
                for _,foodGroup in pairs(FillUtil.foodGroups[mainHusbandry.animalDesc.index]) do
                    local ntfy = getNotification(animalType, ("foodGroup:%s"):format(foodGroup.groupName))
                    if ntfy ~= nil then
                        ntfyFoodGroups[foodGroup] = ntfy
                    end
                end
            end

            --
            for _,husbandry in pairs(husbandries) do
              -- Only check husbandries which actually contains animals
              local livestockAmount = husbandry.totalNumAnimals
              if hasNumberValue(livestockAmount,0) then
              
                -- Livestock
                if ntfyLivestock ~= nil then
                    local fillName = getFillName(ntfyLivestock, "ui_statisticViewAnimals", nil)
                    local res = isBreakingThresholds(ntfyLivestock, livestockAmount, getInfoValue(fillName))
                    if res then
                        updateColor(res.threshold)
                        updateInfoValue(fillName, 1, res.value, "")
                    end
                end

                -- Productivity
                if ntfyProductivity ~= nil then
                    local productivity = husbandry.productivity
                    if hasNumberValue(productivity) then
                        local pct = math.floor(productivity * 100);
                        local fillName = getFillName(ntfyProductivity, "statistic_productivity", nil)
                        local res = isBreakingThresholds(ntfyProductivity, pct, getInfoValue(fillName))
                        if res then
                            updateColor(res.threshold)
                            updateInfoValue(fillName, 1, res.value, "%")
                        end
                    end
                end
                
                -- Pallet (Wool)
                if ntfyPallet ~= nil then
                    if husbandry.currentPallet ~= nil and husbandry.currentPallet.getFillLevel ~= nil 
                    and husbandry.currentPallet.getCapacity ~= nil and hasNumberValue(husbandry.currentPallet:getCapacity(),0)
                    then
                        local pct = math.floor((husbandry.currentPallet:getFillLevel() * 100) / husbandry.currentPallet:getCapacity());
                        local fillName = getFillName(ntfyPallet, nil, husbandry.palletFillType)
                        local res = isBreakingThresholds(ntfyPallet, pct, getInfoValue(fillName))
                        if res then
                            updateColor(res.threshold)
                            updateInfoValue(fillName, 1, res.value, "%")
                        end
                    end
                end
                
                -- PickupObjects (Eggs)
                if ntfyPickupObjects ~= nil then
                    if  husbandry.pickupObjectsToActivate ~= nil
                    and husbandry.numActivePickupObjects ~= nil 
                    then
                        local capacity = table.getn(husbandry.pickupObjectsToActivate) + husbandry.numActivePickupObjects;
                        if capacity > 0 then
                            local pct = math.floor((husbandry.numActivePickupObjects * 100) / capacity);
                            local fillName = getFillName(ntfyPickupObjects, nil, husbandry.pickupObjectsFillType)
                            local res = isBreakingThresholds(ntfyPickupObjects, pct, getInfoValue(fillName))
                            if res then
                                updateColor(res.threshold)
                                updateInfoValue(fillName, 1, res.value, "%")
                            end
                        end
                    end;
                end
                
                -- Cleanliness
                if ntfyCleanliness ~= nil then
                    local factor = husbandry.cleanlinessFactor
                    if hasNumberValue(factor) then
                        local pct = math.floor(factor * 100);
                        local fillName = getFillName(ntfyCleanliness, "statistic_cleanliness", nil)
                        local res = isBreakingThresholds(ntfyCleanliness, pct, getInfoValue(fillName))
                        if res then
                            updateColor(res.threshold)
                            updateInfoValue(fillName, 1, res.value, "%")
                        end
                    end
                end
                
                -- Fill-Levels
                for fillType,ntfy in pairs(ntfyStorage) do
                    if fillType == FillUtil.FILLTYPE_MILK then
                        local fillLevel = husbandry.fillLevelMilk
                        if hasNumberValue(fillLevel) then
                            local fillName = getFillName(ntfy, nil, fillType)
                            local res = isBreakingThresholds(ntfy, fillLevel, getInfoValue(fillName))
                            if res then
                                updateColor(res.threshold)
                                updateInfoValue(fillName, 1, res.value, "");
                            end
                        end
                    elseif fillType == FillUtil.FILLTYPE_MANURE then
                        local fillLevel = husbandry.manureFillLevel
                        if hasNumberValue(fillLevel) then
                            local fillName = getFillName(ntfy, nil, fillType)
                            local res = isBreakingThresholds(ntfy, fillLevel, getInfoValue(fillName))
                            if res then
                                updateColor(res.threshold)
                                updateInfoValue(fillName, 1, res.value, "");
                            end
                        end
                    elseif fillType == FillUtil.FILLTYPE_LIQUIDMANURE then
                        local liquidManure = Utils.getNoNil(husbandry.liquidManureTrigger, husbandry.liquidManureSiloTrigger)
                        if liquidManure ~= nil 
                        and hasNumberValue(liquidManure.fillLevel) 
                        and hasNumberValue(liquidManure.capacity,0) 
                        then
                            local pct = math.floor(100 * liquidManure.fillLevel / liquidManure.capacity)
                            local fillName = getFillName(ntfy, nil, fillType)
                            local res = isBreakingThresholds(ntfy, pct, getInfoValue(fillName))
                            if res then
                                updateColor(res.threshold)
                                updateInfoValue(fillName, 1, res.value, "%");
                            end
                        end
                    elseif fillType <= FillUtil.NUM_FILLTYPES and husbandry.getFillLevel ~= nil and husbandry.getCapacity ~= nil then
                        local capacity = husbandry:getCapacity(fillType, nil)
                        if hasNumberValue(capacity,0) then
                            local pct = math.floor(100 * husbandry:getFillLevel(fillType) / capacity)
                            local fillName = getFillName(ntfy, nil, fillType)
                            local res = isBreakingThresholds(ntfy, pct, getInfoValue(fillName))
                            if res then
                                updateColor(res.threshold)
                                updateInfoValue(fillName, 1, res.value, "%");
                            end
                        end
                    end
                end
                
                -- Food groups
                if  husbandry.getAvailableAmountOfFillTypes ~= nil
                and husbandry.getCapacity ~= nil
                then
                    for foodGroup,ntfy in pairs(ntfyFoodGroups) do
                        local capacity = husbandry:getCapacity(nil, foodGroup)
                        if hasNumberValue(capacity, 0) then
                            local pct = math.floor(100 * husbandry:getAvailableAmountOfFillTypes(foodGroup.fillTypes) / capacity)
                            local fillName = getFillName(ntfy, foodGroup.nameI18N, nil)
                            local res = isBreakingThresholds(ntfy, pct, getInfoValue(fillName))
                            if res then
                                updateColor(res.threshold)
                                updateInfoValue(fillName, 1, res.value, "%");
                            end
                        end
                    end
                end
              end
            end

            --
--log("#=",#infos)
--log("table.getn=",table.getn(infos))
--log("~={}=",infos ~= {})
--log("next=",next(infos))
            if next(infos) then
                local animalI18N = "ui_statisticView_"..animalType
                if g_i18n:hasText(animalI18N) then
                    animalType = g_i18n:getText(animalI18N);
                end;
                local txt = animalType;
                local prefix=":"
                for nfoName,nfo in pairs(infos) do
                    txt = txt .. (Glance.nonVehiclesFillLevelFormat):format(prefix, nfoName, ("%d%s"):format(nfo.value, nfo.valueSuffix))
                    prefix=","
                end
                table.insert(notifyList, { getNotificationColor(colorAndLevel.color), txt});
            end;
        end;
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
                ,color      = getNotificationColor(col.color)
            };
            table.insert(columns, column)
        end
    end
    self.linesVehicles = { columns }
    local lines = 1
    --
    local steerables = {}
    for _,v in pairs(g_currentMission.steerables) do
        if v.getVehicleName == nil then
            -- Ignore
        else
            table.insert(steerables,v);
        end
    end
    if VehicleGroupsSwitcher ~= nil or FS17_DCK_VehicleGroupsSwitcher ~= nil then
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
            self.linesVehicles[lines] = columns
        end
    end
    
    -- Find max text width per column
    for i=2,table.getn(self.linesVehicles) do
        for c=1,table.getn(self.linesVehicles[1]) do
            for e=1,table.getn(self.linesVehicles[i][c]) do
                --
                if self.linesVehicles[1][c].maxLetters ~= nil and self.linesVehicles[i][c][e][2]:len() > self.linesVehicles[1][c].maxLetters then
                    self.linesVehicles[i][c][e][2] = self.linesVehicles[i][c][e][2]:sub(1, self.linesVehicles[1][c].maxLetters) .. ".."; --   "…"; -- 0x2026  -- "…"
                end
                --
                local txtWidth = getTextWidth(Glance.cFontSize, self.linesVehicles[i][c][e][2]);
                --log("i="..i..",c="..c..",e="..e..",txt=" .. tostring(self.linesVehicles[i][c][e][2])..",txtWidth="..tostring(txtWidth));
                self.linesVehicles[1][c].minWidth = math.max(self.linesVehicles[1][c].minWidth, txtWidth);
            end
        end;
    end;
    
    -- Update column positions.
    local xPos = 0.0;
    for c=1,table.getn(self.linesVehicles[1]) do
        if (self.linesVehicles[1][c].alignment == RenderText.ALIGN_LEFT) then
            self.linesVehicles[1][c].pos = xPos;
        elseif (self.linesVehicles[1][c].alignment == RenderText.ALIGN_CENTER) then
            self.linesVehicles[1][c].pos = xPos + (self.linesVehicles[1][c].minWidth / 2);
        elseif (self.linesVehicles[1][c].alignment == RenderText.ALIGN_RIGHT) then
            self.linesVehicles[1][c].pos = xPos + self.linesVehicles[1][c].minWidth;
        end;
        
        xPos = xPos + self.linesVehicles[1][c].minWidth + self.linesVehicles[1][c].sufOff;
    end

end

-----
function Glance:getCellData_VehicleGroupsSwitcherNumber(dt, lineColor, colParms, cells, veh)
    if veh.modVeGS ~= nil and veh.modVeGS.group ~= 0 then
        return { { getNotificationColor(colParms.color, lineColor), tostring(veh.modVeGS.group % 10) } };
    end
end
function Glance:getCellData_VehicleController(dt, lineColor, colParms, cells, veh)
    return cells["VehicleController"]
end
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
    return { { getNotificationColor(colParms.color, lineColor), Utils.getNoNil(colParms.text, Glance.cColumnDelimChar) } }
end
function Glance:getCellData_VehicleAtWorldPositionXZ(dt, lineColor, colParms, cells, veh)
    if veh.components and veh.components[1] and veh.components[1].node then
        local wx,_,wz = getWorldTranslation(veh.components[1].node);
    
        if wx~=wx or wz~=wz then
            -- Something is very wrong!
            local vehName = "(unknown vehicle name)"
            if veh.getVehicleName ~= nil then
                vehName = veh.getVehicleName()
            end
            log("ERROR - Glance:getCellData_VehicleAtWorldPositionXZ(), getWorldTranslation() returned invalid values: x/_/z="..tostring(wx).."/_/"..tostring(wz)..", for vehicle: "..vehName)
            return
        end
    
        -- World location
    
        local pdaMap = Utils.getNoNil(g_currentMission.ingameMap, g_currentMission.missionPDA)
        wx = wx + pdaMap.worldCenterOffsetX;
        wz = wz + pdaMap.worldCenterOffsetZ;
        return { { getNotificationColor(lineColor), string.format("%dx%d", wx,wz) } }
    end
end
function Glance:getCellData_VehicleAtWorldCorner(dt, lineColor, colParms, cells, veh)
    if veh.components and veh.components[1] and veh.components[1].node then
        local wx,_,wz = getWorldTranslation(veh.components[1].node);
    
        if wx~=wx or wz~=wz then
            -- Something is very wrong!
            local vehName = "(unknown vehicle name)"
            if veh.getVehicleName ~= nil then
                vehName = veh.getVehicleName()
            end
            log("ERROR - Glance:getCellData_VehicleAtWorldCorner(), getWorldTranslation() returned invalid values: x/_/z="..tostring(wx).."/_/"..tostring(wz)..", for vehicle: "..vehName)
            return
        end
    
        -- World location
        local pdaMap = Utils.getNoNil(g_currentMission.ingameMap, g_currentMission.missionPDA)
        wx = wx + pdaMap.worldCenterOffsetX;
        wz = wz + pdaMap.worldCenterOffsetZ;
        -- Determine world corner - 3x3 grid
        wx = 1 + Utils.clamp(math.floor(wx / (pdaMap.worldSizeX / 3 + 1)), 0, 2); -- We '+1' if at any point the worldSizeX would be zero.
        wz = 1 + Utils.clamp(math.floor(wz / (pdaMap.worldSizeZ / 3 + 1)), 0, 2); -- We '+1' if at any point the worldSizeX would be zero.
        return { { getNotificationColor(lineColor), self.cWorldCorners3x3[wz][wx] } }
    end
end
function Glance:getCellData_VehicleAtFieldNumber(dt, lineColor, colParms, cells, veh)
    if veh.components and veh.components[1] and veh.components[1].node then
        local wx,_,wz = getWorldTranslation(veh.components[1].node);
    
        if wx~=wx or wz~=wz then
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
        for fieldNum,fieldRects in ipairs(Glance.fieldsRects) do
            for _,rect in ipairs(fieldRects) do
                if  rect.x1 <= wx and wx <= rect.x2
                and rect.z1 <= wz and wz <= rect.z2
                then
                    closestField = fieldNum;
                    break
                end
            end
            if closestField ~= nil then
                return { { getNotificationColor(lineColor), string.format(g_i18n:getText("closestfield"), closestField) } }
            end;
        end
    end
end
function Glance:getCellData_VehicleName(dt, lineColor, colParms, cells, veh)
    if veh.getVehicleName ~= nil then
        return { { getNotificationColor(lineColor), veh:getVehicleName() } }
    end
end
function Glance:getCellData_FuelLow(dt, lineColor, colParms, cells, veh)
    return cells["FuelLow"]
end
function Glance:getCellData_FuelLevel(dt, lineColor, colParms, cells, veh)
    if veh.fuelFillLevel ~= nil then
        return { { getNotificationColor(lineColor), ("Fuel:%.0f"):format(veh.fuelFillLevel) } }
    end
end
function Glance:getCellData_FuelLevelPct(dt, lineColor, colParms, cells, veh)
    if veh.fuelFillLevel ~= nil and veh.fuelCapacity ~= nil and veh.fuelCapacity > 0 then
        return { { getNotificationColor(lineColor), ("Fuel:%.0f%%"):format((100 * veh.fuelFillLevel) / veh.fuelCapacity) } }
    end
end
function Glance:getCellData_DirtAmount(dt, lineColor, colParms, cells, veh)
    return cells["DirtAmount"]
end
function Glance:getCellData_Collision(dt, lineColor, colParms, cells, veh)
    return cells["Collision"]
end
function Glance:getCellData_EngineOn(dt, lineColor, colParms, cells, veh)
    return cells["EngineOn"]
end
--[[
function Glance:getCellData_Damaged(dt, lineColor, colParms, cells, veh)
    return cells["Damaged"]
end
--]]
function Glance:getCellData_FillLevel(dt, lineColor, colParms, cells, veh)
    return cells["FillLevel"]
end
function Glance:getCellData_FillPercent(dt, lineColor, colParms, cells, veh)
    return cells["FillPct"]
end
function Glance:getCellData_FillTypeName(dt, lineColor, colParms, cells, veh)
    return cells["FillType"]
end
function Glance:getCellData_AllFillPcts(dt, lineColor, colParms, cells, veh)
    return cells["AllFillPcts"]
end
function Glance:getCellData_AllFillLvls(dt, lineColor, colParms, cells, veh)
    return cells["AllFillLvls"]
end
function Glance:getCellData_ActiveTask(dt, lineColor, colParms, cells, veh)
    return cells["ActiveTask"]
end
--[[
function Glance:getCellData_BalerNumFoilsNets(dt, lineColor, colParms, cells, veh)
    return cells["balerNumFoilsNets"]
end
function Glance:getCellData_BalerNumFoils(dt, lineColor, colParms, cells, veh)
    return cells["balerNumFoils"]
end
function Glance:getCellData_BalerNumNets(dt, lineColor, colParms, cells, veh)
    return cells["balerNumNets"]
end
--]]
-----

function Glance:notify_vehicleBroken(dt, notifyParms, veh)
    if veh.isBroken then
        return { "VehicleBroken", g_i18n:getText("broken") }
    end
end

--function Glance:notify_vehicleCollision(dt, notifyParms, veh)
--end

function Glance:notify_vehicleFuelLow(dt, notifyParms, veh)
    if  hasNumberValue(veh.fuelCapacity, 0)
    and hasNumberValue(veh.fuelFillLevel)
    then
        local fuelPct = math.floor(100 * veh.fuelFillLevel / veh.fuelCapacity);
        local res = isBreakingThresholds(notifyParms, fuelPct)
        if res then
            return { "FuelLow", string.format(g_i18n:getText("fuellow"), tostring(res.value)) }
        end
    end;
end

function Glance:notify_vehicleDirtAmount(dt, notifyParms, veh)
    if veh.getDirtAmount ~= nil then
        local dirtAmount = veh:getDirtAmount()
        if hasNumberValue(dirtAmount) then
            local res = isBreakingThresholds(notifyParms, math.floor(dirtAmount * 100))
            if res then
                return { "DirtAmount", string.format(g_i18n:getText("dirtamount"), tostring(res.value)) }
            end
        end
    end;
end

function Glance:notify_engineOnButNotControlled(dt, notifyParms, veh)
    if veh.isMotorStarted then
        if veh.isControlled
        or veh.isHired
        or (veh.getIsCourseplayDriving ~= nil and veh:getIsCourseplayDriving())
        or (veh.getIsFollowMeActive ~= nil and veh:getIsFollowMeActive())
        or (g_currentMission.AutoDrive ~= nil and veh.ad ~= nil and veh.bActive == true) -- AutoDrive
        or (veh.ld ~= nil and veh.ld.active == true) -- LocoDrive
        then
            -- do nothing
        else
            return { "EngineOn", g_i18n:getText("engineon") }
        end;
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
                table.insert(cells["VehicleController"], { getNotificationColor(Glance.lineColorVehicleControlledByMe), veh.controllerName } );
            end
            vehIsControlled = true
        else
            -- Controlled by 'other player'
            local ntfy = Glance.notifications["controlledByPlayer"]
            if ntfy ~= nil and ntfy.enabled == true then
                notifyLevel = math.max(notifyLevel, ntfy.level)
                notifyLineColor = Glance.lineColorVehicleControlledByPlayer
                table.insert(cells["VehicleController"], { getNotificationColor(Glance.lineColorVehicleControlledByPlayer), veh.controllerName } );
            end
            vehIsControlled = true
        end
    end
    -- Hired Worker
    if veh.isHired then
        self:setProperty(veh, "wasHired", true)
        --
        local ntfy = Glance.notifications["controlledByHiredWorker"]
        if ntfy ~= nil and ntfy.enabled == true then
            notifyLevel = math.max(notifyLevel, ntfy.level)
            notifyLineColor = Glance.lineColorVehicleControlledByComputer
            table.insert(cells["VehicleController"], { getNotificationColor(Glance.lineColorVehicleControlledByComputer), g_i18n:getText("hired") } );
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
                cells["HiredFinished"] = { { getNotificationColor(notifyLineColor), g_i18n:getText("dismissed") } }
            end
        end
    end
    -- CoursePlay
    if veh.getIsCourseplayDriving ~= nil and veh:getIsCourseplayDriving() then
        local ntfy = Glance.notifications["controlledByCourseplay"]
        if ntfy ~= nil and ntfy.enabled == true then
            notifyLevel = math.max(notifyLevel, ntfy.level)
            notifyLineColor = Glance.lineColorVehicleControlledByComputer
            table.insert(cells["VehicleController"], { getNotificationColor(Glance.lineColorVehicleControlledByComputer), g_i18n:getText("courseplay") } );
        end
        vehIsControlled = true
        vehIsControlledByComputer = true
    end
    -- FollowMe
    if veh.getIsFollowMeActive ~= nil and veh:getIsFollowMeActive() then
        local ntfy = Glance.notifications["controlledByFollowMe"]
        if ntfy ~= nil and ntfy.enabled == true then
            notifyLevel = math.max(notifyLevel, ntfy.level)
            notifyLineColor = Glance.lineColorVehicleControlledByComputer
            table.insert(cells["VehicleController"], { getNotificationColor(Glance.lineColorVehicleControlledByComputer), g_i18n:getText("followme") } );
        end
        vehIsControlled = true
        vehIsControlledByComputer = true
    end
    -- AutoDrive
    if g_currentMission.AutoDrive ~= nil and veh.ad ~= nil and veh.bActive == true then
        local ntfy = Glance.notifications["controlledByAutoDrive"]
        if ntfy ~= nil and ntfy.enabled == true then
            notifyLevel = math.max(notifyLevel, ntfy.level)
            notifyLineColor = Glance.lineColorVehicleControlledByComputer
            table.insert(cells["VehicleController"], { getNotificationColor(Glance.lineColorVehicleControlledByComputer), g_i18n:getText("autodrive") } );
        end
        vehIsControlled = true
        vehIsControlledByComputer = true
    end
    -- LocoDrive
    if veh.ld ~= nil and veh.ld.active == true then
        vehIsControlled = true
        vehIsControlledByComputer = true
    end

    ---

    cells["MovementSpeed"] = {}
    cells["Collision"] = {}

    if vehIsControlled and veh.isMotorStarted then
        local speedKmh = veh:getLastSpeed()
        --
        local waiting = nil;
        if g_currentMission:getIsServer() then
            if (veh.getIsCourseplayDriving ~= nil and veh:getIsCourseplayDriving()) and veh.cp ~= nil and veh.cp.wait then
                -- CoursePlay waiting?
                waiting = true
            end
            self:setProperty(veh, "cpWaiting", waiting)
        else
            waiting = self:getProperty(veh, "cpWaiting");
        end
        --
        local ntfyIdle = Glance.notifications["vehicleIdleMovement"]
        
        --
        local res = isBreakingThresholds(ntfyIdle, speedKmh)
        if res then
            -- Not moving.
            notifyLevel = math.max(notifyLevel, res.threshold.level)
    
            if waiting then
                cells["MovementSpeed"] = { { getNotificationColor(res.color, notifyLineColor), g_i18n:getText("cp_waiting") } };
            else
                cells["MovementSpeed"] = { { getNotificationColor(res.color, notifyLineColor), g_i18n:getText("speedIdle") } };
            end
        else
            cells["MovementSpeed"] = { { getNotificationColor(notifyLineColor), string.format(g_i18n:getText("speed+Unit"), g_i18n:getSpeed(speedKmh), g_i18n.globalI18N:getSpeedMeasuringUnit()) } }
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
                        if not waiting then -- not CoursePlay or not cp-waiting
                            if veh.numCollidingVehicles ~= nil then
                                for _,numCollisions in pairs(veh.numCollidingVehicles) do
                                    if numCollisions > 0 then
                                        -- Begin timeout
                                        notifyBlockedMS = g_currentMission.time + ntfyCollision.aboveThreshold
                                        break;
                                    end;
                                end;
                            end
                            if veh.lastSpeedAcceleration ~= nil and math.abs(veh.lastSpeedAcceleration) > 0.0 then
                                -- Begin timeout
                                notifyBlockedMS = g_currentMission.time + ntfyCollision.aboveThreshold
                            end
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
                cells["Collision"] = { { getNotificationColor(ntfyCollision.color, notifyLineColor), g_i18n:getText("collision") } };
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
            if      Sprayer            == spec then impStates.isSprayerOn           = (imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn()) or imp.isTurnedOn;
            elseif  ManureSpreader     == spec then impStates.isSprayerOn           = (imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn()) or imp.isTurnedOn;
            elseif  ManureBarrel       == spec then impStates.isSprayerOn           = (imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn()) or imp.isTurnedOn;
            elseif  SowingMachine      == spec then impStates.isSeederOn            = (imp.movingDirection > 0 and imp.sowingMachineHasGroundContact and (not imp.needsActivation or (imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn()) or imp.isTurnedOn));
            elseif  TreePlanter        == spec then impStates.isTreePlanterOn       = (imp.movingDirection > 0                                       and (not imp.needsActivation or (imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn())));
            elseif  Cultivator         == spec then impStates.isCultivatorOn        = (imp.cultivatorHasGroundContact and (not imp.onlyActiveWhenLowered or imp:isLowered(false)) );
            elseif  Plough             == spec then impStates.isPloughOn            = imp.ploughHasGroundContact;
            elseif  Combine            == spec then impStates.isHarvesterOn         = ((imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn()) or imp.isThreshing) and imp:getIsThreshingAllowed(false);
            elseif  ForageWagon        == spec then impStates.isForageWagonOn       = (imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn()) or imp.isTurnedOn;
            elseif  Baler              == spec then impStates.isBalerOn             = (imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn()) or imp.isTurnedOn;
            elseif  Mower              == spec then impStates.isMowerOn             = (imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn()) or imp.isTurnedOn;
            elseif  Tedder             == spec then impStates.isTedderOn            = (imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn()) or imp.isTurnedOn;
            elseif  Windrower          == spec then impStates.isWindrowerOn         = (imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn()) or imp.isTurnedOn;
            elseif  Weeder             == spec then impStates.isWeederOn            = imp.doGroundManipulation;
            elseif  FruitPreparer      == spec then impStates.isFruitPreparerOn     = (imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn()) or imp.isTurnedOn;
            elseif  BaleLoader         == spec then impStates.isBaleLoadingOn       = imp.isInWorkPosition;
            elseif  BaleWrapper        == spec then impStates.isBaleWrapperOn       = imp.baleWrapperState ~= nil and ((imp.baleWrapperState > 0) and (imp.baleWrapperState < 4));
            elseif  StrawBlower        == spec then impStates.isStrawBlowerOn       = (imp.tipState == Trailer.TIPSTATE_OPENING or imp.tipState == Trailer.TIPSTATE_OPEN);
            elseif  MixerWagon         == spec then impStates.isMixerWagonOn        = (imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn()) or imp.isTurnedOn;
            elseif  StumpCutter        == spec then impStates.isStumpCutterOn       = (imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn());
            elseif  WoodCrusher        == spec then impStates.isWoodCrusherOn       = (imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn());
            elseif  Cutter             == spec then impStates.isCutterOn            = false; -- TODO
            elseif  LivestockTrailer   == spec then impStates.isLivestockTrailerOn  = ((imp.movingDirection > 0.0001) or (imp.movingDirection < -0.0001)) and (imp.getUnitFillLevel ~= nil and imp:getUnitFillLevel(1) > 0);
            elseif  Trailer            == spec then impStates.isTrailerOn           = (imp.movingDirection > 0.0001) or (imp.movingDirection < -0.0001);
                                                    impStates.isTrailerUnloads      = (imp.tipState == Trailer.TIPSTATE_OPENING or imp.tipState == Trailer.TIPSTATE_OPEN);
            end;
        end
    end;

    local taskList = {}
    if impStates.isHarvesterOn          then table.insert(taskList, "task_Harvesting"           ); end;
    if impStates.isFruitPreparerOn      then table.insert(taskList, "task_Defoliator"           ); end;
    if impStates.isBaleLoadingOn        then table.insert(taskList, "task_Loading_bales"        ); end;
    if impStates.isBaleWrapperOn        then table.insert(taskList, "task_Wrapping_bale"        ); end;
    if impStates.isBalerOn              then table.insert(taskList, "task_Baling"               ); end;
    if impStates.isForageWagonOn        then table.insert(taskList, "task_Foraging"             ); end;
    if impStates.isTedderOn             then table.insert(taskList, "task_Tedding"              ); end;
    if impStates.isWindrowerOn          then table.insert(taskList, "task_Swathing"             ); end;
    if impStates.isMowerOn              then table.insert(taskList, "task_Mowing"               ); end;
    if impStates.isSprayerOn            then table.insert(taskList, "task_Spraying"             ); end;
    if impStates.isSeederOn             then table.insert(taskList, "task_Seeding"              ); end;
    if impStates.isTreePlanterOn        then table.insert(taskList, "task_TreePlanting"         ); end;
    if impStates.isStrawBlowerOn        then table.insert(taskList, "task_Bedding"              ); end;
    if impStates.isMixerWagonOn         then table.insert(taskList, "task_Feeding"              ); end;
    if impStates.isCutterOn             then table.insert(taskList, "task_Cutting"              ); end;
    if impStates.isStumpCutterOn        then table.insert(taskList, "task_StumpCutting"         ); end;
    if impStates.isWoodCrusherOn        then table.insert(taskList, "task_WoodCrushing"         ); end;
    if impStates.isCultivatorOn         then table.insert(taskList, "task_Cultivating"          ); end;
    if impStates.isPloughOn             then table.insert(taskList, "task_Ploughing"            ); end;
    if impStates.isWeederOn             then table.insert(taskList, "task_Weeding"              ); end;
    if impStates.isLivestockTrailerOn   then table.insert(taskList, "task_LivestockTransport"   ); end;
    if impStates.isTrailerUnloads       then table.insert(taskList, "task_Unloading"            ); end;
    
    if #taskList <= 0 and impStates.isTrailerOn then table.insert(taskList, "task_Transporting" ); end;
    
    if #taskList > 0 then
        for i=#taskList,1,-1 do
            if g_i18n:hasText(taskList[i]) then
                taskList[i] = g_i18n:getText(taskList[i])
            end
        end
    
        cells["ActiveTask"] = { { getNotificationColor(notify_lineColor), table.concat(taskList, ", ") } }
    end
    --
    return -1; -- notifyLevel
end

function Glance:static_fillTypeLevelPct(dt, staticParms, veh, implements, cells, notify_lineColor)
    local notifyLevel = 0
    
    -- Examine each implement for fillable parts.
    self.fillTypesCapacityLevelColor = {}
    local function updateFill(fillType,capacity,fillLevel,color,notifyLevel)
        if self.fillTypesCapacityLevelColor[fillType] == nil then
            self.fillTypesCapacityLevelColor[fillType] = {capacity=capacity, fillLevel=fillLevel, color=color, notifyLevel=notifyLevel}
        else
            local elem = self.fillTypesCapacityLevelColor[fillType]
            elem.capacity   = elem.capacity  + capacity
            elem.fillLevel  = elem.fillLevel + fillLevel
            if elem.notifyLevel <= notifyLevel then
                elem.notifyLevel = notifyLevel
                elem.color = color
            end
        end
    end
    --
    local highestNotifyLevel = -1
    local highestNotifyColor = nil
    local sowingMachine = {seederPart=nil, seedTankPart={}} -- Due to Kuhn DLC
    for _,obj in pairs(implements) do
        if obj.fillUnits ~= nil then
            local impType = {}
            for _,spec in pairs(obj.specializations) do
                    if spec == SowingMachine then impType.isSowingMachine = true
                elseif spec == Sprayer       then impType.isSprayer       = true
                elseif spec == WaterTrailer
                    or spec == FuelTrailer   then impType.isLiquidTrailer = true
                elseif spec == ForageWagon   then impType.isForageWagon   = true
                elseif spec == Trailer       then impType.isTrailer       = true
                elseif spec == Combine       then impType.isCombine       = true
                elseif spec == BaleLoader    then impType.isBaleLoader    = true
                end
            end

            for fillUnitIndex,fillUnit in pairs(obj.fillUnits) do
                local fillCap = fillUnit.capacity
                local fillLvl = fillUnit.fillLevel
                local fillTpe = fillUnit.currentFillType

                -- Special handling of sowingMachine due to Kuhn DLC
                local checkMore = true
                if impType.isSowingMachine then
                    if true == obj.isSeedTank and true ~= obj.allowsSeedChanging then
                        sowingMachine.seedTankPart = {fillTpe, fillCap, fillLvl}
                        checkMore = false
                    elseif obj.sowingMachine ~= nil and fillUnitIndex == obj.sowingMachine.fillUnitIndex then
                        -- For sowingmachine, show the selected seed type.
                        sowingMachine.seederPart = {FruitUtil.fruitTypeToFillType[obj.seeds[obj.currentSeed]], fillCap, fillLvl}
                        checkMore = false
                    end
                end
              
                if  checkMore
                and fillTpe ~= nil and fillTpe ~= FillUtil.FILLTYPE_UNKNOWN
                and hasNumberValue(fillCap, 0)
                and hasNumberValue(fillLvl)
                then
                    local fillPct = math.floor(fillLvl * 100 / fillCap)
                    local fillClr = notify_lineColor
                    local res = nil
                    --
                    if impType.isSowingMachine then
                        if impType.isSprayer then -- TODO check for fill-type is allowed in sprayer
                            res = isBreakingThresholds(Glance.notifications["sprayerLow"], fillPct)
                            if res then
                                fillClr = Utils.getNoNil(res.threshold.color, fillClr)
                                notifyLevel = math.max(notifyLevel, res.threshold.level)
                            end
                        end
                    elseif impType.isSprayer then
                        res = isBreakingThresholds(Glance.notifications["sprayerLow"], fillPct)
                        if res then
                            fillClr = Utils.getNoNil(res.threshold.color, fillClr)
                            notifyLevel = math.max(notifyLevel, res.threshold.level)
                        end
                    elseif impType.isLiquidTrailer then
                        res = isBreakingThresholds(Glance.notifications["liquidsLow"], fillPct)
                        if res then
                            fillClr = Utils.getNoNil(res.threshold.color, fillClr)
                            notifyLevel = math.max(notifyLevel, res.threshold.level)
                        end
                    elseif impType.isForageWagon then
                        res = isBreakingThresholds(Glance.notifications["forageWagonFull"], fillPct)
                        if res then
                            fillClr = Utils.getNoNil(res.threshold.color, fillClr)
                            notifyLevel = math.max(notifyLevel, res.threshold.level)
                        end
                    elseif impType.isTrailer then
                        res = isBreakingThresholds(Glance.notifications["trailerFull"], fillPct)
                        if res then
                            fillClr = Utils.getNoNil(res.threshold.color, fillClr)
                            notifyLevel = math.max(notifyLevel, res.threshold.level)
                        end
                    elseif impType.isCombine then
                        res = isBreakingThresholds(Glance.notifications["grainTankFull"], fillPct)
                        if res then
                            fillClr = Utils.getNoNil(res.threshold.color, fillClr)
                            notifyLevel = math.max(notifyLevel, res.threshold.level)
                            -- For combines, when hired and grain-tank full, blink the icon.
                            if veh.mapAIHotspot ~= nil then
                                veh.mapAIHotspot:setBlinking(true == res.threshold.blinkIcon)
                            end
                        else
                            if veh.mapAIHotspot ~= nil then
                                veh.mapAIHotspot:setBlinking(false)
                            end
                        end
                    elseif impType.isBaleLoader then
                        res = isBreakingThresholds(Glance.notifications["baleLoaderFull"], fillPct)
                        if res then
                            fillClr = Utils.getNoNil(res.threshold.color, fillClr)
                            notifyLevel = math.max(notifyLevel, res.threshold.level)
                        end                
                    end
                    --
                    updateFill(fillTpe, fillCap, fillLvl, fillClr, res~=nil and res.threshold.level or 0)
                    --
                    if notifyLevel > highestNotifyLevel then
                        highestNotifyLevel = notifyLevel
                        highestNotifyColor = fillClr
                    end
                end
            end
        end
    end
    
    -- Due to Kuhn DLC, containing sowingMachine with external seed-tank.
    if nil ~= sowingMachine.seederPart then
        local fillTpe = sowingMachine.seederPart[1]
        local fillCap = Utils.getNoNil(sowingMachine.seedTankPart[2], sowingMachine.seederPart[2])
        local fillLvl = Utils.getNoNil(sowingMachine.seedTankPart[3], sowingMachine.seederPart[3])
        local fillClr = notify_lineColor
        local fillPct = (fillCap <= 0 and 0) or math.floor(fillLvl * 100 / fillCap)
        
        local res = isBreakingThresholds(Glance.notifications["seederLow"], fillPct)
        if res then
            fillClr = Utils.getNoNil(res.threshold.color, fillClr)
            notifyLevel = math.max(notifyLevel, res.threshold.level)
        end

        updateFill(fillTpe, fillCap, fillLvl, fillClr, res~=nil and res.threshold.level or 0)

        if notifyLevel > highestNotifyLevel then
            highestNotifyLevel = notifyLevel
            highestNotifyColor = fillClr
        end
    end
    
    --
    cells["FillLevel"] = {}
    cells["FillPct"]   = {}
    cells["FillType"]  = {}
    local allFillLvls = ""
    local allFillPcts = ""
    local delimLvls = ""
    local delimPcts = ""
    --
    --local freeCapacity = self.fillTypesCapacityLevelColor["n/a"]
    --self.fillTypesCapacityLevelColor["n/a"] = nil
    for fillTpe,v in pairs(self.fillTypesCapacityLevelColor) do
        local fillClr = getNotificationColor(v.color)
        local fillLvl = v.fillLevel
        local fillCap = v.capacity
        --
        --if freeCapacity ~= nil then
        --    fillCap = fillCap + freeCapacity.capacity
        --    freeCapacity = nil
        --end
        local fillPct = 0
        if fillCap > 0 then
            fillPct = math.floor(fillLvl * 100 / fillCap);
        end
        --
        local fillDesc = nil
        local fillNme = nil
        if type(fillTpe) == type("") then
            -- Not a "normal" Fillable type
            fillNme = fillTpe;
            fillDesc = FillUtil.fillTypeNameToDesc[fillTpe]
        else
            fillDesc = FillUtil.fillTypeIndexToDesc[fillTpe]
        end
        if fillDesc ~= nil and fillDesc.nameI18N ~= nil then
            fillNme = fillDesc.nameI18N;
        end
        if fillNme == nil then
            fillNme = g_i18n:getText("unknownFillType")
        end
        --
        table.insert(cells["FillLevel"], { fillClr, string.format("%d", fillLvl)        } );
        table.insert(cells["FillPct"],   { fillClr, string.format("(%d%%)", fillPct)    } );
        table.insert(cells["FillType"],  { fillClr, fillNme } );
        --
        allFillLvls = allFillLvls .. Glance.allFillLvlsFormat:format(delimLvls, fillNme, tostring(math.floor(fillLvl)))
        allFillPcts = allFillPcts .. Glance.allFillPctsFormat:format(delimPcts, fillNme, string.format("%d%%", fillPct))
        delimLvls = Glance.allFillLvlsSeparator        
        delimPcts = Glance.allFillPctsSeparator        
    end
    cells["AllFillLvls"] = { { getNotificationColor(highestNotifyColor), allFillLvls } }
    cells["AllFillPcts"] = { { getNotificationColor(highestNotifyColor), allFillPcts } }
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
                    table.insert(cells[cellName], { getNotificationColor(notifyParms.color), notifyText } )
                else
                    cells[cellName] = { { getNotificationColor(notifyParms.color), notifyText } }
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
    if (not Glance.ignoreHelpboxVisibility and g_gameSettings:getValue("showHelpMenu")) 
    or (g_currentMission.ingameMap ~= nil and g_currentMission.ingameMap.isFullSize) then
        return
    end
    --
    self.helpButtonsTimeout = g_currentMission.time + 7500;

    --
    local xPos = Glance.cStartLineX;
    local yPos = Glance.cStartLineY - Glance.cLineSpacing;
    local timeSec = math.floor(g_currentMission.time / 1000);

    if Glance.textMinLevelTimeout ~= nil and Glance.textMinLevelTimeout > g_currentMission.time then
        setTextAlignment(RenderText.ALIGN_LEFT);
        setTextBold(true);
        Glance.renderTextShaded(xPos, yPos, Glance.cFontSize, string.format(g_i18n:getText("GlanceMinLevel"), Glance.minNotifyLevel), Glance.cFontShadowOffs, {1,1,1,1}, Glance.colors[Glance.cFontShadowColor]);
        yPos = yPos - Glance.cLineSpacing;
    end

    setTextBold(false);

    if self.linesNonVehicles then
        for _,lineNonVehicles in ipairs(self.linesNonVehicles) do
            local delimWidth = getTextWidth(Glance.cFontSize, Glance.nonVehiclesSeparator);
            xPos = Glance.cStartLineX;
            for c=1,table.getn(lineNonVehicles) do
                if c > 1 then
                    setTextAlignment(RenderText.ALIGN_CENTER);
                    Glance.renderTextShaded(xPos + (delimWidth / 2),yPos,Glance.cFontSize,Glance.nonVehiclesSeparator,Glance.cFontShadowOffs, Glance.colors[Glance.lineColorDefault], Glance.colors[Glance.cFontShadowColor]);
                    xPos = xPos + delimWidth;
                end
    
                local elem = lineNonVehicles[c];
                if elem then
                    setTextAlignment(RenderText.ALIGN_LEFT);
                    Glance.renderTextShaded(xPos,yPos,Glance.cFontSize,elem[2],Glance.cFontShadowOffs,elem[1], Glance.colors[Glance.cFontShadowColor]);
                    xPos = xPos + getTextWidth(Glance.cFontSize, elem[2])
                end
            end;
            yPos = yPos - Glance.cLineSpacing;
        end
    end

    if self.linesVehicles then
        for i=2,table.getn(self.linesVehicles) do -- First element of linesVehicles contain column-widths and other stuff.
            for c=1,table.getn(self.linesVehicles[1]) do
                local numSubElems = table.getn(self.linesVehicles[i][c]);
                if numSubElems > 0 then
                    xPos = Glance.cStartLineX + self.linesVehicles[1][c].pos;
                    setTextAlignment(self.linesVehicles[1][c].alignment);
                    --
                    local e = 1 + (timeSec % numSubElems);
                    Glance.renderTextShaded(xPos,yPos,Glance.cFontSize,self.linesVehicles[i][c][e][2],Glance.cFontShadowOffs,self.linesVehicles[i][c][e][1], Glance.colors[Glance.cFontShadowColor]);
                end;
            end
            yPos = yPos - Glance.cLineSpacing;
        end;
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
    for _,_ in pairs(Glance.makeUpdateEventFor) do
        numElems = numElems + 1
    end
    --log(numElems .." ".. tostring(table.getn(Glance.makeUpdateEventFor)).." "..tostring(#Glance.makeUpdateEventFor));
    --numElems = table.getn(Glance.makeUpdateEventFor);
    --log(tostring(numElems))
    streamWriteUInt8(streamId, numElems);
    --
    for netId,obj in pairs(Glance.makeUpdateEventFor) do
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
        --log("Event-Write: ",netId," ",props)
        streamWriteInt32(streamId, netId)
        streamWriteString(streamId, props)
    end
end;

function GlanceEvent:readStream(streamId, connection)
    --log("GlanceEvent:readStream(streamId, connection)")
    local numElems = streamReadUInt8(streamId)
    --log(tostring(numElems))
    --
    for i=1,numElems do
        local netId = streamReadInt32(streamId)
        local props = streamReadString(streamId)
        --log("Event-Read: ",netId," ",props)
        --
        local obj = Glance
        if netId ~= 0 then
            obj = networkGetObject(netId)
        end
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

---
print(string.format("Script loaded: Glance.lua (v%s)", Glance.version));
