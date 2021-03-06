loadscript cozDualVolt
-- $Title: Dual Voltage
-- $Product: DAQ6510, DMM6500
-- $Tag: Dual Voltage, Ratio, Noise
-- $Description: Uses ratio feature to diplay both input and sense voltage values
-- $Requires: v1.0.01f
-- $Icon: dualvolt_icon
-- Last Updated: $Date: 2019/2/3
--[[
Script: cozDualVolt.tspa
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
local BUFLEN = 1000000

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
sampleNo = 1

function ValuePrefix(value, short)
	if type(value)~="number" then return "NaN", "" end
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
	beeper.beep(0.1, 1000) -- to make sure this is executed
	noiseWindowSize = val
	nextNoiseSample = dualIn.endindex+noiseWindowSize
end

function onNoiseFormatChange(val)
	beeper.beep(0.1, 1000)
	noiseFormat = val
	displayNoise()
end

function onClearBuffers()
	beeper.beep(0.1, 1000)

	tstate = trigger.model.state()
	if tstate==trigger.STATE_RUNNING or tstate==trigger.STATE_WAITING then
		trigger.model.abort()
		--trigger.model.pause()
	end
	waitcomplete()

	dualIn.clear()
	dualVi.clear()
	dualVr.clear()
	sampleNo = 1

	if tstate==trigger.STATE_RUNNING or tstate==trigger.STATE_WAITING then
		trigger.model.initiate()
		--trigger.model.resume()
	end
end

function onPresetChange(val)
	beeper.beep(0.1, 1000)

	tstate = trigger.model.state()
	if tstate==trigger.STATE_RUNNING or tstate==trigger.STATE_WAITING then
		trigger.model.abort()
		--trigger.model.pause()
	end
	waitcomplete()

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
	waitcomplete()

	if tstate==trigger.STATE_RUNNING or tstate==trigger.STATE_WAITING then
		trigger.model.initiate()
		--trigger.model.resume()
	end
end

function onOpenSettings()
	beeper.beep(0.1, 1000)
	display.changescreen(settingsId) 
end

function onCloseSettings()
	beeper.beep(0.1, 1000)
	display.changescreen(display.SCREEN_HOME) --TODO: does this leak? 
    --display.delete(settingsId)
    --delay() -- Needed to allow change to cozDualVoltSwipeId?
    --display.changescreen(cozDualVoltSwipeId)
end

function onStartStop()
	beeper.beep(0.1, 1000)
	if trigger.model.state()==trigger.STATE_RUNNING then
		trigger.model.abort()
	else
		trigger.model.initiate()
	end
end

function createSettingsScreen()
	settingsId = display.create(display.ROOT, display.OBJ_SCREEN, 'Dual Voltage Settings')

	local noiseWindowId = display.create(settingsId, display.OBJ_EDIT_NUMBER, 200, 10, "Noise Window", "# of samples", display.NFORMAT_INTEGER, noiseWindowSize, 10, 10000, "")
	display.setevent(noiseWindowId, display.EVENT_PRESS, "onNoiseWindowChange(%value)")

    local noiseTypeId = display.create(settingsId, display.OBJ_EDIT_OPTION, 200, 90, "Noise Format", "Noise Reporting Format", "ppm", "Vp-p")
    display.setevent(noiseTypeId, display.EVENT_PRESS, "onNoiseFormatChange(%value)")
    display.setvalue(noiseTypeId, noiseFormat)    

    local presetId = display.create(settingsId, display.OBJ_EDIT_OPTION, 200, 170, "Presets", "Sampling Presets", "As Is", "Fast", "Medium", "Slow", "Slow Filter")
    display.setevent(presetId, display.EVENT_PRESS, "onPresetChange(%value)")
    display.setvalue(presetId, presetNo)

    local closeSettingsId = display.create(settingsId, display.OBJ_BUTTON, 350, 360,  "Back")
    display.setevent(closeSettingsId, display.EVENT_PRESS, "onCloseSettings()")

    local endAppId = display.create(settingsId, display.OBJ_BUTTON, 400, 10,  "End App")
    display.setevent(endAppId, display.EVENT_PRESS, "onExit()")
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
    display.setevent(settings_button_id, display.EVENT_PRESS, "onOpenSettings()")

    -- Clear Buffers button
    clearBuffersId = display.create(cozDualVoltSwipeId, display.OBJ_BUTTON, 625, 70,  "Buf. Clear")
    display.setevent(clearBuffersId, display.EVENT_PRESS, "onClearBuffers()")  

    -- Start/Stop
    startId = display.create(cozDualVoltSwipeId, display.OBJ_BUTTON, 625, 130,  "Start/Stop")
    display.setevent(startId, display.EVENT_PRESS, "onStartStop()")  

	display.changescreen(display.SCREEN_HOME) -- Go to the newly created screen
    display.changescreen(cozDualVoltSwipeId)
end

function deleteMainScreen()
	display.clear(cozDualVoltSwipeId) 
	collectgarbage()
	--display.changescreen(display.SCREEN_FUNCTIONS_SWIPE)
	--waitcomplete()
		
	-- BUG: this doesn't remove the swipe from the home screen and orphan screen seems to 
	-- crash the DMM
	display.delete(cozDualVoltSwipeId)
	
	collectgarbage()
	--waitcomplete()
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
		local v1ppm = 0 
		local v2ppm = 0
		if lastminv1!=lastmaxv1 then
			v1ppm = 2e6*(lastmaxv1 - lastminv1)/(lastmaxv1+lastminv1)
		end
		if lastminv2!=lastmaxv2 then
			v2ppm = 2e6*(lastmaxv2 - lastminv2)/(lastmaxv2+lastminv2)		
		end
		s1 = string.format("%.3f ppm", v1ppm)
		s2 = string.format("%.3f ppm", v2ppm)
	else
		local v1valstr, v1pref = ValuePrefix(lastmaxv1 - lastminv1, true)
		local v2valstr, v2pref = ValuePrefix(lastmaxv2 - lastminv2, true)
		s1 = string.format("%s %sVp-p", v1valstr, v1pref)
		s2 = string.format("%s %sVp-p", v2valstr, v2pref)
	end

	display.settext(vInNoiseId, s1)
	display.settext(vSenseNoiseId, s2)
end

function createBuffers()
	-- create a reading buffer with extra field to hold the sense voltage
	dualIn = buffer.make(BUFLEN, buffer.STYLE_FULL)
	dualIn.fillmode = buffer.FILL_ONCE

	--create two writable buffers to store computed voltages
	--buffer.unit(buffer.UNIT_CUSTOM1, "Vi") 
	--buffer.unit(buffer.UNIT_CUSTOM2, "Vr") --unfortunately stats don't work with CUSTOM2 unit. CUSTOM1 is fine. BUG?
	dualVi = buffer.make(BUFLEN, buffer.STYLE_WRITABLE)
	dualVr = buffer.make(BUFLEN, buffer.STYLE_WRITABLE)
	buffer.write.format(dualVi, buffer.UNIT_VOLT, buffer.DIGITS_8_5) -- you can't set reading buffers to 8.5 digit 
	buffer.write.format(dualVr, buffer.UNIT_VOLT, buffer.DIGITS_8_5) -- but write buffers accept it (actually default is 8.5). YAY!!!
	dualVi.fillmode = buffer.FILL_ONCE
	dualVr.fillmode = buffer.FILL_ONCE
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

	-- Initiate readings
	trigger.model.load("Empty")
	--trigger.model.setblock(1, trigger.BLOCK_BUFFER_CLEAR, dualIn)
	--trigger.model.setblock(2, trigger.BLOCK_BUFFER_CLEAR, dualVi)
	--trigger.model.setblock(3, trigger.BLOCK_BUFFER_CLEAR, dualVr)

	trigger.model.setblock(1, trigger.BLOCK_DELAY_CONSTANT, 0.1)
	trigger.model.setblock(2, trigger.BLOCK_MEASURE_DIGITIZE, dualIn, 1)
	trigger.model.setblock(3, trigger.BLOCK_NOTIFY, trigger.EVENT_NOTIFY2)
	trigger.model.setblock(4, trigger.BLOCK_BRANCH_ALWAYS,  1)

	display.activebuffer = dualVi

	-- clear buffers (this seems to be needed but why?)
	onClearBuffers()
end

function ResetNoiseStats(resetLastToo)
	minv1 = 1e30	maxv1 = -1e30
	minv2 = 1e30	maxv2 = -1e30
	if resetLastToo then
		lastminv1 = 0 lastmaxv1 = 0
		lastminv2 = 0 lastmaxv2 = 0
	end
end

function setup()
	print("setup begin")
	--stats
	ResetNoiseStats(true)
	nextNoiseSample = noiseWindowSize	

	createBuffers()

	createSettingsScreen()
	
	--createMenu()	
	
	createMainScreen()

	setupDMM()

	createTimers()

	--start sampling 
	-- for some reason triggering is aborted when the script exits. Thus added start/stop button
	--trigger.model.initiate() 

	print("setup end")
end

function onExit()
	display.activebuffer = dualIn	
	deleteTimers() collectgarbage() delay(0.1)

	trigger.model.abort()
	waitcomplete()	

	 
	--DMM BUG: when the app is terminated, the swipe screen is left orpah which
	-- crashes the DMM upon display attempt. Try to implement a workaround by forcing
	-- the swipe parent to refresh
	-- UPDATE: doen't work!!! :(

	display.clear()
	display.settext(display.TEXT1, "Exiting cozDualVolt")
	display.clear()

	deleteMainScreen() 	--this leaves the orphan UI window which crashes the DMM
	--deleting the user swipe seems to work fine. Hoping this would force redraw
	display.delete(display.SCREEN_USER_SWIPE) 

	collectgarbage() 
	delay(0.1)

	print("cozDualVolt waiting complete")

	print("cozDualVolt terminated")
	exit()
end



function sample()
	--Read the value and compute individual voltages


	-- process the samples since the last visit
	local v1 = nil
	local v2 = nil
	while sampleNo < dualIn.endindex  do
		local i = sampleNo
		local ratio = dualIn.readings[i]
		v2 = dualIn.extravalues[i]
		--print(ratio, v2)
		v1 = v2 * ratio;

		--get sample details
		local fracsec = dualIn.fractionalseconds[i]
		local sec = dualIn.seconds[i]
		local sta = dualIn.statuses[i]
		--local unit 		= dualIn.units[n]
		--local extunit 	= dualIn.extravalueunits[n]
		--date = readBuf.dates[n]	
		--time = readBuf.times[n]
		--timestamp = readBuf.timestamps[n]

		--write computed values to v1 & v2 buffers
		buffer.write.reading(dualVi, v1, sec, fracsec, sta)
		buffer.write.reading(dualVr, v2, sec, fracsec, sta)
		sampleNo = sampleNo+1
	
		--update min & max
		if(v1 < minv1) then minv1 = v1 end
		if(v2 < minv2) then minv2 = v2 end
		if(v1 > maxv1) then maxv1 = v1 end
		if(v2 > maxv2) then maxv2 = v2 end

		-- compute peak-to-peak values every Nth sample
		if sampleNo>=nextNoiseSample then
			lastminv1 = minv1 lastmaxv1 = maxv1
			lastminv2 = minv2 lastmaxv2 = maxv2			
			ResetNoiseStats(false)
			nextNoiseSample = sampleNo+noiseWindowSize		
		end
	end

	--display the latest reading
	displayNoise()
	if(v1 and v2) then
		displayReadings(v1, v2)
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
	--[[
	while true do
		dmm.measure.read(dualIn)
		display.waitevent(0.1)
	end
	]]
end

setup()
main()

--[[]]

--endscript

loadimage dualvolt_icon cozDualVolt
iVBORw0KGgoAAAANSUhEUgAAADwAAAA8CAIAAAC1nk4lAAAACXBIWXMAAAsTAAALEwEAmpwY
AAAF0WlUWHRYTUw6Y29tLmFkb2JlLnhtcAAAAAAAPD94cGFja2V0IGJlZ2luPSLvu78iIGlk
PSJXNU0wTXBDZWhpSHpyZVN6TlRjemtjOWQiPz4gPHg6eG1wbWV0YSB4bWxuczp4PSJhZG9i
ZTpuczptZXRhLyIgeDp4bXB0az0iQWRvYmUgWE1QIENvcmUgNS42LWMxNDUgNzkuMTYzNDk5
LCAyMDE4LzA4LzEzLTE2OjQwOjIyICAgICAgICAiPiA8cmRmOlJERiB4bWxuczpyZGY9Imh0
dHA6Ly93d3cudzMub3JnLzE5OTkvMDIvMjItcmRmLXN5bnRheC1ucyMiPiA8cmRmOkRlc2Ny
aXB0aW9uIHJkZjphYm91dD0iIiB4bWxuczp4bXA9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFw
LzEuMC8iIHhtbG5zOnhtcE1NPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvbW0vIiB4
bWxuczpzdEV2dD0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL3NUeXBlL1Jlc291cmNl
RXZlbnQjIiB4bWxuczpkYz0iaHR0cDovL3B1cmwub3JnL2RjL2VsZW1lbnRzLzEuMS8iIHht
bG5zOnBob3Rvc2hvcD0iaHR0cDovL25zLmFkb2JlLmNvbS9waG90b3Nob3AvMS4wLyIgeG1w
OkNyZWF0b3JUb29sPSJBZG9iZSBQaG90b3Nob3AgQ0MgMjAxOSAoV2luZG93cykiIHhtcDpD
cmVhdGVEYXRlPSIyMDE5LTAyLTAzVDE4OjEwOjI1LTA4OjAwIiB4bXA6TWV0YWRhdGFEYXRl
PSIyMDE5LTAyLTAzVDE4OjEwOjI1LTA4OjAwIiB4bXA6TW9kaWZ5RGF0ZT0iMjAxOS0wMi0w
M1QxODoxMDoyNS0wODowMCIgeG1wTU06SW5zdGFuY2VJRD0ieG1wLmlpZDo5YzFjZDg4MC0z
Y2U4LTY4NDMtYWNiOC1lM2I4MDUxYjcyNDgiIHhtcE1NOkRvY3VtZW50SUQ9ImFkb2JlOmRv
Y2lkOnBob3Rvc2hvcDozMDViOGZjNi1lOWI2LWVlNDMtYmY1YS04MTdiNmI3YTlmY2EiIHht
cE1NOk9yaWdpbmFsRG9jdW1lbnRJRD0ieG1wLmRpZDpiNmY1NjNjNC1lOWRjLWJiNDYtOWFl
NC04ZGUxYjRlZDgwMDYiIGRjOmZvcm1hdD0iaW1hZ2UvcG5nIiBwaG90b3Nob3A6Q29sb3JN
b2RlPSIzIj4gPHhtcE1NOkhpc3Rvcnk+IDxyZGY6U2VxPiA8cmRmOmxpIHN0RXZ0OmFjdGlv
bj0iY3JlYXRlZCIgc3RFdnQ6aW5zdGFuY2VJRD0ieG1wLmlpZDpiNmY1NjNjNC1lOWRjLWJi
NDYtOWFlNC04ZGUxYjRlZDgwMDYiIHN0RXZ0OndoZW49IjIwMTktMDItMDNUMTg6MTA6MjUt
MDg6MDAiIHN0RXZ0OnNvZnR3YXJlQWdlbnQ9IkFkb2JlIFBob3Rvc2hvcCBDQyAyMDE5IChX
aW5kb3dzKSIvPiA8cmRmOmxpIHN0RXZ0OmFjdGlvbj0ic2F2ZWQiIHN0RXZ0Omluc3RhbmNl
SUQ9InhtcC5paWQ6OWMxY2Q4ODAtM2NlOC02ODQzLWFjYjgtZTNiODA1MWI3MjQ4IiBzdEV2
dDp3aGVuPSIyMDE5LTAyLTAzVDE4OjEwOjI1LTA4OjAwIiBzdEV2dDpzb2Z0d2FyZUFnZW50
PSJBZG9iZSBQaG90b3Nob3AgQ0MgMjAxOSAoV2luZG93cykiIHN0RXZ0OmNoYW5nZWQ9Ii8i
Lz4gPC9yZGY6U2VxPiA8L3htcE1NOkhpc3Rvcnk+IDwvcmRmOkRlc2NyaXB0aW9uPiA8L3Jk
ZjpSREY+IDwveDp4bXBtZXRhPiA8P3hwYWNrZXQgZW5kPSJyIj8+UWD5yAAAEV5JREFUaN7t
WAlwnEV2lmRZ9zGjue/70hzS3PeMZjQ6Rqd1n9ZhS5bkQ5ZtbMvybWww2BDbGJ+xcQw22CxH
MGAbSEJhoJJUsoRsaklRW5sC1y4UYXcTQgoIGyZf//8gZEmAtpYykNqu1l/vf//r11+/fu/r
HqUIhUKllc8RFslMPJGWW8gs4EqKBEo2i8tAF+u5KptAqOZIi7n5+flMdiFfwcq/tRUU5N/O
BsApWQXpplqBp1+m8LKkdiY631Dg7pOVNonUQQ5fn29pFBZX80uWiNiq3CJptrNXCgOhqVBg
LBBZCtUBdlZ+esptbghnyRKhrU0sMhfqyrlSB3NRRpqnX+4ZkMvdRQW8LE2IA9yw4ajzWPIc
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
endimage

cozDualVolt.save()

--[[]]
