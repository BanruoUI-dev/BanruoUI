-- Bre/Core/Const.lua
-- Fixed UI metrics (main window size)

local addonName, Bre = ...
Bre = Bre or {}
Bre.Const = Bre.Const or {}

-- versioning
Bre.Const.VERSION = "2.19.41"

-- dev mode (default off)
-- You may enable via: /run Bre.Const.DEV_MODE=true
Bre.Const.DEV_MODE = false
Bre.Const.WIDTH  = 900
Bre.Const.HEIGHT = 650

-- legacy aliases (if any internal code uses old names)
Bre.Const.FRAME_W = Bre.Const.WIDTH
Bre.Const.FRAME_H = Bre.Const.HEIGHT
