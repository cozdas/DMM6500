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

-- create a reading buffer with extra field to hold the sense voltage
readBuf = buffer.make(BUFLEN, buffer.STYLE_FULL)
readBuf.fillmode = buffer.FILL_CONTINUOUS

--create two writable buffers to store computed voltages
buffer.unit(buffer.UNIT_CUSTOM1, "Vi") 
buffer.unit(buffer.UNIT_CUSTOM2, "Vr") --unfortunately stats don't work with CUSTOM2 unit. CUSTOM1 is fine. BUG?
v1Buf = buffer.make(BUFLEN, buffer.STYLE_WRITABLE)
v2Buf = buffer.make(BUFLEN, buffer.STYLE_WRITABLE)
buffer.write.format(v1Buf, buffer.UNIT_VOLT, buffer.DIGITS_8_5) -- you can't set reading buffers to 8.5 digit 
buffer.write.format(v2Buf, buffer.UNIT_VOLT, buffer.DIGITS_8_5) -- but write buffers accept it (actually default is 8.5). YAY!!!
v1Buf.fillmode = buffer.FILL_CONTINUOUS
v2Buf.fillmode = buffer.FILL_CONTINUOUS

--Set the measure function voltage ratio
dmm.measure.func = dmm.FUNC_DCV_RATIO
dmm.measure.autorange = dmm.ON
dmm.measure.autozero.enable = dmm.ON

-- ask for the sampling parameters
opt = display.input.option("Sampling Params", "Use Current", "Fast", "Med", "Slow")
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
--slow
if (opt==display.BUTTON_OPTION4) then
	--dmm.measure.offsetcompensation.enable = dmm.ON
	dmm.measure.nplc = 10
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
display.activebuffer = v1Buf
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
	buffer.write.reading(v1Buf, v1)
	buffer.write.reading(v2Buf, v2)
	
	--update min & max
	if(v1 < minv1) then minv1 = v1 end
	if(v2 < minv2) then minv2 = v2 end
	if(v1 > maxv1) then maxv1 = v1 end
	if(v2 > maxv2) then maxv2 = v2 end
	
	--display voltages
	s2 = string.format("In:%02.7fV Ref:%02.7fV", v1, v2)
	display.settext(display.TEXT2, s2)

	-- report peak-to-peak values every Nth sample
	-- for some reason modulo operator % gives syntax err BUG?
	if (math.floor(x/NOISEWINDOW)*NOISEWINDOW)==x then
		v1pp = 2e6*(maxv1 - minv1)/(maxv1+minv1)
		v2pp = 2e6*(maxv2 - minv2)/(maxv2+minv2)
		
		s1 = string.format("I:%.2f, R:%.2f ppm", v1pp, v2pp)
		display.settext(display.TEXT1, s1)
		ResetNoiseStats()
	end
end

