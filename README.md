# Bode Plots using MATLAB & Rigol 1000 Series gear
Using this MATLAB® app/script you can create bode plots of phase and magnitude/attenuation.
So far only using a Rigol DS1000Z series oscilloscope and an Rigol DG1000Z series arbitrary function generator connected to the LAN.

## Requirements:
- Matlab R2006b or higher (theoretically)
- Instrument Control Toolbox
- IVI Drivers:
	- [DS1000Z](https://www.rigol.eu/En/Index/listView/catid/28/tp/9/p/2)
	- [DG1000Z](https://www.rigol.eu/En/Index/listView/catid/28/tp/9/cat/6/wd/)
- Note: In R2021a MathWorks introduced the visadev class which will replace the visa class used in this repository. However the decision was made to use the older class because it does not require any instrument support packages.

## Getting started
1. Install all requirements listed above, only explicitly listed requirements are needed.
2. Add bodeplott.mlapp and Measurement.m to your MATLAB path.
3. Launch bodeplott.mlapp via the app designer.
4. Replace the ip-addresses in the gui, here is where you find your instruments addresses:
	- On your DS1000Z series oscilloscope:
		- Press the 'Utility' button 
		- Select 'IO Setting' -> 'LAN Conf.'
	- On your DG1000Z function generator:
		- Press the 'Utility' button
		- Navigate 'I/O Config' -> 'LAN'
5. Package the app

Alternatively you can also use Measurement.m to take frequency response measurements on its own.    
To do so, first create a measurement object using the class constructor:    
```
m1 = Measurement()    
```
Take the measurement:    
```
m1.makeMeasurement('scopeIp', 'fgenIp')    
```
	
## Physical connection
- Function gen. CH1 -> BNC T-splitter -> Osc. CH1 & DUT input
- DUT output -> Osc. CH2

Check probe attenuation settings to match setup!

###### Notes:
- All SCPI commands are case-insensitive and can be appreviated to only the
  capital letters for example :MEASure:ADISplay? can be abbreviated to
  :MEAS:ADIS?
- A read command indicated by '?' must always be followed by a fread(), the "?" is placed after
  the highest-level keyword
