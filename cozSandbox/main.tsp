-- playing with some API functions, mostly undocumented features

-- fan level
------------
--fan.level = fan.LEVEL_QUIET --fan.LEVEL_QUIET fan.LEVEL_NORMAL  

-- system info
--------------
--print(localnode.info())

-- Pixel read
-------------
pixel1 = ki.display.getpixel(200,370)
pixel2 = ki.display.getpixel(150,200)

print(pixel1)
print(pixel2)


-- menu
-------
menu = display.create(display.ROOT, display.OBJ_SCREEN_MENU, "Foo", "Bar", "Coz")
display.create(menu, display.OBJ_BUTTON_MENU, 0, 0, display.SCREEN_MEAS_SETTINGS)

-- object query
---------------



    
--[[
print("_____________ pairs(getmetatable(fan)) ____________")
i = 0
for key,value in ipairs(fan) do
    print("key: " .. key .. " value:" .. tostring(value) .. " type:" .. type(value))
    i=i+1
end
print("member count:" .. tostring(i))

print("_______________ pairs(getmetatable(display).Objects) ____________")
i = 0
for key,value in pairs(getmetatable(display).Objects) do
    print("key:" .. key .. " \tvalue:" .. tostring(value) .. " \ttype:" .. type(value))
    i=i+1
end
print("member count:" .. tostring(i))

print("display.Objects")
print(display.Objects)
]]--

-- Pixel write
--ki.display.setpixel(150,200, 0xFFFFFF)

-- Create Screen
screenID = display.create(display.ROOT, display.OBJ_SCREEN_HOME, "CozTest")

-- drawing
display.create(screenID, display.OBJ_CIRCLE, 200,200,100)
display.create(screenID, display.OBJ_LINE, 200,200,100,100)


