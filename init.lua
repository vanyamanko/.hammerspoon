-- Exposes Hammerspoon's API over a local IPC socket, allowing any module
-- to be invoked directly from the terminal via the `hs` command.
require("hs.ipc")

-- Cycles backward through tabs the way Cmd+` cycles through application
-- windows — bound to Ctrl+` for a familiar "step back" gesture.
hs.hotkey.bind({"ctrl"}, "`", function()
    hs.eventtap.keyStroke({"ctrl", "shift"}, "tab")
end)

-- Opens IntelliJ IDEA's "Search Everywhere" with a single chord — invokes
-- Alt+F1 to reveal the file in the project tree, then presses 1 to select it.
hs.hotkey.bind({"alt"}, "P", function()
    hs.eventtap.keyStroke({"alt"}, "F1")
    hs.timer.usleep(100000)
    hs.eventtap.keyStroke({}, "1")
end)

-- Mirrors the custom sleep-mode toggle on the Caps Lock LED: polls the
-- SleepDisabled flag every half second and rewrites the LED accordingly,
-- and also re-reads it right after every input-source change so macOS
-- flicker doesn't win the race.
-- Keep strong global references: local init.lua variables and unreferenced
-- timers can be garbage-collected after configuration loading finishes.
capsSleepIndicator = {}
local capsLogger = hs.logger.new("capsSleep", "warning")

local function getDisablesleep()
    local out, success, reason, code = hs.execute("/usr/bin/pmset -g")
    if not success then
        error("pmset failed: " .. tostring(reason) .. " " .. tostring(code))
    end
    local value = out and out:match("SleepDisabled%s+(%S+)")
    if value ~= "0" and value ~= "1" then
        error("pmset returned no valid SleepDisabled value")
    end
    return value == "1"
end

local function applyCapsLED()
    local ok, err = xpcall(function()
        local sleepDisabled = getDisablesleep()
        -- Keep even a brief error visible for five seconds after it occurs.
        local errorVisible = capsSleepIndicator.errorUntil ~= nil
            and hs.timer.secondsSinceEpoch() < capsSleepIndicator.errorUntil
        if not hs.hid.led.set("caps", sleepDisabled or errorVisible) then
            error("Could not set Caps Lock LED")
        end
    end, debug.traceback)

    if ok then
        capsSleepIndicator.lastError = nil
    else
        capsSleepIndicator.errorUntil = hs.timer.secondsSinceEpoch() + 5
        if capsSleepIndicator.lastError ~= err then
            capsLogger.e(err)
        end
        capsSleepIndicator.lastError = err
        -- The LED API itself may be failing; protect this fallback as well.
        local ledOK, ledResult = pcall(hs.hid.led.set, "caps", true)
        if not ledOK or not ledResult then
            capsLogger.e("Could not light Caps Lock LED to signal the error")
        end
    end
end

capsSleepIndicator.inputSourceTimer = hs.timer.delayed.new(0.05, applyCapsLED)

capsSleepIndicator.inputSourceWatcher = hs.distributednotifications.new(
    function(name, object)
        capsSleepIndicator.inputSourceTimer:start()
    end,
    "com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"
)

capsSleepIndicator.inputSourceWatcher:start()

-- A transient callback error should not permanently stop polling.
capsSleepIndicator.pollTimer = hs.timer.new(0.5, applyCapsLED, true):start()
applyCapsLED()
