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
--  2014-November
--      v2.0.0      - Upgraded to FS15.
--                  - A bit of cleanup, removal of non-functional code.
--                  - Added blinking of hired-helper icon when combine is full.
--      v2.0.1      - On dedicated server, will NOT attempt to create file; Mods\GlanceConfig.XML
--                  - Courseplay v4.00.0056 now has different way of telling if its driving.
--      v2.0.2      - Hired helper map-icon, use grainTankFull's "whenAboveThreshold" to activate blinking of the icon.
--  2014-December
--      v2.1.0      - Re-factored husbandry and placeables. Requires new config-file to be generated.
--                    Now possible to test against fill-levels/-percentages.
--                    Attempting to include placeable MischStation's percentages too. (Marhu / TMT)
--      v2.1.1      - Re-factored methods for testing notification thresholds.
--                  - Attempted to add support for modded husbandry; SchweineZucht.LUA (Marhu / TMT)
--                  - Tweaked default font-size to 0.011 and placementInDisplay to 0.989 (= 1.000 - 0.011)
--      v2.1.2      - Minor code-cleanup.
--      v2.1.6      - Re-factored support for SchweineZucht.LUA, as apparently there can be multiple husbandries for one animal-type.
--      v2.1.7      - Added configuration option for formatting the animals/placeables line.
--                    Look for the `<nonVehicles .. />` in config-file, to see more.
--      v2.1.8      - Warning-notification changed to use show-message instead, as it looks better in FS15.
--      v2.1.9      - Misc. minor changes.
--                  - Changed config-file-name to 'Glance_Config.XML'.
--

--[[
spaceraver:
    http://fs-uk.com/forum/index.php?topic=154077.msg1049475#msg1049475
    "plugins" support
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

Glance.lineColorDefault                        = "gray"
Glance.lineColorVehicleControlledByMe          = "green"
Glance.lineColorVehicleControlledByPlayer      = "white"
Glance.lineColorVehicleControlledByComputer    = "blue"

Glance.cStartLineY      = 0.999
Glance.cFontSize        = 0.011;
Glance.cFontShadowOffs  = Glance.cFontSize * 0.08;
Glance.cFontShadowColor = "black"
Glance.cLineSpacing     = Glance.cFontSize * 0.9;

--
Glance.nonVehiclesSeparator         = "  //  ";
Glance.nonVehiclesFillLevelFormat   = "%s %s %s";

--Glance.cColumnDelimChar = "・"  -- Katakana Middle Dot "・" = 0x30FB or 0xE383BB
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
    if Glance.initialized > 0 then
      return
    end
    if Glance.initialized < 0 then
      g_inGameMenu.update = Utils.appendedFunction(g_inGameMenu.update, Glance_InGameMenu_Update)
    end
    Glance.initialized = 1

    log("g_dedicatedServerInfo=",g_dedicatedServerInfo,", g_server=",g_server,", g_client=",g_client,", g_currentMission:getIsServer()=",g_currentMission:getIsServer(),", g_currentMission:getIsClient()=",g_currentMission:getIsClient())

    --
    Glance.fieldsRects = nil

    --
    if g_currentMission:getIsServer() then
      -- Force husbandries to update NOW!
      if g_currentMission.husbandries ~= nil then
        for _,husbandry in pairs(g_currentMission.husbandries) do
          if husbandry.updateMinutesInterval ~= nil then
            husbandry.updateMinutes = husbandry.updateMinutesInterval + 1
          end
        end
      end
    end
    --
    if g_currentMission:getIsClient() then
        self.cWorldCorners3x3 = {
            { g_i18n:getText("northwest") ,g_i18n:getText("north")  ,g_i18n:getText("northeast") },
            { g_i18n:getText("west")      ,g_i18n:getText("center") ,g_i18n:getText("east")      },
            { g_i18n:getText("southwest") ,g_i18n:getText("south")  ,g_i18n:getText("southeast") }
        };
        -- If some fruit-name could not be found, try using the map-mod's own g_i18n:getText() function
        if g_currentMission.missionInfo and g_currentMission.missionInfo.map and g_currentMission.missionInfo.map.customEnvironment then
            local env0 = getfenv(0)
            local mapMod = env0[g_currentMission.missionInfo.map.customEnvironment]
            if mapMod ~= nil and mapMod.g_i18n ~= nil then
                self.mapGI18N = mapMod.g_i18n;
            end
        end;
    end
    --
    self:loadConfig()
    --
    Glance.discoverLocationOfSchweineDaten()
end;

function Glance:deleteMap()
  --Glance.soilModLayers = nil;
  self.mapGI18N = nil;
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

function Glance.discoverLocationOfSchweineDaten()
    Glance.mod_SchweineZucht = nil

    local env = getfenv(0);
    for modName,isLoaded in pairs(g_modIsLoaded) do
        if isLoaded then
            if env[modName] ~= nil and env[modName]["g_SchweineDaten"] ~= nil then
                -- Found location of g_SchweineDaten from SchweineZucht.LUA
                Glance.mod_SchweineZucht = env[modName];
                --log("Glance.LUA: Found ",modName,".g_SchweineDaten")
                print(("** Glance found %s.g_SchweineDaten"):format(modName))
                break
            end
        end
    end
end;


function Glance:update(dt)
  if g_dedicatedServerInfo == nil then
    if Glance.triggerReload ~= nil then
      -- Simple auto-reload of Glance config, when leaving the ESC menu.
      Glance.triggerReload = Glance.triggerReload - 1
      if Glance.triggerReload <= 0 then
          Glance.triggerReload = nil
          self:loadConfig()
          --
          if Glance.failedConfigLoad ~= nil then
            g_currentMission.inGameMessage:showMessage("Glance", g_i18n:getText("config_error"), 5000);
          end
      end
    end
    --if Glance.failedConfigLoad ~= nil and Glance.failedConfigLoad > g_currentMission.time then
    --    local secsRemain = math.floor((Glance.failedConfigLoad - g_currentMission.time) / 1000)
    --    g_currentMission:addWarning(string.format(g_i18n:getText("config_error"), secsRemain), "bb", "cc");
    --    --g_currentMission.inGameMessage:showMessage("Glance", g_i18n:getText("config_error"), 5000);
    --end;
  end
  --
  Glance.sumTime = Glance.sumTime + dt;
  if Glance.sumTime >= Glance.updateIntervalMS then
    Glance.sumTime = 0;
    Glance.makeUpdateEventFor = {}
    --
    if Glance.fieldsRects == nil then
        log("g_dedicatedServerInfo=",g_dedicatedServerInfo,", g_server=",g_server,", g_client=",g_client,", g_currentMission:getIsServer()=",g_currentMission:getIsServer(),", g_currentMission:getIsClient()=",g_currentMission:getIsClient())
    
        Glance.fieldsRects = {}
        Glance.buildFieldsRects()
    end
    --
    if g_currentMission:getIsClient() then
--[[
        self.drawSoilCondition = {}
        Glance.makeSoilCondition(self, Glance.sumTime, self.drawSoilCondition);
        if not next(self.drawSoilCondition) then
            self.drawSoilCondition = nil;
        end
--]]
        --
        self.linesNonVehicles = {};

        local lineNonVehicles = {}
        Glance.makeHusbandriesLine(self, Glance.sumTime, lineNonVehicles);
        Glance.makePlaceablesLine(self, Glance.sumTime, lineNonVehicles);
        if next(lineNonVehicles) then
            table.insert(self.linesNonVehicles, lineNonVehicles)
        end

        local lineNonVehicles = {}
        Glance.makeFieldsLine(self, Glance.sumTime, lineNonVehicles);
        if next(lineNonVehicles) then
            table.insert(self.linesNonVehicles, lineNonVehicles)
        end
        --
        Glance.makeVehiclesLines(self, Glance.sumTime);
    else
        -- Gather notifications that are only available server-side, and when its a dedicated-server.
        local lineNonVehicles = {}
        Glance.makeFieldsLine(self, Glance.sumTime, lineNonVehicles);
    end
    --
    if next(Glance.makeUpdateEventFor)
    and (g_dedicatedServerInfo ~= nil or g_server ~= nil)
    then
        -- Only server sends to clients
        GlanceEvent.sendEvent();
    end
  end;
  --
    if g_currentMission:getIsClient() then
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
    end
end;

Glance.cCfgVersion = 7

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
,'        <notification  minimumLevel="'..dnl()..'"  updateIntervalMs="2000" />'
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
,'        <!-- Size of the font is measured in percentage of the screen-height, which goes from 0.0000 (0%) to 1.0000 (100%)'
,'             Next row position is calculated from \'size + rowSpacing\', which then gives the rowHeight. -->'
,'        <font  size="0.011"  rowSpacing="-0.001"  shadowOffset="0.00128"  shadowColor="black" />'
,''
,'        <!-- Currently only Y position is supported. Bottom is at 0.0000 (0%) and top is at 1.0000 (100%) -->'
,'        <placementInDisplay  positionXY="0.000 0.999" />'
,'    </general>'
,''
,'    <notifications>'
,'        <collisionDetection whenBelowThreshold="1" /> <!-- threshold unit is "km/h" -->'
,''
,'        <!-- Set  enabled="false"   to disable a particular notification.'
,'             Set  level="<number>"  to change the level of a notification. -->'
,'        <notification  enabled="true"  type="controlledByMe"            level="'..dnl( 0)..'"   color="green" />'
,'        <notification  enabled="true"  type="controlledByPlayer"        level="'..dnl( 0)..'"   color="white" />'
,'        <notification  enabled="true"  type="controlledByHiredWorker"   level="'..dnl( 0)..'"   color="blue" />'
,'        <notification  enabled="true"  type="controlledByCourseplay"    level="'..dnl( 0)..'"   color="blue" />'
,'        <notification  enabled="true"  type="controlledByFollowMe"      level="'..dnl( 0)..'"   color="blue" />'
,''
,'        <notification  enabled="true"  type="hiredWorkerFinished"       level="'..dnl( 3)..'"   color="orange" />'
,''
,'        <notification  enabled="true"  type="vehicleBroken"             level="'..dnl( 0)..'"   color="red" />'
,'        <notification  enabled="true"  type="vehicleCollision"          level="'..dnl( 3)..'"   whenAboveThreshold="10000"  color="red"    /> <!-- threshold unit is "milliseconds" -->'
,'        <notification  enabled="true"  type="vehicleIdleMovement"       level="'..dnl(-2)..'"   whenBelowThreshold="0.5"                   /> <!-- threshold unit is "km/h" -->'
,'        <notification  enabled="true"  type="vehicleFuelLow"            level="'..dnl(-1)..'"   whenBelowThreshold="5"      color="red"    /> <!-- threshold unit is "percentage" -->'
,''
,'        <!-- Vehicle fill-level -->'
,'        <notification  enabled="true"  type="grainTankFull"             level="'..dnl( 2)..'"   whenAboveThreshold="80"  color="yellow" /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="forageWagonFull"           level="'..dnl( 0)..'"   whenAboveThreshold="99"  color="yellow" /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="baleLoaderFull"            level="'..dnl( 1)..'"   whenAboveThreshold="99"  color="yellow" /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="trailerFull"               level="'..dnl(-1)..'"   whenAboveThreshold="99.99"              /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="sprayerLow"                level="'..dnl( 0)..'"   whenBelowThreshold="3"   color="red"    /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="seederLow"                 level="'..dnl( 0)..'"   whenBelowThreshold="3"   color="red"    /> <!-- threshold unit is "percentage" -->'
,''
,'        <!-- Fields specific -->'
,'        <notification  enabled="true"  type="balesWithinFields"             level="'..dnl(-1)..'"   whenAboveThreshold="0"  color="yellow" /> <!-- threshold unit is "units" -->'
,'        <notification  enabled="false" type="balesOutsideFields"            level="'..dnl(-2)..'"   whenAboveThreshold="0"  color="yellow" /> <!-- threshold unit is "units" -->'
,''
,'        <!-- Animal husbandry - Productivity, Wool pallet, Eggs (pickup objects) -->'
,'        <!--                                "husbandry[:<animalTypeName>]:(PickupObjects|Pallet|Productivity)"  -->'
,'        <notification  enabled="true"  type="husbandry:PickupObjects"       level="'..dnl(-2)..'"   whenAboveThreshold="99.99"  color="yellow" /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="husbandry:Pallet"              level="'..dnl(-1)..'"   whenAboveThreshold="99.99"  color="yellow" /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="husbandry:Productivity"        level="'..dnl( 1)..'"   whenAboveThreshold="0"  whenBelowThreshold="100"    color="yellow" /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="husbandry:sheep:Productivity"  level="'..dnl( 0)..'"   whenAboveThreshold="0"  whenBelowThreshold="90"     color="yellow" /> <!-- threshold unit is "percentage" -->'
,''
,'        <!-- Animal husbandry - Fill-level -->'
,'        <!--                                "husbandry[:<animalTypeName>]:<fillTypeName>"  -->'
,'        <notification  enabled="true"  type="husbandry:forage"              level="'..dnl( 0)..'"   whenBelowThreshold="1000"   color="yellow"  text="TMR"     /> <!-- threshold unit is "units" -->'
,'        <notification  enabled="false" type="husbandry:chicken:forage"      level="'..dnl(-3)..'"                               color="yellow"                 /> <!-- chickens do not require forage, so hide it by setting enabled to false -->'
,'        <notification  enabled="true"  type="husbandry:sheep:forage"        level="'..dnl( 0)..'"   whenBelowThreshold="100"    color="yellow"  text="Grass"   /> <!-- sheep do not really take forage, but Grass -->'
--[[
,'        <EXAMPLEnotification  enabled="true"  type="husbandry:cow:forage"          level="'..dnl( 0)..'"   whenBelowThreshold="1000"   color="yellow"  text="TMR"     /> <!-- threshold unit is "units" -->'
,'        <EXAMPLEnotification  enabled="false" type="husbandry:cow:silage"          level="'..dnl( 0)..'"   whenBelowThreshold="1000"   color="yellow"  text="Silage"  /> <!-- threshold unit is "units" -->'
,'        <EXAMPLEnotification  enabled="false" type="husbandry:cow:grass_windrow"   level="'..dnl( 0)..'"   whenBelowThreshold="1000"   color="yellow"  text="Grass"   /> <!-- threshold unit is "units" -->'
--]]
,'        <notification  enabled="true"  type="husbandry:cow:wheat_windrow"   level="'..dnl( 0)..'"   whenBelowThreshold="1000"   color="yellow"  text="Straw"   /> <!-- threshold unit is "units" -->'
,'        <notification  enabled="true"  type="husbandry:cow:manure"          level="'..dnl(-2)..'"   whenAboveThreshold="99"     color="yellow"                 /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="husbandry:cow:liquidManure"    level="'..dnl(-2)..'"   whenAboveThreshold="99"     color="yellow"                 /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="false" type="husbandry:cow:milk"            level="'..dnl(-1)..'"   whenAboveThreshold="20000"  color="yellow"                 /> <!-- threshold unit is "units" -->'
,'        <!-- mod support -->'
,'        <notification  enabled="false" type="husbandry:chicken:wheat"       level="'..dnl(-1)..'"   whenBelowThreshold="100"    color="yellow"                    /> <!-- threshold unit is "units" -->'
,'        <notification  enabled="false" type="husbandry:water"               level="'..dnl( 0)..'"   whenBelowThreshold="100"    color="yellow"                    /> <!-- threshold unit is "units" -->'
,'        <notification  enabled="false" type="husbandry:grain_fruits"        level="'..dnl( 0)..'"   whenBelowThreshold="1000"   color="yellow"  text="Grains"     /> <!-- threshold unit is "units" -->'
,'        <notification  enabled="false" type="husbandry:earth_fruits"        level="'..dnl( 0)..'"   whenBelowThreshold="1000"   color="yellow"  text="Roots"      /> <!-- threshold unit is "units" -->'
,'        <notification  enabled="false" type="husbandry:Silo_fruits"         level="'..dnl( 0)..'"   whenBelowThreshold="1000"   color="yellow"  text="SiloFruits" /> <!-- threshold unit is "units" -->'
--[[
,'        <EXAMPLEnotification  enabled="false" type="husbandry:cow:water"           level="'..dnl( 0)..'"   whenBelowThreshold="100"    color="yellow"                    /> <!-- threshold unit is "units" -->'
,'        <EXAMPLEnotification  enabled="false" type="husbandry:pig:forage"          level="'..dnl( 0)..'"   whenBelowThreshold="1000"   color="yellow"  text="TMR"        /> <!-- threshold unit is "units" -->'
,'        <EXAMPLEnotification  enabled="false" type="husbandry:pig:grain_fruits"    level="'..dnl( 0)..'"   whenBelowThreshold="1000"   color="yellow"  text="Grains"     /> <!-- threshold unit is "units" -->'
,'        <EXAMPLEnotification  enabled="false" type="husbandry:pig:earth_fruits"    level="'..dnl( 0)..'"   whenBelowThreshold="1000"   color="yellow"  text="Roots"      /> <!-- threshold unit is "units" -->'
,'        <EXAMPLEnotification  enabled="false" type="husbandry:pig:Silo_fruits"     level="'..dnl( 0)..'"   whenBelowThreshold="1000"   color="yellow"  text="SiloFruits" /> <!-- threshold unit is "units" -->'
,'        <EXAMPLEnotification  enabled="false" type="husbandry:beef:forage"         level="'..dnl( 0)..'"   whenBelowThreshold="1000"   color="yellow"  text="TMR"        /> <!-- threshold unit is "units" -->'
,'        <EXAMPLEnotification  enabled="false" type="husbandry:beef:grain_fruits"   level="'..dnl( 0)..'"   whenBelowThreshold="1000"   color="yellow"  text="Grains"     /> <!-- threshold unit is "units" -->'
,'        <EXAMPLEnotification  enabled="false" type="husbandry:beef:earth_fruits"   level="'..dnl( 0)..'"   whenBelowThreshold="1000"   color="yellow"  text="Roots"      /> <!-- threshold unit is "units" -->'
,'        <EXAMPLEnotification  enabled="false" type="husbandry:beef:Silo_fruits"    level="'..dnl( 0)..'"   whenBelowThreshold="1000"   color="yellow"  text="SiloFruits" /> <!-- threshold unit is "units" -->'
--]]
,''
,'        <!-- Placeable - Fill-level -->'
,'        <!--                                "placeable:(Greenhouse|MischStation)[:<fillTypeName>]"  -->'
,'        <notification  enabled="true"  type="placeable:Greenhouse:water"    level="'..dnl(-1)..'"   whenBelowThreshold="10"      color="yellow" /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="placeable:Greenhouse:manure"   level="'..dnl(-1)..'"   whenBelowThreshold="10"      color="yellow" /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="false" type="placeable:Greenhouse"          level="'..dnl(-1)..'"   whenBelowThreshold="10"      color="yellow" /> <!-- threshold unit is "percentage" -->'
,'        <!-- mod support -->'
,'        <notification  enabled="false" type="placeable:MischStation:wheat_windrow"    level="'..dnl(-1)..'"   whenBelowThreshold="1"       color="yellow"  text="Straw"  /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="false" type="placeable:MischStation:barley_windrow"   level="'..dnl(-1)..'"   whenBelowThreshold="1"       color="yellow"  text="Straw"  /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="false" type="placeable:MischStation:grass_windrow"    level="'..dnl(-1)..'"   whenBelowThreshold="1"       color="yellow"  text="Grass"  /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="false" type="placeable:MischStation:dryGrass_windrow" level="'..dnl(-1)..'"   whenBelowThreshold="1"       color="yellow"  text="Grass"  /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="false" type="placeable:MischStation:silage"           level="'..dnl(-1)..'"   whenBelowThreshold="1"       color="yellow"  text="Silage" /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="placeable:MischStation:forage"           level="'..dnl( 0)..'"   whenBelowThreshold="10"      color="yellow"  text="TMR"    /> <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="false" type="placeable:MischStation"                  level="'..dnl(-1)..'"   whenBelowThreshold="10"      color="yellow"                /> <!-- threshold unit is "percentage" -->'
,''
,'        <!-- Additional mods -->'
,'        <notification  enabled="true"  type="engineOnButNotControlled"  level="'..dnl( 0)..'"   color="yellow"/>'
--[[
,'        <notification  enabled="true"  type="damaged"                   level="'..dnl(-1)..'"   whenAboveThreshold="25" color="yellow"/>  <!-- threshold unit is "percentage" -->'
,'        <notification  enabled="true"  type="aForestModTrees"           level="'..dnl(-3)..'"   whenAboveThreshold="0"  color="yellow"/>  <!-- threshold unit is "count-of-trees-ready" -->'
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
,'        <column  enabled="true"  contains="ColumnDelim"                  color="gray"            align="center"  minWidthText=""                  text="'..Glance.cColumnDelimChar..'" />'
,'        <column  enabled="true"  contains="FillLevel"                                            align="right"   minWidthText=""                  />'
,'        <column  enabled="true"  contains="ColumnDelim"                                          align="right"   minWidthText="I"                 text="" />'
,'        <column  enabled="true"  contains="FillPercent"                                          align="center"  minWidthText=""                  />'
,'        <column  enabled="true"  contains="ColumnDelim"                                          align="left"    minWidthText="I"                 text="" />'
,'        <column  enabled="true"  contains="FillTypeName"                                         align="left"    minWidthText=""  maxTextLen="12" />'
,'        <column  enabled="true"  contains="ColumnDelim"                  color="gray"            align="center"  minWidthText=""                  text="'..Glance.cColumnDelimChar..'" />'
,'        <column  enabled="true"  contains="ActiveTask;EngineOn"                                  align="left"    minWidthText=""                  />'
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

    local fileName = g_modsDirectory .. "/" .. "Glance_Config.XML";
    local tag = "glanceConfig"

    -- Inspired by ZZZ_GPS
    local function checkIsDedi()
        local pixelX, pixelY = getScreenModeInfo(getScreenMode());
        return pixelX*pixelY < 1;
    end;
    local isDediServer = checkIsDedi();
    --
    local xmlFile = nil
    if g_dedicatedServerInfo ~= nil or isDediServer then
        print("** Glance seems to be running on a dedicated-server. So default built-in configuration values will be used.");
        xmlFile = loadXMLFileFromMemory(tag, self:getDefaultConfig(), true)
    elseif fileExists(fileName) then
        xmlFile = loadXMLFile(tag, fileName)
    else
        print("** Glance will now try to create a new default configuration file; " .. fileName);
        self:createNewConfig(fileName)
        xmlFile = loadXMLFile(tag, fileName)
    end;

    --
    local version = getXMLInt(xmlFile, "glanceConfig#version")
    if xmlFile == nil or version == nil then
        print("** Looks like an error may have occurred, when Glance tried to load its configuration file.");
        print("** This could be due to a corrupted XML structure, or otherwise problematic file-handling.");
        print("!! Please quit the game and fix the XML or delete the file to let Glance create a new one; " .. fileName);
        Glance.failedConfigLoad = g_currentMission.time + 10000;
        return;
    end
    if version ~= Glance.cCfgVersion then
        print("!! The existing Glance_Config.XML file is of a not supported version '"..tostring(version).."', and will NOT be loaded.")
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
            print("!! Glance_Config.XML has invalid color setting, for color name: "..tostring(colorName));
        end
    end
    --
    local function getColorName(xmlFile, tag, defaultColorName)
        local colorName = getXMLString(xmlFile, tag)
        if colorName ~= nil then
            if Glance.colors[colorName] ~= nil then
                return colorName
            end
            print("!! Glance_Config.XML has invalid color-name '"..tostring(colorName).."', in: "..tostring(tag));
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
            ,aboveThreshold =                getXMLFloat(  xmlFile, tag.."#whenAboveThreshold")
            ,belowThreshold =                getXMLFloat(  xmlFile, tag.."#whenBelowThreshold")
          --,coolDownMS     =                getXMLInt(    xmlFile, tag.."#coolDownMs")
            ,text           =                getXMLString( xmlFile, tag.."#text")
        }
        --
        Glance.maxNotifyLevel = math.max(Glance.maxNotifyLevel, Glance.notifications[notifyType].level)
    end
    --
    Glance.collisionDetection_belowThreshold = Utils.getNoNil(getXMLFloat(xmlFile, "glanceConfig.notifications.collisionDetection#whenBelowThreshold"), Glance.collisionDetection_belowThreshold);

    Glance.nonVehiclesSeparator = Utils.getNoNil(getXMLString(xmlFile, "glanceConfig.nonVehicles#separator"), Glance.nonVehiclesSeparator);
    Glance.nonVehiclesFillLevelFormat = Utils.getNoNil(getXMLString(xmlFile, "glanceConfig.nonVehicles#fillLevelFormat"), Glance.nonVehiclesFillLevelFormat);

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
    local isBroken = false
    local newValue = oldValue

    if (ntfy ~= nil and value ~= nil) then
        if (ntfy.belowThreshold == nil and ntfy.aboveThreshold ~= nil) then
            -- Only test above
            if (value > ntfy.aboveThreshold) then
                isBroken = true
                newValue = math.max(value, Utils.getNoNil(newValue, value))
            end
        elseif (ntfy.belowThreshold ~= nil and ntfy.aboveThreshold == nil) then
            -- Only test below
            if (value < ntfy.belowThreshold) then
                isBroken = true
                newValue = math.min(value, Utils.getNoNil(newValue, value))
            end
        elseif (ntfy.belowThreshold ~= nil and ntfy.aboveThreshold ~= nil) then
            -- Either test outside or inside
            if (ntfy.belowThreshold < ntfy.aboveThreshold) then
                -- Only test outside
                if (value < ntfy.belowThreshold) then
                    isBroken = true
                    newValue = math.min(value, Utils.getNoNil(newValue, value))
                elseif (ntfy.aboveThreshold < value) then
                    isBroken = true
                    newValue = math.max(value, Utils.getNoNil(newValue, value))
                end
            elseif (ntfy.belowThreshold > ntfy.aboveThreshold) then
                -- Only test inside
                if (ntfy.aboveThreshold < value and value < ntfy.belowThreshold) then
                    isBroken = true
                    newValue = math.max(value, Utils.getNoNil(newValue, value)) -- TODO. Calculate closest distance to either above or below, and use that as new value.
                end
            end
        end
    end

    return isBroken, newValue
end

local function isOutsideThresholds(ntfy, value)
    return  (   ntfy ~= nil and value ~= nil
            and (   (ntfy.belowThreshold ~= nil and value < ntfy.belowThreshold)
                 or (ntfy.aboveThreshold ~= nil and value > ntfy.aboveThreshold) )
            )
end

local function isBelowThreshold(ntfy, value)
    return (ntfy ~= nil and value ~= nil and ntfy.belowThreshold ~= nil and value < ntfy.belowThreshold)
end

local function isAboveThreshold(ntfy, value)
    return (ntfy ~= nil and value ~= nil and ntfy.aboveThreshold ~= nil and value > ntfy.aboveThreshold)
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
    local fieldsBales = {}
    local constNumFields = 0

    if  g_currentMission.fieldDefinitionBase ~= nil
    and g_currentMission.fieldDefinitionBase.fieldDefs ~= nil
    then
        constNumFields = table.getn(g_currentMission.fieldDefinitionBase.fieldDefs)
    end

    local balesWithinFields  = Glance.notifications["balesWithinFields"]
    local balesOutsideFields = Glance.notifications["balesOutsideFields"]

    --
    if g_currentMission.itemsToSave ~= nil
    and (g_dedicatedServerInfo ~= nil or g_server ~= nil)
    then
        local numUsers = table.getn(g_currentMission.users)
        -- If listen-server and only 1 player (i.e. singleplayer)
        if  g_dedicatedServerInfo == nil
        and numUsers <= 1
        then
            if  false == isNotifyLevel(balesWithinFields)
            and false == isNotifyLevel(balesOutsideFields)
            then
                -- The singleplayer does currently not want these notifications.
                return
            end
        end

        -- Server.
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
                    fieldsBales[0] = 1 + Utils.getNoNil(fieldsBales[0],0)
                end
            end
        end

        -- Build string so it can be send to clients.
        if g_dedicatedServerInfo ~= nil or numUsers > 1 then
            local value = nil
            local delim = ""
            for fieldNum=0,constNumFields do
                if fieldsBales[fieldNum] ~= nil and fieldsBales[fieldNum] > 0 then
                    value = Utils.getNoNil(value,"") .. delim .. ("%d:%d"):format(fieldNum,fieldsBales[fieldNum])
                    delim = ","
                end
            end

            log("setProperty 'fieldsBales': ",value)
            Glance.setProperty(nil, "fieldsBales", value)
        end
    else
        -- Client(s).
        local value = Glance.getProperty(nil, "fieldsBales")
        log("getProperty 'fieldsBales': ",value)
        if value ~= nil then
            -- Parse the string received from server.
            value = Utils.splitString(",", value)
            for _,fieldBales in pairs(value) do
                local fieldNum,balesCount = Utils.splitString(":", fieldBales)
                fieldNum,balesCount = tonumber(fieldNum),tonumber(balesCount)
                if fieldNum ~= nil and balesCount ~= nil then
                    fieldsBales[fieldNum] = balesCount
                end
            end
        end
    end

    --
    if g_currentMission:getIsClient() then
        if isNotifyLevel(balesWithinFields) then
            local txt = nil
            for fieldNum=1,constNumFields do
                if isBreakingThresholds(balesWithinFields, fieldsBales[fieldNum]) then
                    txt = Utils.getNoNil(txt,"") .. (g_i18n:getText("fieldNumAndBales")):format(fieldNum,fieldsBales[fieldNum]);
                end
            end
            if txt ~= nil then
                table.insert(notifyList, { Glance.colors[balesWithinFields.color], g_i18n:getText("fieldsWithBales") .. txt });
            end
        end

        if isNotifyLevel(balesOutsideFields) and isBreakingThresholds(balesOutsideFields, fieldsBales[0]) then
            table.insert(notifyList, { Glance.colors[balesOutsideFields.color], (g_i18n:getText("balesElsewhere")):format(fieldsBales[0]) });
        end
    end
end

-----

function Glance:makePlaceablesLine(dt, notifyList)

    if g_currentMission.placeables ~= nil then

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
        local function updateNotification(placeableType, addItemCount, fillType, newLow, newHigh, newColor)
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
                end
                if newHigh ~= nil and (pct == nil or pct < newHigh) then
                    foundNotifications[placeableType].fillLevels[fillType] = newHigh
                end
            end
            if newColor ~= nil then
                foundNotifications[placeableType].color = newColor
            end
        end

        for plcXmlFilename,plcTable in pairs(g_currentMission.placeables) do
            local funcTestPlaceable = nil;

            -- plcXmlFilename contains placeable-name in lowercase
            if string.find(plcXmlFilename, "greenhouse") ~= nil then
                local placeableType = "Greenhouse"
                local ntfyGreenhouse = {}
                ntfyGreenhouse[Fillable.FILLTYPE_WATER]   = getNotification(placeableType, "water")
                ntfyGreenhouse[Fillable.FILLTYPE_MANURE]  = getNotification(placeableType, "manure")
                ntfyGreenhouse[Fillable.FILLTYPE_UNKNOWN] = getNotification(placeableType)
                --
                funcTestPlaceable = function(plc)
                    -- Make sure the variables we expect, are actually there.
                    if not (    hasNumberValue(plc.waterTankFillLevel) and hasNumberValue(plc.waterTankCapacity,0)
                            and hasNumberValue(plc.manureFillLevel)    and hasNumberValue(plc.manureCapacity,0)   )
                    then
                        return
                    end
                    --
                    local fillLevels = {}
                    fillLevels[Fillable.FILLTYPE_WATER]  = 100 * plc.waterTankFillLevel / plc.waterTankCapacity;
                    fillLevels[Fillable.FILLTYPE_MANURE] = 100 * plc.manureFillLevel    / plc.manureCapacity;

                    if isNotifyEnabled(ntfyGreenhouse[Fillable.FILLTYPE_UNKNOWN]) then
                        if isNotifyLevel(ntfyGreenhouse[Fillable.FILLTYPE_UNKNOWN]) then
                            local minPct = math.min(fillLevels[Fillable.FILLTYPE_WATER], fillLevels[Fillable.FILLTYPE_MANURE])
                            if isBelowThreshold(ntfyGreenhouse[Fillable.FILLTYPE_UNKNOWN], minPct) then
                                updateNotification(placeableType, 1, Fillable.FILLTYPE_UNKNOWN, minPct, nil, ntfyGreenhouse[Fillable.FILLTYPE_UNKNOWN].color)
                            end
                        end
                    else
                        local itemCount = nil
                        for fillType,ntfy in pairs(ntfyGreenhouse) do
                            if fillType ~= Fillable.FILLTYPE_UNKNOWN and isNotifyLevel(ntfy) then
                                if isBelowThreshold(ntfy, fillLevels[fillType]) then
                                    updateNotification(placeableType, nil, fillType, fillLevels[fillType], nil, ntfy.color)
                                    itemCount = 1
                                end
                            end
                        end
                        if itemCount ~= nil then
                            updateNotification(placeableType, itemCount)
                        end
                    end
                end
            elseif string.find(plcXmlFilename, "mischstation") ~= nil then
                local placeableType = "MischStation"
                local ntfyMischStation = {}
                for fillType,fillDesc in pairs(Fillable.fillTypeIndexToDesc) do
                    local fillName = (fillType ~= Fillable.FILLTYPE_UNKNOWN and fillDesc.name or nil)
                    local ntfy = getNotification(placeableType, fillName)
                    if ntfy ~= nil then
                        ntfyMischStation[fillType] = ntfy
                    end
                end
                --
                funcTestPlaceable = function(plc)
                    -- Make sure the variables we expect, are actually there.
                    if not (    plc.SetLamp ~= nil and plc.MixLvl ~= nil and plc.LvLIndicator ~= nil and hasNumberValue(plc.LvLIndicator.capacity,0)
                            and plc.MixTypLvl ~= nil and plc.MixTypName ~= nil and plc.TipTriggers ~= nil )
                    then
                        return
                    end
                    --
                    local fillLevels = {}
                    fillLevels[Fillable.FILLTYPE_FORAGE] = 100 * plc.MixLvl / plc.LvLIndicator.capacity;
                    local minPct = fillLevels[Fillable.FILLTYPE_FORAGE];
                    for i=1,table.getn(plc.MixTypName) do
                        if plc.MixTypName[i] ~= nil and plc.MixTypName[i].index ~= nil and plc.TipTriggers[i] ~= nil and hasNumberValue(plc.TipTriggers[i].capacity,0) then
                            local fillType = plc.MixTypName[i].index
                            local pct = 100 * plc.MixTypLvl[i] / plc.TipTriggers[i].capacity;
                            fillLevels[fillType] = pct
                            minPct = math.min(minPct,pct)
                        end
                    end

                    if isNotifyEnabled(ntfyMischStation[Fillable.FILLTYPE_UNKNOWN]) then
                        if isNotifyLevel(ntfyMischStation[Fillable.FILLTYPE_UNKNOWN]) and isOutsideThresholds(ntfyMischStation[Fillable.FILLTYPE_UNKNOWN], minPct) then
                            updateNotification(placeableType, 1, Fillable.FILLTYPE_UNKNOWN, minPct, nil, ntfyMischStation[Fillable.FILLTYPE_UNKNOWN].color)
                        end
                    else
                        local itemCount = nil
                        for fillType,ntfy in pairs(ntfyMischStation) do
                            if fillType ~= Fillable.FILLTYPE_UNKNOWN and isNotifyLevel(ntfy) then
                                if isOutsideThresholds(ntfy, fillLevels[fillType]) then
                                    updateNotification(placeableType, nil, fillType, fillLevels[fillType], nil, ntfy.color)
                                    itemCount = 1
                                end
                            end
                        end
                        if itemCount ~= nil then
                            updateNotification(placeableType, itemCount)
                        end
                    end

                end
            else
                -- TODO - Add other useful placeables???
            end

            --
            if funcTestPlaceable ~= nil then
                for _,plc in pairs(plcTable) do
                    funcTestPlaceable(plc)
                end
            end
        end


        --
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
            if elem.fillLevels[Fillable.FILLTYPE_UNKNOWN] ~= nil then
                --txt = txt .. ("@%.0f%%"):format(elem.fillLevels[Fillable.FILLTYPE_UNKNOWN])
                txt = txt .. (Glance.nonVehiclesFillLevelFormat):format("", "", ("%.0f%%"):format(elem.fillLevels[Fillable.FILLTYPE_UNKNOWN]))
            else
                local prefix=":"
                for fillType,fillPct in pairs(elem.fillLevels) do
                    if fillType ~= Fillable.FILLTYPE_UNKNOWN then
                        --txt = txt .. prefix .. ("%s@%.0f%%"):format(Fillable.fillTypeIndexToDesc[fillType].nameI18N, fillPct)
                        txt = txt .. (Glance.nonVehiclesFillLevelFormat):format(prefix, Fillable.fillTypeIndexToDesc[fillType].nameI18N, ("%.0f%%"):format(fillPct))
                        prefix=","
                    end
                end
            end
            table.insert(notifyList, { Glance.colors[elem.color], txt });
        end
    end

--[[
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
--]]
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


--[[
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
                        if sumPixels1>0 and numPixels1>0 then
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
--]]

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
        local function getFillName(ntfy, i18nName, fillType)
            if ntfy.text ~= nil then
                return tostring(ntfy.text)
            end
            if fillType ~= nil then
                if Fillable.fillTypeIndexToDesc[fillType] ~= nil then
                    if Fillable.fillTypeIndexToDesc[fillType].nameI18N ~= nil then
                        return Fillable.fillTypeIndexToDesc[fillType].nameI18N
                    else
                        return Fillable.fillTypeIndexToDesc[fillType].name
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
            return Fillable.fillTypeIndexToDesc[Fillable.FILLTYPE_UNKNOWN].name
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

        -- Support for SchweineZucht.LUA
        local customFillTypes = {}
        local grainFruitsType = nil
        local earthFruitsType = nil
        local siloFruitsType  = nil
        if Glance.mod_SchweineZucht ~= nil then
            -- Because SchweineZucht have no accessible tables to determine what fill-type/-name is what,
            -- it has to be hardcoded here, and I assume that its FutterIntName table won't be altered.
            grainFruitsType = Fillable.NUM_FILLTYPES + 1
            earthFruitsType = Fillable.NUM_FILLTYPES + 2
            siloFruitsType  = Fillable.NUM_FILLTYPES + 3
            customFillTypes[grainFruitsType] = "grain_fruits"
            customFillTypes[earthFruitsType] = "earth_fruits"
            customFillTypes[siloFruitsType ] = "Silo_fruits"
        end

        --
        for animalType,mainHusbandry in pairs(g_currentMission.husbandries) do
            local husbandries = { mainHusbandry } -- Due to support for multiple husbandries, because of SchweineZucht.LUA
            infos = {}
            local color = Glance.lineColorDefault;
            --
            local ntfyProductivity  = getNotification(animalType, "Productivity")
            local ntfyPallet        = getNotification(animalType, "Pallet")
            local ntfyPickupObjects = getNotification(animalType, "PickupObjects")

            -- Fill-levels
            local ntfyStorage = {}
            for fillType,fillDesc in pairs(Fillable.fillTypeIndexToDesc) do
                if fillType ~= Fillable.FILLTYPE_UNKNOWN then
                    local ntfy = getNotification(animalType, fillDesc.name)
                    if ntfy ~= nil then
                        ntfyStorage[fillType] = ntfy
                    end
                end
            end
            for fillType,fillName in pairs(customFillTypes) do
                local ntfy = getNotification(animalType, fillName)
                if ntfy ~= nil then
                    ntfyStorage[fillType] = ntfy
                end
            end

            -- Support for SchweineZucht.LUA
            if Glance.mod_SchweineZucht ~= nil then
                if Glance.mod_SchweineZucht.g_SchweineDaten ~= nil and Glance.mod_SchweineZucht.g_SchweineDaten[animalType] ~= nil then
                    husbandries = Glance.mod_SchweineZucht.g_SchweineDaten[animalType]
                end
            end

            -- Due to support for one animalType with multiple husbandries, because of SchweineZucht.LUA
            for _,husbandry in pairs(husbandries) do

                -- Productivity
                if isNotifyLevel(ntfyProductivity) then
                    local productivity = Utils.getNoNil(husbandry.productivity, husbandry.Produktivi)   -- Support for SchweineZucht.LUA
                    if productivity ~= nil then
                        local pct = math.floor(productivity * 100);
                        local fillName = getFillName(ntfyProductivity, "Productivity", nil)
                        local isBroken, pct = isBreakingThresholds(ntfyProductivity, pct, getInfoValue(fillName))
                        if isBroken then
                            color = Utils.getNoNil(ntfyProductivity.color, color)
                            updateInfoValue(fillName, 1, pct, "%")
                        end
                    end
                end;

                -- Pallet (Wool)
                if husbandry.currentPallet ~= nil and husbandry.currentPallet.getFillLevel ~= nil
                and husbandry.currentPallet.getCapacity ~= nil and hasNumberValue(husbandry.currentPallet:getCapacity(),0)
                and isNotifyLevel(ntfyPallet)
                then
                    local pct = math.floor((husbandry.currentPallet:getFillLevel() * 100) / husbandry.currentPallet:getCapacity());
                    local fillName = getFillName(ntfyPallet, nil, husbandry.palletFillType)
                    local isBroken, pct = isBreakingThresholds(ntfyPallet, pct, getInfoValue(fillName))
                    if isBroken then
                        color = Utils.getNoNil(ntfyPallet.color, color)
                        updateInfoValue(fillName, 1, pct, "%");
                    end
                end

                -- PickupObjects (Eggs)
                if husbandry.pickupObjectsToActivate ~= nil and husbandry.numActivePickupObjects ~= nil
                and isNotifyLevel(ntfyPickupObjects)
                then
                    local capacity = table.getn(husbandry.pickupObjectsToActivate) + husbandry.numActivePickupObjects;
                    local pct = math.floor((husbandry.numActivePickupObjects * 100) / capacity);
                    local fillName = getFillName(ntfyPickupObjects, nil, husbandry.pickupObjectsFillType)
                    local isBroken, pct = isBreakingThresholds(ntfyPickupObjects, pct, getInfoValue(fillName))
                    if isBroken then
                        color = Utils.getNoNil(ntfyPickupObjects.color, color)
                        updateInfoValue(fillName, 1, pct, "%");
                    end;
                end;

                -- Fill-Levels
                for fillType,ntfy in pairs(ntfyStorage) do
                    if isNotifyLevel(ntfy) then
                        if fillType == Fillable.FILLTYPE_MANURE then
                            if husbandry.manureHeap ~= nil then
                                local fillLevel = Utils.getNoNil(husbandry.manureHeap.fillLevel, husbandry.manureHeap.FillLvl)  -- Support for SchweineZucht.LUA
                                if  hasNumberValue(fillLevel)
                                and hasNumberValue(husbandry.manureHeap.capacity,0)
                                then
                                    local pct = math.floor(100 * fillLevel / husbandry.manureHeap.capacity)
                                    local fillName = getFillName(ntfy, nil, fillType)
                                    local isBroken, pct = isBreakingThresholds(ntfy, pct, getInfoValue(fillName))
                                    if isBroken then
                                        color = Utils.getNoNil(ntfy.color, color)
                                        updateInfoValue(fillName, 1, pct, "%");
                                    end
                                end
                            end
                        elseif fillType == Fillable.FILLTYPE_LIQUIDMANURE then
                            local liquidManure = Utils.getNoNil(husbandry.liquidManureTrigger, husbandry.liquidManureSiloTrigger)  -- Support for SchweineZucht.LUA
                            if liquidManure ~= nil
                            and hasNumberValue(liquidManure.fillLevel)
                            and hasNumberValue(liquidManure.capacity,0)
                            then
                                local pct = math.floor(100 * liquidManure.fillLevel / liquidManure.capacity)
                                local fillName = getFillName(ntfy, nil, fillType)
                                local isBroken, pct = isBreakingThresholds(ntfy, pct, getInfoValue(fillName))
                                if isBroken then
                                    color = Utils.getNoNil(ntfy.color, color)
                                    updateInfoValue(fillName, 1, pct, "%");
                                end
                            end
                        elseif husbandry.FutterTypLvl ~= nil then   -- Support for SchweineZucht.LUA
                            -- Because SchweineZucht have no accessible tables to determine what fill-type/-name is what,
                            -- it has to be hardcoded here, and I assume that its FutterIntName table won't be altered.
                            -- If only SchweineZucht.LUA could implement its own special getFillLevel() method, that would be helpful in the future... ;-)
                            -- 1=grain_fruits, 2=earth_fruits, 3=Silo_fruits, 4=forage, 5=water, 6=straw
                            local fillTypeToFutterTyp = {
                                [grainFruitsType]=1,
                                [earthFruitsType]=2,
                                [siloFruitsType ]=3,
                                [Fillable.FILLTYPE_FORAGE]=4,
                                [Fillable.FILLTYPE_WATER]=5,
                                [Fillable.FILLTYPE_WHEAT_WINDROW]=6,
                                [Fillable.FILLTYPE_BARLEY_WINDROW]=6
                            }
                            local FutterTypIdx = fillTypeToFutterTyp[fillType]
--log(animalType,":",husbandry,": ",fillType,"=",FutterTypIdx,". ",husbandry.FutterTypLvl[FutterTypIdx])
                            if FutterTypIdx ~= nil and husbandry.FutterTypLvl[FutterTypIdx] ~= nil then
                                local lvl = math.floor(husbandry.FutterTypLvl[FutterTypIdx])
                                local fillName = getFillName(ntfy, customFillTypes[fillType], fillType)
                                local isBroken, lvl = isBreakingThresholds(ntfy, lvl, getInfoValue(fillName))
                                if isBroken then
                                    color = Utils.getNoNil(ntfy.color, color)
                                    updateInfoValue(fillName, 1, lvl, "");
                                end
                            end
                        elseif fillType <= Fillable.NUM_FILLTYPES and husbandry.getFillLevel ~= nil then
                            local lvl = math.floor(husbandry:getFillLevel(fillType))
                            local fillName = getFillName(ntfy, nil, fillType)
                            local isBroken, lvl = isBreakingThresholds(ntfy, lvl, getInfoValue(fillName))
                            if isBroken then
                                color = Utils.getNoNil(ntfy.color, color)
                                updateInfoValue(fillName, 1, lvl, "");
                            end
                        end
                    end
                end
                --
            end

            --
--log("#=",#infos)
--log("table.getn=",table.getn(infos))
--log("~={}=",infos ~= {})
--log("next=",next(infos))
            if next(infos) then
                local animalI18N = "statisticView_"..animalType
                if g_i18n:hasText(animalI18N) then
                    animalType = g_i18n:getText(animalI18N);
                elseif Glance.mod_SchweineZucht ~= nil then     -- Support for SchweineZucht.LUA
                    for _,animalI18N in pairs({"statisticView_"..animalType, animalType.."_amount", animalType}) do
                        if Glance.mod_SchweineZucht.g_i18n:hasText(animalI18N) then
                            animalType = Glance.mod_SchweineZucht.g_i18n:getText(animalI18N);
                            break
                        end
                    end
                end;
                local txt = animalType;
                local prefix=":"
                for nfoName,nfo in pairs(infos) do
                    --txt = txt .. prefix .. nfoName .. "@" .. nfo.value .. nfo.valueSuffix;
                    txt = txt .. (Glance.nonVehiclesFillLevelFormat):format(prefix, nfoName, ("%d%s"):format(nfo.value, nfo.valueSuffix))
                    prefix=","
                end
                table.insert(notifyList, { Glance.colors[color], txt});
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
            ,color      = Glance.colors[col.color] or {1,1,1,1}
        };
        table.insert(columns, column)
    end
  end
  self.linesVehicles = { columns }
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
        self.linesVehicles[lines] = columns
    end
  end

  -- Find max text width per column
  for i=2,table.getn(self.linesVehicles) do
    for c=1,table.getn(self.linesVehicles[1]) do
      for e=1,table.getn(self.linesVehicles[i][c]) do
        --
        if self.linesVehicles[1][c].maxLetters ~= nil and self.linesVehicles[i][c][e][2]:len() > self.linesVehicles[1][c].maxLetters then
            self.linesVehicles[i][c][e][2] = self.linesVehicles[i][c][e][2]:sub(1, self.linesVehicles[1][c].maxLetters) .. "…"; -- 0x2026  -- "…"
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
    return { { Glance.colors[colParms.color or lineColor], Utils.getNoNil(colParms.text, Glance.cColumnDelimChar) } }
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

      local pdaMap = Utils.getNoNil(g_currentMission.ingameMap, g_currentMission.missionPDA)
      wx = wx + pdaMap.worldCenterOffsetX;
      wz = wz + pdaMap.worldCenterOffsetZ;
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
      local pdaMap = Utils.getNoNil(g_currentMission.ingameMap, g_currentMission.missionPDA)
      wx = wx + pdaMap.worldCenterOffsetX;
      wz = wz + pdaMap.worldCenterOffsetZ;
      -- Determine world corner - 3x3 grid
      wx = 1 + Utils.clamp(math.floor(wx / (pdaMap.worldSizeX / 3 + 1)), 0, 2); -- We '+1' if at any point the worldSizeX would be zero.
      wz = 1 + Utils.clamp(math.floor(wz / (pdaMap.worldSizeZ / 3 + 1)), 0, 2); -- We '+1' if at any point the worldSizeX would be zero.
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
      for fieldNum,fieldRects in ipairs(Glance.fieldsRects) do
        for _,rect in ipairs(fieldRects) do
          if  rect.x1 <= wx and wx <= rect.x2
          and rect.z1 <= wz and wz <= rect.z2 then
            closestField = fieldNum;
            break
          end
        end
        if closestField ~= nil then
          return { { Glance.colors[lineColor], string.format(g_i18n:getText("closestfield"), closestField) } }
        end;
      end
  end
end
function Glance:getCellData_VehicleName(dt, lineColor, colParms, cells, veh)
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

function Glance:notify_vehicleFuelLow(dt, notifyParms, veh)
  if veh.fuelCapacity ~= nil and veh.fuelCapacity > 0 then
    local fuelPct = math.floor(veh.fuelFillLevel / veh.fuelCapacity * 100);
    if isBelowThreshold(notifyParms, fuelPct) then
      return { "FuelLow", string.format(g_i18n:getText("fuellow"), tostring(fuelPct)) }
    end;
  end;
end

function Glance:notify_engineOnButNotControlled(dt, notifyParms, veh)
  if veh.isMotorStarted then
    if veh.isControlled
    or veh.isHired
    or (veh.getIsCourseplayDriving ~= nil and veh:getIsCourseplayDriving())
    or (veh.modFM ~= nil and veh.modFM.FollowVehicleObj ~= nil)
    then
      -- do nothing
    else
      return { "EngineOn", g_i18n:getText("engineon") }
    end;
  end
end

--[[
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
--]]

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
    if veh.getIsCourseplayDriving ~= nil and veh:getIsCourseplayDriving() then
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
    if veh.modFM ~= nil and veh.modFM.FollowVehicleObj ~= nil then
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
    --if veh.isRealistic and veh.realDisplaySpeed ~= nil then -- Support for Dural's MoreRealistic mod.
    --  speedKmh = veh.realDisplaySpeed * 3.6;
    --else
      speedKmh = veh.lastSpeed * 3600
    --end
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

    --if ntfyIdle ~= nil and ntfyIdle.enabled == true and speedKmh < ntfyIdle.belowThreshold then
    if isNotifyEnabled(ntfyIdle) and isBelowThreshold(ntfyIdle, speedKmh) then
      -- Not moving.
      notifyLevel = math.max(notifyLevel, ntfyIdle.level)

      if waiting then
        cells["MovementSpeed"] = { { Glance.colors[Utils.getNoNil(ntfyIdle.color, notifyLineColor)], g_i18n:getText("cp_waiting") } };
      else
        cells["MovementSpeed"] = { { Glance.colors[Utils.getNoNil(ntfyIdle.color, notifyLineColor)], g_i18n:getText("speedIdle") } };
      end
    else
        cells["MovementSpeed"] = { { Glance.colors[notifyLineColor], string.format(g_i18n:getText("speed+Unit"), g_i18n:getSpeed(speedKmh), g_i18n.globalI18N:getSpeedMeasuringUnit()) } }
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
                        if math.abs(veh.lastSpeedAcceleration) > 0.0 then
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
        if      Sprayer            == spec then impStates.isSprayerOn       = (imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn());
        elseif  ManureSpreader     == spec then impStates.isSprayerOn       = (imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn());
        elseif  ManureBarrel       == spec then impStates.isSprayerOn       = (imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn());
        elseif  SowingMachine      == spec then impStates.isSeederOn        = (imp.movingDirection > 0 and imp.sowingMachineHasGroundContact and (not imp.needsActivation or (imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn())));
        elseif  TreePlanter        == spec then impStates.isTreePlanterOn   = (imp.movingDirection > 0                                       and (not imp.needsActivation or (imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn())));
        elseif  Cultivator         == spec then impStates.isCultivatorOn    = (imp.cultivatorHasGroundContact and (not imp.onlyActiveWhenLowered or imp:isLowered(false)) );
        elseif  Plough             == spec then impStates.isPloughOn        = imp.ploughHasGroundContact;
        elseif  Combine            == spec then impStates.isHarvesterOn     = ((imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn()) and imp:getIsThreshingAllowed(false));
        elseif  ForageWagon        == spec then impStates.isForageWagonOn   = (imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn());
        elseif  Baler              == spec then impStates.isBalerOn         = (imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn());
        elseif  Mower              == spec then impStates.isMowerOn         = (imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn());
        elseif  Tedder             == spec then impStates.isTedderOn        = (imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn());
        elseif  Windrower          == spec then impStates.isWindrowerOn     = (imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn());
        elseif  FruitPreparer      == spec then impStates.isFruitPreparerOn = (imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn());
        elseif  BaleLoader         == spec then impStates.isBaleLoadingOn   = imp.isInWorkPosition;
        elseif  BaleWrapper        == spec then impStates.isBaleWrapperOn   = imp.baleWrapperState ~= nil and ((imp.baleWrapperState > 0) and (imp.baleWrapperState < 4));
        elseif  StrawBlower        == spec then impStates.isStrawBlowerOn   = (imp.tipState == Trailer.TIPSTATE_OPENING or imp.tipState == Trailer.TIPSTATE_OPEN);
        elseif  MixerWagon         == spec then impStates.isMixerWagonOn    = (imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn());
        elseif  StumpCutter        == spec then impStates.isStumpCutterOn   = (imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn());
        elseif  WoodCrusher        == spec then impStates.isWoodCrusherOn   = (imp.getIsTurnedOn ~= nil and imp:getIsTurnedOn());
        elseif  Cutter             == spec then impStates.isCutterOn        = false; -- TODO
        elseif  Trailer            == spec then impStates.isTrailerOn       = (imp.movingDirection > 0.0001) or (imp.movingDirection < -0.0001);
                                                impStates.isTrailerUnloads  = (imp.tipState == Trailer.TIPSTATE_OPENING or imp.tipState == Trailer.TIPSTATE_OPEN);
        end;
    end
  end;


  local function withDelim(txtVal)
    if txtVal ~= nil then
      return txtVal..", "
    else
      return ""
    end
  end

  local txt = nil; -- No task.
  if impStates.isHarvesterOn      then txt = withDelim(txt) .. g_i18n:getText("task_Harvesting"   ); end;
  if impStates.isFruitPreparerOn  then txt = withDelim(txt) .. g_i18n:getText("task_Defoliator"   ); end;
  if impStates.isBaleLoadingOn    then txt = withDelim(txt) .. g_i18n:getText("task_Loading_bales"); end;
  if impStates.isBaleWrapperOn    then txt = withDelim(txt) .. g_i18n:getText("task_Wrapping_bale"); end;
  if impStates.isBalerOn          then txt = withDelim(txt) .. g_i18n:getText("task_Baling"       ); end;
  if impStates.isForageWagonOn    then txt = withDelim(txt) .. g_i18n:getText("task_Foraging"     ); end;
  if impStates.isTedderOn         then txt = withDelim(txt) .. g_i18n:getText("task_Tedding"      ); end;
  if impStates.isWindrowerOn      then txt = withDelim(txt) .. g_i18n:getText("task_Swathing"     ); end;
  if impStates.isMowerOn          then txt = withDelim(txt) .. g_i18n:getText("task_Mowing"       ); end;
  if impStates.isSprayerOn        then txt = withDelim(txt) .. g_i18n:getText("task_Spraying"     ); end;
  if impStates.isSeederOn         then txt = withDelim(txt) .. g_i18n:getText("task_Seeding"      ); end;
  if impStates.isTreePlanterOn    then txt = withDelim(txt) .. g_i18n:getText("task_TreePlanting" ); end;
  if impStates.isStrawBlowerOn    then txt = withDelim(txt) .. g_i18n:getText("task_Bedding"      ); end;
  if impStates.isMixerWagonOn     then txt = withDelim(txt) .. g_i18n:getText("task_Feeding"      ); end;
  if impStates.isCutterOn         then txt = withDelim(txt) .. g_i18n:getText("task_Cutting"      ); end;
  if impStates.isStumpCutterOn    then txt = withDelim(txt) .. g_i18n:getText("task_StumpCutting" ); end;
  if impStates.isWoodCrusherOn    then txt = withDelim(txt) .. g_i18n:getText("task_WoodCrushing" ); end;
  if impStates.isCultivatorOn     then txt = withDelim(txt) .. g_i18n:getText("task_Cultivating"  ); end;
  if impStates.isPloughOn         then txt = withDelim(txt) .. g_i18n:getText("task_Ploughing"    ); end;
  if impStates.isTrailerUnloads   then txt = withDelim(txt) .. g_i18n:getText("task_Unloading"    ); end;

  if txt == nil and impStates.isTrailerOn then txt = withDelim(txt) .. g_i18n:getText("task_Transporting" ); end;

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

    if obj.fillLevelMax and obj.fillLevel and obj.fillLevelMax > 0 and obj.fillLevel > 0 then
        -- Most likely a baleloader
        fillTpe = g_i18n:getText("bales");
        fillPct = math.floor(obj.fillLevel / obj.fillLevelMax * 100);
        fillLvl = obj.fillLevel;
        --
        local ntfy = Glance.notifications["baleLoaderFull"]
        if isNotifyEnabled(ntfy) and isAboveThreshold(ntfy, fillPct) then
            fillClr = ntfy.color or fillClr
            notifyLevel = math.max(notifyLevel, ntfy.level)
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
            if isNotifyEnabled(ntfy) and isBelowThreshold(ntfy, fillPct) then
                fillClr = ntfy.color or fillClr
                notifyLevel = math.max(notifyLevel, ntfy.level)
            end
        elseif SpecializationUtil.hasSpecialization(Sprayer, obj.specializations) then
            local ntfy = Glance.notifications["sprayerLow"]
            if isNotifyEnabled(ntfy) and isBelowThreshold(ntfy, fillPct) then
                fillClr = ntfy.color or fillClr
                notifyLevel = math.max(notifyLevel, ntfy.level)
            end
        elseif SpecializationUtil.hasSpecialization(ForageWagon, obj.specializations) then
            local ntfy = Glance.notifications["forageWagonFull"]
            if isNotifyEnabled(ntfy) and isAboveThreshold(ntfy, fillPct) then
                fillClr = ntfy.color or fillClr
                notifyLevel = math.max(notifyLevel, ntfy.level)
            end
        elseif SpecializationUtil.hasSpecialization(Trailer, obj.specializations) then
            local ntfy = Glance.notifications["trailerFull"]
            if isNotifyEnabled(ntfy) and isAboveThreshold(ntfy, fillPct) then
                fillClr = ntfy.color or fillClr
                notifyLevel = math.max(notifyLevel, ntfy.level)
            end
        elseif SpecializationUtil.hasSpecialization(Combine, obj.specializations) then
          local ntfy = Glance.notifications["grainTankFull"]
          if isNotifyEnabled(ntfy) then
              local isAbove = isAboveThreshold(ntfy, fillPct)
              if isAbove then
                  fillClr = ntfy.color or fillClr
                  notifyLevel = math.max(notifyLevel, ntfy.level)
              end
              -- For combines, when hired and grain-tank full, blink the icon.
              if veh.mapAIHotspot ~= nil then
                  veh.mapAIHotspot:setBlinking(isAbove)
              end
          end
        end
        --
        updateFill(fillTpe,obj.capacity,obj.fillLevel,fillClr)
      elseif SpecializationUtil.hasSpecialization(Trailer, obj.specializations) then
        updateFill("n/a",obj.capacity,0,fillClr)
      end;
    end;
--[[
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
--]]
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
    if g_currentMission.showHelpText or g_currentMission.ingameMap.isFullSize then
        return
    end
    --
    self.helpButtonsTimeout = g_currentMission.time + 7500;

    --
    local xPos = 0.0;
    local yPos = Glance.cStartLineY - Glance.cLineSpacing;
    local timeSec = math.floor(g_currentMission.time / 1000);

    if Glance.textMinLevelTimeout ~= nil and Glance.textMinLevelTimeout > g_currentMission.time then
        setTextAlignment(RenderText.ALIGN_LEFT);
        setTextBold(true);
        Glance.renderTextShaded(xPos, yPos, Glance.cFontSize, string.format(g_i18n:getText("GlanceMinLevel"), Glance.minNotifyLevel), Glance.cFontShadowOffs, {1,1,1,1}, Glance.colors[Glance.cFontShadowColor]);
        yPos = yPos - Glance.cLineSpacing;
    end

    setTextBold(false);

--[[
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
--]]

    if self.linesNonVehicles then
        for _,lineNonVehicles in ipairs(self.linesNonVehicles) do
            local delimWidth = getTextWidth(Glance.cFontSize, Glance.nonVehiclesSeparator);
            xPos = 0.0;
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
                    xPos = self.linesVehicles[1][c].pos;
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
        log("Event-Write: ",netId," ",props)
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
        log("Event-Read: ",netId," ",props)
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


print(string.format("Script loaded: Glance.lua (v%s)", Glance.version));
