//Get the file that you want to process (must be a single slice, single frame, multicolor image).
input = getDirectory("Choose Source Directory: ");
list = getFileList(input);

//specify output folder to save rois, "target" colorcoded images to show spacing of circles, and intensity meaasurements whic have the excel files
output = input + "rois/";
output2 = input + "target_hyperstacks/";
output3 = input + "IntensityMeasurements/";
File.makeDirectory(output);
File.makeDirectory(output2);
File.makeDirectory(output3);


// I recommend just using one tif in a folder at a time until you get comfortable with the code (it takes a few minutes to run each cell and you want to make sure it's doing what you think it is). That said, this should allow it to process as many tiffs as are in a folder.  IF processing lots of tifs, you might want to consider turning off the bit that makes the hyperstacks and doing more steps in set bath mode hide
for (i = 0; i< list.length; i++) {

		filename=list[i];
		NucToPM(input, filename);
	}
		
function NucToPM(dir,file){
	
	
	if (endsWith(file, ".tif")) {

		//  Pick the file and get the name
			L=lengthOf(file);
			filebase=substring(file,0,L-4);

		//  Open the file and make a working copy
			run("Bio-Formats", "open=" + input + filename + " autoscale color_mode=Default view=Hyperstack stack_order=XYCZT");
			imageID=getTitle();
			run("Split Channels"); // break up the individual channels
			selectWindow("C1-"+imageID+""); // select which ever channel is C1
		
		// --------------------------------------------------------------------------------------------------------------------
		//HERE WE SET PROCESS THE FIRST COLOR WHICH WILL HEREAFTER BE KNOWN AS C1. 256 STEPS WILL BE USED FOR THE UNWRAPPING
		n = 255; //number of slices
		//create stack of 256 slices form single image for C1.  We need to duplicate 255 times.  This number can be set to whatever you want and will govern the number of concentric rings.
		setBatchMode("hide");
		for (i = 0; i < n; i++) {
			run("Duplicate...", "title=C1");
		}
		//convert to stack with 256 slices for C1
		run("Images to Stack", "name=C1 title=C1 use");
		setBatchMode("exit and display");
		//-----------------------------------------------------------------------------------------------------------------
		
		
		
		
		// --------------------------------------------------------------------------------------------------------------------
		// HERE WE SET PROCESS THE SECOND COLOR WHICH WILL HEREAFTER BE KNOWN AS C1. 256 STEPS WILL BE USED FOR THE UNWRAPPING.  You can basically copy and npaste this but make it C3. I will eventually put all of this in a loop so the number of channels can be just set at the beginning.
		//Create stack of 256 slices for C2 (still using n =255 from above).
		selectWindow("C2-"+imageID+"");
		setBatchMode("hide");
		for (i = 0; i < n; i++) {
			run("Duplicate...", "title=C2");
		}
		//Convert to stack with 256 slices for C2
		run("Images to Stack", "name=C2 title=C2 use");
		setBatchMode("exit and display");
		//-----------------------------------------------------------------------------------------------------------------


		//Now we manually select the nucleus and the plasma membrane. Be sure to only hit ok after you have fully traced the structure.  Also make sure not to change the frame once you start.
		// THE SINGLE MOST IMPORTANT THING IS THAT THERE CAN'T BE ANYTHING IN THE ROI MANAGER WHEN YOU START THIS CODE OR IT WILL BE ERRONEOUSLY INCORPORATED INTO THE INTERPOLATION. I SHOULD PROBABLY WRITE SOMETHING TO MAKE SURE THIS NEVER HAPPENS BUT I HAVENT YET
		//This should be done on the ER channel or whatever channel easily lets you see the nucleus and PM.  The objective here is to create an ROI of the nucleus on slice 1 and an ROI of the plasma membrane on slice 256 then interpolate between them
		waitForUser ( "SelectImage","Select the image to trace the nucleus and plasma membrane");
		Stack.setSlice(1);			
		setTool("polygon"); // do your best to trace the nucleus. dont worry about sharp angles, this runs a fit spline command to make your annotation nice and SMOOOOOTH
		waitForUser ( "Nucleus","Trace the Nucleus");
		run("Fit Spline");
		roiManager("Add");
		run("Select None");	
		Stack.setSlice(256);
		waitForUser ( "ROI","Trace the cell you want to analyze");
		run("Fit Spline");
		roiManager("Add");	
		roiManager("Interpolate ROIs");	
		Stack.setSlice(1);	
		run("Select None");	
	
	
		//-----------------------------------------------------------------------------------------------------------------
		//In order to calculate the area and intensity of each ring we will slice the image into concentric polygons of increasing size. 
		//As a somewhat hacky solution we just clear outside of the selected slice, jump to the next slice (j+1) and clear a portion of the image the size of j.
		// so for j = 0, that is Roi 0 and we end up clear everything around the nucleus (which stays). I don't know if it's necessary or not, but better to keep it.  I'll just ignore the values later in the matlab analysis if i dont want them.
		// When we then iterate to the next value of j, we clear inside and now that gives a ring of intensity values surrounded by 0 value background
		// Roi value 254 corresponds to the second to last slice (255...the images are 1 indexed but the rois are 0 indexed which is annoying AF and I keep forgetting). This will give a stack with a nucleus in the first slice, 254 ring slices, and 1 final slice that has not been cropped..we'll handle that below.
	
		selectWindow("C1");
		resetMinAndMax();
		run("Add...", "value=1 stack"); // This will be important later to ensure that there are no 0 value pixels in the signal (which really should never happen but you never know... Airyscan and decon sometimes to weird things).  0 value will thus just be cropped background.  
		roiManager("Select", 0);
	for (j=0; j<255; j++) {
		roiManager("Select",j);
		run("Clear Outside", "slice");
		run("Next Slice [>]");
		run("Clear", "slice");
		}
		
		// This will clear the final area outside of the final slice to complete the picture
		roiManager("Select", 255);
		run("Clear Outside", "slice");

		run("32-bit"); // making it 32 bit so we can convert the 0 to nan background
		setAutoThreshold("Percentile dark");  // OK so this is important.  i worked out that this thresholding always worked for my test images...but it may not be the best way to do it.  Lots of other options works.  Your background is always equal to 0 and foreground is >0.
		run("NaN Background", "stack");
		run("Statistics"); // so you make the background not a number then get stats to get min and max values for the whole stack to set the display for the eventual 8 bit conversion
		MaxValueC1 = getResult("Max",0);
		print(MaxValueC1);
		MinValueC1 = getResult("Min",0);
		print(MinValueC1);
		setMinAndMax(MinValueC1, MaxValueC1);
		Table.rename("Results", "C1ThresholdedStackRawIntDen"); //This has the max and min info...we don't really need it but I wanted to rename the table
		
		//-----------
		selectWindow("C1");
		run("Set Measurements...", "area mean standard modal min integrated display nan redirect=None decimal=3");
		run("Measure Stack...");
		Table.rename("Results", "C1_IntensityInformation");
		saveAs("results", output3+filebase+"_C1Intensity.csv"); //This is the good stuff with intensity values.  You really only need to set area and integrated.
	// Sets the display range of the active image to min and max
		run("8-bit");
		run("Temporal-Color Code", "lut=BarberPoleRamp start=1 end=256");
	
	//-------------------------------------------------------------------------------------------------------
	//Just doing the same thing with the second channel
		selectWindow("C2");
		resetMinAndMax();
		run("Add...", "value=1 stack"); //ensuring no zero values in the signal
		roiManager("Select", 0);
		
	for (k=0; k<255; k++) {
		roiManager("Select",k);
		run("Clear Outside", "slice");
		run("Next Slice [>]");
		run("Clear", "slice");
		}
		// This will clear the final area outside of the final slice to complete the picture
		roiManager("Select", 255);
		run("Clear Outside", "slice");
		
		run("32-bit");
		setAutoThreshold("Percentile dark");
		run("NaN Background", "stack");
		run("Statistics");
		MaxValueC2 = getResult("Max",0);
		print(MaxValueC2);
		MinValueC2 = getResult("Min",0);
		print(MinValueC2);
		setMinAndMax(MinValueC2, MaxValueC2);
		Table.rename("Results", "C2ThresholdedStackRawIntDen");
		
		//-------------
		selectWindow("C2");
		run("Set Measurements...", "area mean standard modal min integrated display nan redirect=None decimal=1");
		run("Measure Stack...");
		Table.rename("Results", "C2_IntensityInformation");
		saveAs("results", output3+filebase+"_C2Intensity.csv");
		
		//scale intensity for display
		run("8-bit");
		run("Temporal-Color Code", "lut=BarberPoleRamp start=1 end=256"); // You can replace "Target" with any LUT installed. I'm including some funny radial ones that I made like "SunsetSplines" and "BarberPoleProper".
	

		
		run("Concatenate...", "open image1=MAX_colored image2=MAX_colored-1 image3=[-- None --]");
		saveAs("Tiff", output2+filebase+"_TargetImage");
		run("Concatenate...", "open image1=C1 image2=C2 image=[-- None --]");
		saveAs("Tiff", output2+filebase+"_CroppedImage");
		roiManager("Select", newArray(0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255));
		roiManager("Save", output+filebase+"All.zip")
}
}
