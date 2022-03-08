Using this MATLAB app you can create bode plots of phase and magnitude/attenuation.
So far only using a Rigol DS1000Z series oscilloscope and an Rigol DG1000Z series arbitrary function generator connected via LAN.
The app uses the Visa protocoll over TCP/IP. Any other connection could however easily be made with some simple modifications.

Requirements:
- Matlab R2006b or higher (theoretically)
- Instrument Control Toolbox
- IVI Drivers:
	- https://www.rigol.eu/En/Index/listView/catid/28/tp/9/p/2		    (DS1000Z)
	- https://www.rigol.eu/En/Index/listView/catid/28/tp/9/cat/6/wd/    (DG1000Z)

Physical wiring:
function gen. CH1 -> BNC T-splitter -> Osc. CH1 & DUT input
DUT output -> Osc. CH2

Check probe attenuation settings to match setup!

Notes:
- All commands are case-insensitive and can be appreviated to only the
  capital letters for example :MEASure:ADISplay? can be abbreviated to
  :MEAS:ADIS?
- A query "?" must always be followed by a fread(), the "?" is placed after
  the highest-level keyword
