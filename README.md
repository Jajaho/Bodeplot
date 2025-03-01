# Bode Plots using MATLAB & Rigol 1000 Series gear
![gui](https://user-images.githubusercontent.com/28218941/157631414-a55477ee-ffc0-4c8d-96af-5da1d0fa22a3.png)
This repository consists out of a MATLAB® script that provides the measurement capabilities and a MATLAB® app providing access to the script via a GUI.
Using this app or also just with the script you can create Bode plots of phase and magnitude/attenuation.
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
Sirst create a measurement object using the class constructor with or without arguments:    
```
m1 = Measurement()    
```
Afterwards you can set the measurement parameters:
```
m1.samples = 50;
m1.fstart = 1000;
m1.ftsop = 1e+6;
```
Take the measurement:    
```
m1.makeMeasurement('scopeIp', 'fgenIp')    
```
To get the progress state of the data acquisition [%], use:
```
m1.progress  
```
If someting goes wrong, the measurement can be aborted using:
```
m1.abortMeasurement
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
