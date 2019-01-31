--Reset the Model DMM6500 to the default settings.
-- reset()

BUFLEN = 50000
NOISEWINDOW = 100

readBuf = buffer.make(BUFLEN, buffer.STYLE_FULL)
readBuf.fillmode = buffer.FILL_CONTINUOUS

--create a writable buffer to store computed voltages
dualBuf = buffer.make(BUFLEN, buffer.STYLE_WRITABLE_FULL)
buffer.write.format(dualBuf, buffer.UNIT_VOLT, buffer.DIGITS_8_5, buffer.UNIT_VOLT, buffer.DIGITS_8_5) --nice hack to display 7 digits on DMM6500
dualBuf.fillmode = buffer.FILL_CONTINUOUS

--Set the measure function voltage ratio
--dmm.measure.func = dmm.FUNC_DC_VOLTAGE
dmm.measure.func = dmm.FUNC_DCV_RATIO
dmm.measure.autorange = dmm.ON
dmm.measure.autozero.enable = dmm.ON

-- EXPERIMENTAL
display.activebuffer = dualBuf
display.changescreen(display.SCREEN_USER_SWIPE)

opt = display.input.option("Sampling Params", "Use Current", "Fast", "Med", "Slow")
--res = display.input.prompt(display.BUTTONS_YESNO, "Set Sampling Options")

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

minv1 = 1e9
maxv1 = -1e9
minv2 = 1e9
maxv2 = -1e9

v1pp = 0.0
v2pp = 0.0

display.settext(display.TEXT1, "p-p noise reading..")

for x=1,BUFLEN do

	--Read the resistance value.
	dmm.measure.read(readBuf)
	n = readBuf.n
	ratio = readBuf.readings[n]
	v2 = readBuf.extravalues[n]
	v1 = v2 * ratio;
	
	--write computed values to dualBuf
	buffer.write.reading(dualBuf, v1, v2)
	
	--compute min & max
	if(v1 < minv1) then minv1 = v1 end
	if(v2 < minv2) then minv2 = v2 end
	if(v1 > maxv1) then maxv1 = v1 end
	if(v2 > maxv2) then maxv2 = v2 end
	
	--display voltages
	s2 = string.format("In:%02.7fV Ref:%02.7fV", v1, v2)
	display.settext(display.TEXT2, s2)

	-- report peak-to-peak values every Nth sample
	-- for some reason modulo operator % gives syntax err 
	if (math.floor(x/NOISEWINDOW)*NOISEWINDOW)==x then
		v1pp = 2e6*(maxv1 - minv1)/(maxv1+minv1)
		v2pp = 2e6*(maxv2 - minv2)/(maxv2+minv2)
		
		s1 = string.format("I:%.2f, R:%.2f ppm", v1pp, v2pp)
		display.settext(display.TEXT1, s1)
		minv1 = 200.0
		maxv1 = -100.0
		minv2 = 200.0
		maxv2 = -100.0
	end
end

