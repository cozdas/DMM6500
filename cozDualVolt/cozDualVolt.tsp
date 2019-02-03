-- $Title: Dual Voltage
-- $Product: DAQ6510, DMM6500
-- $Tag: Dual Voltage, Ratio, Noise
-- $Description: Uses ratio feature to diplay both input and sense voltage values
-- $Requires: v1.0.01f
-- Last Updated: $Date: 2019/2/2
--[[
Script: Probe_Hold.tspa
Dual Voltage display using the voltage ratio capability of Keithlet DMM series
 
Read the values in a loop into a reading buffer, for each reading compute the individual
voltages using the ratio and the sense voltage which is available in the extra value field
of the reading buffer. Write those values to two new "writable" buffers which can be displayed
on the main screen or be plotted. Also computes the peak-to-peak noise in a moving window 
 
===================================================================================================
MIT License
Copyright (c) 2019 Cuneyt Ozdas 
see https://github.com/cozdas/DMM6500 for full info and updates
===================================================================================================
]]


-- TODO
-- check with the continious buffer behavior and get the indices from the buffer and get rid of the fixed-len loop
-- Play with timer based approach

-- following the hold probe example I first made this exit the application which keeps the things interactive
	-- and the display buttons operate properly but when the swipe screen is not visible the timer don't call the 
	-- callback function, does that when the swipe screen is visible. 
	-- making this normal script has its own handicaps, such as display buttons not calling the callbacks. There needs to be 
	-- a way to yield to message pump or such. I'll keep trying.

-- global constants
local BUFLEN = 50000

local PRESET_ASIS	=1
local PRESET_FAST	=2
local PRESET_MED	=3
local PRESET_SLOW	=4
local PRESET_SLOWFILTER=5

local NOISE_FMT_PPM	=1 -- part per million
local NOISE_FMT_VPP	=2 -- peak-to-peak Volts

-- global setting values
noiseWindowSize = 100
noiseFormat = NOISE_FMT_PPM
presetNo = PRESET_ASIS

-- global run time values
sampleNo = 0



function ValuePrefix(value, short)
	if value>=9.9e37 then return "OVR","" end 
		
	a = math.abs(value)
	p = ""
	v = value
	
	if a==0.0 then
		return "0.0", ""
	elseif a <1e-12 then
		v = v * 1e15
		p = "f"
	elseif a<1e-9 then
		v = v * 1e12
		p = "p"
	elseif a<1e-6 then
		v = v * 1e9
		p = "n"
	elseif a<1e-3 then
		v = v * 1e6
		p = "u"
	elseif a<1 then
		v = v * 1e3
		p = "m"
	elseif a>1e15 then
		v = v * 1e-15
		p = "P"
	elseif a>1e12 then
		v = v * 1e-12
		p = "T"
	elseif a>1e9 then
		v = v * 1e-9
		p = "G"
	elseif a>1e6 then
		v = v * 1e-6
		p = "M"
	elseif a>1e3 then
		v = v * 1e-3
		p = "k"
	end
	
	a = math.abs(v)
	--[[
	if(a<10.0) then
		return string.format("%.9f", v), p
	elseif (a<100.0) then
		return string.format("%.8f", v), p
	end
	]]
	if short then
		return string.format("%.2f", v), p
	end

	return string.format("%.9f", v), p
end	

-- event handlers
function onNoiseWindowChange(val)
	beeper.beep(0.1, 1000)
	noiseWindowSize = val
	nextNoiseSample = dualIn.endindex6+noiseWindowSize
end

function onNoiseFormatChange(val)
	beeper.beep(0.1, 1000)
	noiseFormat = val
end

function onClearBuffers()
	beeper.beep(0.1, 1000)
	dualIn.clear()
	dualVi.clear()
	dualVr.clear()
end

function onPresetChange(val)
	beeper.beep(0.1, 1000)
	--Fast
	if (val==PRESET_FAST) then
		--dmm.measure.offsetcompensation.enable = dmm.ON
		dmm.measure.nplc = 1
		dmm.measure.filter.enable = dmm.OFF
	end
	--Med
	if (val==PRESET_MED) then
		--dmm.measure.offsetcompensation.enable = dmm.ON
		dmm.measure.nplc = 2
		dmm.measure.filter.enable = dmm.ON
		dmm.measure.filter.type = dmm.FILTER_MOVING_AVG
		dmm.measure.filter.count = 10
	end
	--slow no filter
	if (val==PRESET_SLOW) then
		--dmm.measure.offsetcompensation.enable = dmm.ON
		dmm.measure.nplc = 15
		dmm.measure.filter.enable = dmm.OFF
	end
	--slow
	if (val==PRESET_SLOWFILTER) then
		--dmm.measure.offsetcompensation.enable = dmm.ON
		dmm.measure.nplc = 15
		dmm.measure.filter.enable = dmm.ON
		dmm.measure.filter.type = dmm.FILTER_MOVING_AVG
		dmm.measure.filter.count = 50
	end
end

--[[
function onCloseSettings()
	beeper.beep(0.1, 2000)
	display.changescreen(display.SCREEN_HOME)
    display.delete(settingsId)
    delay() -- Needed to allow change to cozDualVoltSwipeId?
    display.changescreen(cozDualVoltSwipeId)
    collectgarbage()
end
]]

function openSettingsScreen()
	settingsId = display.create(display.ROOT, display.OBJ_SCREEN, 'Dual Voltage Settings')

	local noiseWindowId = display.create(settingsId, display.OBJ_EDIT_NUMBER, 200, 10, "Noise Window", "# of samples", display.NFORMAT_INTEGER, noiseWindowSize, 10, 10000, "")
	display.setevent(noiseWindowId, display.EVENT_PRESS, "onNoiseWindowChange(%value)")

    local noiseTypeId = display.create(settingsId, display.OBJ_EDIT_OPTION, 200, 90, "Noise Format", "Noise Reporting Format", "ppm", "Vp-p")
    display.setevent(noiseTypeId, display.EVENT_PRESS, "onNoiseFormatChange(%value)")
    display.setvalue(noiseTypeId, noiseFormat)    

    local presetId = display.create(settingsId, display.OBJ_EDIT_OPTION, 200, 170, "Presets", "Sampling Presets", "As Is", "Fast", "Medium", "Slow", "Slow Filter")
    display.setevent(presetId, display.EVENT_PRESS, "onPresetChange(%value)")
    display.setvalue(presetId, presetNo)

    --local closeSettingsId = display.create(settingsId, display.OBJ_BUTTON, 350, 360,  "Back")
    --display.setevent(closeSettingsId, display.EVENT_PRESS, "onCloseSettings()")
end

--[[ 
			COLOR_EDIT_HELP -> 8421504 (number)
			COLOR_EDIT_TITLE -> 901375 (number)
			COLOR_MEASUREMENT -> 6485851 (number)
			COLOR_SCREEN_BACKGROUND -> 2573 (number)
			COLOR_SWIPE_BACKGROUND -> 1644825 (number)
			COLOR_VALUE_LABEL -> 294566 (number)
			COLOR_VALUE_VALUE -> 14737632 (number)

			FONT_HUGE -> display.FONT_HUGE (userdata)
			FONT_LARGE -> display.FONT_LARGE (userdata)
			FONT_MEDIUM -> display.FONT_MEDIUM (userdata)
			FONT_SMALL -> display.FONT_SMALL (userdata)


]]

function createMainScreen()
	-- Create swipe screen
	if not cozDualVoltSwipeId or type(cozDualVoltSwipeId)~="number" then
    	cozDualVoltSwipeId = display.create(display.SCREEN_HOME, display.OBJ_SWIPE, 'coz Dual Voltage')
    end
    print("cozDualVoltSwipeId=",cozDualVoltSwipeId)

    -- text fields for readings
    readingTitleId 	= display.create(cozDualVoltSwipeId, display.OBJ_TEXT, 140, 35,  "Reading", display.COLOR_VALUE_LABEL, display.FONT_LARGE)
    noiseTitleId 	= display.create(cozDualVoltSwipeId, display.OBJ_TEXT, 400, 35,  "Noise", display.COLOR_VALUE_LABEL, display.FONT_LARGE)

    vInNameId 	= display.create(cozDualVoltSwipeId, display.OBJ_TEXT, 12, 85,   "Input:", display.COLOR_VALUE_LABEL, display.FONT_LARGE)
    vSenseNameId= display.create(cozDualVoltSwipeId, display.OBJ_TEXT, 12, 135,   "Sense:", display.COLOR_VALUE_LABEL, display.FONT_LARGE)

    vInValId 	= display.create(cozDualVoltSwipeId, display.OBJ_TEXT, 140, 85,   "...", display.COLOR_MEASUREMENT, display.FONT_LARGE)
    vSenseValId = display.create(cozDualVoltSwipeId, display.OBJ_TEXT, 140, 135,  "...", display.COLOR_MEASUREMENT, display.FONT_LARGE)

    vInNoiseId 		= display.create(cozDualVoltSwipeId, display.OBJ_TEXT, 400, 85,   "...", display.COLOR_MEASUREMENT, display.FONT_MEDIUM)
    vSenseNoiseId 	= display.create(cozDualVoltSwipeId, display.OBJ_TEXT, 400, 135,  "...", display.COLOR_MEASUREMENT, display.FONT_MEDIUM)

    -- Settings button
    settings_button_id = display.create(cozDualVoltSwipeId, display.OBJ_BUTTON, 625, 10, "Settings")
    display.setevent(settings_button_id, display.EVENT_PRESS, "openSettingsScreen()")

    -- Clear Buffers button
    clearBuffersId = display.create(cozDualVoltSwipeId, display.OBJ_BUTTON, 625, 70,  "Buf. Clear")
    display.setevent(clearBuffersId, display.EVENT_PRESS, "onClearBuffers()")  

    -- Exit button
    --exitId = display.create(cozDualVoltSwipeId, display.OBJ_BUTTON, 625, 130,  "Exit")
    --display.setevent(exitId, display.EVENT_PRESS, "onExit()")  

	display.changescreen(display.SCREEN_HOME) -- Go to the newly created screen
    display.changescreen(cozDualVoltSwipeId)
end

function deleteMainScreen()
	display.clear(cozDualVoltSwipeId) 
	collectgarbage()
	display.changescreen(display.SCREEN_FUNCTIONS_SWIPE)
	waitcomplete()
		
	-- BUG: this doesn't remove the swipe from the home screen and orphan screen seems to 
	-- crash the DMM
	--display.delete(cozDualVoltSwipeId)
	
	collectgarbage()
	waitcomplete()
end

function createMenu()
 	menu = display.create(display.ROOT, display.OBJ_SCREEN_MENU, "Settings", "cozDualVolt")
	display.create(menu, display.OBJ_BUTTON_MENU, 0, 0, display.SCREEN_MEAS_SETTINGS)
	display.create(menu, display.OBJ_BUTTON_MENU, 1, 0, settingsId, "Settings")
end

function displayReadings(vIn, vRef)
	local v1valstr, v1pref = ValuePrefix(vIn)
	local v2valstr, v2pref = ValuePrefix(vRef)
		
	--display voltages
	local s1 = string.format("%s %sV", v1valstr, v1pref)
	local s2 = string.format("%s %sV", v2valstr, v2pref)

	display.settext(vInValId, s1)
	display.settext(vSenseValId, s2)
end
	
function displayNoise()
	local s1=""
	local s2=""
	if noiseFormat==NOISE_FMT_PPM then
		local v1ppm = 2e6*(maxv1 - minv1)/(maxv1+minv1)
		local v2ppm = 2e6*(maxv2 - minv2)/(maxv2+minv2)		
		s1 = string.format("%.3f ppm", v1ppm)
		s2 = string.format("%.3f ppm", v2ppm)
	else
		local v1valstr, v1pref = ValuePrefix(maxv1 - minv1, true)
		local v2valstr, v2pref = ValuePrefix(maxv2 - minv2, true)
		s1 = string.format("%s %sVp-p", v1valstr, v1pref)
		s2 = string.format("%s %sVp-p", v2valstr, v2pref)
	end

	display.settext(vInNoiseId, s1)
	display.settext(vSenseNoiseId, s2)
end

function createBuffers()
	-- create a reading buffer with extra field to hold the sense voltage
	dualIn = buffer.make(BUFLEN, buffer.STYLE_FULL)
	dualIn.fillmode = buffer.FILL_CONTINUOUS

	--create two writable buffers to store computed voltages
	--buffer.unit(buffer.UNIT_CUSTOM1, "Vi") 
	--buffer.unit(buffer.UNIT_CUSTOM2, "Vr") --unfortunately stats don't work with CUSTOM2 unit. CUSTOM1 is fine. BUG?
	dualVi = buffer.make(BUFLEN, buffer.STYLE_WRITABLE)
	dualVr = buffer.make(BUFLEN, buffer.STYLE_WRITABLE)
	buffer.write.format(dualVi, buffer.UNIT_VOLT, buffer.DIGITS_8_5) -- you can't set reading buffers to 8.5 digit 
	buffer.write.format(dualVr, buffer.UNIT_VOLT, buffer.DIGITS_8_5) -- but write buffers accept it (actually default is 8.5). YAY!!!
	dualVi.fillmode = buffer.FILL_CONTINUOUS
	dualVr.fillmode = buffer.FILL_CONTINUOUS
end

function createTimers()
	sampleTimerId = display.create(cozDualVoltSwipeId, display.OBJ_TIMER, 0.1, display.TIMER_FOREVER, "sample()")
	--sampleTimerId = display.create(display.SCREEN_HOME, display.OBJ_TIMER, 0.1, display.TIMER_FOREVER, "sample()")
	garbageTimerId = display.create(cozDualVoltSwipeId, display.OBJ_TIMER, 60, display.TIMER_FOREVER, "collectgarbage()")
end

function deleteTimers()
	display.delete(sampleTimerId)
	collectgarbage()
end

function setupDMM()
	--Set the measure function voltage ratio
	dmm.measure.func = dmm.FUNC_DCV_RATIO
	--dmm.measure.autorange = dmm.ON
	--dmm.measure.autozero.enable = dmm.ON

	display.activebuffer = dualVi
end

function ResetNoiseStats()
	minv1 = 1e30
	maxv1 = -1e30
	minv2 = 1e30
	maxv2 = -1e30
end

function setup()
	print("setup begin")
	createBuffers()

	openSettingsScreen()
	createMenu()	
	createMainScreen()

	setupDMM()
	createTimers()

	--stats
	ResetNoiseStats()
	v1pp = 0.0
	v2pp = 0.0	
	nextNoiseSample = noiseWindowSize
	print("setup end")
end

function onExit()
	deleteTimers() collectgarbage() delay(0.1)
	deleteMainScreen()  collectgarbage() delay(0.1)
	display.activebuffer = dualIn
	collectgarbage() 
	print("cozDualVolt waiting complete")
	waitcomplete()
	print("cozDualVolt terminated")
	exit()
end

function sample()

	--TODO: replace this logic with the buffer start-end pointer.
	sampleNo = sampleNo+1 

	--Read the value and compute individual voltages
	dmm.measure.read(dualIn)
	local n = dualIn.endindex
	local ratio = dualIn.readings[n]
	local v2 = dualIn.extravalues[n]
	local v1 = v2 * ratio;
	
	--write computed values to v1 & v2 buffers
	buffer.write.reading(dualVi, v1)
	buffer.write.reading(dualVr, v2)
	
	--update min & max
	if(v1 < minv1) then minv1 = v1 end
	if(v2 < minv2) then minv2 = v2 end
	if(v1 > maxv1) then maxv1 = v1 end
	if(v2 > maxv2) then maxv2 = v2 end

	displayReadings(v1, v2)
	
	-- report peak-to-peak values every Nth sample
	-- for some reason modulo operator % gives syntax err BUG?
	if sampleNo>=nextNoiseSample then
	
		displayNoise(v1pp, v2pp)

		ResetNoiseStats()
		nextNoiseSample = sampleNo+noiseWindowSize		
	end
end

function main()
	-- following the hold probe example I first made this exit the application which keeps the things interactive
	-- and the display buttons operate properly but when the swipe screen is not visible the timer don't call the 
	-- callback function, does that when the swipe screen is visible. 
	
	--coroutine.yield()
	--while true do
	--	trigger.timer[1].wait(1)
	--end
	--while true do
	--	display.waitevent(0.1)
	--	sample()
	--end
end



setup()
main()

--endscript
-- cozDualVolt.save()