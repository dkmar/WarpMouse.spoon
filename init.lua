local WarpMouse                = {}
WarpMouse.__index              = WarpMouse

-- Metadata
WarpMouse.name                 = "WarpMouse"
WarpMouse.version              = "0.1"
WarpMouse.author               = "Michael Mogenson"
WarpMouse.homepage             = "https://github.com/mogenson/WarpMouse.spoon"
WarpMouse.license              = "MIT - https://opensource.org/licenses/MIT"

local getCurrentScreen <const> = hs.mouse.getCurrentScreen
local absolutePosition <const> = hs.mouse.absolutePosition
local screenFind <const>       = hs.screen.find
local isPointInRect <const>    = hs.geometry.isPointInRect
WarpMouse.logger               = hs.logger.new(WarpMouse.name, 0)

-- a global variable that PaperWM can use to disable the eventtap while Mission Control is open
_WarpMouseEventTap             = nil

-- Tweakables ---------------------------------------------------------------
local BORDER = 1             -- border width to treat as "at the edge" (px)
local RESET_DISTANCE = 25    -- px you must travel *into* a display to re-arm warp
------------------------------------------------------------------------

local function relative_y(y, current_frame, new_frame)
    return new_frame.h * (y - current_frame.y) / current_frame.h + new_frame.y
end

local function warp(to)
    absolutePosition(to)
end

local function get_screen(cursor, frames)
    for index, frame in ipairs(frames) do
        if isPointInRect(cursor, frame) then
            return index, frame
        end
    end
    assert("cursor is not in any screen")
end

function WarpMouse:start()
    local screens = hs.screen.allScreens()

    table.sort(screens, function(a, b)
        -- sort list by screen postion top to bottom
        return select(2, a:position()) < select(2, b:position())
    end)

    for i, screen in ipairs(screens) do
        screens[i] = screen:fullFrame()
    end

    self.logger.f("Starting with screens from left to right: %s",
        hs.inspect(screens))

    -- can we warp?
    local warpEligible = true
    local screenID = get_screen(hs.mouse.absolutePosition(), screens)

    _WarpMouseEventTap = hs.eventtap.new({
        hs.eventtap.event.types.mouseMoved,
        hs.eventtap.event.types.leftMouseDragged,
        hs.eventtap.event.types.rightMouseDragged,
    }, function(event)
        local cursor = event:location()
        local frame = screens[screenID]
        if not warpEligible then
            warpEligible = (cursor.x > frame.x + RESET_DISTANCE) and (cursor.x < frame.x2 - RESET_DISTANCE)
            return false
        end

        if cursor.x <= frame.x + BORDER then
            local left_frame = screens[screenID - 1]
            if left_frame then
                warpEligible = false
                warp({ x = left_frame.x2 - 2, y = relative_y(cursor.y, frame, left_frame) })
                screenID = screenID - 1
                -- swallow stale position
                return true
            end
        elseif cursor.x > frame.x2 - BORDER then
            local right_frame = screens[screenID + 1]
            if right_frame then
                warpEligible = false
                warp({ x = right_frame.x + 1, y = relative_y(cursor.y, frame, right_frame) })
                screenID = screenID + 1
                -- swallow stale position
                return true
            end
        end
        return false
    end):start()

    self.screen_watcher = hs.screen.watcher.new(function()
        self.logger.d("Screen layout change")
        self:stop()
        self:start()
    end):start()
end

function WarpMouse:stop()
    self.logger.i("Stopping")

    if _WarpMouseEventTap then
        _WarpMouseEventTap:stop()
        _WarpMouseEventTap = nil
    end

    if self.screen_watcher then
        self.screen_watcher:stop()
        self.screen_watcher = nil
    end
end

return WarpMouse
