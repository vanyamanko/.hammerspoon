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
local function getDisablesleep()
    local out = hs.execute("pmset -g | awk '/SleepDisabled/{print $2}'")
    return out and out:gsub("%s+", "") == "1"
end

local function applyCapsLED()
    hs.hid.led.set("caps", getDisablesleep())
end

local inputSourceWatcher = hs.distributednotifications.new(
    function(name, object)
        hs.timer.doAfter(0.05, applyCapsLED)
    end,
    "com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"
)

inputSourceWatcher:start()

hs.timer.new(0.5, applyCapsLED):start()
applyCapsLED()