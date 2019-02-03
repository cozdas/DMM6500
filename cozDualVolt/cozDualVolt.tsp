-- Dual Voltage display using the voltage ratio capability of Keithlet DMM series
-- 
-- Read the values in a loop into a reading buffer, for each reading compute the individual
-- voltages using the ratio and the sense voltage which is available in the extra value field
-- of the reading buffer. Write those values to two new "writable" buffers which can be displayed
-- on the main screen or be plotted. Also computes the peak-to-peak noise in a moving window 
-- 
-- MIT License
-- Copyright (c) 2019 Cuneyt Ozdas 
-- see https://github.com/cozdas/DMM6500 for full info and updates

-- contants
BUFLEN = 50000
NOISEWINDOW = 100

function ValuePrefix(value)
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
	if(a<10.0) then
		return string.format("%.9f", v), p
	elseif (a<100.0) then
		return string.format("%.8f", v), p
	end
	
	return string.format("%.7f", v), p
end	



-- create a reading buffer with extra field to hold the sense voltage
readBuf = buffer.make(BUFLEN, buffer.STYLE_FULL)
readBuf.fillmode = buffer.FILL_CONTINUOUS

--create two writable buffers to store computed voltages
buffer.unit(buffer.UNIT_CUSTOM1, "Vi") 
buffer.unit(buffer.UNIT_CUSTOM2, "Vr") --unfortunately stats don't work with CUSTOM2 unit. CUSTOM1 is fine. BUG?
ViBuf = buffer.make(BUFLEN, buffer.STYLE_WRITABLE)
VrBuf = buffer.make(BUFLEN, buffer.STYLE_WRITABLE)
buffer.write.format(ViBuf, buffer.UNIT_VOLT, buffer.DIGITS_8_5) -- you can't set reading buffers to 8.5 digit 
buffer.write.format(VrBuf, buffer.UNIT_VOLT, buffer.DIGITS_8_5) -- but write buffers accept it (actually default is 8.5). YAY!!!
ViBuf.fillmode = buffer.FILL_CONTINUOUS
VrBuf.fillmode = buffer.FILL_CONTINUOUS

--Set the measure function voltage ratio
dmm.measure.func = dmm.FUNC_DCV_RATIO
dmm.measure.autorange = dmm.ON
dmm.measure.autozero.enable = dmm.ON

-- ask for the sampling parameters
opt = display.input.option("Sampling Params", "Use Current", "Fast", "Med Filter", "Slow", "Slow Filter")
--Fast
if (opt==display.BUTTON_OPTION2) then
	--dmm.measure.offsetcompensation.enable = dmm.ON
	dmm.measure.nplc = 1
	dmm.measure.filter.enable = dmm.OFF
end
--Med
if (opt==display.BUTTON_OPTION3) then
	--dmm.measure.offsetcompensation.enable = dmm.ON
	dmm.measure.nplc = 2
	dmm.measure.filter.enable = dmm.ON
	dmm.measure.filter.type = dmm.FILTER_MOVING_AVG
	dmm.measure.filter.count = 10
end
--slow no filter
if (opt==display.BUTTON_OPTION4) then
	--dmm.measure.offsetcompensation.enable = dmm.ON
	dmm.measure.nplc = 15
	dmm.measure.filter.enable = dmm.OFF
end
--slow
if (opt==display.BUTTON_OPTION5) then
	--dmm.measure.offsetcompensation.enable = dmm.ON
	dmm.measure.nplc = 15
	dmm.measure.filter.enable = dmm.ON
	dmm.measure.filter.type = dmm.FILTER_MOVING_AVG
	dmm.measure.filter.count = 50
end
function ResetNoiseStats()
	minv1 = 1e30
	maxv1 = -1e30
	minv2 = 1e30
	maxv2 = -1e30
end

-- reset Noise Stats
ResetNoiseStats()
v1pp = 0.0
v2pp = 0.0

-- Set Display
-- unfortunately I can't set the graph buffers programatically. Needs to be done manually 
display.activebuffer = ViBuf
display.settext(display.TEXT1, "p-p noise reading..")
display.changescreen(display.SCREEN_USER_SWIPE)

-- sample in a loop for interactive display
for x=1,BUFLEN do

	--Read the value and compute individual voltages
	dmm.measure.read(readBuf)
	n = readBuf.n
	ratio = readBuf.readings[n]
	v2 = readBuf.extravalues[n]
	v1 = v2 * ratio;
	
	--write computed values to v1 & v2 buffers
	buffer.write.reading(ViBuf, v1)
	buffer.write.reading(VrBuf, v2)
	
	--update min & max
	if(v1 < minv1) then minv1 = v1 end
	if(v2 < minv2) then minv2 = v2 end
	if(v1 > maxv1) then maxv1 = v1 end
	if(v2 > maxv2) then maxv2 = v2 end
	
	
	v1valstr, v1pref = ValuePrefix(v1)
	v2valstr, v2pref = ValuePrefix(v2)
	
	--display voltages
	s2 = string.format("Vi:%s%s Vr:%s%s", v1valstr, v1pref, v2valstr, v2pref)
	display.settext(display.TEXT2, s2)

	-- report peak-to-peak values every Nth sample
	-- for some reason modulo operator % gives syntax err BUG?
	if (math.floor(x/NOISEWINDOW)*NOISEWINDOW)==x then
		v1pp = 2e6*(maxv1 - minv1)/(maxv1+minv1)
		v2pp = 2e6*(maxv2 - minv2)/(maxv2+minv2)
		
		s1 = string.format("Vi:%.2f, Vr:%.2f ppm", v1pp, v2pp)
		display.settext(display.TEXT1, s1)
		ResetNoiseStats()
	end
end

